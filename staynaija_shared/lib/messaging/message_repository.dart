import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:staynaija_shared/core/api/api_config.dart';
import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/storage/secure_storage.dart';
import 'package:staynaija_shared/models/message.dart';

final messageRepositoryProvider = Provider((ref) => MessageRepository());

class MessageRepository {
  final Dio _dio = DioClient.instance.dio;

  Future<List<ConversationSummary>> listConversations() async {
    final response = await _dio.get('/messages/conversations');
    return (response.data as List).map((json) => ConversationSummary.fromJson(json)).toList();
  }

  Future<Conversation> startConversation(String listingId) async {
    final response = await _dio.post('/messages/conversations', data: {'listing_id': listingId});
    return Conversation.fromJson(response.data);
  }

  Future<List<ChatMessage>> listMessages(String conversationId) async {
    final response = await _dio.get('/messages/conversations/$conversationId/messages');
    return (response.data as List).map((json) => ChatMessage.fromJson(json)).toList();
  }

  Future<ChatMessage> sendMessage(String conversationId, String body) async {
    final response = await _dio.post('/messages/conversations/$conversationId/messages', data: {'body': body});
    return ChatMessage.fromJson(response.data);
  }

  /// Opens a live feed of new messages for a conversation. Sending still goes through
  /// [sendMessage] (REST) so every message is validated/persisted the same way; this
  /// socket only pushes messages (including ones sent by the other party) as they arrive.
  Future<WebSocketChannel> openLiveFeed(String conversationId) async {
    final token = await SecureStorage.accessToken;
    final uri = Uri.parse('${ApiConfig.wsBaseUrl}/api/v1/ws/conversations/$conversationId?token=$token');
    return WebSocketChannel.connect(uri);
  }

  ChatMessage parseSocketMessage(dynamic data) => ChatMessage.fromJson(jsonDecode(data as String));
}
