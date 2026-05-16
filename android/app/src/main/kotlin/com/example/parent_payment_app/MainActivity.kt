package com.example.parent_payment_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.InetAddress
import java.net.UnknownHostException

class MainActivity : FlutterActivity() {

    companion object {
        private const val DNS_CHANNEL = "com.example.parent_payment_app/dns"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DNS_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "resolveHost") {
                val hostname = call.argument<String>("hostname")

                if (hostname.isNullOrBlank()) {
                    result.error("INVALID_ARG", "hostname must not be empty", null)
                    return@setMethodCallHandler
                }

                Thread {
                    try {
                        val addresses = InetAddress.getAllByName(hostname)
                        val ipv4 = addresses.filter { !it.hostAddress!!.contains(':') }.map { it.hostAddress!! }
                        val ipv6 = addresses.filter { it.hostAddress!!.contains(':') }.map { it.hostAddress!! }
                        val sorted = ipv4 + ipv6
                        result.success(sorted)
                    } catch (e: UnknownHostException) {
                        result.error("DNS_UNKNOWN_HOST", "Cannot resolve hostname: $hostname", e.message)
                    } catch (e: Exception) {
                        result.error("DNS_ERROR", "Unexpected error: ${e.message}", null)
                    }
                }.start()
            } else {
                result.notImplemented()
            }
        }
    }
}