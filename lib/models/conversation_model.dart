class ConversationModel {
  final int conversationId;
  final String type;
  final String? title;
  final ConversationMetadata? metadata;
  final String? lastMessageAt;
  final String? role;
  final int unreadCount;
  final String joinedAt;
  final int userId;
  final String userName;
  final String? userProfilePic;
  final bool? isOnline; // Online status for DM conversations

  ConversationModel({
    required this.conversationId,
    required this.type,
    this.title,
    this.metadata,
    this.lastMessageAt,
    this.role,
    required this.unreadCount,
    required this.joinedAt,
    required this.userId,
    required this.userName,
    this.userProfilePic,
    this.isOnline,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      conversationId: _parseToInt(json['conversationId']),
      type: json['type'] ?? '',
      title: json['title'],
      metadata: json['metadata'] != null
          ? ConversationMetadata.fromJson(json['metadata'])
          : null,
      lastMessageAt: json['lastMessageAt'],
      role: json['role'],
      unreadCount: _parseToInt(json['unreadCount']),
      joinedAt: json['joinedAt'] ?? '',
      userId: _parseToInt(json['userId']),
      userName: json['userName'] ?? 'Unknown User',
      userProfilePic: json['userProfilePic'],
      isOnline: json['isOnline'], // Will be set separately by UserStatusService
    );
  }

  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Get the display name for this conversation
  /// For DM conversations, returns userName
  /// For group conversations, returns title
  String get displayName {
    if (type.toLowerCase() == 'group') {
      return title ?? 'Group Chat';
    } else {
      return userName;
    }
  }

  /// Get the appropriate avatar/icon for this conversation
  /// For DM conversations, returns user profile pic or initials
  /// For group conversations, returns group icon
  String? get displayAvatar {
    if (type.toLowerCase() == 'group') {
      return null; // Groups typically don't have profile pics
    } else {
      return userProfilePic;
    }
  }

  /// Check if this is a group conversation
  bool get isGroup {
    return type.toLowerCase() == 'group';
  }

  /// Check if this is a DM conversation
  bool get isDM {
    return type.toLowerCase() == 'dm';
  }

  /// Convert this conversation to JSON
  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'type': type,
      'title': title,
      'metadata': metadata?.toJson(),
      'lastMessageAt': lastMessageAt,
      'role': role,
      'unreadCount': unreadCount,
      'joinedAt': joinedAt,
      'userId': userId,
      'userName': userName,
      'userProfilePic': userProfilePic,
      'isOnline': isOnline,
    };
  }

  /// Create a copy of this conversation with updated online status
  ConversationModel copyWith({
    int? conversationId,
    String? type,
    String? title,
    ConversationMetadata? metadata,
    String? lastMessageAt,
    String? role,
    int? unreadCount,
    String? joinedAt,
    int? userId,
    String? userName,
    String? userProfilePic,
    bool? isOnline,
  }) {
    return ConversationModel(
      conversationId: conversationId ?? this.conversationId,
      type: type ?? this.type,
      title: title ?? this.title,
      metadata: metadata ?? this.metadata,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      role: role ?? this.role,
      unreadCount: unreadCount ?? this.unreadCount,
      joinedAt: joinedAt ?? this.joinedAt,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userProfilePic: userProfilePic ?? this.userProfilePic,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

class ConversationMetadata {
  final LastMessage lastMessage;

  ConversationMetadata({required this.lastMessage});

  factory ConversationMetadata.fromJson(Map<String, dynamic> json) {
    return ConversationMetadata(
      lastMessage: LastMessage.fromJson(json['last_message']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'last_message': lastMessage.toJson()};
  }
}

class LastMessage {
  final int id;
  final String body;
  final String type;
  final int senderId;
  final String createdAt;
  final int conversationId;

  LastMessage({
    required this.id,
    required this.body,
    required this.type,
    required this.senderId,
    required this.createdAt,
    required this.conversationId,
  });

  factory LastMessage.fromJson(Map<String, dynamic> json) {
    return LastMessage(
      id: _parseToInt(json['id']),
      body: json['body'] ?? '',
      type: json['type'] ?? 'text',
      senderId: _parseToInt(json['sender_id']),
      createdAt: json['created_at'] ?? '',
      conversationId: _parseToInt(json['conversation_id']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'body': body,
      'type': type,
      'sender_id': senderId,
      'created_at': createdAt,
      'conversation_id': conversationId,
    };
  }

  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
