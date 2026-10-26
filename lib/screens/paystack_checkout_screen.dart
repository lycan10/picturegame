import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_theme.dart';

/// Paystack hosted checkout, loaded in a secure WebView.
///
/// Returns `true` when the checkout page reached its close redirect (Paystack
/// redirects to https://standard.paystack.co/close after payment attempts) and
/// `false` when the user backed out early. Callers must ALWAYS verify the
/// reference with the backend afterwards — success/failure is a server
/// decision, never a WebView decision.
class PaystackCheckoutScreen extends StatefulWidget {
  const PaystackCheckoutScreen({super.key, required this.checkoutUrl});

  final String checkoutUrl;

  /// Paystack's standard "close" redirect target.
  static const String closeUrl = 'https://standard.paystack.co/close';

  @override
  State<PaystackCheckoutScreen> createState() => _PaystackCheckoutScreenState();
}

class _PaystackCheckoutScreenState extends State<PaystackCheckoutScreen> {
  late final WebViewController _controller;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            // Checkout must stay on https:// — block intent:, data:, http:
            // and any other scheme a redirected page could try to open.
            final uri = Uri.tryParse(request.url);
            if (uri == null || uri.scheme != 'https') {
              return NavigationDecision.prevent;
            }
            if (request.url.startsWith(PaystackCheckoutScreen.closeUrl)) {
              if (!_settled) {
                _settled = true;
                Navigator.of(context).pop(true);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (url) {
            if (url.startsWith(PaystackCheckoutScreen.closeUrl) && !_settled) {
              _settled = true;
              Navigator.of(context).pop(true);
            }
          },
          onWebResourceError: (error) =>
              log('Paystack checkout error: ${error.description}'),
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_settled,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Secure Checkout',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.palePurple,
              child: const Row(
                children: [
                  Icon(Icons.lock_rounded, size: 15, color: AppColors.purple),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payments are processed securely by Paystack.',
                      style: TextStyle(fontSize: 12, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
      ),
    );
  }
}
