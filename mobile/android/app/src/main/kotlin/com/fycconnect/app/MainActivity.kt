package com.fycconnect.app

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

/**
 * The app, and one question it can answer about itself.
 *
 * Google Sign-In fails with DEVELOPER_ERROR (code 10) when it does not
 * recognise the pair (package name, signing certificate). Diagnosing that from
 * the outside means trusting a chain of assumptions — that the build installed
 * on this phone is the one CI published, signed with the key the workflow
 * printed, matching the fingerprint somebody typed into a console. Every link
 * looked right while sign-in kept failing, which means one of them was not.
 *
 * So the app reads its own certificate and says so. No inference, no chain:
 * the fingerprint the phone will present to Google, from the phone.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "signingSha1" -> result.success(signingSha1())
                    "packageName" -> result.success(packageName)
                    else -> result.notImplemented()
                }
            }
    }

    /** SHA-1 of the certificate this install is signed with, or null. */
    private fun signingSha1(): String? = try {
        val certificate: ByteArray? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageManager
                .getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                .signingInfo
                ?.apkContentsSigners
                ?.firstOrNull()
                ?.toByteArray()
        } else {
            @Suppress("DEPRECATION")
            packageManager
                .getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
                .signatures
                ?.firstOrNull()
                ?.toByteArray()
        }
        certificate?.let { bytes ->
            MessageDigest.getInstance("SHA-1")
                .digest(bytes)
                .joinToString(":") { "%02X".format(it) }
        }
    } catch (e: Exception) {
        null
    }

    private companion object {
        const val CHANNEL = "fyc/app_identity"
    }
}
