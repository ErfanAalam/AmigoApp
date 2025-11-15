class ConversationsModel {
  final int id;
  final String type;
  final String? title;
  final int createrId;
  final int? unreadCount;
  final int? lastMessageId;
  final bool? isDeleted;
  final bool? isPinned;
  final bool? isFavorite;
  final bool? isMuted;
  final String createdAt;

  ConversationsModel({
    required this.id,
    required this.type,
    this.title,
    required this.createrId,
    this.lastMessageId,
    this.unreadCount,
    this.isDeleted,
    this.isPinned,
    this.isMuted,
    this.isFavorite,
    required this.createdAt,
  });

  // factory ConversationsModel.fromJson(Map<String, dynamic> json) {
  //   return ConversationsModel(
  //     id: _parseToInt(json['id']),
  //     type: json['type'] ?? 'dm',
  //     title: json['title'] as String?,
  //     createrId: _parseToInt(json['createrId']),
  //     lastMessageId: _parseToInt(json['lastMessageId']),
  //     lastMessageAt: json['lastMessageAt'] as String?,
  //     lastMessageBody: json['lastMessageBody'] as String?,
  //     lastMessageType: json['lastMessageType'] as String?,
  //     // role: json['role'] as String?,
  //     unreadCount: _parseToInt(json['unreadCount']),
  //     createdAt:
  //         json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
  //     userId: _parseToInt(json['userId']),
  //     userName: json['userName'] as String? ?? 'Unknown',
  //     userProfilePic: json['userProfilePic'] as String?,
  //     isOnline: json['isOnline'] as bool?,
  //     isDeleted: json['isDeleted'] as bool?,
  //     isPinned: json['isPinned'] as bool?,
  //     isMuted: json['isMuted'] as bool?,
  //     isFavorite: json['isFavorite'] as bool?,
  //   );
  // }
  //
  // static int _parseToInt(dynamic value) {
  //   if (value == null) return 0;
  //   if (value is int) return value;
  //   if (value is String) return int.tryParse(value) ?? 0;
  //   return 0;
  // }
  //
  // /// Get the display name for this conversation
  // /// For DM conversations, returns userName
  // /// For group conversations, returns title
  // String? get displayName {
  //   if (type.toLowerCase() == 'group') {
  //     return title ?? 'Group Chat';
  //   } else {
  //     return userName;
  //   }
  // }
  //
  // /// Get the appropriate avatar/icon for this conversation
  // /// For DM conversations, returns user profile pic or initials
  // /// For group conversations, returns group icon
  // String? get displayAvatar {
  //   if (type.toLowerCase() == 'group') {
  //     return null; // Groups typically don't have profile pics
  //   } else {
  //     return userProfilePic;
  //   }
  // }
  //
  // /// Check if this is a group conversation
  // bool get isGroup {
  //   return type.toLowerCase() == 'group';
  // }
  //
  // /// Check if this is a DM conversation
  // bool get isDM {
  //   return type.toLowerCase() == 'dm';
  // }
  //
  // /// Convert this conversation to JSON
  // Map<String, dynamic> toJson() {
  //   return {
  //     'id': id,
  //     'type': type,
  //     'title': title,
  //     'createrId': createrId,
  //     'lastMessageId': lastMessageId,
  //     'lastMessageAt': lastMessageAt,
  //     'lastMessageBody': lastMessageBody,
  //     'lastMessageType': lastMessageType,
  //     // 'role': role,
  //     'unreadCount': unreadCount,
  //     'createdAt': createdAt,
  //     'userId': userId,
  //     'userName': userName,
  //     'userProfilePic': userProfilePic,
  //     'isOnline': isOnline,
  //     'isDeleted': isDeleted,
  //     'isPinned': isPinned,
  //     'isMuted': isMuted,
  //     'isFavorite': isFavorite,
  //   };
}

class DmListModel {
  final int conversationId;
  final int recipientId;
  final String recipientName;
  final String recipientPhone;
  final String? recipientProfilePic;
  final int? lastMessageId;
  final String? lastMessageType;
  final String? lastMessageBody;
  final String? lastMessageAt;
  final int? unreadCount;
  final bool isOnline;
  final bool isDeleted;
  final bool isPinned;
  final bool isMuted;
  final bool isFavorite;
  final String createdAt;

  DmListModel({
    required this.conversationId,
    required this.recipientId,
    required this.recipientName,
    required this.recipientPhone,
    this.recipientProfilePic,
    this.lastMessageId,
    this.lastMessageType,
    this.lastMessageBody,
    this.lastMessageAt,
    this.unreadCount,
    required this.isOnline,
    required this.isDeleted,
    required this.isPinned,
    required this.isMuted,
    required this.isFavorite,
    required this.createdAt,
  })

  factory DmListModel.fromJson(Map<String, dynamic> json) {
    return DmListModel(
      id: _parseToInt(json['id']),
      type: json['type'] ?? 'dm',
      title: json['title'] as String?,
      createrId: _parseToInt(json['createrId']),
      lastMessageId: _parseToInt(json['lastMessageId']),
      lastMessageAt: json['lastMessageAt'] as String?,
      lastMessageBody: json['lastMessageBody'] as String?,
      lastMessageType: json['lastMessageType'] as String?,
      // role: json['role'] as String?,
      unreadCount: _parseToInt(json['unreadCount']),
      createdAt:
          json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      userId: _parseToInt(json['userId']),
      userName: json['userName'] as String? ?? 'Unknown',
      userProfilePic: json['userProfilePic'] as String?,
      isOnline: json['isOnline'] as bool?,
      isDeleted: json['isDeleted'] as bool?,
      isPinned: json['isPinned'] as bool?,
      isMuted: json['isMuted'] as bool?,
      isFavorite: json['isFavorite'] as bool?,
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
  String? get displayName {
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
      'id': id,
      'type': type,
      'title': title,
      'createrId': createrId,
      'lastMessageId': lastMessageId,
      'lastMessageAt': lastMessageAt,
      'lastMessageBody': lastMessageBody,
      'lastMessageType': lastMessageType,
      // 'role': role,
      'unreadCount': unreadCount,
      'createdAt': createdAt,
      'userId': userId,
      'userName': userName,
      'userProfilePic': userProfilePic,
      'isOnline': isOnline,
      'isDeleted': isDeleted,
      'isPinned': isPinned,
      'isMuted': isMuted,
      'isFavorite': isFavorite,
    };
  }

  /// Create a copy of this conversation with updated online status
  DmListModel copyWith({
    int? id,
    String? type,
    String? title,
    int? createrId,
    int? lastMessageId,
    String? lastMessageAt,
    String? lastMessageBody,
    String? lastMessageType,
    // String? role,
    int? unreadCount,
    String? createdAt,
    int? userId,
    String? userName,
    String? userProfilePic,
    bool? isOnline,
    bool? isDeleted,
    bool? isPinned,
    bool? isMuted,
    bool? isFavorite,
  }) {
    return DmListModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      createrId: createrId ?? this.createrId,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageBody: lastMessageBody ?? this.lastMessageBody,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      // role: role ?? this.role,
      unreadCount: unreadCount ?? this.unreadCount,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userProfilePic: userProfilePic ?? this.userProfilePic,
      isOnline: isOnline ?? this.isOnline,
      isDeleted: isDeleted ?? this.isDeleted,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class GroupListModel {
  final int id;
  final String type;
  final String? title;
  final int? createrId;
  final int? lastMessageId;
  final String? lastMessageAt;
  final String? lastMessageBody;
  final String? lastMessageType;
  // final String? role;
  final int? unreadCount;
  final int? userId;
  final String? userName;
  final String? userPhone;
  final String? userProfilePic;
  final bool? isOnline;
  final bool? isDeleted;
  final bool? isPinned;
  final bool? isMuted;
  final bool? isFavorite;
  final String createdAt;

  GroupListModel({
    required this.id,
    required this.type,
    this.title,
    this.createrId,
    this.lastMessageId,
    this.lastMessageAt,
    this.lastMessageBody,
    this.lastMessageType,
    // this.role,
    this.unreadCount,
    this.userId,
    this.userName,
    this.userPhone,
    this.userProfilePic,
    this.isOnline,
    this.isDeleted,
    this.isPinned,
    this.isMuted,
    this.isFavorite,
    required this.createdAt,
  });

  factory GroupListModel.fromJson(Map<String, dynamic> json) {
    return GroupListModel(
      id: _parseToInt(json['id']),
      type: json['type'] ?? 'dm',
      title: json['title'] as String?,
      createrId: _parseToInt(json['createrId']),
      lastMessageId: _parseToInt(json['lastMessageId']),
      lastMessageAt: json['lastMessageAt'] as String?,
      lastMessageBody: json['lastMessageBody'] as String?,
      lastMessageType: json['lastMessageType'] as String?,
      // role: json['role'] as String?,
      unreadCount: _parseToInt(json['unreadCount']),
      createdAt:
          json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      userId: _parseToInt(json['userId']),
      userName: json['userName'] as String? ?? 'Unknown',
      userProfilePic: json['userProfilePic'] as String?,
      isOnline: json['isOnline'] as bool?,
      isDeleted: json['isDeleted'] as bool?,
      isPinned: json['isPinned'] as bool?,
      isMuted: json['isMuted'] as bool?,
      isFavorite: json['isFavorite'] as bool?,
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
  String? get displayName {
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
      'id': id,
      'type': type,
      'title': title,
      'createrId': createrId,
      'lastMessageId': lastMessageId,
      'lastMessageAt': lastMessageAt,
      'lastMessageBody': lastMessageBody,
      'lastMessageType': lastMessageType,
      // 'role': role,
      'unreadCount': unreadCount,
      'createdAt': createdAt,
      'userId': userId,
      'userName': userName,
      'userProfilePic': userProfilePic,
      'isOnline': isOnline,
      'isDeleted': isDeleted,
      'isPinned': isPinned,
      'isMuted': isMuted,
      'isFavorite': isFavorite,
    };
  }

  /// Create a copy of this conversation with updated online status
  GroupListModel copyWith({
    int? id,
    String? type,
    String? title,
    int? createrId,
    int? lastMessageId,
    String? lastMessageAt,
    String? lastMessageBody,
    String? lastMessageType,
    // String? role,
    int? unreadCount,
    String? createdAt,
    int? userId,
    String? userName,
    String? userProfilePic,
    bool? isOnline,
    bool? isDeleted,
    bool? isPinned,
    bool? isMuted,
    bool? isFavorite,
  }) {
    return GroupListModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      createrId: createrId ?? this.createrId,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageBody: lastMessageBody ?? this.lastMessageBody,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      // role: role ?? this.role,
      unreadCount: unreadCount ?? this.unreadCount,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userProfilePic: userProfilePic ?? this.userProfilePic,
      isOnline: isOnline ?? this.isOnline,
      isDeleted: isDeleted ?? this.isDeleted,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// class ConversationMetadata {
//   final LastMessage lastMessage;
//   final PinnedMessage? pinnedMessage;
//
//   ConversationMetadata({required this.lastMessage, this.pinnedMessage});
//
//   factory ConversationMetadata.fromJson(Map<String, dynamic> json) {
//     return ConversationMetadata(
//       lastMessage: LastMessage.fromJson(json['last_message']),
//       pinnedMessage: json['pinned_message'] != null
//           ? PinnedMessage.fromJson(json['pinned_message'])
//           : null,
//     );
//   }
//
//   Map<String, dynamic> toJson() {
//     return {
//       'last_message': lastMessage.toJson(),
//       'pinned_message': pinnedMessage?.toJson(),
//     };
//   }
// }

// class LastMessage {
//   final int id;
//   final String body;
//   final String type;
//   final int senderId;
//   final String sentAt;
//   final int conversationId;
//   final Map<String, dynamic>? attachmentData;
//
//   LastMessage({
//     required this.id,
//     required this.body,
//     required this.type,
//     required this.senderId,
//     required this.sentAt,
//     required this.conversationId,
//     this.attachmentData,
//   });
//
//   factory LastMessage.fromJson(Map<String, dynamic> json) {
//     return LastMessage(
//       id: _parseToInt(json['id']),
//       body: json['body'] ?? '',
//       type: json['type'] ?? 'text',
//       senderId: _parseToInt(json['sender_id']),
//       sentAt: json['created_at'] ?? '',
//       conversationId: _parseToInt(json['conversation_id']),
//       attachmentData: json['attachments'] as Map<String, dynamic>?,
//     );
//   }
//
//   Map<String, dynamic> toJson() {
//     return {
//       'id': id,
//       'body': body,
//       'type': type,
//       'sender_id': senderId,
//       'created_at': sentAt,
//       'conversation_id': conversationId,
//       'attachments': attachmentData,
//     };
//   }
//
//   static int _parseToInt(dynamic value) {
//     if (value == null) return 0;
//     if (value is int) return value;
//     if (value is String) return int.tryParse(value) ?? 0;
//     return 0;
//   }
// }
//
// class PinnedMessage {
//   final int userId;
//   final int messageId;
//   final String pinnedAt;
//
//   PinnedMessage({
//     required this.userId,
//     required this.messageId,
//     required this.pinnedAt,
//   });
//
//   factory PinnedMessage.fromJson(Map<String, dynamic> json) {
//     return PinnedMessage(
//       userId: _parseToInt(json['user_id']),
//       messageId: _parseToInt(json['message_id']),
//       pinnedAt: json['pinned_at'] ?? DateTime.now().toIso8601String(),
//     );
//   }
//
//   Map<String, dynamic> toJson() {
//     return {'user_id': userId, 'message_id': messageId, 'pinned_at': pinnedAt};
//   }
//
//   static int _parseToInt(dynamic value) {
//     if (value == null) return 0;
//     if (value is int) return value;
//     if (value is String) return int.tryParse(value) ?? 0;
//     return 0;
//   }
// }
