import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/app_refresh.dart';
import 'package:staynaija_shared/core/widgets/soft_card.dart';
import 'package:staynaija_shared/messaging/message_repository.dart';

final conversationsProvider = FutureProvider.autoDispose((ref) => ref.watch(messageRepositoryProvider).listConversations());

class ConversationsListScreen extends ConsumerWidget {
  const ConversationsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Messages')),
      body: AppRefresh(
        onRefresh: () async {
          ref.invalidate(conversationsProvider);
          // Await the refetch so the indicator stays until new data
          // lands, instead of snapping away the moment it is asked for.
          await ref.read(conversationsProvider.future);
        },
        child: conversationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(padding: const EdgeInsets.all(24), child: Text('Could not load messages.\n${apiErrorMessage(e)}')),
            ],
          ),
          data: (conversations) {
            if (conversations.isEmpty) return const _EmptyMessages();

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                return SoftCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  onTap: () => context.push('/chat/${conversation.id}'),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Avatar(
                          name: conversation.otherUserName,
                          avatarUrl: conversation.otherUserAvatarUrl,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      conversation.otherUserName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                  ),
                                  if (conversation.lastMessageAt != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      _relativeTime(conversation.lastMessageAt!),
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                conversation.lastMessageBody ?? 'Say hello!',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  height: 1.45,
                                  fontStyle: conversation.lastMessageBody == null ? FontStyle.italic : FontStyle.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Falls back to the contact's initials rather than a generic person glyph, so
/// a list of avatar-less hosts is still scannable.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null) {
      return CircleAvatar(radius: 25, backgroundImage: NetworkImage(avatarUrl!));
    }
    return CircleAvatar(
      radius: 25,
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      child: Text(
        _initials(name),
        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 90, 32, 0),
          child: Column(
            children: [
              Icon(LucideIcons.messageSquare, size: 44, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('No messages yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                'Guests can message you from your listings. Replies will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _relativeTime(DateTime timestamp) {
  final difference = DateTime.now().difference(timestamp);
  if (difference.inMinutes < 1) return 'now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m';
  if (difference.inHours < 24) return '${difference.inHours}h';
  if (difference.inDays < 7) return '${difference.inDays}d';
  return DateFormat('d MMM').format(timestamp);
}
