class ConversationModel {
  final int id;
  final String type;
  final String? title;
  final int createrId;
  final int? unreadCount;
  final int? lastMessageId;
  final int? pinnedMessageId;
  final bool? isDeleted;
  final bool? isPinned;
  final bool? isFavorite;
  final bool? isMuted;
  final String createdAt;
  final String? updatedAt;
  final bool? needSync;

  ConversationModel({
    required this.id,
    required this.type,
    this.title,
    required this.createrId,
    this.lastMessageId,
    this.pinnedMessageId,
    this.unreadCount,
    this.isDeleted,
    this.isPinned,
    this.isMuted,
    this.isFavorite,
    required this.createdAt,
    this.updatedAt,
    this.needSync,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'],
      type: json['type'],
      title: json['title'],
      createrId: json['createrId'],
      lastMessageId: json['lastMessageId'],
      pinnedMessageId: json['pinnedMessageId'],
      unreadCount: json['unreadCount'],
      isDeleted: json['isDeleted'],
      isPinned: json['isPinned'],
      isMuted: json['isMuted'],
      isFavorite: json['isFavorite'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      needSync: json['needSync'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'createrId': createrId,
      'lastMessageId': lastMessageId,
      'pinnedMessageId': pinnedMessageId,
      'unreadCount': unreadCount,
      'isDeleted': isDeleted,
      'isPinned': isPinned,
      'isMuted': isMuted,
      'isFavorite': isFavorite,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'needSync': needSync,
    };
  }
}

class DmModel {
  final int conversationId;
  final int recipientId;
  final String recipientName;
  final String recipientPhone;
  final String? recipientProfilePic;
  final int? lastMessageId;
  final String? lastMessageType;
  final String? lastMessageBody;
  final String? lastMessageAt;
  final int? pinnedMessageId;
  final int? unreadCount;
  final bool isRecipientOnline;
  final bool? isDeleted;
  final bool? isPinned;
  final bool? isMuted;
  final bool? isFavorite;
  final String createdAt;

  DmModel({
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
    required this.isRecipientOnline,
    this.isDeleted,
    this.isPinned,
    this.isMuted,
    this.isFavorite,
    required this.createdAt,
    this.pinnedMessageId,
  });

  factory DmModel.fromJson(Map<String, dynamic> json) {
    return DmModel(
      conversationId: json['conversationId'],
      recipientId: json['recipientId'],
      recipientName: json['recipientName'],
      recipientPhone: json['recipientPhone'],
      recipientProfilePic: json['recipientProfilePic'],
      lastMessageId: json['lastMessageId'],
      lastMessageType: json['lastMessageType'],
      lastMessageBody: json['lastMessageBody'],
      lastMessageAt: json['lastMessageAt'],
      unreadCount: json['unreadCount'],
      isRecipientOnline: json['isOnline'],
      isDeleted: json['isDeleted'],
      isPinned: json['isPinned'],
      isMuted: json['isMuted'],
      isFavorite: json['isFavorite'],
      createdAt: json['createdAt'],
      pinnedMessageId: json['pinnedMessageId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'recipientProfilePic': recipientProfilePic,
      'lastMessageId': lastMessageId,
      'lastMessageType': lastMessageType,
      'lastMessageBody': lastMessageBody,
      'lastMessageAt': lastMessageAt,
      'unreadCount': unreadCount,
      'isOnline': isRecipientOnline,
      'isDeleted': isDeleted,
      'isPinned': isPinned,
      'isMuted': isMuted,
      'isFavorite': isFavorite,
      'createdAt': createdAt,
      'pinnedMessageId': pinnedMessageId,
    };
  }

  DmModel copyWith({
    int? conversationId,
    int? recipientId,
    String? recipientName,
    String? recipientPhone,
    String? recipientProfilePic,
    int? lastMessageId,
    String? lastMessageType,
    String? lastMessageBody,
    String? lastMessageAt,
    int? unreadCount,
    bool? isRecipientOnline,
    bool? isDeleted,
    bool? isPinned,
    bool? isMuted,
    bool? isFavorite,
    String? createdAt,
    int? pinnedMessageId,
  }) {
    return DmModel(
      conversationId: conversationId ?? this.conversationId,
      recipientId: recipientId ?? this.recipientId,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      recipientProfilePic: recipientProfilePic ?? this.recipientProfilePic,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageBody: lastMessageBody ?? this.lastMessageBody,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isRecipientOnline: isRecipientOnline ?? this.isRecipientOnline,
      isDeleted: isDeleted ?? this.isDeleted,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      pinnedMessageId: pinnedMessageId ?? this.pinnedMessageId,
    );
  }
}

class ConversationMemberModel {
  final int? id;
  final int conversationId;
  final int userId;
  final String role;
  final int? unreadCount;
  final String? joinedAt;
  final String? removedAt;
  final int? lastReadMessageId;
  final int? lastDeliveredMessageId;

  ConversationMemberModel({
    this.id,
    required this.conversationId,
    required this.userId,
    required this.role,
    this.unreadCount,
    this.joinedAt,
    this.removedAt,
    this.lastReadMessageId,
    this.lastDeliveredMessageId,
  });
}

class ConversationWithMiscs extends ConversationModel {
  final String lastMessageBody;
  final String lastMessageType;
  final String lastMessageAt;

  ConversationWithMiscs({
    required this.lastMessageBody,
    required this.lastMessageType,
    required this.lastMessageAt,

    required super.id,
    required super.lastMessageId,
    required super.type,
    required super.createrId,
    required super.createdAt,
  });
}
