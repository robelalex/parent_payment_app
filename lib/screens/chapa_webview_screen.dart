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
import '../services/api_service.dart';

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
  bool _paymentNotCompleted = false;

  // Any of these appearing in a navigated URL means Chapa is done and is
  // trying to hand control back — whether that's our backend's
  // mobile-redirect page, the custom parentpay:// scheme it also tries, or
  // (for completeness) the plain web success URL.
  bool _isReturnUrl(String url) {
    return url.contains('/api/chapa/mobile-redirect/') ||
        url.startsWith('parentpay://') ||
        url.contains('/payment/success');
  }

  // ✅ FIX: the check above only recognized SUCCESS-shaped URLs. On a
  // failed/cancelled/timed-out transaction, Chapa doesn't necessarily send
  // us to one of those — it can just bounce the browser back to our own
  // site's domain root instead (no tx_ref, no /payment/success path).
  // The old code let that fall through to NavigationDecision.navigate,
  // which made the WebView silently load our actual website (which then
  // redirects an unauthenticated visitor to its own login screen) INSIDE
  // the payment popup — looking exactly like a broken "redirected to the
  // admin login page" bug, and leaving the Payment row stuck at 'pending'
  // forever since nothing ever told the backend the attempt failed.
  //
  // Fix: explicitly recognize our own site's domains. Any navigation to
  // them that ISN'T one of the known success paths above means Chapa gave
  // up on the transaction — treat it as "not completed", not as "keep
  // browsing", and don't let our own website ever render inside this
  // popup.
  bool _isOwnSiteDomain(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.endsWith('onrender.com') || host.endsWith('vercel.app');
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
            // ✅ FIX: Chapa giving up and bouncing us to our own domain,
            // on any path that isn't a recognized success URL, means the
            // transaction did not go through. Stop it here instead of
            // rendering our own website inside the payment popup.
            if (_isOwnSiteDomain(request.url)) {
              _handlePaymentNotCompleted();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  void _handlePaymentNotCompleted() {
    if (_handledCompletion || !mounted) return;
    _handledCompletion = true;
    setState(() => _paymentNotCompleted = true);
    // ✅ Ask the backend to independently confirm the real status with
    // Chapa right now, instead of leaving this Payment row sitting at
    // 'pending' indefinitely until something else happens to poll it.
    // Fire-and-forget: this screen doesn't need to wait on it, the
    // dashboard will reflect whatever the backend records.
    ApiService().verifyPayment(widget.txRef).catchError((_) => <String, dynamic>{});
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
        body: _paymentNotCompleted
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 56, color: Colors.red.shade600),
                      const SizedBox(height: 16),
                      const Text('Payment Not Completed',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        'Chapa was unable to complete this transaction '
                        '(it may have been cancelled, timed out, or the '
                        'payment method failed). No money was confirmed '
                        'as paid. We\'re checking the final status with '
                        'Chapa now — check your dashboard in a moment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Back to Dashboard',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Stack(
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