import 'package:freezed_annotation/freezed_annotation.dart';

part 'socket.types.freezed.dart';
part 'socket.types.g.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

enum ChatType {
  dm('dm'),
  group('group'),
  communityGroup('community_group');

  final String value;
  const ChatType(this.value);

  static ChatType? fromString(String? value) {
    if (value == null) return null;
    return ChatType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ChatType.dm,
    );
  }
}

enum ConnectionStatusType {
  online('online'),
  offline('offline'),
  stale('stale');

  final String value;
  const ConnectionStatusType(this.value);

  static ConnectionStatusType? fromString(String? value) {
    if (value == null) return null;
    return ConnectionStatusType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ConnectionStatusType.offline,
    );
  }
}

enum MessageType {
  text('text'),
  image('image'),
  video('video'),
  audio('audio'),
  document('document'),
  media('media'),
  reply('reply'),
  forwarded('forwarded'),
  system('system'),
  attachment('attachment'),
  reaction('reaction'),
  contact('contact');

  final String value;
  const MessageType(this.value);

  static MessageType? fromString(String? value) {
    if (value == null) return null;
    return MessageType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MessageType.text,
    );
  }
}

enum MessageStatusType {
  unsent('unsent'),
  sent('sent'),
  delivered('delivered'),
  uploading('uploading'),
  read('read'),
  failed('failed');

  final String value;
  const MessageStatusType(this.value);

  static MessageStatusType? fromString(String? value) {
    if (value == null) return null;
    return MessageStatusType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MessageStatusType.sent,
    );
  }
}

enum ChatRoleType {
  member('member'),
  admin('admin');

  final String value;
  const ChatRoleType(this.value);

  static ChatRoleType? fromString(String? value) {
    if (value == null) return null;
    return ChatRoleType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ChatRoleType.member,
    );
  }
}

enum ConversationActionType {
  memberAdded('member_added'),
  memberRemoved('member_removed'),
  memberPromoted('member_promoted'),
  memberDemoted('member_demoted'),
  chatDelete('chat_delete'),
  // Group title or profile picture changed by an admin. Members list is
  // empty for this action; the new title / profilePic / previousProfilePic
  // fields on ConversationActionPayload describe the change.
  chatDetailsUpdate('chat_details:update');

  final String value;
  const ConversationActionType(this.value);

  static ConversationActionType? fromString(String? value) {
    if (value == null) return null;
    return ConversationActionType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ConversationActionType.memberAdded,
    );
  }
}

enum WSMessageType {
  connectionStatus('connection:status'),
  conversationJoin('conversation:join'),
  conversationMarkRead('conversation:mark_read'),
  conversationNew('conversation:new'),
  conversationTyping('conversation:typing'),
  conversationAction('conversation:action'),
  messageNew('message:new'),
  messageSentAck('message:sent:ack'),
  messageStatusAck('message:status:ack'),
  messagePin('message:pin'),
  messageForward('message:forward'),
  messageDelete('message:delete'),
  messageReact('message:react'),
  conversationDisappearing('conversation:disappearing'),
  callInit('call:init'),
  callInitAck('call:init:ack'),
  callOffer('call:offer'),
  callAnswer('call:answer'),
  callIce('call:ice'),
  callRinging('call:ringing'),
  callAccept('call:accept'),
  callTerminate('call:terminate'),
  callHold('call:hold'),
  callMissed('call:missed'),
  callError('call:error'),
  // Ghost-call recovery / rejoin window (see RejoinableCall feature):
  // G→backend "peer dropped, open 10s window"; backend→L "you can rejoin";
  // G→backend "window resolved"; backend→L "window closed, clear the dot".
  callRejoinOpen('call:rejoin:open'),
  callRejoinAvailable('call:rejoin:available'),
  callRejoinResolved('call:rejoin:resolved'),
  callRejoinExpired('call:rejoin:expired'),
  callRejoinPeerDropped('call:rejoin:peer_dropped'),
  socketHealthCheck('socket:health_check'),
  socketPing('socket:ping'),
  socketPong('socket:pong'),
  socketError('socket:error'),
  authForceLogout('auth:force_logout'),
  userUpdate('user:update');

  final String value;
  const WSMessageType(this.value);

  static WSMessageType? fromString(String? value) {
    if (value == null) return null;
    try {
      return WSMessageType.values.firstWhere((e) => e.value == value);
    } catch (e) {
      return null;
    }
  }
}

enum VitalWSMessageType {
  conversationJoin('conversation:join'),
  conversationMarkRead('conversation:mark_read'),
  conversationNew('conversation:new'),
  conversationAction('conversation:action'),
  messageNew('message:new'),
  messageSentAck('message:sent:ack'),
  messageStatusAck('message:status:ack'),
  messagePin('message:pin'),
  messageForward('message:forward'),
  messageDelete('message:delete'),
  messageReact('message:react'),
  conversationDisappearing('conversation:disappearing'),
  userUpdate('user:update');

  final String value;
  const VitalWSMessageType(this.value);

  static VitalWSMessageType? fromString(String? value) {
    if (value == null) return null;
    try {
      return VitalWSMessageType.values.firstWhere((e) => e.value == value);
    } catch (e) {
      return null;
    }
  }

  static bool isVital(WSMessageType type) {
    return VitalWSMessageType.values.any((v) => v.value == type.value);
  }
}

// ─── JSON converters for enums ───────────────────────────────────────────────

class ChatTypeConverter implements JsonConverter<ChatType, String> {
  const ChatTypeConverter();
  @override
  ChatType fromJson(String json) => ChatType.fromString(json) ?? ChatType.dm;
  @override
  String toJson(ChatType object) => object.value;
}

class MessageTypeConverter implements JsonConverter<MessageType, String> {
  const MessageTypeConverter();
  @override
  MessageType fromJson(String json) =>
      MessageType.fromString(json) ?? MessageType.text;
  @override
  String toJson(MessageType object) => object.value;
}

class ChatRoleTypeConverter implements JsonConverter<ChatRoleType, String> {
  const ChatRoleTypeConverter();
  @override
  ChatRoleType fromJson(String json) =>
      ChatRoleType.fromString(json) ?? ChatRoleType.member;
  @override
  String toJson(ChatRoleType object) => object.value;
}

class ConversationActionTypeConverter
    implements JsonConverter<ConversationActionType, String> {
  const ConversationActionTypeConverter();
  @override
  ConversationActionType fromJson(String json) =>
      ConversationActionType.fromString(json) ??
      ConversationActionType.memberAdded;
  @override
  String toJson(ConversationActionType object) => object.value;
}

// ─── Freezed payload classes ─────────────────────────────────────────────────

@freezed
abstract class ConnectionStatusPayload with _$ConnectionStatusPayload {
  const factory ConnectionStatusPayload({
    @JsonKey(name: 'sender_id') required String senderId,
    required String status,
  }) = _ConnectionStatusPayload;
  factory ConnectionStatusPayload.fromJson(Map<String, dynamic> json) =>
      _$ConnectionStatusPayloadFromJson(json);
}

@freezed
abstract class ConvJoinPayload with _$ConvJoinPayload {
  const factory ConvJoinPayload({
    @JsonKey(name: 'conv_id') required String convId,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'last_read_msg_id') required String lastReadMsgId,
  }) = _ConvJoinPayload;
  factory ConvJoinPayload.fromJson(Map<String, dynamic> json) =>
      _$ConvJoinPayloadFromJson(json);
}

@freezed
abstract class ChatMessagePayload with _$ChatMessagePayload {
  const factory ChatMessagePayload({
    required String id,
    @JsonKey(name: 'conv_id') required String convId,
    @JsonKey(name: 'sender_id') required String senderId,
    @JsonKey(name: 'msg_type') @MessageTypeConverter() required MessageType msgType,
    String? body,
    dynamic attachments,
    @JsonKey(name: 'replied_to') String? repliedTo,
    // Pre-warmed compact preview of the replied-to message, attached by the
    // server so the receiver can render the reply container without a local
    // DB lookup falling through to "empty".
    @JsonKey(name: 'replied_to_message') Map<String, dynamic>? repliedToMessage,
    @JsonKey(name: 'sent_at') required DateTime sentAt,
    // Disappearing-messages deadline (server-stamped on broadcast). Null when
    // the chat has the feature off. Persisted onto the local messages row.
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
  }) = _ChatMessagePayload;
  factory ChatMessagePayload.fromJson(Map<String, dynamic> json) =>
      _$ChatMessagePayloadFromJson(json);
}

@freezed
abstract class MessageSentAckPayload with _$MessageSentAckPayload {
  const factory MessageSentAckPayload({
    @JsonKey(name: 'msg_id') required String msgId,
    @JsonKey(name: 'conv_id') required String convId,
    @JsonKey(name: 'is_sent') required bool isSent,
    @JsonKey(name: 'error_code') int? errorCode,
    @JsonKey(name: 'new_id') String? newId,
  }) = _MessageSentAckPayload;
  factory MessageSentAckPayload.fromJson(Map<String, dynamic> json) =>
      _$MessageSentAckPayloadFromJson(json);
}

@freezed
abstract class StatusAck with _$StatusAck {
  const factory StatusAck({
    @JsonKey(name: 'chat_id') required String chatId,
    @JsonKey(name: 'msg_ids') required List<String> msgIds,
    required List<String> status,
  }) = _StatusAck;
  factory StatusAck.fromJson(Map<String, dynamic> json) =>
      _$StatusAckFromJson(json);
}

@freezed
abstract class MessageStatusAckPayload with _$MessageStatusAckPayload {
  const factory MessageStatusAckPayload({
    @JsonKey(name: 'recipient_id') required String recipientId,
    required DateTime at,
    required List<StatusAck> acks,
  }) = _MessageStatusAckPayload;
  factory MessageStatusAckPayload.fromJson(Map<String, dynamic> json) =>
      _$MessageStatusAckPayloadFromJson(json);
}

@freezed
abstract class TypingPayload with _$TypingPayload {
  const factory TypingPayload({
    @JsonKey(name: 'conv_id') required String convId,
    @JsonKey(name: 'sender_id') required String senderId,
  }) = _TypingPayload;
  factory TypingPayload.fromJson(Map<String, dynamic> json) =>
      _$TypingPayloadFromJson(json);
}

@freezed
abstract class DeleteMessagePayload with _$DeleteMessagePayload {
  const factory DeleteMessagePayload({
    @JsonKey(name: 'conv_id') required String convId,
    @JsonKey(name: 'sender_id') required String senderId,
    @JsonKey(name: 'message_ids') required List<String> messageIds,
  }) = _DeleteMessagePayload;
  factory DeleteMessagePayload.fromJson(Map<String, dynamic> json) =>
      _$DeleteMessagePayloadFromJson(json);
}

@freezed
abstract class MembersType with _$MembersType {
  const factory MembersType({
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'user_name') required String userName,
    @JsonKey(name: 'user_pfp') String? userPfp,
    @ChatRoleTypeConverter() required ChatRoleType role,
    @JsonKey(name: 'joined_at') required DateTime joinedAt,
  }) = _MembersType;
  factory MembersType.fromJson(Map<String, dynamic> json) =>
      _$MembersTypeFromJson(json);
}

@freezed
abstract class NewConversationPayload with _$NewConversationPayload {
  const factory NewConversationPayload({
    @JsonKey(name: 'conv_id') required String convId,
    @JsonKey(name: 'conv_type') @ChatTypeConverter() required ChatType convType,
    String? title,
    @JsonKey(name: 'creater_id') required String createrId,
    @JsonKey(name: 'creater_name') required String createrName,
    @JsonKey(name: 'creater_phone') required String createrPhone,
    @JsonKey(name: 'creater_pfp') String? createrPfp,
    List<MembersType>? members,
    @JsonKey(name: 'joined_at') required DateTime joinedAt,
  }) = _NewConversationPayload;
  factory NewConversationPayload.fromJson(Map<String, dynamic> json) =>
      _$NewConversationPayloadFromJson(json);
}

@freezed
abstract class ConversationActionPayload with _$ConversationActionPayload {
  const factory ConversationActionPayload({
    @JsonKey(name: 'event_id') required String eventId,
    @JsonKey(name: 'conv_id') required String convId,
    @JsonKey(name: 'conv_type') @ChatTypeConverter() required ChatType convType,
    @ConversationActionTypeConverter() required ConversationActionType action,
    @Default(<MembersType>[]) List<MembersType> members,
    @JsonKey(name: 'actor_id') String? actorId,
    required String message,
    @JsonKey(name: 'action_at') required DateTime actionAt,
    // chat_details:update fields. Only set when at least one of title /
    // profilePic changed. profilePic == null with profilePicChanged = true
    // means the admin cleared the avatar.
    String? title,
    @JsonKey(name: 'profile_pic') String? profilePic,
    // Previous profile pic URL — used as the key to evict the old image
    // from the on-disk CachedNetworkImage cache when the pfp changes.
    @JsonKey(name: 'previous_profile_pic') String? previousProfilePic,
    // Explicit "pfp column was touched in this update" flag. Needed because
    // profilePic == null can mean either "cleared" or "absent from payload",
    // and the on-the-wire JSON collapses those two cases.
    @JsonKey(name: 'profile_pic_changed') @Default(false)
    bool profilePicChanged,
  }) = _ConversationActionPayload;
  factory ConversationActionPayload.fromJson(Map<String, dynamic> json) =>
      _$ConversationActionPayloadFromJson(json);
}

@freezed
abstract class MiscPayload with _$MiscPayload {
  const factory MiscPayload({
    String? message,
    dynamic data,
    int? code,
    dynamic error,
  }) = _MiscPayload;
  factory MiscPayload.fromJson(Map<String, dynamic> json) =>
      _$MiscPayloadFromJson(json);
}

@freezed
abstract class MessagePinPayload with _$MessagePinPayload {
  const factory MessagePinPayload({
    @JsonKey(name: 'conv_id') required String convId,
    @JsonKey(name: 'message_id') required String messageId,
    @JsonKey(name: 'message_type') @MessageTypeConverter() required MessageType messageType,
    @JsonKey(name: 'sender_id') required String senderId,
    required bool pin,
  }) = _MessagePinPayload;
  factory MessagePinPayload.fromJson(Map<String, dynamic> json) =>
      _$MessagePinPayloadFromJson(json);
}

@freezed
abstract class MessageForwardPayload with _$MessageForwardPayload {
  const factory MessageForwardPayload({
    @JsonKey(name: 'source_conv_id') required String sourceConvId,
    @JsonKey(name: 'forwarder_id') required String forwarderId,
    @JsonKey(name: 'forwarder_name') String? forwarderName,
    @JsonKey(name: 'forwarded_message_ids') required List<String> forwardedMessageIds,
    @JsonKey(name: 'target_conv_ids') required List<String> targetConvIds,
  }) = _MessageForwardPayload;
  factory MessageForwardPayload.fromJson(Map<String, dynamic> json) =>
      _$MessageForwardPayloadFromJson(json);
}

@freezed
abstract class MessageReactPayload with _$MessageReactPayload {
  const factory MessageReactPayload({
    @JsonKey(name: 'message_id') required String messageId,
    @JsonKey(name: 'conv_id') required String convId,
    @JsonKey(name: 'sender_id') required String senderId,
    required String emoji,
    required String action,
  }) = _MessageReactPayload;
  factory MessageReactPayload.fromJson(Map<String, dynamic> json) =>
      _$MessageReactPayloadFromJson(json);
}

@freezed
abstract class CallPayload with _$CallPayload {
  const factory CallPayload({
    @JsonKey(name: 'call_id') String? callId,
    @JsonKey(name: 'caller_id') required String callerId,
    @JsonKey(name: 'caller_name') String? callerName,
    @JsonKey(name: 'caller_pfp') String? callerPfp,
    @JsonKey(name: 'callee_id') required String calleeId,
    @JsonKey(name: 'callee_name') String? calleeName,
    @JsonKey(name: 'callee_pfp') String? calleePfp,
    @JsonKey(name: 'callType') String? callType,
    dynamic data,
    dynamic error,
    DateTime? timestamp,
  }) = _CallPayload;
  factory CallPayload.fromJson(Map<String, dynamic> json) =>
      _$CallPayloadFromJson(json);
}

/// Sent when a user changes the disappearing-messages duration on a chat.
/// `durationSec == null` means the feature was turned off. Manual class for
/// the same reason as [UserUpdatePayload] — avoids tangling freezed codegen.
class ConversationDisappearingPayload {
  final String convId;
  final String actorId;
  final int? durationSec;
  final DateTime changedAt;

  ConversationDisappearingPayload({
    required this.convId,
    required this.actorId,
    required this.durationSec,
    required this.changedAt,
  });

  factory ConversationDisappearingPayload.fromJson(Map<String, dynamic> json) {
    return ConversationDisappearingPayload(
      convId: json['conv_id'] as String,
      actorId: json['actor_id'] as String,
      durationSec: (json['duration_sec'] as num?)?.toInt(),
      changedAt: json['changed_at'] != null
          ? DateTime.tryParse(json['changed_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'conv_id': convId,
        'actor_id': actorId,
        'duration_sec': durationSec,
        'changed_at': changedAt.toUtc().toIso8601String(),
      };
}

/// Sent when another user updates their profile (name and/or profile pic),
/// or when a super-admin changes a user's app-level role from the admin
/// dashboard (in which case [role] is set and the payload is also delivered
/// to the target user themselves so their permissions update live).
/// Manual class — adding a freezed class would require re-running codegen
/// on this file, which we want to keep an isolated change.
class UserUpdatePayload {
  final String userId;
  final String? name;
  final String? profilePic;
  final String? previousProfilePic;
  final String? role;
  final DateTime updatedAt;

  UserUpdatePayload({
    required this.userId,
    this.name,
    this.profilePic,
    this.previousProfilePic,
    this.role,
    required this.updatedAt,
  });

  factory UserUpdatePayload.fromJson(Map<String, dynamic> json) {
    return UserUpdatePayload(
      userId: json['user_id'] as String,
      name: json['name'] as String?,
      profilePic: json['profile_pic'] as String?,
      previousProfilePic: json['previous_profile_pic'] as String?,
      role: json['role'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        if (name != null) 'name': name,
        if (profilePic != null) 'profile_pic': profilePic,
        if (previousProfilePic != null)
          'previous_profile_pic': previousProfilePic,
        if (role != null) 'role': role,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}

@freezed
abstract class MediaResponse with _$MediaResponse {
  const factory MediaResponse({
    required String url,
    required String key,
    required String category,
    @JsonKey(name: 'file_name') required String fileName,
    @JsonKey(name: 'file_size') required int fileSize,
    @JsonKey(name: 'mime_type') required String mimeType,
  }) = _MediaResponse;
  factory MediaResponse.fromJson(Map<String, dynamic> json) =>
      _$MediaResponseFromJson(json);
}

// ─── WSMessage wrapper ───────────────────────────────────────────────────────
// Manual class — the payload switch dispatch doesn't benefit from Freezed.

class WSMessage {
  final WSMessageType type;
  final dynamic payload;
  final DateTime? wsTimestamp;

  WSMessage({required this.type, this.payload, this.wsTimestamp});

  factory WSMessage.fromJson(Map<String, dynamic> json) {
    final typeString = json['type'] as String?;
    final type = WSMessageType.fromString(typeString);

    if (type == null) {
      throw FormatException('Unknown WebSocket message type: $typeString');
    }

    dynamic payload;
    final payloadData = json['payload'];
    if (payloadData is Map<String, dynamic>) {
      try {
        payload = _parsePayload(type, payloadData);
      } catch (_) {
        payload = payloadData;
      }
    }

    return WSMessage(
      type: type,
      payload: payload,
      wsTimestamp: json['ws_timestamp'] != null
          ? DateTime.tryParse(json['ws_timestamp'].toString())
          : null,
    );
  }

  static dynamic _parsePayload(
    WSMessageType type,
    Map<String, dynamic> json,
  ) {
    switch (type) {
      case WSMessageType.connectionStatus:
        return ConnectionStatusPayload.fromJson(json);
      case WSMessageType.conversationJoin:
        return ConvJoinPayload.fromJson(json);
      case WSMessageType.conversationMarkRead:
        // Outbound-only from this client; servers re-broadcast as
        // conversation:join to senders, so this case is defensive.
        return ConvJoinPayload.fromJson(json);
      case WSMessageType.conversationNew:
        return NewConversationPayload.fromJson(json);
      case WSMessageType.conversationTyping:
        return TypingPayload.fromJson(json);
      case WSMessageType.conversationAction:
        return ConversationActionPayload.fromJson(json);
      case WSMessageType.messageNew:
        return ChatMessagePayload.fromJson(json);
      case WSMessageType.messageSentAck:
        return MessageSentAckPayload.fromJson(json);
      case WSMessageType.messageStatusAck:
        return MessageStatusAckPayload.fromJson(json);
      case WSMessageType.messagePin:
        return MessagePinPayload.fromJson(json);
      case WSMessageType.messageForward:
        return MessageForwardPayload.fromJson(json);
      case WSMessageType.messageDelete:
        return DeleteMessagePayload.fromJson(json);
      case WSMessageType.messageReact:
        return MessageReactPayload.fromJson(json);
      case WSMessageType.callInit:
      case WSMessageType.callInitAck:
      case WSMessageType.callOffer:
      case WSMessageType.callAnswer:
      case WSMessageType.callIce:
      case WSMessageType.callRinging:
      case WSMessageType.callAccept:
      case WSMessageType.callTerminate:
      case WSMessageType.callHold:
      case WSMessageType.callMissed:
      case WSMessageType.callError:
      case WSMessageType.callRejoinOpen:
      case WSMessageType.callRejoinAvailable:
      case WSMessageType.callRejoinResolved:
      case WSMessageType.callRejoinExpired:
      case WSMessageType.callRejoinPeerDropped:
        try {
          return CallPayload.fromJson(json);
        } catch (_) {
          return json;
        }
      case WSMessageType.socketPing:
      case WSMessageType.socketPong:
        return null;
      case WSMessageType.socketHealthCheck:
      case WSMessageType.socketError:
      case WSMessageType.authForceLogout:
        return MiscPayload.fromJson(json);
      case WSMessageType.userUpdate:
        return UserUpdatePayload.fromJson(json);
      case WSMessageType.conversationDisappearing:
        return ConversationDisappearingPayload.fromJson(json);
    }
  }

  Map<String, dynamic> toJson() => {
    'type': type.value,
    if (payload != null) 'payload': _payloadToJson(payload),
    if (wsTimestamp != null)
      'ws_timestamp': wsTimestamp!.toUtc().toIso8601String(),
  };

  dynamic _payloadToJson(dynamic payload) {
    if (payload is ConnectionStatusPayload) return payload.toJson();
    if (payload is ConvJoinPayload) return payload.toJson();
    if (payload is ChatMessagePayload) return payload.toJson();
    if (payload is MessageSentAckPayload) return payload.toJson();
    if (payload is MessageStatusAckPayload) return payload.toJson();
    if (payload is TypingPayload) return payload.toJson();
    if (payload is DeleteMessagePayload) return payload.toJson();
    if (payload is NewConversationPayload) return payload.toJson();
    if (payload is MiscPayload) return payload.toJson();
    if (payload is MessagePinPayload) return payload.toJson();
    if (payload is MessageForwardPayload) return payload.toJson();
    if (payload is MessageReactPayload) return payload.toJson();
    if (payload is CallPayload) return payload.toJson();
    if (payload is ConversationActionPayload) return payload.toJson();
    if (payload is UserUpdatePayload) return payload.toJson();
    if (payload is ConversationDisappearingPayload) return payload.toJson();
    return payload;
  }

  // Typed payload accessors
  ConnectionStatusPayload? get connectionStatusPayload =>
      payload is ConnectionStatusPayload ? payload : null;
  ConvJoinPayload? get convJoinPayload =>
      payload is ConvJoinPayload ? payload : null;
  ChatMessagePayload? get chatMessagePayload =>
      payload is ChatMessagePayload ? payload : null;
  MessageSentAckPayload? get messageSentAckPayload =>
      payload is MessageSentAckPayload ? payload : null;
  MessageStatusAckPayload? get messageStatusAckPayload =>
      payload is MessageStatusAckPayload ? payload : null;
  TypingPayload? get typingPayload =>
      payload is TypingPayload ? payload : null;
  DeleteMessagePayload? get deleteMessagePayload =>
      payload is DeleteMessagePayload ? payload : null;
  NewConversationPayload? get newConversationPayload =>
      payload is NewConversationPayload ? payload : null;
  MiscPayload? get miscPayload =>
      payload is MiscPayload ? payload : null;
  MessagePinPayload? get messagePinPayload =>
      payload is MessagePinPayload ? payload : null;
  MessageForwardPayload? get messageForwardPayload =>
      payload is MessageForwardPayload ? payload : null;
  MessageReactPayload? get messageReactPayload =>
      payload is MessageReactPayload ? payload : null;
  CallPayload? get callPayload =>
      payload is CallPayload ? payload : null;
  ConversationActionPayload? get conversationActionPayload =>
      payload is ConversationActionPayload ? payload : null;
  UserUpdatePayload? get userUpdatePayload =>
      payload is UserUpdatePayload ? payload : null;
  ConversationDisappearingPayload? get conversationDisappearingPayload =>
      payload is ConversationDisappearingPayload ? payload : null;
}
