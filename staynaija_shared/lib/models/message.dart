class Conversation {
  final String id;
  final String listingId;
  final String guestId;
  final String hostId;
  final DateTime createdAt;

  Conversation({
    required this.id,
    required this.listingId,
    required this.guestId,
    required this.hostId,
    required this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'],
        listingId: json['listing_id'],
        guestId: json['guest_id'],
        hostId: json['host_id'],
        createdAt: DateTime.parse(json['created_at']),
      );
}

class ConversationSummary {
  final String id;
  final String listingId;
  final String otherUserName;
  final String? otherUserAvatarUrl;
  final String? lastMessageBody;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  ConversationSummary({
    required this.id,
    required this.listingId,
    required this.otherUserName,
    required this.otherUserAvatarUrl,
    required this.lastMessageBody,
    required this.lastMessageAt,
    required this.createdAt,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) => ConversationSummary(
        id: json['id'],
        listingId: json['listing_id'],
        otherUserName: json['other_user_name'],
        otherUserAvatarUrl: json['other_user_avatar_url'],
        lastMessageBody: json['last_message_body'],
        lastMessageAt: json['last_message_at'] != null ? DateTime.parse(json['last_message_at']) : null,
        createdAt: DateTime.parse(json['created_at']),
      );
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final String? imageUrl;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.imageUrl,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'],
        conversationId: json['conversation_id'],
        senderId: json['sender_id'],
        body: json['body'],
        imageUrl: json['image_url'],
        createdAt: DateTime.parse(json['created_at']),
      );
}
