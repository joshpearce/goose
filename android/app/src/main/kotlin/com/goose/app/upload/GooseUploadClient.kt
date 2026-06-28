package com.goose.app.upload

import android.content.Context
import android.util.Log
import com.goose.app.bridge.GooseBridge
import com.goose.app.viewmodel.UploadState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/**
 * GooseUploadClient — uploads captured frames to the configured server (D-03).
 *
 * Uses HttpURLConnection (no external HTTP library).
 * Skips silently when serverUrl is empty (upload disabled).
 * Emits upload progress via [uploadState] StateFlow.
 *
 * Endpoint: POST {serverUrl}/v1/ingest-frames
 * Mirrors iOS GooseUploadService.swift ingest-frames endpoint.
 */
object GooseUploadClient {

  private const val TAG = "GooseUpload"

  private val _uploadState = MutableStateFlow<UploadState>(UploadState.Idle)
  val uploadState: StateFlow<UploadState> = _uploadState.asStateFlow()

  /**
   * Upload recent decoded streams to the configured server.
   *
   * Must be called from a background thread (Dispatchers.IO) — performs network I/O.
   *
   * @param context Android context for filesDir path
   * @param serverUrl Base server URL; empty string = skip upload
   */
  fun upload(context: Context, serverUrl: String) {
    if (serverUrl.isEmpty()) {
      Log.d(TAG, "Server URL not configured — skipping upload")
      return
    }

    _uploadState.value = UploadState.Uploading

    try {
      val dbPath = context.filesDir.absolutePath + "/goose.sqlite"

      // Fetch pending frames from Rust bridge
      val bridgeRequest = buildGetStreamsRequest(dbPath)
      val bridgeResponse = GooseBridge.safeHandle(bridgeRequest)
      val responseJson = JSONObject(bridgeResponse)

      if (!responseJson.optBoolean("ok", false)) {
        val errMsg = responseJson.optJSONObject("error")?.optString("message") ?: "bridge error"
        Log.d(TAG, "upload.get_recent_decoded_streams failed: $errMsg")
        _uploadState.value = UploadState.Error(errMsg)
        return
      }

      val result = responseJson.optJSONObject("result")
      if (result == null || result.length() == 0) {
        Log.d(TAG, "No pending frames to upload")
        _uploadState.value = UploadState.Success(0)
        return
      }

      // POST payload to server
      val count = result.length()
      val payload = result.toString().toByteArray(Charsets.UTF_8)
      val endpoint = "${serverUrl.trimEnd('/')}/v1/ingest-frames"
      val code = postToServer(endpoint, payload)
      _uploadState.value = if (code in 200..299) {
        UploadState.Success(count)
      } else {
        UploadState.Error("HTTP $code")
      }

    } catch (e: Exception) {
      Log.w(TAG, "Upload failed: ${e.message}")
      _uploadState.value = UploadState.Error(e.message ?: "upload failed")
    }
  }

  private fun buildGetStreamsRequest(dbPath: String): String {
    val args = JSONObject().apply { put("database_path", dbPath) }
    return JSONObject().apply {
      put("schema", "goose.bridge.request.v1")
      put("method", "upload.get_recent_decoded_streams")
      put("args", args)
    }.toString()
  }

  /**
   * POST [payload] to [endpoint] and return the HTTP response code,
   * or -1 on IOException.
   */
  private fun postToServer(endpoint: String, payload: ByteArray): Int {
    var conn: HttpURLConnection? = null
    return try {
      conn = URL(endpoint).openConnection() as HttpURLConnection
      conn.requestMethod = "POST"
      conn.setRequestProperty("Content-Type", "application/json")
      conn.setRequestProperty("Content-Length", payload.size.toString())
      conn.doOutput = true
      conn.connectTimeout = 10_000
      conn.readTimeout = 15_000

      conn.outputStream.use { it.write(payload) }

      val responseCode = conn.responseCode
      if (responseCode in 200..299) {
        Log.d(TAG, "Upload successful: HTTP $responseCode endpoint=$endpoint bytes=${payload.size}")
      } else {
        Log.w(TAG, "Upload HTTP error: $responseCode endpoint=$endpoint")
      }
      responseCode
    } catch (e: IOException) {
      Log.w(TAG, "Upload network error: ${e.message}")
      -1
    } finally {
      conn?.disconnect()
    }
  }
}
