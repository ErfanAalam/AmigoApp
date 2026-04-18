import 'package:freezed_annotation/freezed_annotation.dart';

part 'conversations.model.freezed.dart';
part 'conversations.model.g.dart';

@freezed
abstract class ChatModel with _$ChatModel {
  const factory ChatModel({
    required String id,
    required String type,
    String? title,
    @JsonKey(name: 'creater_id') String? createrId,
    @JsonKey(name: 'unread_count') int? unreadCount,
    @JsonKey(name: 'last_msg_id') String? lastMsgId,
    @JsonKey(name: 'last_msg_at') String? lastMsgAt,
    @JsonKey(name: 'pinned_msg_id') String? pinnedMsgId,
    @JsonKey(name: 'deleted_at') String? deletedAt,
    @JsonKey(name: 'is_pinned') @Default(false) bool isPinned,
    @JsonKey(name: 'is_favorite') @Default(false) bool isFavorite,
    @JsonKey(name: 'is_muted') @Default(false) bool isMuted,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
    @JsonKey(name: 'need_sync') @Default(true) bool needSync,
  }) = _ChatModel;

  factory ChatModel.fromJson(Map<String, dynamic> json) =>
      _$ChatModelFromJson(json);
}

// Back-compat alias so the many screen/provider references keep compiling
// until they're migrated to ChatModel directly.
typedef ConversationModel = ChatModel;

@freezed
abstract class DmModel with _$DmModel {
  const factory DmModel({
    @JsonKey(name: 'chat_id') required String chatId,
    @JsonKey(name: 'recipient_id') required String recipientId,
    @JsonKey(name: 'recipient_name') required String recipientName,
    @JsonKey(name: 'recipient_phone') required String recipientPhone,
    @JsonKey(name: 'recipient_profile_pic') String? recipientProfilePic,
    @JsonKey(name: 'last_msg_id') String? lastMsgId,
    @JsonKey(name: 'last_msg_type') String? lastMsgType,
    @JsonKey(name: 'last_msg_body') String? lastMsgBody,
    @JsonKey(name: 'last_msg_at') String? lastMsgAt,
    @JsonKey(name: 'pinned_msg_id') String? pinnedMsgId,
    @JsonKey(name: 'unread_count') int? unreadCount,
    @JsonKey(name: 'is_online') @Default(false) bool isRecipientOnline,
    @JsonKey(name: 'deleted_at') String? deletedAt,
    @JsonKey(name: 'is_pinned') @Default(false) bool isPinned,
    @JsonKey(name: 'is_muted') @Default(false) bool isMuted,
    @JsonKey(name: 'is_favorite') @Default(false) bool isFavorite,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _DmModel;

  factory DmModel.fromJson(Map<String, dynamic> json) =>
      _$DmModelFromJson(json);
}

@freezed
abstract class ChatMemberModel with _$ChatMemberModel {
  const factory ChatMemberModel({
    String? id,
    @JsonKey(name: 'chat_id') required String chatId,
    @JsonKey(name: 'user_id') required String userId,
    required String role,
    @JsonKey(name: 'joined_at') String? joinedAt,
    @JsonKey(name: 'removed_at') String? removedAt,
    @JsonKey(name: 'last_read_msg_id') String? lastReadMsgId,
    @JsonKey(name: 'last_delivered_msg_id') String? lastDeliveredMsgId,
  }) = _ChatMemberModel;

  factory ChatMemberModel.fromJson(Map<String, dynamic> json) =>
      _$ChatMemberModelFromJson(json);
}

typedef ConversationMemberModel = ChatMemberModel;
