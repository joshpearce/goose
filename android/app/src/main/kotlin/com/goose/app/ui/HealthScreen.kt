package com.goose.app.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun HealthScreen(
    modifier: Modifier = Modifier,
    recoveryScore: Float?,
    strainScore: Float?,
    sleepScore: Float?,
) {
    Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            modifier = Modifier.padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("Health", style = MaterialTheme.typography.titleLarge)
            Text(
                text = "Recovery: ${recoveryScore?.let { "%.0f%%".format(it) } ?: "—"}",
                style = MaterialTheme.typography.bodyLarge,
            )
            Text(
                text = "Strain: ${strainScore?.let { "%.1f".format(it) } ?: "—"}",
                style = MaterialTheme.typography.bodyLarge,
            )
            Text(
                text = "Sleep: ${sleepScore?.let { "%.0f%%".format(it) } ?: "—"}",
                style = MaterialTheme.typography.bodyLarge,
            )
        }
    }
}
