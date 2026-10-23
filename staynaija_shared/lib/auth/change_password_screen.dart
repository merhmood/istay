import 'package:flutter/material.dart';

import 'package:staynaija_shared/auth/auth_repository.dart';
import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.forced = false, this.onChanged, this.onLogout});

  /// Set when an admin-issued temporary password has to be replaced: hides the
  /// back button and swaps "current password" wording for the temporary one.
  final bool forced;

  /// Called after a successful change instead of popping the screen.
  final Future<void> Function()? onChanged;

  /// Lets a forced screen offer an escape hatch.
  final Future<void> Function()? onLogout;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _repository = AuthRepository();
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository.changePassword(currentPassword: _current.text, newPassword: _new.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated')));
      if (widget.onChanged != null) {
        await widget.onChanged!();
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final toggle = IconButton(
      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
      onPressed: () => setState(() => _obscure = !_obscure),
    );
    return PopScope(
      canPop: !widget.forced,
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.forced ? 'Choose a new password' : 'Change password'),
        automaticallyImplyLeading: !widget.forced,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.forced)
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                'You are signed in with a temporary password. Choose your own to continue.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
            ),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _current,
                  obscureText: _obscure,
                  decoration: InputDecoration(labelText: widget.forced ? 'Temporary password' : 'Current password', suffixIcon: toggle),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _new,
                  obscureText: _obscure,
                  decoration: const InputDecoration(labelText: 'New password'),
                  validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  decoration: const InputDecoration(labelText: 'Confirm new password'),
                  validator: (v) => v != _new.text ? 'Passwords do not match' : null,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Update password'),
                  ),
                ),
                if (widget.onLogout != null)
                  TextButton(onPressed: widget.onLogout, child: const Text('Log out')),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}
