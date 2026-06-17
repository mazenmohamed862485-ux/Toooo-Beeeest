// packages/shared/lib/data/models/chat_model.dart

import 'package:isar/isar.dart';
import 'package:shared/domain/entities/chat_entity.dart';

part 'chat_model.g.dart';

@Collection()
class ChatMessageModel {
  Id get isarId => Isar.autoIncrement;

  @Index(unique: true)
  late String id;

  @Index()
  late String conversationId;

  late String senderId;
  late String senderRole;
  late String content;

  @Index()
  late DateTime sentAt;

  late String messageType;
  String? mediaUrl;
  String? replyToId;
  String? replyToContent;
  late bool isDeleted;
  late bool isEdited;
  DateTime? editedAt;
  DateTime? readAt;

  ChatMessage toEntity() => ChatMessage(
        id:             id,
        conversationId: conversationId,
        senderId:       senderId,
        senderRole:     senderRole,
        content:        content,
        sentAt:         sentAt,
        messageType:    MessageType.values.firstWhere(
          (t) => t.name == messageType,
          orElse: () => MessageType.text,
        ),
        mediaUrl:       mediaUrl,
        replyToId:      replyToId,
        replyToContent: replyToContent,
        isDeleted:      isDeleted,
        isEdited:       isEdited,
        editedAt:       editedAt,
        readAt:         readAt,
      );

  static ChatMessageModel fromEntity(ChatMessage e) => ChatMessageModel()
    ..id             = e.id
    ..conversationId = e.conversationId
    ..senderId       = e.senderId
    ..senderRole     = e.senderRole
    ..content        = e.content
    ..sentAt         = e.sentAt
    ..messageType    = e.messageType.name
    ..mediaUrl       = e.mediaUrl
    ..replyToId      = e.replyToId
    ..replyToContent = e.replyToContent
    ..isDeleted      = e.isDeleted
    ..isEdited       = e.isEdited
    ..editedAt       = e.editedAt
    ..readAt         = e.readAt;

  static ChatMessageModel fromJson(Map<String, dynamic> json) =>
      ChatMessageModel.fromEntity(ChatMessage(
        id:             json['id'] as String,
        conversationId: json['conversationId'] as String,
        senderId:       json['senderId'] as String,
        senderRole:     json['senderRole'] as String,
        content:        json['content'] as String,
        sentAt:         DateTime.parse(json['sentAt'] as String),
        messageType:    MessageType.values.firstWhere(
          (t) => t.name == json['messageType'],
          orElse: () => MessageType.text,
        ),
        mediaUrl:       json['mediaUrl'] as String?,
        replyToId:      json['replyToId'] as String?,
        replyToContent: json['replyToContent'] as String?,
        isDeleted:      json['isDeleted'] as bool? ?? false,
        isEdited:       json['isEdited'] as bool? ?? false,
        editedAt:       json['editedAt'] != null
            ? DateTime.parse(json['editedAt'] as String)
            : null,
        readAt: json['readAt'] != null
            ? DateTime.parse(json['readAt'] as String)
            : null,
      ));
}

@Collection()
class ConversationModel {
  Id get isarId => Isar.autoIncrement;

  @Index(unique: true)
  late String id;

  late List<String> participantIds;
  late List<String> participantRoles;
  String? lastMessageContent;
  DateTime? lastMessageAt;
  late int unreadCount;
  DateTime? updatedAt;
}
