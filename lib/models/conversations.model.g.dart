// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversations.model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChatModel _$ChatModelFromJson(Map<String, dynamic> json) => _ChatModel(
  id: json['id'] as String,
  type: json['type'] as String,
  title: json['title'] as String?,
  createrId: json['creater_id'] as String?,
  unreadCount: (json['unread_count'] as num?)?.toInt(),
  lastMsgId: json['last_msg_id'] as String?,
  lastMsgAt: json['last_msg_at'] as String?,
  pinnedMsgId: json['pinned_msg_id'] as String?,
  deletedAt: json['deleted_at'] as String?,
  isPinned: json['is_pinned'] as bool? ?? false,
  isFavorite: json['is_favorite'] as bool? ?? false,
  isMuted: json['is_muted'] as bool? ?? false,
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
  needSync: json['need_sync'] as bool? ?? true,
  disappearingAfterSec: (json['disappearing_after_sec'] as num?)?.toInt(),
);

Map<String, dynamic> _$ChatModelToJson(_ChatModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'title': instance.title,
      'creater_id': instance.createrId,
      'unread_count': instance.unreadCount,
      'last_msg_id': instance.lastMsgId,
      'last_msg_at': instance.lastMsgAt,
      'pinned_msg_id': instance.pinnedMsgId,
      'deleted_at': instance.deletedAt,
      'is_pinned': instance.isPinned,
      'is_favorite': instance.isFavorite,
      'is_muted': instance.isMuted,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'need_sync': instance.needSync,
      'disappearing_after_sec': instance.disappearingAfterSec,
    };

_DmModel _$DmModelFromJson(Map<String, dynamic> json) => _DmModel(
  chatId: json['chat_id'] as String,
  recipientId: json['recipient_id'] as String,
  recipientName: json['recipient_name'] as String,
  recipientPhone: json['recipient_phone'] as String,
  recipientProfilePic: json['recipient_profile_pic'] as String?,
  lastMsgId: json['last_msg_id'] as String?,
  lastMsgType: json['last_msg_type'] as String?,
  lastMsgBody: json['last_msg_body'] as String?,
  lastMsgAt: json['last_msg_at'] as String?,
  pinnedMsgId: json['pinned_msg_id'] as String?,
  unreadCount: (json['unread_count'] as num?)?.toInt(),
  isRecipientOnline: json['is_online'] as bool? ?? false,
  deletedAt: json['deleted_at'] as String?,
  isPinned: json['is_pinned'] as bool? ?? false,
  isMuted: json['is_muted'] as bool? ?? false,
  isFavorite: json['is_favorite'] as bool? ?? false,
  createdAt: json['created_at'] as String,
  disappearingAfterSec: (json['disappearing_after_sec'] as num?)?.toInt(),
);

Map<String, dynamic> _$DmModelToJson(_DmModel instance) => <String, dynamic>{
  'chat_id': instance.chatId,
  'recipient_id': instance.recipientId,
  'recipient_name': instance.recipientName,
  'recipient_phone': instance.recipientPhone,
  'recipient_profile_pic': instance.recipientProfilePic,
  'last_msg_id': instance.lastMsgId,
  'last_msg_type': instance.lastMsgType,
  'last_msg_body': instance.lastMsgBody,
  'last_msg_at': instance.lastMsgAt,
  'pinned_msg_id': instance.pinnedMsgId,
  'unread_count': instance.unreadCount,
  'is_online': instance.isRecipientOnline,
  'deleted_at': instance.deletedAt,
  'is_pinned': instance.isPinned,
  'is_muted': instance.isMuted,
  'is_favorite': instance.isFavorite,
  'created_at': instance.createdAt,
  'disappearing_after_sec': instance.disappearingAfterSec,
};

_ChatMemberModel _$ChatMemberModelFromJson(Map<String, dynamic> json) =>
    _ChatMemberModel(
      id: json['id'] as String?,
      chatId: json['chat_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      joinedAt: json['joined_at'] as String?,
      removedAt: json['removed_at'] as String?,
      lastReadMsgId: json['last_read_msg_id'] as String?,
      lastDeliveredMsgId: json['last_delivered_msg_id'] as String?,
    );

Map<String, dynamic> _$ChatMemberModelToJson(_ChatMemberModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'chat_id': instance.chatId,
      'user_id': instance.userId,
      'role': instance.role,
      'joined_at': instance.joinedAt,
      'removed_at': instance.removedAt,
      'last_read_msg_id': instance.lastReadMsgId,
      'last_delivered_msg_id': instance.lastDeliveredMsgId,
    };
