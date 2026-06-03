import Foundation


extension GooseAppModel {

  func configureUploadService() {
    uploadService.onStatusUpdate = { [weak self] status in
      // Called on @MainActor via DispatchQueue.main.async in GooseUploadService
      self?.uploadLastTimestamp = status.lastUploadTimestamp
      self?.uploadPendingBatchCount = status.pendingBatchCount
    }
  }

  func triggerUpload(for result: CaptureFrameWriteResult, deviceEvent: GooseNotificationEvent) {
    guard result.pass, result.errorDescription == nil else { return }
    // sinceTimestamp: 30 seconds ago covers the batch window generously
    let sinceTimestamp = Date().addingTimeInterval(-30)
    uploadService.upload(
      deviceID: deviceEvent.deviceID,
      deviceType: deviceEvent.rustDeviceType,
      sinceTimestamp: sinceTimestamp
    )
  }
}
