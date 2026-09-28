import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/bookings/payment_repository.dart';

/// Opens Paystack's real hosted checkout page (from the authorization_url the backend
/// obtained via Paystack's Initialize Transaction API) in a WebView. Paystack doesn't
/// know about a callback URL we control here, so completion is detected two ways:
/// the WebView surfacing Paystack's own "successful" confirmation page, and a manual
/// "I've completed payment" fallback that calls /payments/verify directly.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _paymentRepository = PaymentRepository();
  PaymentInit? _paymentInit;
  WebViewController? _controller;
  String? _error;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  Future<void> _initializePayment() async {
    try {
      final init = await _paymentRepository.initialize(widget.bookingId);
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              if (request.url.contains('/close') || request.url.toLowerCase().contains('success')) {
                _verifyPayment();
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(init.authorizationUrl));
      setState(() {
        _paymentInit = init;
        _controller = controller;
      });
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    }
  }

  Future<void> _verifyPayment() async {
    if (_isVerifying || _paymentInit == null) return;
    setState(() => _isVerifying = true);
    try {
      final booking = await _paymentRepository.verify(_paymentInit!.reference);
      if (!mounted) return;
      if (booking.status.name == 'confirmed') {
        context.pushReplacement('/booking-confirmed/${booking.id}');
      } else {
        setState(() => _error = 'Payment was not successful. Please try again.');
      }
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _initializePayment, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : _controller == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    WebViewWidget(controller: _controller!),
                    if (_isVerifying) const Center(child: CircularProgressIndicator()),
                  ],
                ),
      bottomNavigationBar: (_controller != null && _error == null)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton(
                  onPressed: _isVerifying ? null : _verifyPayment,
                  child: const Text("I've completed payment"),
                ),
              ),
            )
          : null,
    );
  }
}
