package com.goose.app.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.goose.app.viewmodel.UploadState

@Composable
fun MoreScreen(
    modifier: Modifier = Modifier,
    serverUrl: String,
    onServerUrlChange: (String) -> Unit,
    uploadStatus: UploadState,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp),
    ) {
        Text(
            text = "Settings",
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(bottom = 16.dp),
        )
        Text(
            text = "Server URL",
            style = MaterialTheme.typography.labelMedium,
            modifier = Modifier.padding(bottom = 4.dp),
        )
        OutlinedTextField(
            value = serverUrl,
            onValueChange = onServerUrlChange,
            label = { Text("e.g. http://192.168.1.10:8000") },
            placeholder = { Text("http://your-server:8000") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
        )
        val statusText = when (uploadStatus) {
            is UploadState.Idle -> null
            is UploadState.Uploading -> "Uploading..."
            is UploadState.Success -> "Uploaded ${uploadStatus.count}"
            is UploadState.Error -> "Upload error: ${uploadStatus.msg}"
        }
        if (statusText != null) {
            Text(
                text = statusText,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
    }
}
