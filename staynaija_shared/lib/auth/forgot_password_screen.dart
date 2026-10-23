import 'package:flutter/material.dart';

import 'package:staynaija_shared/auth/auth_repository.dart';
import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';

/// Two steps on one screen: ask for a reset code by email, then enter the code
/// with a new password. Pops with `true` once the password has been changed.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _repository = AuthRepository();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email = TextEditingController(text: widget.initialEmail ?? '');
  final _code = TextEditingController();
  final _password = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _devCode;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final devCode = await _repository.forgotPassword(_email.text.trim());
      setState(() {
        _codeSent = true;
        _devCode = devCode;
      });
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository.resetPassword(
        email: _email.text.trim(),
        code: _code.text.trim(),
        newPassword: _password.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed. You can log in now.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Reset password')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _codeSent
                ? 'If an account exists for ${_email.text.trim()}, we have emailed a 6-digit code. Enter it below with your new password.'
                : 'Enter the email on your account and we will send you a code to reset your password.',
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _email,
                  enabled: !_codeSent,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(labelText: 'Reset code', counterText: ''),
                    validator: (v) => (v == null || v.trim().length != 6) ? 'Enter the 6-digit code' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
                  ),
                  if (_devCode != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text('Dev code: $_devCode', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _busy ? null : (_codeSent ? _reset : _sendCode),
                    child: _busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_codeSent ? 'Reset password' : 'Send code'),
                  ),
                ),
                if (_codeSent)
                  TextButton(
                    onPressed: _busy ? null : _sendCode,
                    child: const Text('Send a new code'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
