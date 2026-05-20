import 'package:freezed_annotation/freezed_annotation.dart';

part 'conversations.model.freezed.dart';
part 'conversations.model.g.dart';

@freezed
abstract class ChatModel with _$ChatModel {
  const ChatModel._();

  const factory ChatModel({
    required String id,
    required String type,
    String? title,
    @JsonKey(name: 'profile_pic') String? profilePic,
    @JsonKey(name: 'creater_id') String? createrId,
    @JsonKey(name: 'unread_count') int? unreadCount,
    @JsonKey(name: 'last_msg_id') String? lastMsgId,
    @JsonKey(name: 'last_msg_at') String? lastMsgAt,
    @JsonKey(name: 'pinned_msg_id') String? pinnedMsgId,
    @JsonKey(name: 'deleted_at') String? deletedAt,
    // Client-only pin-to-top. Null = unpinned. Pinned chats sort above
    // non-pinned chats by descending pinnedAt — most recently pinned first.
    @JsonKey(name: 'pinned_at') String? pinnedAt,
    @JsonKey(name: 'is_favorite') @Default(false) bool isFavorite,
    // Per-user mute end time as ISO-8601 UTC. Null = not muted. Replaces the
    // old client-only `is_muted` boolean. `isMuted` is now a computed getter
    // that checks the timestamp against now() so expired mutes self-clear
    // without a sweeper. See backend muted_until on chat_members.
    @JsonKey(name: 'muted_until') String? mutedUntil,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
    @JsonKey(name: 'need_sync') @Default(true) bool needSync,
    // Disappearing-messages duration in seconds; null = off. Updated by the
    // conversation:disappearing WS event.
    @JsonKey(name: 'disappearing_after_sec') int? disappearingAfterSec,
  }) = _ChatModel;

  factory ChatModel.fromJson(Map<String, dynamic> json) =>
      _$ChatModelFromJson(json);

  bool get isPinned => pinnedAt != null;
  bool get isMuted {
    if (mutedUntil == null) return false;
    final until = DateTime.tryParse(mutedUntil!);
    if (until == null) return false;
    return until.isAfter(DateTime.now().toUtc());
  }
}

// Back-compat alias so the many screen/provider references keep compiling
// until they're migrated to ChatModel directly.
typedef ConversationModel = ChatModel;

@freezed
abstract class DmModel with _$DmModel {
  const DmModel._();

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
    @JsonKey(name: 'pinned_at') String? pinnedAt,
    // Mirrors ChatModel.mutedUntil — see that doc-string. null = not muted.
    @JsonKey(name: 'muted_until') String? mutedUntil,
    @JsonKey(name: 'is_favorite') @Default(false) bool isFavorite,
    @JsonKey(name: 'created_at') required String createdAt,
    // Disappearing-messages duration in seconds; null = off. Mirrors the
    // chats table column. Drives the avatar timer-badge + input-border UI.
    @JsonKey(name: 'disappearing_after_sec') int? disappearingAfterSec,
  }) = _DmModel;

  factory DmModel.fromJson(Map<String, dynamic> json) =>
      _$DmModelFromJson(json);

  bool get isPinned => pinnedAt != null;
  bool get isMuted {
    if (mutedUntil == null) return false;
    final until = DateTime.tryParse(mutedUntil!);
    if (until == null) return false;
    return until.isAfter(DateTime.now().toUtc());
  }
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
    // Per-user mute end time as ISO-8601. Returned by /chat/get-chat-members
    // and on the chat-list payload (synced into the local chats table for
    // the current user).
    @JsonKey(name: 'muted_until') String? mutedUntil,
  }) = _ChatMemberModel;

  factory ChatMemberModel.fromJson(Map<String, dynamic> json) =>
      _$ChatMemberModelFromJson(json);
}

typedef ConversationMemberModel = ChatMemberModel;
