import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/auth/auth_provider.dart';
import 'package:staynaija_shared/auth/auth_repository.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({super.key, required this.phoneNumber});

  final String phoneNumber;

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isSendingCode = true;
  String? _error;
  String? _devCode;

  @override
  void initState() {
    super.initState();
    _requestOtp();
  }

  Future<void> _requestOtp() async {
    setState(() {
      _isSendingCode = true;
      _error = null;
    });
    try {
      final devCode = await AuthRepository().requestOtp(widget.phoneNumber);
      setState(() => _devCode = devCode);
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      setState(() => _isSendingCode = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthRepository().verifyOtp(phoneNumber: widget.phoneNumber, code: _codeController.text.trim());
      await ref.read(authProvider.notifier).refreshUser();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify phone number')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('We sent a 6-digit code to ${widget.phoneNumber}'),
            const SizedBox(height: 8),
            if (_isSendingCode) const LinearProgressIndicator(),
            if (_devCode != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    'No SMS provider is configured yet, so in dev mode the code is returned directly: $_devCode',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: '6-digit code'),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _verify,
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Verify'),
            ),
            TextButton(onPressed: _isSendingCode ? null : _requestOtp, child: const Text('Resend code')),
          ],
        ),
      ),
    );
  }
}
