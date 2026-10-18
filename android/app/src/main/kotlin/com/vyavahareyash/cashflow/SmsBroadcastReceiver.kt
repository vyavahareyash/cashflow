package com.vyavahareyash.cashflow

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsMessage

class SmsBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages: Array<SmsMessage>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            Telephony.Sms.Intents.getMessagesFromIntent(intent)
        } else {
            @Suppress("DEPRECATION")
            val bundle = intent.extras
            val pdus = bundle?.get("pdus") as? Array<*>
            pdus?.mapNotNull { pdu ->
                @Suppress("DEPRECATION")
                SmsMessage.createFromPdu(pdu as ByteArray)
            }?.toTypedArray()
        }

        if (messages.isNullOrEmpty()) return

        val fullBody = StringBuilder()
        val sender = messages[0].displayOriginatingAddress ?: ""
        val timestamp = messages[0].timestampMillis

        for (msg in messages) {
            fullBody.append(msg.displayMessageBody)
        }

        if (context != null) {
            MainActivity.notifySmsReceived(
                context = context,
                sender = sender,
                body = fullBody.toString(),
                timestamp = timestamp
            )
        }
    }
}
