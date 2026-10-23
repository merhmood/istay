import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

import 'package:staynaija_shared/admin/admin_repository.dart';
import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/app_refresh.dart';
import 'package:staynaija_shared/core/widgets/empty_state.dart';
import 'package:staynaija_shared/core/widgets/soft_card.dart';
import 'package:staynaija_shared/models/user.dart';

final _hostsProvider = FutureProvider.autoDispose<List<AppUser>>(
  (ref) => ref.watch(adminRepositoryProvider).listHosts(),
);

/// Host accounts are vetted and created by hand, so this is where an admin adds
/// one and hands over the temporary login.
class AdminHostsScreen extends ConsumerWidget {
  const AdminHostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostsAsync = ref.watch(_hostsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Hosts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const _AddHostScreen()),
          );
          if (created == true) ref.invalidate(_hostsProvider);
        },
        icon: Icon(LucideIcons.plus),
        label: const Text('Add host'),
      ),
      body: AppRefresh(
        onRefresh: () async {
          ref.invalidate(_hostsProvider);
          await ref.read(_hostsProvider.future);
        },
        child: hostsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(apiErrorMessage(e)))]),
          data: (hosts) {
            if (hosts.isEmpty) {
              return ScrollableEmptyState(
                child: EmptyState(
                  icon: LucideIcons.users,
                  title: 'No hosts yet',
                  message: 'Add your first vetted host. They sign in with the temporary password you give them.',
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: hosts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _HostTile(host: hosts[i]),
            );
          },
        ),
      ),
    );
  }
}

class _HostTile extends StatelessWidget {
  const _HostTile({required this.host});

  final AppUser host;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              host.fullName.isEmpty ? '?' : host.fullName[0].toUpperCase(),
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(host.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(host.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                if (host.phoneNumber != null)
                  Text(host.phoneNumber!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
              ],
            ),
          ),
          if (host.mustChangePassword)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(
                'Temp password',
                style: TextStyle(color: Colors.orange.shade800, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddHostScreen extends ConsumerStatefulWidget {
  const _AddHostScreen();

  @override
  ConsumerState<_AddHostScreen> createState() => _AddHostScreenState();
}

class _AddHostScreenState extends ConsumerState<_AddHostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  late final TextEditingController _password = TextEditingController(text: _generatePassword());

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Readable (no 0/O or 1/l lookalikes) since an admin will send it to the
  /// host over chat.
  static String _generatePassword() {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(10, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      final password = _password.text;
      await ref.read(adminRepositoryProvider).createHost(
            email: email,
            fullName: _name.text.trim(),
            phoneNumber: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            password: password,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Host created'),
          content: Text(
            'Send these login details to the host. They will be asked to choose their own password the first time they sign in.\n\n'
            'Email: $email\nTemporary password: $password\n\n'
            'If this email already had an account, it was upgraded to a host account and its existing password still works.',
          ),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: 'Email: $email\nTemporary password: $password')),
              child: const Text('Copy'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
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
      appBar: AppBar(title: const Text('Add host')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number (optional)'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  decoration: InputDecoration(
                    labelText: 'Temporary password',
                    suffixIcon: IconButton(
                      tooltip: 'Generate another',
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: () => setState(() => _password.text = _generatePassword()),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
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
                        : const Text('Create host'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
