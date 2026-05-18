import 'package:freezed_annotation/freezed_annotation.dart';

part 'group.model.freezed.dart';
part 'group.model.g.dart';

@freezed
abstract class GroupModel with _$GroupModel {
  const GroupModel._();

  const factory GroupModel({
    @JsonKey(name: 'chat_id') required String chatId,
    @Default('') String title,
    @JsonKey(name: 'profile_pic') String? profilePic,
    List<GroupMember>? members,
    GroupMetadata? metadata,
    @JsonKey(name: 'last_msg_id') String? lastMsgId,
    @JsonKey(name: 'last_msg_type') String? lastMsgType,
    @JsonKey(name: 'last_msg_body') String? lastMsgBody,
    @JsonKey(name: 'last_msg_at') String? lastMsgAt,
    @JsonKey(name: 'pinned_msg_id') String? pinnedMsgId,
    String? role,
    @JsonKey(name: 'unread_count') @Default(0) int unreadCount,
    // Client-only pin-to-top. Null = unpinned. Pinned chats sort above
    // non-pinned chats by descending pinnedAt — most recently pinned first.
    @JsonKey(name: 'pinned_at') String? pinnedAt,
    @JsonKey(name: 'is_muted') @Default(false) bool isMuted,
    @JsonKey(name: 'is_favorite') @Default(false) bool isFavorite,
    @JsonKey(name: 'joined_at') @Default('') String joinedAt,
    // Disappearing-messages duration in seconds; null = off. Mirrors the
    // chats table column. Drives the avatar timer-badge + input-border UI.
    @JsonKey(name: 'disappearing_after_sec') int? disappearingAfterSec,
  }) = _GroupModel;

  factory GroupModel.fromJson(Map<String, dynamic> json) =>
      _$GroupModelFromJson(json);

  static Map<String, dynamic> normalizeApiResponse(Map<String, dynamic> json) {
    return <String, dynamic>{
      'chat_id': json['chat_id'] ?? json['conversationId'] ?? '',
      'title': json['title'] ?? '',
      'profile_pic': json['profile_pic'] ?? json['profilePic'],
      'members': json['members'],
      'metadata': json['metadata'],
      'last_msg_id': json['last_msg_id'] ?? json['lastMsgId'],
      'last_msg_type': json['last_msg_type'] ?? json['lastMsgType'],
      'last_msg_body': json['last_msg_body'] ?? json['lastMsgBody'],
      'last_msg_at': json['last_msg_at'] ?? json['lastMsgAt'],
      'pinned_msg_id': json['pinned_msg_id'] ?? json['pinnedMsgId'],
      'role': json['role'],
      'unread_count': json['unread_count'] ?? json['unreadCount'] ?? 0,
      'pinned_at': json['pinned_at'] ?? json['pinnedAt'],
      'is_muted': json['is_muted'] ?? json['isMuted'] ?? false,
      'is_favorite': json['is_favorite'] ?? json['isFavorite'] ?? false,
      'joined_at': json['joined_at'] ?? json['joinedAt'] ?? '',
      'disappearing_after_sec':
          json['disappearing_after_sec'] ?? json['disappearingAfterSec'],
    };
  }

  bool get isPinned => pinnedAt != null;

  int get memberCount => members?.length ?? 0;

  List<GroupMember> getDisplayMembers(String currentUserId) {
    return members
            ?.where((member) => member.userId != currentUserId)
            .toList() ??
        const <GroupMember>[];
  }

  bool isUserAdmin(String userId) {
    final m = members;
    if (m == null) return false;
    for (final member in m) {
      if (member.userId == userId) return member.role == 'admin';
    }
    return false;
  }
}

@freezed
abstract class GroupMember with _$GroupMember {
  const factory GroupMember({
    @JsonKey(name: 'user_id') required String userId,
    required String name,
    @JsonKey(name: 'profile_pic') String? profilePic,
    @Default('member') String role,
    @JsonKey(name: 'joined_at') String? joinedAt,
  }) = _GroupMember;

  factory GroupMember.fromJson(Map<String, dynamic> json) =>
      _$GroupMemberFromJson(json);
}

@freezed
abstract class GroupMetadata with _$GroupMetadata {
  const factory GroupMetadata({
    @JsonKey(name: 'last_message') GroupLastMessage? lastMessage,
    @JsonKey(name: 'total_messages') @Default(0) int totalMessages,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'created_by') String? createdBy,
    @JsonKey(name: 'pinned_message') GroupPinnedMessage? pinnedMessage,
  }) = _GroupMetadata;

  factory GroupMetadata.fromJson(Map<String, dynamic> json) =>
      _$GroupMetadataFromJson(json);
}

@freezed
abstract class GroupLastMessage with _$GroupLastMessage {
  const factory GroupLastMessage({
    required String id,
    String? body,
    @Default('text') String type,
    @JsonKey(name: 'sender_id') String? senderId,
    @JsonKey(name: 'sender_name') String? senderName,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'chat_id') String? chatId,
    @JsonKey(name: 'attachments') Map<String, dynamic>? attachmentData,
  }) = _GroupLastMessage;

  factory GroupLastMessage.fromJson(Map<String, dynamic> json) =>
      _$GroupLastMessageFromJson(json);
}

@freezed
abstract class GroupPinnedMessage with _$GroupPinnedMessage {
  const factory GroupPinnedMessage({
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'message_id') required String messageId,
    @JsonKey(name: 'pinned_at') required String pinnedAt,
  }) = _GroupPinnedMessage;

  factory GroupPinnedMessage.fromJson(Map<String, dynamic> json) =>
      _$GroupPinnedMessageFromJson(json);
}

class CreateGroupRequest {
  final String title;
  final List<String> memberIds;

  CreateGroupRequest({required this.title, required this.memberIds});

  Map<String, dynamic> toJson() => {'title': title, 'member_ids': memberIds};

  CreateGroupRequest copyWith({String? title, List<String>? memberIds}) =>
      CreateGroupRequest(
        title: title ?? this.title,
        memberIds: memberIds ?? this.memberIds,
      );
}

class GroupMemberAction {
  final String chatId;
  final String userId;
  final String? role;

  GroupMemberAction({
    required this.chatId,
    required this.userId,
    this.role,
  });

  Map<String, dynamic> toJson() => {
        'chat_id': chatId,
        'user_id': userId,
        if (role != null) 'role': role,
      };

  GroupMemberAction copyWith({String? chatId, String? userId, String? role}) =>
      GroupMemberAction(
        chatId: chatId ?? this.chatId,
        userId: userId ?? this.userId,
        role: role ?? this.role,
      );
}
