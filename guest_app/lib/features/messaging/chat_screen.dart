import 'dart:async';

import 'package:flutter/material.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/app_refresh.dart';
import 'package:staynaija_shared/auth/auth_provider.dart';
import 'package:staynaija_shared/messaging/message_repository.dart';
import 'package:staynaija_shared/models/message.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _repository = MessageRepository();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final history = await _repository.listMessages(widget.conversationId);
    setState(() {
      _messages.addAll(history);
      _isLoading = false;
    });
    _scrollToBottom();

    final channel = await _repository.openLiveFeed(widget.conversationId);
    _channel = channel;
    _subscription = channel.stream.listen((data) {
      final message = _repository.parseSocketMessage(data);
      if (!mounted) return;
      setState(() => _messages.add(message));
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    final message = await _repository.sendMessage(widget.conversationId, text);
    if (!mounted) return;
    setState(() => _messages.add(message));
    _scrollToBottom();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authProvider).user?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Conversation')),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : AppRefresh(
                    // Chat arrives over the WebSocket, but a manual pull is the
                    // recovery path when the socket has dropped unnoticed.
                    onRefresh: _init,
                    child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMine = message.senderId == currentUserId;
                      return Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isMine ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(message.body, style: TextStyle(color: isMine ? Colors.white : AppColors.textPrimary)),
                        ),
                      );
                    },
                  ),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(hintText: 'Type a message...'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                    icon: Icon(LucideIcons.send, color: Colors.white),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
