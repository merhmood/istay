import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/reviews/review_repository.dart';

Future<void> showReviewDialog(BuildContext context, String bookingId) async {
  await showDialog(context: context, builder: (_) => _ReviewDialog(bookingId: bookingId));
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.bookingId});

  final String bookingId;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final Map<String, int> _ratings = {
    'Cleanliness': 5,
    'Communication': 5,
    'Accuracy': 5,
    'Location': 5,
    'Value': 5,
  };
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ReviewRepository().createReview(
        bookingId: widget.bookingId,
        cleanliness: _ratings['Cleanliness']!,
        communication: _ratings['Communication']!,
        accuracy: _ratings['Accuracy']!,
        locationRating: _ratings['Location']!,
        value: _ratings['Value']!,
        comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Material 3 tints dialog surfaces with the seed colour, which turns this
      // pale green; the rest of the app uses plain white surfaces.
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text('Rate your stay'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._ratings.keys.map((category) => _ratingRow(category)),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Comment (optional)'),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        // The app-wide ElevatedButton theme sets minimumSize to
        // Size.fromHeight(50) for full-width forms, which forces the dialog's
        // action row to wrap into a stack. Bound it so the two sit side by side.
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: 22),
          ),
          onPressed: _isSubmitting ? null : _submit,
          child: const Text('Submit'),
        ),
      ],
    );
  }

  Widget _ratingRow(String category) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Flexible rather than a fixed 110px: combined with five 48px default
          // IconButton hit targets that overflowed the dialog by 45px.
          Expanded(
            child: Text(category, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
          ),
          ...List.generate(5, (index) {
            final starValue = index + 1;
            final selected = starValue <= _ratings[category]!;
            return GestureDetector(
              onTap: () => setState(() => _ratings[category] = starValue),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                // Kept tight: five stars at 24px with wider padding left too
                // little room for "Communication", which wrapped mid-word.
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: HeroIcon(
                  HeroIcons.star,
                  // Both branches used the same outline icon before, so the
                  // chosen rating was invisible.
                  style: selected ? HeroIconStyle.solid : HeroIconStyle.outline,
                  color: selected ? AppColors.accent : Colors.grey.shade400,
                  size: 21,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
