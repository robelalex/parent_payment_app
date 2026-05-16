package com.example.parent_payment_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.example.parent_payment_app/http"
    }

    private val okHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)
        .build()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            val url     = call.argument<String>("url") ?: run {
                result.error("INVALID_ARG", "url is required", null); return@setMethodCallHandler
            }
            val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
            val body    = call.argument<String>("body")

            // Build request headers
            val requestHeaders = Headers.Builder().apply {
                headers.forEach { (k, v) -> add(k, v) }
            }.build()

            when (call.method) {
                "GET" -> executeAsync(result) {
                    val request = Request.Builder()
                        .url(url)
                        .headers(requestHeaders)
                        .get()
                        .build()
                    okHttpClient.newCall(request).execute()
                }

                "POST" -> executeAsync(result) {
                    val mediaType = "application/json; charset=utf-8".toMediaType()
                    val requestBody = (body ?: "{}").toRequestBody(mediaType)
                    val request = Request.Builder()
                        .url(url)
                        .headers(requestHeaders)
                        .post(requestBody)
                        .build()
                    okHttpClient.newCall(request).execute()
                }

                "PUT" -> executeAsync(result) {
                    val mediaType = "application/json; charset=utf-8".toMediaType()
                    val requestBody = (body ?: "{}").toRequestBody(mediaType)
                    val request = Request.Builder()
                        .url(url)
                        .headers(requestHeaders)
                        .put(requestBody)
                        .build()
                    okHttpClient.newCall(request).execute()
                }

                "DELETE" -> executeAsync(result) {
                    val request = Request.Builder()
                        .url(url)
                        .headers(requestHeaders)
                        .delete()
                        .build()
                    okHttpClient.newCall(request).execute()
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * Runs [block] on a background thread, converts the OkHttp Response
     * into a plain Map, and sends it back to Dart — all error paths handled.
     */
    private fun executeAsync(
        result: MethodChannel.Result,
        block: () -> Response
    ) {
        Thread {
            try {
                val response = block()
                val responseBody = response.body?.string() ?: ""

                // Always return to main thread for result callbacks
                runOnUiThread {
                    result.success(
                        mapOf(
                            "statusCode" to response.code,
                            "body"       to responseBody,
                            "headers"    to response.headers.toMap()
                        )
                    )
                }
            } catch (e: IOException) {
                runOnUiThread {
                    result.error("NETWORK_ERROR", e.message, null)
                }
            } catch (e: IllegalArgumentException) {
                runOnUiThread {
                    result.error("INVALID_URL", e.message, null)
                }
            } catch (e: Exception) {
                runOnUiThread {
                    result.error("HTTP_ERROR", e.message, null)
                }
            }
        }.start()
    }
}