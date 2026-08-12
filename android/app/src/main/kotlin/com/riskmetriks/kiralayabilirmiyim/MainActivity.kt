package com.riskmetriks.kiralayabilirmiyim

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import androidx.core.content.ContextCompat
import com.google.android.gms.auth.api.phone.SmsRetriever
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.Status
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL =
            "com.riskmetriks.kiralayabilirmiyim/sms_retriever"
    }

    private var methodChannel: MethodChannel? = null
    private var receiverRegistered = false

    private val smsReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != SmsRetriever.SMS_RETRIEVED_ACTION) {
                return
            }

            val extras = intent.extras ?: return

            @Suppress("DEPRECATION")
            val status = extras.get(SmsRetriever.EXTRA_STATUS) as? Status
                ?: return

            when (status.statusCode) {
                CommonStatusCodes.SUCCESS -> {
                    val message =
                        extras.getString(SmsRetriever.EXTRA_SMS_MESSAGE)

                    if (!message.isNullOrBlank()) {
                        methodChannel?.invokeMethod(
                            "smsRetrieved",
                            message
                        )
                    }

                    unregisterSmsReceiver()
                }

                CommonStatusCodes.TIMEOUT -> {
                    methodChannel?.invokeMethod(
                        "smsRetrieverTimeout",
                        null
                    )

                    unregisterSmsReceiver()
                }
            }
        }
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {

                "startSmsRetriever" -> {
                    registerSmsReceiver()

                    SmsRetriever
                        .getClient(this)
                        .startSmsRetriever()
                        .addOnSuccessListener {
                            result.success(true)
                        }
                        .addOnFailureListener { exception ->
                            unregisterSmsReceiver()

                            result.error(
                                "SMS_RETRIEVER_START_FAILED",
                                exception.message,
                                null
                            )
                        }
                }

                "stopSmsRetriever" -> {
                    unregisterSmsReceiver()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun registerSmsReceiver() {
        if (receiverRegistered) {
            return
        }

        val filter =
            IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION)

        ContextCompat.registerReceiver(
            this,
            smsReceiver,
            filter,
            SmsRetriever.SEND_PERMISSION,
            null,
            ContextCompat.RECEIVER_EXPORTED
        )

        receiverRegistered = true
    }

    private fun unregisterSmsReceiver() {
        if (!receiverRegistered) {
            return
        }

        try {
            unregisterReceiver(smsReceiver)
        } catch (_: IllegalArgumentException) {
            // Receiver zaten kaldırılmış olabilir.
        }

        receiverRegistered = false
    }

    override fun onDestroy() {
        unregisterSmsReceiver()
        methodChannel = null
        super.onDestroy()
    }
}
