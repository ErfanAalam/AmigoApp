import 'package:flutter/foundation.dart';

class MessageModel {
  final int id;
  final String body;
  final String type;
  final int senderId;
  final int conversationId;
  final String createdAt;
  final String? editedAt;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic>? attachments;
  final bool deleted;
  final String senderName;
  final String? senderProfilePic;
  final MessageModel? replyToMessage; // Reply to message
  final int? replyToMessageId; // Reply to message ID
  final bool isDelivered; // Message delivery status
  final String? localMediaPath; // Local cached media file path

  MessageModel({
    required this.id,
    required this.body,
    required this.type,
    required this.senderId,
    required this.conversationId,
    required this.createdAt,
    this.editedAt,
    this.metadata,
    this.attachments,
    required this.deleted,
    required this.senderName,
    this.senderProfilePic,
    this.replyToMessage,
    this.replyToMessageId,
    this.isDelivered = false,
    this.localMediaPath,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    MessageModel? replyToMessage;
    int? replyToMessageId;

    // Check for reply data in reply_to_message field first
    if (json['reply_to_message'] != null) {
      replyToMessage = MessageModel.fromJson(
        json['reply_to_message'] as Map<String, dynamic>,
      );
    } else if (json['reply_to_message_id'] != null) {
      replyToMessageId = _parseToInt(json['reply_to_message_id']);
    }

    // Also check for reply data in metadata field (server format)
    final metadata = json['metadata'] as Map<String, dynamic>?;
    if (replyToMessage == null &&
        metadata != null &&
        metadata['reply_to'] != null) {
      final replyToData = metadata['reply_to'] as Map<String, dynamic>;
      replyToMessageId = _parseToInt(replyToData['message_id']);

      // Create reply message from metadata
      replyToMessage = MessageModel(
        id: replyToMessageId,
        body: replyToData['body']?.toString() ?? '',
        type: 'text',
        senderId: _parseToInt(replyToData['sender_id']),
        conversationId: _parseToInt(json['conversation_id']),
        createdAt: replyToData['created_at']?.toString() ?? '',
        deleted: false,
        senderName: '', // Will be populated later if needed
        senderProfilePic: null,
        isDelivered: false,
      );
    }

    return MessageModel(
      id: _parseToInt(json['id']),
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      senderId: _parseToInt(json['sender_id']),
      conversationId: _parseToInt(json['conversation_id']),
      createdAt: json['created_at']?.toString() ?? '',
      editedAt: json['edited_at']?.toString(),
      metadata: metadata,
      attachments: json['attachments'] as Map<String, dynamic>?,
      deleted: json['deleted'] == true || json['deleted'] == 'true',
      senderName: json['sender_name']?.toString() ?? '',
      senderProfilePic: json['sender_profile_pic']?.toString(),
      replyToMessage: replyToMessage,
      replyToMessageId:
          replyToMessageId ??
          (json['reply_to_message_id'] != null
              ? _parseToInt(json['reply_to_message_id'])
              : null),
      isDelivered:
          json['is_delivered'] == true || json['is_delivered'] == 'true',
      localMediaPath: json['local_media_path']?.toString(),
    );
  }

  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'body': body,
      'type': type,
      'sender_id': senderId,
      'conversation_id': conversationId,
      'created_at': createdAt,
      'edited_at': editedAt,
      'metadata': metadata,
      'attachments': attachments,
      'deleted': deleted,
      'sender_name': senderName,
      'sender_profile_pic': senderProfilePic,
      'reply_to_message': replyToMessage?.toJson(),
      'reply_to_message_id': replyToMessageId,
      'is_delivered': isDelivered,
      'local_media_path': localMediaPath,
    };
  }

  bool get isText => type == 'text';
  bool get isImage => type == 'image';
  bool get isFile => type == 'file';

  /// Create a copy of this message with updated read/delivery status
  MessageModel copyWith({
    bool? isDelivered,
    bool? isRead,
    String? localMediaPath,
  }) {
    return MessageModel(
      id: id,
      body: body,
      type: type,
      senderId: senderId,
      conversationId: conversationId,
      createdAt: createdAt,
      editedAt: editedAt,
      metadata: metadata,
      attachments: attachments,
      deleted: deleted,
      senderName: senderName,
      senderProfilePic: senderProfilePic,
      replyToMessage: replyToMessage,
      replyToMessageId: replyToMessageId,
      isDelivered: isDelivered ?? this.isDelivered,
      localMediaPath: localMediaPath ?? this.localMediaPath,
    );
  }
}

class ConversationHistoryResponse {
  final List<MessageModel> messages;
  final int totalCount;
  final int currentPage;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final List<Map<String, dynamic>>
  members; // Store members data for sender names

  ConversationHistoryResponse({
    required this.messages,
    required this.totalCount,
    required this.currentPage,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPreviousPage,
    this.members = const [],
  });

  factory ConversationHistoryResponse.fromJson(Map<String, dynamic> json) {
    // Handle the nested structure: data.data.messages and data.data.pagination
    final outerData = json['data'] ?? json;
    final innerData = outerData['data'] ?? outerData;
    final messagesData = innerData['messages'] ?? [];
    final pagination = innerData['pagination'] ?? {};
    final membersData = innerData['members'] ?? [];

    debugPrint(
      '🔍 ConversationHistoryResponse: Parsing members data: $membersData',
    );
    debugPrint(
      '🔍 ConversationHistoryResponse: Members count: ${membersData.length}',
    );

    return ConversationHistoryResponse(
      messages: (messagesData as List)
          .map(
            (messageJson) =>
                MessageModel.fromJson(messageJson as Map<String, dynamic>),
          )
          .toList(),
      totalCount: _parseToInt(pagination['totalCount']),
      currentPage: _parseToInt(pagination['currentPage']),
      totalPages: _parseToInt(pagination['totalPages']),
      hasNextPage:
          pagination['hasNextPage'] == true ||
          pagination['hasNextPage'] == 'true',
      hasPreviousPage:
          pagination['hasPreviousPage'] == true ||
          pagination['hasPreviousPage'] == 'true',
      members: (membersData as List).cast<Map<String, dynamic>>(),
    );
  }

  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
