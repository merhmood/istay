import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  // Placeholder contact details - swap for the real support desk before launch.
  static const _supportEmail = 'support@staynaija.example';
  static const _supportPhone = '+234 800 000 0000';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Talk to us', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                const Text(
                  'Our team replies within a few hours, 8am - 9pm WAT.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 14),
                _ContactRow(icon: LucideIcons.mail, label: 'Email', value: _supportEmail),
                const SizedBox(height: 10),
                _ContactRow(icon: LucideIcons.phone, label: 'Phone', value: _supportPhone),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text('Common questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: const Column(
              children: [
                _Faq(
                  question: 'When is my money released to the host?',
                  answer: 'Payments are held in escrow and released 24 hours after check-in. If something is wrong '
                      'with the place, contact us before that window closes.',
                ),
                _Faq(
                  question: 'Can I cancel a booking?',
                  answer: 'Yes. Open the booking under Trips and tap Cancel. Refunds follow the cancellation policy '
                      'shown on the listing before you paid.',
                ),
                _Faq(
                  question: 'The host is not responding. What do I do?',
                  answer: 'Message them from the Messages tab first. If there is still no reply within 24 hours of '
                      'your check-in date, contact support and we will step in.',
                ),
                _Faq(
                  question: 'Is my card safe?',
                  answer: 'Card details are handled entirely by Flutterwave and never stored on StayNaija servers.',
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        IconButton(
          icon: Icon(LucideIcons.copy, size: 16, color: AppColors.textSecondary),
          tooltip: 'Copy',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
          },
        ),
      ],
    );
  }
}

class _Faq extends StatelessWidget {
  const _Faq({required this.question, required this.answer, this.isLast = false});

  final String question;
  final String answer;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(question, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(answer, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
              ),
            ),
          ],
        ),
        if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}
