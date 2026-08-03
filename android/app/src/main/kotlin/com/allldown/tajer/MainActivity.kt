package com.allldown.tajer

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.allldown.tajer/signature"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getSignature") {
                val signature = getAppSignature()
                if (signature != null) {
                    result.success(signature)
                } else {
                    result.error("UNAVAILABLE", "Signature not available.", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getAppSignature(): String? {
        try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
            }

            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.signingInfo.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                packageInfo.signatures
            }

            if (signatures != null && signatures.isNotEmpty()) {
                val md = MessageDigest.getInstance("SHA-1")
                md.update(signatures[0].toByteArray())
                val digest = md.digest()
                return digest.joinToString(":") { String.format("%02X", it.toInt() and 0xFF) }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }
}
