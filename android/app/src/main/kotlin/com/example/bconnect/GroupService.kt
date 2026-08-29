package com.example.bconnect

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder

/**
 * Keeps the process alive while a group is active.
 *
 * Android stops BLE advertising when the hosting app leaves the foreground.
 * Without this service a host that locks their screen silently drops the
 * group, and every member sees a connection loss.
 */
class GroupService : Service() {
    companion object {
        private const val CHANNEL_ID = "bconnect_group"
        private const val NOTIFICATION_ID = 1
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannel()

        val notification: Notification =
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("Group active")
                .setContentText("Bconnect is keeping your group open")
                .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
                .setOngoing(true)
                .build()

        startForeground(NOTIFICATION_ID, notification)
        // Do not restart with a null intent if the process is killed: the
        // group is gone by then and a notification with no group behind it
        // would be a lie.
        return START_NOT_STICKY
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Active group",
            NotificationManager.IMPORTANCE_LOW,
        )
        val manager = getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager
        manager.createNotificationChannel(channel)
    }
}
