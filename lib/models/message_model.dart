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
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    MessageModel? replyToMessage;
    if (json['reply_to_message'] != null) {
      replyToMessage = MessageModel.fromJson(
        json['reply_to_message'] as Map<String, dynamic>,
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
      metadata: json['metadata'] as Map<String, dynamic>?,
      attachments: json['attachments'] as Map<String, dynamic>?,
      deleted: json['deleted'] == true || json['deleted'] == 'true',
      senderName: json['sender_name']?.toString() ?? '',
      senderProfilePic: json['sender_profile_pic']?.toString(),
      replyToMessage: replyToMessage,
      replyToMessageId: json['reply_to_message_id'] != null
          ? _parseToInt(json['reply_to_message_id'])
          : null,
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
    };
  }

  bool get isText => type == 'text';
  bool get isImage => type == 'image';
  bool get isFile => type == 'file';
}

class ConversationHistoryResponse {
  final List<MessageModel> messages;
  final int totalCount;
  final int currentPage;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPreviousPage;

  ConversationHistoryResponse({
    required this.messages,
    required this.totalCount,
    required this.currentPage,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  factory ConversationHistoryResponse.fromJson(Map<String, dynamic> json) {
    // Handle the nested structure: data.data.messages and data.data.pagination
    final outerData = json['data'] ?? json;
    final innerData = outerData['data'] ?? outerData;
    final messagesData = innerData['messages'] ?? [];
    final pagination = innerData['pagination'] ?? {};

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
    );
  }

  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
