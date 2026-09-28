import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/auth/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  // Only shown once someone tries to submit without checking the box - showing
  // it from the start would flag a field nobody has had a chance to fill yet.
  bool _termsTouched = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _termsTouched = true);
    final formValid = _formKey.currentState!.validate();
    if (!formValid || !_acceptedTerms) return;

    final success = await ref.read(authProvider.notifier).register(
          fullName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          isHost: true,
        );
    if (success && mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final showTermsError = _termsTouched && !_acceptedTerms;

    return Scaffold(
      appBar: AppBar(title: const Text('Become a host')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your full name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number (optional)', hintText: '+234...'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    helperText: 'At least 6 characters',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? LucideIcons.eyeOff : LucideIcons.eye),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 20),
                _TermsCheckbox(
                  value: _acceptedTerms,
                  showError: showTermsError,
                  onChanged: (value) => setState(() => _acceptedTerms = value),
                ),
                if (authState.error != null) ...[
                  const SizedBox(height: 8),
                  Text(authState.error!, style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : _submit,
                    child: authState.isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Create host account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({required this.value, required this.showError, required this.onChanged});

  final bool value;
  final bool showError;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: value,
                    onChanged: (v) => onChanged(v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Text(
                      'I agree to the Terms of Service and Privacy Policy',
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showError)
          const Padding(
            padding: EdgeInsets.only(left: 34, top: 2),
            child: Text('You must accept the terms to continue', style: TextStyle(color: AppColors.error, fontSize: 12)),
          ),
      ],
    );
  }
}
