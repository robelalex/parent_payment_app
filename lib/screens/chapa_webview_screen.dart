// lib/screens/chapa_webview_screen.dart
//
// Hosts the Chapa checkout page INSIDE the app, instead of handing it off
// to the phone's external browser.
//
// Why this exists: the old flow opened Chapa in Chrome/Safari and relied
// on the checkout page auto-redirecting to a custom "parentpay://" link to
// bounce back into the app. Mobile browsers routinely block that kind of
// script-triggered app-switch when it isn't a direct user tap, so the app
// was never actually told the payment had finished — you'd just end up
// back on the dashboard with the payment still sitting as pending.
//
// With an in-app WebView, Flutter is watching every navigation itself, so
// it can detect the moment Chapa redirects to our success/mobile-redirect
// URL directly — no dependency on the OS or browser cooperating.
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'payment_success_handler.dart';

class ChapaWebViewScreen extends StatefulWidget {
  final String checkoutUrl;
  final String txRef;

  const ChapaWebViewScreen({
    super.key,
    required this.checkoutUrl,
    required this.txRef,
  });

  @override
  State<ChapaWebViewScreen> createState() => _ChapaWebViewScreenState();
}

class _ChapaWebViewScreenState extends State<ChapaWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _handledCompletion = false;

  // Any of these appearing in a navigated URL means Chapa is done and is
  // trying to hand control back — whether that's our backend's
  // mobile-redirect page, the custom parentpay:// scheme it also tries, or
  // (for completeness) the plain web success URL.
  bool _isReturnUrl(String url) {
    return url.contains('/api/chapa/mobile-redirect/') ||
        url.startsWith('parentpay://') ||
        url.contains('/payment/success');
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (NavigationRequest request) {
            if (_isReturnUrl(request.url)) {
              _handleCompletion(request.url);
              // Don't let the WebView actually try to load
              // parentpay://... itself — it can't, and doesn't need to.
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  void _handleCompletion(String returnUrl) {
    if (_handledCompletion || !mounted) return;
    _handledCompletion = true;

    // Prefer tx_ref from the return URL if present (covers edge cases
    // where it differs), otherwise fall back to the one we started with.
    String txRef = widget.txRef;
    try {
      final uri = Uri.parse(returnUrl);
      final fromUrl = uri.queryParameters['tx_ref'];
      if (fromUrl != null && fromUrl.isNotEmpty) txRef = fromUrl;
    } catch (_) {}

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PaymentSuccessHandler(txRef: txRef),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancel Payment?'),
            content: const Text(
              'If you leave now, your payment will not be completed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
        return leave ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Complete Payment'),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
