import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/soft_card.dart';
import 'package:staynaija_shared/auth/auth_provider.dart';
import 'package:staynaija_shared/users/user_repository.dart';
import 'package:staynaija_shared/models/user.dart';

/// Nigerian banks, so a host picks rather than types. A mistyped bank name is a
/// failed payout, and free text also makes the data unusable for automating
/// transfers later.
const _nigerianBanks = [
  'Access Bank',
  'Citibank',
  'Ecobank',
  'Fidelity Bank',
  'First Bank of Nigeria',
  'First City Monument Bank',
  'Globus Bank',
  'Guaranty Trust Bank',
  'Heritage Bank',
  'Jaiz Bank',
  'Keystone Bank',
  'Kuda Bank',
  'Lotus Bank',
  'Moniepoint MFB',
  'OPay',
  'PalmPay',
  'Parallex Bank',
  'Polaris Bank',
  'Premium Trust Bank',
  'Providus Bank',
  'Stanbic IBTC Bank',
  'Standard Chartered',
  'Sterling Bank',
  'SunTrust Bank',
  'Titan Trust Bank',
  'Union Bank',
  'United Bank for Africa',
  'Unity Bank',
  'VFD Microfinance Bank',
  'Wema Bank',
  'Zenith Bank',
];

/// Payout account management.
///
/// Has three states rather than one permanently-open form: what is on file,
/// a warning when nothing is, and the editor. The old version rendered an empty
/// form every time, so a host could save their bank details and have no way to
/// tell whether it had worked.
class PayoutCard extends ConsumerStatefulWidget {
  const PayoutCard({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<PayoutCard> createState() => _PayoutCardState();
}

class _PayoutCardState extends ConsumerState<PayoutCard> {
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();
  String? _selectedBank;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _error;

  /// NUBAN account numbers are always 10 digits, which catches the common typo
  /// before it becomes a failed transfer.
  bool get _isValid =>
      _selectedBank != null &&
      _accountNumberController.text.trim().length == 10 &&
      _accountNameController.text.trim().isNotEmpty;

  void _startEditing() {
    final user = widget.user;
    setState(() {
      _selectedBank = _nigerianBanks.contains(user.payoutBankName) ? user.payoutBankName : null;
      _accountNumberController.text = user.payoutAccountNumber ?? '';
      _accountNameController.text = user.payoutAccountName ?? '';
      _error = null;
      _isEditing = true;
    });
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await UserRepository().updateProfile({
        'payout_bank_name': _selectedBank,
        'payout_account_number': _accountNumberController.text.trim(),
        'payout_account_name': _accountNameController.text.trim(),
      });
      await ref.read(authProvider.notifier).refreshUser();
      if (!mounted) return;
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout details saved')));
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) return _editor();
    return widget.user.hasPayoutAccount ? _savedSummary() : _notSetUp();
  }

  Widget _savedSummary() {
    final user = widget.user;

    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(LucideIcons.landmark, size: 19, color: AppColors.primary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.payoutBankName ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.maskedAccountNumber,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, letterSpacing: 1.2),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.circleCheck, size: 19, color: AppColors.primary),
            ],
          ),
          if ((user.payoutAccountName ?? '').isNotEmpty) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
            Row(
              children: [
                const Text('Account name', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                const Spacer(),
                Flexible(
                  child: Text(
                    user.payoutAccountName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(0, 38)),
              onPressed: _startEditing,
              icon: Icon(LucideIcons.pencil, size: 15),
              label: const Text('Change account', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  /// No account on file blocks getting paid at all, so it is stated as a
  /// warning rather than left as a quietly empty form.
  Widget _notSetUp() {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(LucideIcons.triangleAlert, size: 19, color: Colors.orange.shade800),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Text('No payout account yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Add a bank account so StayNaija can send your earnings. Until you do, payouts stay '
            'held even after a guest checks out.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _startEditing, child: const Text('Add payout account')),
          ),
        ],
      ),
    );
  }

  Widget _editor() {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Where StayNaija sends your earnings after each stay.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 16),
          _label('Bank'),
          DropdownButtonFormField<String>(
            initialValue: _selectedBank,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Select your bank',
              fillColor: AppColors.background,
              prefixIcon: Icon(LucideIcons.landmark, size: 18, color: AppColors.textSecondary),
            ),
            items: [
              for (final bank in _nigerianBanks)
                DropdownMenuItem(value: bank, child: Text(bank, style: const TextStyle(fontSize: 14))),
            ],
            onChanged: (value) => setState(() => _selectedBank = value),
          ),
          const SizedBox(height: 14),
          _label('Account number'),
          TextField(
            controller: _accountNumberController,
            keyboardType: TextInputType.number,
            maxLength: 10,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '10 digits',
              counterText: '',
              fillColor: AppColors.background,
              prefixIcon: Icon(LucideIcons.hash, size: 18, color: AppColors.textSecondary),
              // Confirms a complete account number without waiting for a save
              // to fail.
              suffixIcon: _accountNumberController.text.trim().length == 10
                  ? Icon(LucideIcons.circleCheck, size: 18, color: AppColors.primary)
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          _label('Account name'),
          TextField(
            controller: _accountNameController,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'As it appears on your account',
              fillColor: AppColors.background,
              prefixIcon: Icon(LucideIcons.user, size: 18, color: AppColors.textSecondary),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12.5)),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (widget.user.hasPayoutAccount) ...[
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => setState(() => _isEditing = false),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    // Disabled until valid, so an incomplete account cannot be
                    // saved and then silently fail at payout time.
                    onPressed: (_isSaving || !_isValid) ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save account'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
      );
}
