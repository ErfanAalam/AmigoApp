class GroupModel {
  final int conversationId;
  final String title;
  final List<GroupMember>? members;
  final GroupMetadata? metadata;
  final int? lastMessageId;
  final String? lastMessageType;
  final String? lastMessageBody;
  final String? lastMessageAt;
  final int? pinnedMessageId;
  final String? role; // user's role in the group (admin/member)
  final int unreadCount;
  final bool? isPinned;
  final bool? isMuted;
  final bool? isFavorite;
  final String joinedAt;

  GroupModel({
    required this.conversationId,
    required this.title,
    this.members,
    this.metadata,
    this.lastMessageId,
    this.lastMessageType,
    this.lastMessageBody,
    this.lastMessageAt,
    this.role,
    this.unreadCount = 0,
    this.isPinned,
    this.isMuted,
    this.isFavorite,
    required this.joinedAt,
    this.pinnedMessageId,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      conversationId: json['conversationId'] ?? json['conversation_id'] ?? 0,
      title: json['title'] ?? '',
      members: (json['members'] as List<dynamic>?)
          ?.map((member) => GroupMember.fromJson(member))
          .toList(),
      metadata: json['metadata'] != null
          ? GroupMetadata.fromJson(json['metadata'])
          : null,
      lastMessageId: json['lastMessageId'] ?? json['last_message_id'],
      lastMessageType: json['lastMessageType'] ?? json['last_message_type'],
      lastMessageBody: json['lastMessageBody'] ?? json['last_message_body'],
      lastMessageAt: json['lastMessageAt'] ?? json['last_message_at'],
      role: json['role'] ?? json['userRole'],
      unreadCount:
          json['unreadCount'] ??
          json['unread_count'] ??
          json['userUnreadCount'] ??
          0,
      isPinned: json['isPinned'] ?? json['is_pinned'],
      isMuted: json['isMuted'] ?? json['is_muted'],
      isFavorite: json['isFavorite'] ?? json['is_favorite'],
      joinedAt:
          json['joinedAt'] ??
          json['joined_at'] ??
          json['userJoinedAt'] ??
          DateTime.now().toIso8601String(),
      pinnedMessageId: json['pinnedMessageId'] ?? json['pinned_message_id'],
    );
  }

  // Helper to get member count
  int get memberCount => members?.length ?? 0;

  // Helper to get display members (excluding current user for display)
  List<GroupMember> getDisplayMembers(int currentUserId) {
    return members
            ?.where((member) => member.userId != currentUserId)
            .toList() ??
        [];
  }

  // Helper to check if user is admin
  bool isUserAdmin(int userId) {
    if (members == null) return false;
    final member = members!.firstWhere(
      (member) => member.userId == userId,
      orElse: () => GroupMember(userId: 0, name: '', role: 'member'),
    );
    return member.role == 'admin';
  }

  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'title': title,
      'members': members?.map((member) => member.toJson()).toList(),
      'metadata': metadata?.toJson(),
      'lastMessageId': lastMessageId,
      'lastMessageType': lastMessageType,
      'lastMessageBody': lastMessageBody,
      'lastMessageAt': lastMessageAt,
      'role': role,
      'unreadCount': unreadCount,
      'isPinned': isPinned,
      'isMuted': isMuted,
      'isFavorite': isFavorite,
      'joinedAt': joinedAt,
      'pinnedMessageId': pinnedMessageId,
    };
  }

  GroupModel copyWith({
    int? conversationId,
    String? title,
    List<GroupMember>? members,
    GroupMetadata? metadata,
    int? lastMessageId,
    String? lastMessageType,
    String? lastMessageBody,
    String? lastMessageAt,
    String? role,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
    bool? isFavorite,
    String? joinedAt,
    int? pinnedMessageId,
  }) {
    return GroupModel(
      conversationId: conversationId ?? this.conversationId,
      title: title ?? this.title,
      members: members ?? this.members,
      metadata: metadata ?? this.metadata,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageBody: lastMessageBody ?? this.lastMessageBody,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      role: role ?? this.role,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      isFavorite: isFavorite ?? this.isFavorite,
      joinedAt: joinedAt ?? this.joinedAt,
      pinnedMessageId: pinnedMessageId ?? this.pinnedMessageId,
    );
  }
}

class GroupMember {
  final int userId;
  final String name;
  final String? profilePic;
  final String role; // 'admin' or 'member'
  final String? joinedAt;

  GroupMember({
    required this.userId,
    required this.name,
    this.profilePic,
    required this.role,
    this.joinedAt,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['userId'] ?? json['user_id'] ?? 0,
      name: json['name'] ?? json['user_name'] ?? '',
      profilePic: json['profilePic'] ?? json['profile_pic'],
      role: json['role'] ?? 'member',
      joinedAt: json['joinedAt'] ?? json['joined_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'profilePic': profilePic,
      'role': role,
      'joinedAt': joinedAt,
    };
  }

  GroupMember copyWith({
    int? userId,
    String? name,
    String? profilePic,
    String? role,
    String? joinedAt,
  }) {
    return GroupMember(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      profilePic: profilePic ?? this.profilePic,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}

class GroupMetadata {
  final GroupLastMessage? lastMessage;
  final int totalMessages;
  final String? createdAt;
  final int createdBy;
  final GroupPinnedMessage? pinnedMessage;

  GroupMetadata({
    this.lastMessage,
    required this.totalMessages,
    this.createdAt,
    required this.createdBy,
    this.pinnedMessage,
  });

  factory GroupMetadata.fromJson(Map<String, dynamic> json) {
    return GroupMetadata(
      lastMessage: json['last_message'] != null
          ? GroupLastMessage.fromJson(json['last_message'])
          : null,
      totalMessages: json['total_messages'] ?? json['totalMessages'] ?? 0,
      createdAt: json['created_at'] ?? json['createdAt'],
      createdBy: json['created_by'] ?? json['createdBy'] ?? 0,
      pinnedMessage: json['pinned_message'] != null
          ? GroupPinnedMessage.fromJson(json['pinned_message'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'last_message': lastMessage?.toJson(),
      'total_messages': totalMessages,
      'created_at': createdAt,
      'created_by': createdBy,
      'pinned_message': pinnedMessage?.toJson(),
    };
  }

  GroupMetadata copyWith({
    GroupLastMessage? lastMessage,
    int? totalMessages,
    String? createdAt,
    int? createdBy,
    GroupPinnedMessage? pinnedMessage,
  }) {
    return GroupMetadata(
      lastMessage: lastMessage ?? this.lastMessage,
      totalMessages: totalMessages ?? this.totalMessages,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      pinnedMessage: pinnedMessage ?? this.pinnedMessage,
    );
  }
}

class GroupLastMessage {
  final int id;
  final String body;
  final String type;
  final int senderId;
  final String senderName;
  final String createdAt;
  final int conversationId;
  final Map<String, dynamic>? attachmentData;

  GroupLastMessage({
    required this.id,
    required this.body,
    required this.type,
    required this.senderId,
    required this.senderName,
    required this.createdAt,
    required this.conversationId,
    this.attachmentData,
  });

  factory GroupLastMessage.fromJson(Map<String, dynamic> json) {
    return GroupLastMessage(
      id: json['id'] ?? 0,
      body: json['body'] ?? '',
      type: json['type'] ?? 'text',
      senderId: json['sender_id'] ?? json['senderId'] ?? 0,
      senderName: json['sender_name'] ?? json['senderName'] ?? '',
      createdAt: json['created_at'] ?? json['createdAt'] ?? '',
      conversationId: json['conversation_id'] ?? json['conversationId'] ?? 0,
      attachmentData: json['attachments'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'body': body,
      'type': type,
      'sender_id': senderId,
      'sender_name': senderName,
      'created_at': createdAt,
      'conversation_id': conversationId,
      'attachments': attachmentData,
    };
  }

  GroupLastMessage copyWith({
    int? id,
    String? body,
    String? type,
    int? senderId,
    String? senderName,
    String? createdAt,
    int? conversationId,
    Map<String, dynamic>? attachmentData,
  }) {
    return GroupLastMessage(
      id: id ?? this.id,
      body: body ?? this.body,
      type: type ?? this.type,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      createdAt: createdAt ?? this.createdAt,
      conversationId: conversationId ?? this.conversationId,
      attachmentData: attachmentData ?? this.attachmentData,
    );
  }
}

// Helper class for group creation
class CreateGroupRequest {
  final String title;
  final List<int> memberIds;

  CreateGroupRequest({required this.title, required this.memberIds});

  Map<String, dynamic> toJson() {
    return {'title': title, 'member_ids': memberIds};
  }

  CreateGroupRequest copyWith({String? title, List<int>? memberIds}) {
    return CreateGroupRequest(
      title: title ?? this.title,
      memberIds: memberIds ?? this.memberIds,
    );
  }
}

// Helper class for member management
class GroupMemberAction {
  final int conversationId;
  final int userId;
  final String? role;

  GroupMemberAction({
    required this.conversationId,
    required this.userId,
    this.role,
  });

  Map<String, dynamic> toJson() {
    return {
      'conversation_id': conversationId,
      'user_id': userId,
      if (role != null) 'role': role,
    };
  }

  GroupMemberAction copyWith({int? conversationId, int? userId, String? role}) {
    return GroupMemberAction(
      conversationId: conversationId ?? this.conversationId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
    );
  }
}

class GroupPinnedMessage {
  final int userId;
  final int messageId;
  final String pinnedAt;

  GroupPinnedMessage({
    required this.userId,
    required this.messageId,
    required this.pinnedAt,
  });

  factory GroupPinnedMessage.fromJson(Map<String, dynamic> json) {
    return GroupPinnedMessage(
      userId: _parseToInt(json['user_id']),
      messageId: _parseToInt(json['message_id']),
      pinnedAt: json['pinned_at'] ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'user_id': userId, 'message_id': messageId, 'pinned_at': pinnedAt};
  }

  GroupPinnedMessage copyWith({int? userId, int? messageId, String? pinnedAt}) {
    return GroupPinnedMessage(
      userId: userId ?? this.userId,
      messageId: messageId ?? this.messageId,
      pinnedAt: pinnedAt ?? this.pinnedAt,
    );
  }

  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
