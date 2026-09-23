package com.vyavahareyash.cashflow

import android.view.WindowManager
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.vyavahareyash.cashflow/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
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
                    // Individual attempt failed; BiometricPrompt retries automatically
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
