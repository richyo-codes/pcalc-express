package ca.richyoung.pcalcexpress

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app/device_display",
        ).setMethodCallHandler { call, result ->
            if (call.method == "isEinkDevice") {
                result.success(isKnownEinkDevice())
            } else {
                result.notImplemented()
            }
        }
    }

    private fun isKnownEinkDevice(): Boolean {
        val identity = listOf(Build.MANUFACTURER, Build.BRAND, Build.MODEL, Build.DEVICE)
            .joinToString(" ")
            .lowercase(Locale.ROOT)
        return listOf("onyx", "boox", "boyue", "likebook", "meebook").any(identity::contains)
    }
}
