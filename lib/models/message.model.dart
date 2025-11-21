import 'package:amigo/types/socket.type.dart';

class MessageModel {
  final int? canonicalId;
  final int? optimisticId;
  final int conversationId;
  final int senderId;
  final String? senderName;
  final String? senderProfilePic;
  final MessageType type;
  final String? body;
  final MessageStatusType status;
  final Map<String, dynamic>? attachments;
  final Map<String, dynamic>? metadata;
  final String? localMediaPath;
  final bool? isStarred;
  final bool? isReplied;
  final bool? isForwarded;
  final bool? isDeleted;
  final String sentAt;

  MessageModel({
    this.canonicalId,
    this.optimisticId,
    required this.conversationId,
    required this.senderId,
    this.senderName,
    this.senderProfilePic,
    required this.type,
    this.body,
    required this.status,
    this.attachments,
    this.metadata,
    this.localMediaPath,
    this.isStarred,
    this.isReplied,
    this.isForwarded,
    this.isDeleted,
    required this.sentAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>?;

    // Parse message type
    final messageType =
        MessageType.fromString(
          json['type']?.toString() ?? json['msg_type']?.toString(),
        ) ??
        MessageType.text;

    // Parse status - check status field first, then is_delivered for backward compatibility
    MessageStatusType messageStatus;
    if (json['status'] != null) {
      messageStatus =
          MessageStatusType.fromString(json['status']?.toString()) ??
          MessageStatusType.sent;
    } else if (json['is_delivered'] == true || json['is_delivered'] == 'true') {
      messageStatus = MessageStatusType.delivered;
    } else {
      messageStatus = MessageStatusType.sent;
    }

    // Parse IDs - canonical_id takes precedence, then id, then optimistic_id
    final canonicalId = json['canonical_id'] != null
        ? _parseToInt(json['canonical_id'])
        : (json['id'] != null ? _parseToInt(json['id']) : null);
    final optimisticId = json['optimistic_id'] != null
        ? _parseToInt(json['optimistic_id'])
        : null;

    // Parse sentAt - check sent_at first, then created_at for backward compatibility
    final sentAt =
        json['sent_at']?.toString() ??
        json['created_at']?.toString() ??
        DateTime.now().toIso8601String();

    // Parse boolean flags from metadata or direct fields
    final isStarred =
        json['is_starred'] == true ||
        json['is_starred'] == 'true' ||
        metadata?['is_starred'] == true;
    final isReplied =
        json['is_replied'] == true ||
        json['is_replied'] == 'true' ||
        metadata?['is_replied'] == true ||
        metadata?['reply_to'] != null;
    final isForwarded =
        json['is_forwarded'] == true ||
        json['is_forwarded'] == 'true' ||
        metadata?['forwarded_from'] != null;
    final isDeleted =
        json['deleted'] == true ||
        json['deleted'] == 'true' ||
        json['is_deleted'] == true ||
        json['is_deleted'] == 'true';

    return MessageModel(
      canonicalId: canonicalId,
      optimisticId: optimisticId,
      conversationId: _parseToInt(json['conversation_id'] ?? json['conv_id']),
      senderId: _parseToInt(json['sender_id']),
      senderName: json['sender_name']?.toString(),
      senderProfilePic:
          json['sender_profile_pic']?.toString() ??
          json['sender_pfp']?.toString(),
      type: messageType,
      body: json['body']?.toString(),
      status: messageStatus,
      attachments: json['attachments'] as Map<String, dynamic>?,
      metadata: metadata,
      isStarred: isStarred ? true : null,
      isReplied: isReplied ? true : null,
      isForwarded: isForwarded ? true : null,
      isDeleted: isDeleted ? true : null,
      sentAt: sentAt,
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
      if (canonicalId != null) 'canonical_id': canonicalId,
      if (canonicalId != null) 'id': canonicalId, // For backward compatibility
      if (optimisticId != null) 'optimistic_id': optimisticId,
      'conversation_id': conversationId,
      'sender_id': senderId,
      if (senderName != null) 'sender_name': senderName,
      if (senderProfilePic != null) 'sender_profile_pic': senderProfilePic,
      'type': type.value,
      'msg_type': type.value, // For backward compatibility
      if (body != null) 'body': body,
      'status': status.value,
      if (attachments != null) 'attachments': attachments,
      if (metadata != null) 'metadata': metadata,
      if (isStarred == true) 'is_starred': isStarred,
      if (isReplied == true) 'is_replied': isReplied,
      if (isForwarded == true) 'is_forwarded': isForwarded,
      if (isDeleted == true) 'deleted': isDeleted,
      if (isDeleted == true) 'is_deleted': isDeleted,
      'sent_at': sentAt,
      'created_at': sentAt, // For backward compatibility
    };
  }

  bool get isText => type == MessageType.text;
  bool get isImage => type == MessageType.image;
  bool get isFile => type == MessageType.document;
  bool get isVideo => type == MessageType.video;
  bool get isAudio => type == MessageType.audio;
  bool get isReply => type == MessageType.reply || isReplied == true;
  bool get isForwardedMessage =>
      type == MessageType.forwarded || isForwarded == true;

  /// Get the message ID (canonical if available, otherwise optimistic)
  int get id => canonicalId ?? optimisticId ?? 0;

  /// Create a copy of this message with updated fields
  MessageModel copyWith({
    int? canonicalId,
    int? optimisticId,
    int? conversationId,
    int? senderId,
    String? senderName,
    String? senderProfilePic,
    MessageType? type,
    String? body,
    MessageStatusType? status,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? attachments,
    bool? isPinned,
    bool? isStarred,
    bool? isReplied,
    bool? isForwarded,
    bool? isDeleted,
    String? sentAt,
    String? localMediaPath,
  }) {
    return MessageModel(
      canonicalId: canonicalId ?? this.canonicalId,
      optimisticId: optimisticId ?? this.optimisticId,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderProfilePic: senderProfilePic ?? this.senderProfilePic,
      type: type ?? this.type,
      body: body ?? this.body,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
      attachments: attachments ?? this.attachments,
      isStarred: isStarred ?? this.isStarred,
      isReplied: isReplied ?? this.isReplied,
      isForwarded: isForwarded ?? this.isForwarded,
      isDeleted: isDeleted ?? this.isDeleted,
      sentAt: sentAt ?? this.sentAt,
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
