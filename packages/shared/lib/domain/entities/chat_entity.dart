// packages/shared/lib/domain/entities/chat_entity.dart

/// رسالة شات واحدة
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderRole,
    required this.content,
    required this.sentAt,
    this.messageType = MessageType.text,
    this.mediaUrl,
    this.replyToId,
    this.replyToContent,
    this.isDeleted = false,
    this.isEdited = false,
    this.editedAt,
    this.readAt,
    this.reactions = const [],
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String senderRole;
  final String content;
  final DateTime sentAt;
  final MessageType messageType;

  /// رابط الصورة أو الصوت
  final String? mediaUrl;

  /// معرف الرسالة التي يرد عليها
  final String? replyToId;
  final String? replyToContent;
  final bool isDeleted;
  final bool isEdited;
  final DateTime? editedAt;
  final DateTime? readAt;
  final List<MessageReaction> reactions;

  bool get isRead => readAt != null;

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderRole,
    String? content,
    DateTime? sentAt,
    MessageType? messageType,
    String? mediaUrl,
    String? replyToId,
    String? replyToContent,
    bool? isDeleted,
    bool? isEdited,
    DateTime? editedAt,
    DateTime? readAt,
    List<MessageReaction>? reactions,
  }) =>
      ChatMessage(
        id: id ?? this.id,
        conversationId: conversationId ?? this.conversationId,
        senderId: senderId ?? this.senderId,
        senderRole: senderRole ?? this.senderRole,
        content: content ?? this.content,
        sentAt: sentAt ?? this.sentAt,
        messageType: messageType ?? this.messageType,
        mediaUrl: mediaUrl ?? this.mediaUrl,
        replyToId: replyToId ?? this.replyToId,
        replyToContent: replyToContent ?? this.replyToContent,
        isDeleted: isDeleted ?? this.isDeleted,
        isEdited: isEdited ?? this.isEdited,
        editedAt: editedAt ?? this.editedAt,
        readAt: readAt ?? this.readAt,
        reactions: reactions ?? this.reactions,
      );
}

enum MessageType { text, image, voice }

/// تفاعل على رسالة
class MessageReaction {
  const MessageReaction({
    required this.userId,
    required this.reactionType,
    required this.createdAt,
  });

  final String userId;

  /// نوع التفاعل: 'like' | 'love' | 'wow' | 'haha' | 'sad' | 'angry'
  final String reactionType;
  final DateTime createdAt;
}

/// محادثة بين طرفين
class Conversation {
  const Conversation({
    required this.id,
    required this.participantIds,
    required this.participantRoles,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.updatedAt,
  });

  final String id;
  final List<String> participantIds;
  final List<String> participantRoles;
  final ChatMessage? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime? updatedAt;
}
