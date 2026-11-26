package org.pecha.app

import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import co.ab180.airbridge.flutter.AirbridgeFlutter
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val NOTIFICATIONS_CHANNEL = "org.pecha.app/notifications"
        private const val APP_THEME_CHANNEL = "org.pecha.app/app_theme"
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return AudioServicePlugin.getFlutterEngine(context)
    }

    override fun onResume() {
        super.onResume()
        AirbridgeFlutter.trackDeeplink(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATIONS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openChannelSettings" -> {
                    val channelId = call.argument<String>("channelId")
                    if (channelId == null) {
                        result.error("ARG", "channelId required", null)
                        return@setMethodCallHandler
                    }
                    openChannelSettings(channelId)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_THEME_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setNightMode" -> {
                    val mode = call.argument<String>("mode")
                    if (mode == null) {
                        result.error("ARG", "mode required", null)
                        return@setMethodCallHandler
                    }
                    setAppNightMode(mode)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Saves the in-app theme with the system (Android 12+), so the system
     * launch screen draws in the app's theme rather than the phone's on the
     * next cold start. "system" hands the choice back to the phone.
     */
    private fun setAppNightMode(mode: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val uiModeManager = getSystemService(UiModeManager::class.java) ?: return
        val nightMode = when (mode) {
            "light" -> UiModeManager.MODE_NIGHT_NO
            "dark" -> UiModeManager.MODE_NIGHT_YES
            else -> UiModeManager.MODE_NIGHT_AUTO
        }
        uiModeManager.setApplicationNightMode(nightMode)
    }

    /**
     * Opens the OS notification settings page for a specific channel (Android 8+).
     * Falls back to the app-level notification settings on older devices.
     */
    private fun openChannelSettings(channelId: String) {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
            }
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.fromParts("package", packageName, null)
            }
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }
}
