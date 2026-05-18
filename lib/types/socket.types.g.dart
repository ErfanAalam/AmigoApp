// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'socket.types.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ConnectionStatusPayload _$ConnectionStatusPayloadFromJson(
  Map<String, dynamic> json,
) => _ConnectionStatusPayload(
  senderId: json['sender_id'] as String,
  status: json['status'] as String,
);

Map<String, dynamic> _$ConnectionStatusPayloadToJson(
  _ConnectionStatusPayload instance,
) => <String, dynamic>{
  'sender_id': instance.senderId,
  'status': instance.status,
};

_ConvJoinPayload _$ConvJoinPayloadFromJson(Map<String, dynamic> json) =>
    _ConvJoinPayload(
      convId: json['conv_id'] as String,
      userId: json['user_id'] as String,
      lastReadMsgId: json['last_read_msg_id'] as String,
    );

Map<String, dynamic> _$ConvJoinPayloadToJson(_ConvJoinPayload instance) =>
    <String, dynamic>{
      'conv_id': instance.convId,
      'user_id': instance.userId,
      'last_read_msg_id': instance.lastReadMsgId,
    };

_ChatMessagePayload _$ChatMessagePayloadFromJson(Map<String, dynamic> json) =>
    _ChatMessagePayload(
      id: json['id'] as String,
      convId: json['conv_id'] as String,
      senderId: json['sender_id'] as String,
      msgType: const MessageTypeConverter().fromJson(
        json['msg_type'] as String,
      ),
      body: json['body'] as String?,
      attachments: json['attachments'],
      repliedTo: json['replied_to'] as String?,
      repliedToMessage: json['replied_to_message'] as Map<String, dynamic>?,
      sentAt: DateTime.parse(json['sent_at'] as String),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
    );

Map<String, dynamic> _$ChatMessagePayloadToJson(_ChatMessagePayload instance) =>
    <String, dynamic>{
      'id': instance.id,
      'conv_id': instance.convId,
      'sender_id': instance.senderId,
      'msg_type': const MessageTypeConverter().toJson(instance.msgType),
      'body': instance.body,
      'attachments': instance.attachments,
      'replied_to': instance.repliedTo,
      'replied_to_message': instance.repliedToMessage,
      'sent_at': instance.sentAt.toIso8601String(),
      'expires_at': instance.expiresAt?.toIso8601String(),
    };

_MessageSentAckPayload _$MessageSentAckPayloadFromJson(
  Map<String, dynamic> json,
) => _MessageSentAckPayload(
  msgId: json['msg_id'] as String,
  convId: json['conv_id'] as String,
  isSent: json['is_sent'] as bool,
  errorCode: (json['error_code'] as num?)?.toInt(),
  newId: json['new_id'] as String?,
);

Map<String, dynamic> _$MessageSentAckPayloadToJson(
  _MessageSentAckPayload instance,
) => <String, dynamic>{
  'msg_id': instance.msgId,
  'conv_id': instance.convId,
  'is_sent': instance.isSent,
  'error_code': instance.errorCode,
  'new_id': instance.newId,
};

_StatusAck _$StatusAckFromJson(Map<String, dynamic> json) => _StatusAck(
  chatId: json['chat_id'] as String,
  msgIds: (json['msg_ids'] as List<dynamic>).map((e) => e as String).toList(),
  status: (json['status'] as List<dynamic>).map((e) => e as String).toList(),
);

Map<String, dynamic> _$StatusAckToJson(_StatusAck instance) =>
    <String, dynamic>{
      'chat_id': instance.chatId,
      'msg_ids': instance.msgIds,
      'status': instance.status,
    };

_MessageStatusAckPayload _$MessageStatusAckPayloadFromJson(
  Map<String, dynamic> json,
) => _MessageStatusAckPayload(
  recipientId: json['recipient_id'] as String,
  at: DateTime.parse(json['at'] as String),
  acks: (json['acks'] as List<dynamic>)
      .map((e) => StatusAck.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$MessageStatusAckPayloadToJson(
  _MessageStatusAckPayload instance,
) => <String, dynamic>{
  'recipient_id': instance.recipientId,
  'at': instance.at.toIso8601String(),
  'acks': instance.acks,
};

_TypingPayload _$TypingPayloadFromJson(Map<String, dynamic> json) =>
    _TypingPayload(
      convId: json['conv_id'] as String,
      senderId: json['sender_id'] as String,
    );

Map<String, dynamic> _$TypingPayloadToJson(_TypingPayload instance) =>
    <String, dynamic>{
      'conv_id': instance.convId,
      'sender_id': instance.senderId,
    };

_DeleteMessagePayload _$DeleteMessagePayloadFromJson(
  Map<String, dynamic> json,
) => _DeleteMessagePayload(
  convId: json['conv_id'] as String,
  senderId: json['sender_id'] as String,
  messageIds: (json['message_ids'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$DeleteMessagePayloadToJson(
  _DeleteMessagePayload instance,
) => <String, dynamic>{
  'conv_id': instance.convId,
  'sender_id': instance.senderId,
  'message_ids': instance.messageIds,
};

_MembersType _$MembersTypeFromJson(Map<String, dynamic> json) => _MembersType(
  userId: json['user_id'] as String,
  userName: json['user_name'] as String,
  userPfp: json['user_pfp'] as String?,
  role: const ChatRoleTypeConverter().fromJson(json['role'] as String),
  joinedAt: DateTime.parse(json['joined_at'] as String),
);

Map<String, dynamic> _$MembersTypeToJson(_MembersType instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'user_name': instance.userName,
      'user_pfp': instance.userPfp,
      'role': const ChatRoleTypeConverter().toJson(instance.role),
      'joined_at': instance.joinedAt.toIso8601String(),
    };

_NewConversationPayload _$NewConversationPayloadFromJson(
  Map<String, dynamic> json,
) => _NewConversationPayload(
  convId: json['conv_id'] as String,
  convType: const ChatTypeConverter().fromJson(json['conv_type'] as String),
  title: json['title'] as String?,
  createrId: json['creater_id'] as String,
  createrName: json['creater_name'] as String,
  createrPhone: json['creater_phone'] as String,
  createrPfp: json['creater_pfp'] as String?,
  members: (json['members'] as List<dynamic>?)
      ?.map((e) => MembersType.fromJson(e as Map<String, dynamic>))
      .toList(),
  joinedAt: DateTime.parse(json['joined_at'] as String),
);

Map<String, dynamic> _$NewConversationPayloadToJson(
  _NewConversationPayload instance,
) => <String, dynamic>{
  'conv_id': instance.convId,
  'conv_type': const ChatTypeConverter().toJson(instance.convType),
  'title': instance.title,
  'creater_id': instance.createrId,
  'creater_name': instance.createrName,
  'creater_phone': instance.createrPhone,
  'creater_pfp': instance.createrPfp,
  'members': instance.members,
  'joined_at': instance.joinedAt.toIso8601String(),
};

_ConversationActionPayload _$ConversationActionPayloadFromJson(
  Map<String, dynamic> json,
) => _ConversationActionPayload(
  eventId: json['event_id'] as String,
  convId: json['conv_id'] as String,
  convType: const ChatTypeConverter().fromJson(json['conv_type'] as String),
  action: const ConversationActionTypeConverter().fromJson(
    json['action'] as String,
  ),
  members: (json['members'] as List<dynamic>)
      .map((e) => MembersType.fromJson(e as Map<String, dynamic>))
      .toList(),
  actorId: json['actor_id'] as String?,
  message: json['message'] as String,
  actionAt: DateTime.parse(json['action_at'] as String),
);

Map<String, dynamic> _$ConversationActionPayloadToJson(
  _ConversationActionPayload instance,
) => <String, dynamic>{
  'event_id': instance.eventId,
  'conv_id': instance.convId,
  'conv_type': const ChatTypeConverter().toJson(instance.convType),
  'action': const ConversationActionTypeConverter().toJson(instance.action),
  'members': instance.members,
  'actor_id': instance.actorId,
  'message': instance.message,
  'action_at': instance.actionAt.toIso8601String(),
};

_MiscPayload _$MiscPayloadFromJson(Map<String, dynamic> json) => _MiscPayload(
  message: json['message'] as String?,
  data: json['data'],
  code: (json['code'] as num?)?.toInt(),
  error: json['error'],
);

Map<String, dynamic> _$MiscPayloadToJson(_MiscPayload instance) =>
    <String, dynamic>{
      'message': instance.message,
      'data': instance.data,
      'code': instance.code,
      'error': instance.error,
    };

_MessagePinPayload _$MessagePinPayloadFromJson(Map<String, dynamic> json) =>
    _MessagePinPayload(
      convId: json['conv_id'] as String,
      messageId: json['message_id'] as String,
      messageType: const MessageTypeConverter().fromJson(
        json['message_type'] as String,
      ),
      senderId: json['sender_id'] as String,
      pin: json['pin'] as bool,
    );

Map<String, dynamic> _$MessagePinPayloadToJson(_MessagePinPayload instance) =>
    <String, dynamic>{
      'conv_id': instance.convId,
      'message_id': instance.messageId,
      'message_type': const MessageTypeConverter().toJson(instance.messageType),
      'sender_id': instance.senderId,
      'pin': instance.pin,
    };

_MessageForwardPayload _$MessageForwardPayloadFromJson(
  Map<String, dynamic> json,
) => _MessageForwardPayload(
  sourceConvId: json['source_conv_id'] as String,
  forwarderId: json['forwarder_id'] as String,
  forwarderName: json['forwarder_name'] as String?,
  forwardedMessageIds: (json['forwarded_message_ids'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  targetConvIds: (json['target_conv_ids'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$MessageForwardPayloadToJson(
  _MessageForwardPayload instance,
) => <String, dynamic>{
  'source_conv_id': instance.sourceConvId,
  'forwarder_id': instance.forwarderId,
  'forwarder_name': instance.forwarderName,
  'forwarded_message_ids': instance.forwardedMessageIds,
  'target_conv_ids': instance.targetConvIds,
};

_MessageReactPayload _$MessageReactPayloadFromJson(Map<String, dynamic> json) =>
    _MessageReactPayload(
      messageId: json['message_id'] as String,
      convId: json['conv_id'] as String,
      senderId: json['sender_id'] as String,
      emoji: json['emoji'] as String,
      action: json['action'] as String,
    );

Map<String, dynamic> _$MessageReactPayloadToJson(
  _MessageReactPayload instance,
) => <String, dynamic>{
  'message_id': instance.messageId,
  'conv_id': instance.convId,
  'sender_id': instance.senderId,
  'emoji': instance.emoji,
  'action': instance.action,
};

_CallPayload _$CallPayloadFromJson(Map<String, dynamic> json) => _CallPayload(
  callId: json['call_id'] as String?,
  callerId: json['caller_id'] as String,
  callerName: json['caller_name'] as String?,
  callerPfp: json['caller_pfp'] as String?,
  calleeId: json['callee_id'] as String,
  calleeName: json['callee_name'] as String?,
  calleePfp: json['callee_pfp'] as String?,
  callType: json['callType'] as String?,
  data: json['data'],
  error: json['error'],
  timestamp: json['timestamp'] == null
      ? null
      : DateTime.parse(json['timestamp'] as String),
);

Map<String, dynamic> _$CallPayloadToJson(_CallPayload instance) =>
    <String, dynamic>{
      'call_id': instance.callId,
      'caller_id': instance.callerId,
      'caller_name': instance.callerName,
      'caller_pfp': instance.callerPfp,
      'callee_id': instance.calleeId,
      'callee_name': instance.calleeName,
      'callee_pfp': instance.calleePfp,
      'callType': instance.callType,
      'data': instance.data,
      'error': instance.error,
      'timestamp': instance.timestamp?.toIso8601String(),
    };

_MediaResponse _$MediaResponseFromJson(Map<String, dynamic> json) =>
    _MediaResponse(
      url: json['url'] as String,
      key: json['key'] as String,
      category: json['category'] as String,
      fileName: json['file_name'] as String,
      fileSize: (json['file_size'] as num).toInt(),
      mimeType: json['mime_type'] as String,
    );

Map<String, dynamic> _$MediaResponseToJson(_MediaResponse instance) =>
    <String, dynamic>{
      'url': instance.url,
      'key': instance.key,
      'category': instance.category,
      'file_name': instance.fileName,
      'file_size': instance.fileSize,
      'mime_type': instance.mimeType,
    };
