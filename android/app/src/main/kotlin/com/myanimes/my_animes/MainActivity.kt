package com.myanimes.my_animes

import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.myanimes.app/cookies"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getCookies") {
                val url = call.argument<String>("url")
                if (url != null) {
                    try {
                        val cookieManager = CookieManager.getInstance()
                        cookieManager.flush()
                        val cookies = cookieManager.getCookie(url)
                        result.success(cookies ?: "")
                    } catch (e: Exception) {
                        result.error("COOKIE_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_URL", "URL cannot be null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
