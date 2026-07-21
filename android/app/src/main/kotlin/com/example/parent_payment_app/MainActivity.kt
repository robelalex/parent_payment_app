package com.example.parent_payment_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.security.cert.X509Certificate
import java.util.concurrent.TimeUnit
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.example.parent_payment_app/http"
    }

    private val okHttpClient = createTrustingClient()

    private fun createTrustingClient(): OkHttpClient {
        val trustAllCerts = arrayOf<TrustManager>(object : X509TrustManager {
            override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) {}
            override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {}
            override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
        })

        val sslContext = SSLContext.getInstance("SSL")
        sslContext.init(null, trustAllCerts, java.security.SecureRandom())

        return OkHttpClient.Builder()
            // ✅ Was 30s — Render's free tier spins the backend down after
            // inactivity, and waking it back up (a "cold start") can take
            // 30-60+ seconds on its own, before your actual request even
            // starts processing. 30s connect timeout meant every cold-start
            // request failed before the server even finished waking up.
            // Bumped to give cold starts room to finish; also see the
            // keep-alive suggestion to avoid cold starts entirely during
            // school hours.
            .connectTimeout(60, TimeUnit.SECONDS)
            .readTimeout(90, TimeUnit.SECONDS)
            .writeTimeout(60, TimeUnit.SECONDS)
            .retryOnConnectionFailure(true)
            .sslSocketFactory(sslContext.socketFactory, trustAllCerts[0] as X509TrustManager)
            .hostnameVerifier { _, _ -> true }
            .build()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            val url = call.argument<String>("url") ?: run {
                result.error("INVALID_ARG", "url is required", null)
                return@setMethodCallHandler
            }
            val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
            val body = call.argument<String>("body")
            val bodyBytesList = call.argument<List<*>>("bodyBytes")

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
                    val contentType = headers["Content-Type"]
                        ?: "application/json; charset=utf-8"

                    val requestBody = if (bodyBytesList != null) {
                        val bytes = ByteArray(bodyBytesList.size) { i ->
                            (bodyBytesList[i] as Int).toByte()
                        }
                        bytes.toRequestBody(contentType.toMediaType())
                    } else {
                        (body ?: "{}").toRequestBody(
                            "application/json; charset=utf-8".toMediaType()
                        )
                    }

                    val request = Request.Builder()
                        .url(url)
                        .headers(requestHeaders)
                        .post(requestBody)
                        .build()
                    okHttpClient.newCall(request).execute()
                }

                "PUT" -> executeAsync(result) {
                    val requestBody = (body ?: "{}").toRequestBody(
                        "application/json; charset=utf-8".toMediaType()
                    )
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

    private fun executeAsync(
        result: MethodChannel.Result,
        block: () -> Response
    ) {
        Thread {
            try {
                val response = block()
                val responseBody = response.body?.string() ?: ""
                runOnUiThread {
                    result.success(
                        mapOf(
                            "statusCode" to response.code,
                            "body" to responseBody,
                            "headers" to response.headers.toMap()
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