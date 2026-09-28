import 'package:flutter/material.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/listings/listing_repository.dart';

final _availabilityProvider = FutureProvider.autoDispose
    .family((ref, String listingId) => ref.watch(listingRepositoryProvider).getAvailability(listingId));

class CalendarManagementScreen extends ConsumerStatefulWidget {
  const CalendarManagementScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<CalendarManagementScreen> createState() => _CalendarManagementScreenState();
}

class _CalendarManagementScreenState extends ConsumerState<CalendarManagementScreen> {
  DateTime _focusedDay = DateTime.now();

  Future<void> _blockDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 365)));
    if (range == null) return;
    await ref.read(listingRepositoryProvider).blockDates(listingId: widget.listingId, start: range.start, end: range.end);
    ref.invalidate(_availabilityProvider(widget.listingId));
  }

  @override
  Widget build(BuildContext context) {
    final availabilityAsync = ref.watch(_availabilityProvider(widget.listingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Manage calendar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _blockDateRange,
        icon: Icon(LucideIcons.ban),
        label: const Text('Block dates'),
      ),
      body: availabilityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(apiErrorMessage(e))),
        data: (blocks) {
          bool isBlocked(DateTime day) => blocks.any((b) =>
              b.isBlocked &&
              !day.isBefore(DateTime(b.startDate.year, b.startDate.month, b.startDate.day)) &&
              day.isBefore(DateTime(b.endDate.year, b.endDate.month, b.endDate.day)));

          return Column(
            children: [
              TableCalendar(
                firstDay: DateTime.now().subtract(const Duration(days: 30)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                onPageChanged: (day) => setState(() => _focusedDay = day),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, _) => isBlocked(day)
                      ? Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.15), shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text('${day.day}', style: const TextStyle(color: AppColors.error)),
                        )
                      : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text('Blocked / unavailable', style: TextStyle(fontSize: 12)),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: blocks.length,
                  itemBuilder: (context, index) {
                    final block = blocks[index];
                    return ListTile(
                      leading: Icon(LucideIcons.calendarX2, color: AppColors.error),
                      title: Text('${_fmt(block.startDate)} → ${_fmt(block.endDate)}'),
                      trailing: IconButton(
                        icon: Icon(LucideIcons.trash2),
                        onPressed: () async {
                          await ref.read(listingRepositoryProvider).deleteAvailabilityBlock(widget.listingId, block.id);
                          ref.invalidate(_availabilityProvider(widget.listingId));
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _fmt(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
