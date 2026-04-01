package vn.clickon.jobnew

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "vn.clickon.jobnew/device_identity"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceId" -> {
                    val deviceId = Settings.Secure.getString(
                        contentResolver,
                        Settings.Secure.ANDROID_ID
                    )
                    result.success(deviceId?.uppercase())
                }

                else -> result.notImplemented()
            }
        }
    }
}
