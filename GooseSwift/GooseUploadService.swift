import Foundation
import OSLog

private let logger = Logger(subsystem: "com.goose.swift", category: "upload")

struct GooseUploadStatus {
  let lastUploadTimestamp: Date?
  let pendingBatchCount: Int
  let lastSyncedCount: Int?
  // Total rows with synced=0 across primary hr_samples stream.
  var pendingRowCount: Int = 0
}

final class GooseUploadService: @unchecked Sendable {
  private let rust = GooseRustBridge()
  private let databasePath: String
  private let session: URLSession

  // Protected by Swift's cooperative thread pool — only mutated from upload tasks
  private var lastUploadTimestamp: Date?
  private var pendingBatchCount: Int = 0
  private var lastSyncedCount: Int?
  private var pendingRowCount: Int = 0

  var onStatusUpdate: (@MainActor (GooseUploadStatus) -> Void)?

  init(databasePath: String) {
    self.databasePath = databasePath
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 15
    self.session = URLSession(configuration: config)
  }

  init(databasePath: String, session: URLSession) {
    self.databasePath = databasePath
    self.session = session
  }

  func upload(deviceID: UUID, deviceType: String, sinceTimestamp: Date) {
    pendingBatchCount += 1
    Task.detached(priority: .utility) { [weak self] in
      await self?.performUpload(deviceID: deviceID, deviceType: deviceType, sinceTimestamp: sinceTimestamp)
    }
  }

  private func performUpload(deviceID: UUID, deviceType: String, sinceTimestamp: Date) async {
    guard UserDefaults.standard.bool(forKey: RemoteServerStorage.uploadEnabled) else {
      pendingBatchCount = max(0, pendingBatchCount - 1)
      return
    }
    let rawURL = UserDefaults.standard.string(forKey: RemoteServerStorage.serverURL) ?? ""
    guard !rawURL.isEmpty, let baseURL = URL(string: rawURL) else {
      pendingBatchCount = max(0, pendingBatchCount - 1)
      return
    }
    guard let token = (try? RemoteServerKeychain.loadToken()) ?? nil, !token.isEmpty else {
      pendingBatchCount = max(0, pendingBatchCount - 1)
      return
    }

    // Fetch recent decoded streams from Rust bridge (synchronous — runs on detached task thread)
    let streamsResult: [String: Any]
    do {
      streamsResult = try rust.request(
        method: "upload.get_recent_decoded_streams",
        args: [
          "database_path": databasePath,
          "device_id": deviceID.uuidString,
          "since_ts": sinceTimestamp.timeIntervalSince1970,
        ]
      )
    } catch {
      logger.debug("upload.get_recent_decoded_streams failed: \(error)")
      pendingBatchCount = max(0, pendingBatchCount - 1)
      return
    }

    let hr = streamsResult["hr"] as? [Any] ?? []
    let rr = streamsResult["rr"] as? [Any] ?? []
    let events = streamsResult["events"] as? [Any] ?? []
    let battery = streamsResult["battery"] as? [Any] ?? []
    let spo2 = streamsResult["spo2"] as? [Any] ?? []
    let skinTemp = streamsResult["skin_temp"] as? [Any] ?? []
    let resp = streamsResult["resp"] as? [Any] ?? []
    let gravity = streamsResult["gravity"] as? [Any] ?? []

    let hasData = !hr.isEmpty || !rr.isEmpty || !events.isEmpty || !battery.isEmpty
      || !spo2.isEmpty || !skinTemp.isEmpty || !resp.isEmpty || !gravity.isEmpty
    guard hasData else {
      pendingBatchCount = max(0, pendingBatchCount - 1)
      return
    }

    let streams: [String: Any] = [
      "hr": hr, "rr": rr, "events": events, "battery": battery,
      "spo2": spo2, "skin_temp": skinTemp, "resp": resp, "gravity": gravity,
    ]
    let payload = buildUploadPayload(deviceID: deviceID, deviceType: deviceType, streams: streams)

    guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
      pendingBatchCount = max(0, pendingBatchCount - 1)
      return
    }

    var request = URLRequest(url: baseURL.appendingPathComponent("v1/ingest-decoded"))
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body

    // Retry with async backoff — no thread blocking
    let delays: [UInt64] = [1_000_000_000, 2_000_000_000, 4_000_000_000]
    var uploadSucceeded = false
    var syncedCount: Int?
    for attempt in 0..<3 {
      if attempt > 0 {
        try? await Task.sleep(nanoseconds: delays[attempt - 1])
      }
      if let count = await performRequest(request) {
        uploadSucceeded = true
        syncedCount = count
        break
      }
    }

    if uploadSucceeded {
      // Mark hr_samples rows as synced using the rowids from the recent decoded streams.
      // We use sync.rows_pending_upload to get the rowids of hr_samples rows that were just uploaded.
      markHrSamplesSynced(deviceID: deviceID, sinceTimestamp: sinceTimestamp)
      // Upload raw BLE frames alongside decoded streams. This enables a fresh iOS
      // install to reconstruct the trust chain via capture.import_frame_batch.
      await uploadRawFrames(deviceID: deviceID, sinceTimestamp: sinceTimestamp)
      // Advance the checkpoint only after both decoded and raw uploads have been attempted.
      lastUploadTimestamp = Date()
      lastSyncedCount = syncedCount
    } else {
      logger.warning("upload failed after 3 attempts — discarding batch")
    }
    pendingBatchCount = max(0, pendingBatchCount - 1)
    refreshPendingRowCount()
    publishStatus()
  }

  // Upload raw BLE frames to the server's /v1/ingest-frames endpoint.
  // Raw frames allow a fresh iOS install to rebuild the trust chain via
  // capture.import_frame_batch without requiring a BLE reconnection.
  private func uploadRawFrames(deviceID: UUID, sinceTimestamp: Date) async {
    guard UserDefaults.standard.bool(forKey: RemoteServerStorage.uploadEnabled) else { return }
    let rawURL = UserDefaults.standard.string(forKey: RemoteServerStorage.serverURL) ?? ""
    guard !rawURL.isEmpty, let baseURL = URL(string: rawURL) else { return }
    guard let token = (try? RemoteServerKeychain.loadToken()) ?? nil, !token.isEmpty else { return }

    let framesResult: [String: Any]
    do {
      framesResult = try rust.request(
        method: "upload.get_raw_frames_for_upload",
        args: [
          "database_path": databasePath,
          "since_ts": sinceTimestamp.timeIntervalSince1970,
          "limit": 2000,
        ]
      )
    } catch {
      logger.debug("upload.get_raw_frames_for_upload failed: \(error)")
      return
    }

    let frames = framesResult["frames"] as? [Any] ?? []
    guard !frames.isEmpty else { return }

    let deviceDict: [String: Any] = ["id": deviceID.uuidString, "mac": NSNull(), "name": NSNull()]
    let payload: [String: Any] = ["device": deviceDict, "frames": frames]
    guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

    var request = URLRequest(url: baseURL.appendingPathComponent("v1/ingest-frames"))
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body

    guard let (data, response) = try? await session.data(for: request),
          let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      logger.debug("uploadRawFrames: server error")
      return
    }
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let inserted = json["inserted"] as? Int {
      logger.debug("uploadRawFrames: inserted=\(inserted) frames since=\(sinceTimestamp)")
    }
  }

  private func performRequest(_ request: URLRequest) async -> Int? {
    guard let (data, response) = try? await session.data(for: request) else {
      logger.debug("upload request error")
      return nil
    }
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      if let http = response as? HTTPURLResponse {
        logger.debug("upload server error: \(http.statusCode)")
      }
      return nil
    }
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let upserted = json["upserted"] as? [String: Int] {
      return upserted.values.reduce(0, +)
    }
    return 0
  }

  // Pure payload builder — no async, no URLSession, no Rust bridge access.
  // Internal so GooseSwiftTests (@testable import GooseSwift) can call it directly.
  // WHOOP Gen4/Gen5 use device_generation with no device_class key.
  // HR monitors (default case) use device_type (sanitized BLE name) + device_class: "HR_MONITOR"
  // so the server can distinguish wearable class from model name (review HIGH-1, HIGH-3).
  func buildUploadPayload(
    deviceID: UUID,
    deviceType: String,
    streams: [String: Any]
  ) -> [String: Any] {
    let device: [String: Any] = ["id": deviceID.uuidString, "mac": NSNull(), "name": NSNull()]
    switch deviceType {
    case "GEN4":
      return [
        "device": device,
        "streams": streams,
        "device_generation": "4.0",
      ]
    case "GOOSE":
      return [
        "device": device,
        "streams": streams,
        "device_generation": "5.0",
      ]
    default:
      // device_type carries the model/name (pre-sanitized BLE advertised name),
      // device_class carries the wearable class so the server can distinguish class from model.
      return [
        "device": device,
        "streams": streams,
        "device_type": deviceType,
        "device_class": "HR_MONITOR",
      ]
    }
  }

  // Mark the hr_samples rows that were just uploaded as synced=1.
  // Uses sync.rows_pending_upload to get rowids, then sync.mark_synced.
  private func markHrSamplesSynced(deviceID: UUID, sinceTimestamp: Date) {
    do {
      let pendingReport = try rust.request(
        method: "sync.rows_pending_upload",
        args: [
          "database_path": databasePath,
          "stream": "hr_samples",
          "limit": 500,
        ]
      )
      let rows = pendingReport["rows"] as? [[String: Any]] ?? []
      let sinceTs = sinceTimestamp.timeIntervalSince1970
      let rowIds: [Int] = rows.compactMap { row in
        // Only mark rows from this device and in the upload window.
        guard let rowid = (row["rowid"] as? NSNumber)?.intValue ?? (row["rowid"] as? Int),
              let ts = (row["ts"] as? NSNumber)?.doubleValue ?? (row["ts"] as? Double),
              let deviceIdStr = row["device_id"] as? String,
              ts >= sinceTs,
              deviceIdStr == deviceID.uuidString else {
          return nil
        }
        return rowid
      }
      guard !rowIds.isEmpty else { return }
      _ = try rust.request(
        method: "sync.mark_synced",
        args: [
          "database_path": databasePath,
          "stream": "hr_samples",
          "row_ids": rowIds,
        ]
      )
      logger.debug("sync.mark_synced: marked \(rowIds.count) hr_samples rows")
    } catch {
      logger.debug("sync.mark_synced failed: \(error)")
    }
  }

  // Query the total pending row count (hr_samples only) for the badge.
  func refreshPendingRowCount() {
    do {
      let report = try rust.request(
        method: "sync.rows_pending_upload",
        args: [
          "database_path": databasePath,
          "stream": "hr_samples",
          "limit": 10_000,
        ]
      )
      let rows = report["rows"] as? [[String: Any]] ?? []
      pendingRowCount = rows.count
    } catch {
      pendingRowCount = 0
    }
  }

  // Trigger manual backfill + upload of all pending streams.
  // Called from the More tab "Sync pendente" button.
  func triggerBackfill(deviceID: UUID, sinceTimestamp: Date) {
    Task.detached(priority: .utility) { [weak self] in
      guard let self else { return }
      // Call sync.backfill_streams to populate hr_samples/rr_intervals from decoded_frames.
      let end = Date().timeIntervalSince1970
      let start = sinceTimestamp.timeIntervalSince1970
      do {
        let report = try rust.request(
          method: "sync.backfill_streams",
          args: [
            "database_path": databasePath,
            "device_id": deviceID.uuidString,
            "start_ts": start,
            "end_ts": end,
          ]
        )
        let hrInserted = (report["hr_inserted"] as? Int) ?? 0
        logger.debug("sync.backfill_streams: hr_inserted=\(hrInserted)")
      } catch {
        logger.debug("sync.backfill_streams failed: \(error)")
      }
      await performUpload(deviceID: deviceID, deviceType: "GOOSE", sinceTimestamp: sinceTimestamp)
    }
  }

  private func publishStatus() {
    let status = GooseUploadStatus(
      lastUploadTimestamp: lastUploadTimestamp,
      pendingBatchCount: pendingBatchCount,
      lastSyncedCount: lastSyncedCount,
      pendingRowCount: pendingRowCount
    )
    Task { @MainActor [weak self] in
      self?.onStatusUpdate?(status)
    }
  }
}
