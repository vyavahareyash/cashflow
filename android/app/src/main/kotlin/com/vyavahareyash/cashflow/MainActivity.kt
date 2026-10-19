package com.vyavahareyash.cashflow

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.view.WindowManager
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val SECURITY_CHANNEL = "com.vyavahareyash.cashflow/security"
    private val SMS_CHANNEL = "com.vyavahareyash.cashflow/sms"

    companion object {
        private var smsMethodChannel: MethodChannel? = null
        private const val NOTIFICATION_CHANNEL_ID = "cashflow_transactions"
        private const val NOTIFICATION_ID = 42001

        fun notifySmsReceived(context: android.content.Context, sender: String, body: String, timestamp: Long) {
            val payload = mapOf(
                "sender" to sender,
                "body" to body,
                "timestamp" to timestamp.toString()
            )
            val channel = smsMethodChannel
            if (channel != null) {
                channel.invokeMethod("onSmsReceived", payload)
            }
        }

        fun showDraftNotification(context: android.content.Context, title: String, body: String) {
            val notificationManager = context.getSystemService(android.content.Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager ?: return

            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                val channel = android.app.NotificationChannel(
                    NOTIFICATION_CHANNEL_ID,
                    "Transaction Alerts",
                    android.app.NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Prompts to review and draft bank transactions from SMS"
                }
                notificationManager.createNotificationChannel(channel)
            }

            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("open_sms_drafts", true)
            }
            val pendingIntent = android.app.PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M)
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                else
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT
            )

            val notification = androidx.core.app.NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(title)
                .setContentText("Tap to review and add to Cashflow.")
                .setStyle(androidx.core.app.NotificationCompat.BigTextStyle().bigText(body))
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)
                .setPriority(androidx.core.app.NotificationCompat.PRIORITY_HIGH)
                .build()

            // Fixed notification ID so multiple alerts replace each other without bombardment
            notificationManager.notify(NOTIFICATION_ID, notification)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra("open_sms_drafts", false)) {
            smsMethodChannel?.invokeMethod("openSmsDrafts", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Security channel handler
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "authenticate" -> authenticate(result)
                    "canAuthenticate" -> canAuthenticate(result)
                    "setSecureFlag" -> {
                        val enable = call.argument<Boolean>("enable") ?: true
                        setSecureFlag(enable)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // SMS tracking channel handler
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
        smsMethodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermissions" -> {
                    val readGranted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.READ_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    val receiveGranted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.RECEIVE_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(readGranted && receiveGranted)
                }
                "requestPermissions" -> {
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS),
                        101
                    )
                    result.success(true)
                }
                "requestNotificationPermission" -> {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            102
                        )
                    }
                    result.success(true)
                }
                "showDraftNotification" -> {
                    val title = call.argument<String>("title") ?: "Transaction Detected"
                    val body = call.argument<String>("body") ?: "Tap to review"
                    showDraftNotification(this, title, body)
                    result.success(true)
                }
                "readInboxMessages" -> {
                    val days = (call.argument<Any>("days") as? Number)?.toInt() ?: 14
                    val startTimestamp = (call.argument<Any>("startTimestamp") as? Number)?.toLong()
                    val endTimestamp = (call.argument<Any>("endTimestamp") as? Number)?.toLong()
                    val messages = readSmsInbox(days = days, startTimestamp = startTimestamp, endTimestamp = endTimestamp)
                    result.success(messages)
                }
                else -> result.notImplemented()
            }
        }

        if (intent?.getBooleanExtra("open_sms_drafts", false) == true) {
            channel.invokeMethod("openSmsDrafts", null)
        }
    }

    private fun readSmsInbox(days: Int, startTimestamp: Long?, endTimestamp: Long?): List<Map<String, String>> {
        val messageList = mutableListOf<Map<String, String>>()
        val readGranted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.READ_SMS
        ) == PackageManager.PERMISSION_GRANTED
        if (!readGranted) return messageList

        val uri = Uri.parse("content://sms/inbox")
        val selection: String
        val selectionArgs: Array<String>

        if (startTimestamp != null && endTimestamp != null) {
            selection = "date >= ? AND date <= ?"
            selectionArgs = arrayOf(startTimestamp.toString(), endTimestamp.toString())
        } else if (startTimestamp != null) {
            selection = "date >= ?"
            selectionArgs = arrayOf(startTimestamp.toString())
        } else {
            val cutoffTime = System.currentTimeMillis() - (days.toLong() * 24 * 60 * 60 * 1000)
            selection = "date >= ?"
            selectionArgs = arrayOf(cutoffTime.toString())
        }

        try {
            val cursor = contentResolver.query(
                uri,
                arrayOf("address", "body", "date", "date_sent"),
                selection,
                selectionArgs,
                "date DESC"
            )

            cursor?.use {
                val addressIdx = it.getColumnIndex("address")
                val bodyIdx = it.getColumnIndex("body")
                val dateIdx = it.getColumnIndex("date")
                val dateSentIdx = it.getColumnIndex("date_sent")

                while (it.moveToNext()) {
                    val address = if (addressIdx != -1) it.getString(addressIdx) ?: "" else ""
                    val body = if (bodyIdx != -1) it.getString(bodyIdx) ?: "" else ""
                    val dateSent = if (dateSentIdx != -1 && !it.isNull(dateSentIdx)) it.getLong(dateSentIdx) else 0L
                    val dateReceived = if (dateIdx != -1 && !it.isNull(dateIdx)) it.getLong(dateIdx) else 0L
                    val timestamp = if (dateSent > 0L) dateSent.toString() else dateReceived.toString()

                    messageList.add(
                        mapOf(
                            "sender" to address,
                            "body" to body,
                            "timestamp" to timestamp
                        )
                    )
                }
            }
        } catch (_: Exception) {}

        return messageList
    }

    private fun authenticate(result: MethodChannel.Result) {
        val executor = ContextCompat.getMainExecutor(this)
        val biometricPrompt = BiometricPrompt(
            this,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                    result.success(true)
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    if (errorCode == BiometricPrompt.ERROR_USER_CANCELED ||
                        errorCode == BiometricPrompt.ERROR_NEGATIVE_BUTTON ||
                        errorCode == BiometricPrompt.ERROR_CANCELED) {
                        result.success(false)
                    } else {
                        result.error("AUTH_ERROR", errString.toString(), errorCode)
                    }
                }

                override fun onAuthenticationFailed() {
                    // BiometricPrompt handles retries automatically
                }
            }
        )

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Unlock Cashflow")
            .setSubtitle("Verify your identity to access your finances")
            .setAllowedAuthenticators(
                BiometricManager.Authenticators.BIOMETRIC_STRONG or
                BiometricManager.Authenticators.DEVICE_CREDENTIAL
            )
            .build()

        biometricPrompt.authenticate(promptInfo)
    }

    private fun canAuthenticate(result: MethodChannel.Result) {
        val biometricManager = BiometricManager.from(this)
        val canAuth = biometricManager.canAuthenticate(
            BiometricManager.Authenticators.BIOMETRIC_STRONG or
            BiometricManager.Authenticators.DEVICE_CREDENTIAL
        )
        result.success(canAuth == BiometricManager.BIOMETRIC_SUCCESS)
    }

    private fun setSecureFlag(enable: Boolean) {
        if (enable) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
