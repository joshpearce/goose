package com.goose.app.viewmodel

sealed class UploadState {
  object Idle : UploadState()
  object Uploading : UploadState()
  data class Success(val count: Int) : UploadState()
  data class Error(val msg: String) : UploadState()
}
