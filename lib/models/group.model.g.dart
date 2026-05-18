// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group.model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GroupModel _$GroupModelFromJson(Map<String, dynamic> json) => _GroupModel(
  chatId: json['chat_id'] as String,
  title: json['title'] as String? ?? '',
  members: (json['members'] as List<dynamic>?)
      ?.map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
      .toList(),
  metadata: json['metadata'] == null
      ? null
      : GroupMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
  lastMsgId: json['last_msg_id'] as String?,
  lastMsgType: json['last_msg_type'] as String?,
  lastMsgBody: json['last_msg_body'] as String?,
  lastMsgAt: json['last_msg_at'] as String?,
  pinnedMsgId: json['pinned_msg_id'] as String?,
  role: json['role'] as String?,
  unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
  isPinned: json['is_pinned'] as bool? ?? false,
  isMuted: json['is_muted'] as bool? ?? false,
  isFavorite: json['is_favorite'] as bool? ?? false,
  joinedAt: json['joined_at'] as String? ?? '',
  disappearingAfterSec: (json['disappearing_after_sec'] as num?)?.toInt(),
);

Map<String, dynamic> _$GroupModelToJson(_GroupModel instance) =>
    <String, dynamic>{
      'chat_id': instance.chatId,
      'title': instance.title,
      'members': instance.members,
      'metadata': instance.metadata,
      'last_msg_id': instance.lastMsgId,
      'last_msg_type': instance.lastMsgType,
      'last_msg_body': instance.lastMsgBody,
      'last_msg_at': instance.lastMsgAt,
      'pinned_msg_id': instance.pinnedMsgId,
      'role': instance.role,
      'unread_count': instance.unreadCount,
      'is_pinned': instance.isPinned,
      'is_muted': instance.isMuted,
      'is_favorite': instance.isFavorite,
      'joined_at': instance.joinedAt,
      'disappearing_after_sec': instance.disappearingAfterSec,
    };

_GroupMember _$GroupMemberFromJson(Map<String, dynamic> json) => _GroupMember(
  userId: json['user_id'] as String,
  name: json['name'] as String,
  profilePic: json['profile_pic'] as String?,
  role: json['role'] as String? ?? 'member',
  joinedAt: json['joined_at'] as String?,
);

Map<String, dynamic> _$GroupMemberToJson(_GroupMember instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'name': instance.name,
      'profile_pic': instance.profilePic,
      'role': instance.role,
      'joined_at': instance.joinedAt,
    };

_GroupMetadata _$GroupMetadataFromJson(Map<String, dynamic> json) =>
    _GroupMetadata(
      lastMessage: json['last_message'] == null
          ? null
          : GroupLastMessage.fromJson(
              json['last_message'] as Map<String, dynamic>,
            ),
      totalMessages: (json['total_messages'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String?,
      createdBy: json['created_by'] as String?,
      pinnedMessage: json['pinned_message'] == null
          ? null
          : GroupPinnedMessage.fromJson(
              json['pinned_message'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$GroupMetadataToJson(_GroupMetadata instance) =>
    <String, dynamic>{
      'last_message': instance.lastMessage,
      'total_messages': instance.totalMessages,
      'created_at': instance.createdAt,
      'created_by': instance.createdBy,
      'pinned_message': instance.pinnedMessage,
    };

_GroupLastMessage _$GroupLastMessageFromJson(Map<String, dynamic> json) =>
    _GroupLastMessage(
      id: json['id'] as String,
      body: json['body'] as String?,
      type: json['type'] as String? ?? 'text',
      senderId: json['sender_id'] as String?,
      senderName: json['sender_name'] as String?,
      createdAt: json['created_at'] as String,
      chatId: json['chat_id'] as String?,
      attachmentData: json['attachments'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$GroupLastMessageToJson(_GroupLastMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'body': instance.body,
      'type': instance.type,
      'sender_id': instance.senderId,
      'sender_name': instance.senderName,
      'created_at': instance.createdAt,
      'chat_id': instance.chatId,
      'attachments': instance.attachmentData,
    };

_GroupPinnedMessage _$GroupPinnedMessageFromJson(Map<String, dynamic> json) =>
    _GroupPinnedMessage(
      userId: json['user_id'] as String,
      messageId: json['message_id'] as String,
      pinnedAt: json['pinned_at'] as String,
    );

Map<String, dynamic> _$GroupPinnedMessageToJson(_GroupPinnedMessage instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'message_id': instance.messageId,
      'pinned_at': instance.pinnedAt,
    };
