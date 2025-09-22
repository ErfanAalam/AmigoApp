class GroupModel {
  final int conversationId;
  final String title;
  final String type; // 'group'
  final List<GroupMember> members;
  final GroupMetadata? metadata;
  final String? lastMessageAt;
  final String? role; // user's role in the group (admin/member)
  // final int unreadCount;
  final String joinedAt;

  GroupModel({
    required this.conversationId,
    required this.title,
    required this.type,
    required this.members,
    this.metadata,
    this.lastMessageAt,
    this.role,
    // required this.unreadCount,
    required this.joinedAt,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      conversationId: json['conversationId'] ?? json['conversation_id'] ?? 0,
      title: json['title'] ?? '',
      type: json['type'] ?? 'group',
      members:
          (json['members'] as List<dynamic>?)
              ?.map((member) => GroupMember.fromJson(member))
              .toList() ??
          [],
      metadata: json['metadata'] != null
          ? GroupMetadata.fromJson(json['metadata'])
          : null,
      lastMessageAt: json['lastMessageAt'] ?? json['last_message_at'],
      role: json['role'],
      // unreadCount: json['unreadCount'] ?? json['unread_count'] ?? 0,
      joinedAt:
          json['joinedAt'] ??
          json['joined_at'] ??
          DateTime.now().toIso8601String(),
    );
  }

  // Helper to get member count
  int get memberCount => members.length;

  // Helper to get display members (excluding current user for display)
  List<GroupMember> getDisplayMembers(int currentUserId) {
    return members.where((member) => member.userId != currentUserId).toList();
  }

  // Helper to check if user is admin
  bool isUserAdmin(int userId) {
    final member = members.firstWhere(
      (member) => member.userId == userId,
      orElse: () => GroupMember(userId: 0, name: '', role: 'member'),
    );
    return member.role == 'admin';
  }

  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'title': title,
      'type': type,
      'members': members.map((member) => member.toJson()).toList(),
      'metadata': metadata?.toJson(),
      'lastMessageAt': lastMessageAt,
      'role': role,
      // 'unreadCount': unreadCount,
      'joinedAt': joinedAt,
    };
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
}

class GroupMetadata {
  final GroupLastMessage? lastMessage;
  final int totalMessages;
  final String? createdAt;
  final int createdBy;

  GroupMetadata({
    this.lastMessage,
    required this.totalMessages,
    this.createdAt,
    required this.createdBy,
  });

  factory GroupMetadata.fromJson(Map<String, dynamic> json) {
    return GroupMetadata(
      lastMessage: json['last_message'] != null
          ? GroupLastMessage.fromJson(json['last_message'])
          : null,
      totalMessages: json['total_messages'] ?? json['totalMessages'] ?? 0,
      createdAt: json['created_at'] ?? json['createdAt'],
      createdBy: json['created_by'] ?? json['createdBy'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'last_message': lastMessage?.toJson(),
      'total_messages': totalMessages,
      'created_at': createdAt,
      'created_by': createdBy,
    };
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

  GroupLastMessage({
    required this.id,
    required this.body,
    required this.type,
    required this.senderId,
    required this.senderName,
    required this.createdAt,
    required this.conversationId,
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
    };
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
}
