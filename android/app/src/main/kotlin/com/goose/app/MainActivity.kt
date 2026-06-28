package com.goose.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goose.app.ui.AppShell
import com.goose.app.ui.theme.GooseTheme
import com.goose.app.viewmodel.AppViewModel

class MainActivity : ComponentActivity() {

    private val appViewModel: AppViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            GooseTheme {
                val connectionState by appViewModel.connectionState.collectAsStateWithLifecycle()
                val liveHeartRateBPM by appViewModel.liveHeartRateBPM.collectAsStateWithLifecycle()
                val recoveryScore by appViewModel.recoveryScore.collectAsStateWithLifecycle()
                val strainScore by appViewModel.strainScore.collectAsStateWithLifecycle()
                val sleepScore by appViewModel.sleepScore.collectAsStateWithLifecycle()
                val serverUrl by appViewModel.serverUrl.collectAsStateWithLifecycle()
                val uploadStatus by appViewModel.uploadStatus.collectAsStateWithLifecycle()

                AppShell(
                    connectionState = connectionState,
                    liveHeartRateBPM = liveHeartRateBPM,
                    recoveryScore = recoveryScore,
                    strainScore = strainScore,
                    sleepScore = sleepScore,
                    serverUrl = serverUrl,
                    onServerUrlChange = { appViewModel.setServerUrl(it) },
                    uploadStatus = uploadStatus,
                )
            }
        }
    }
}
