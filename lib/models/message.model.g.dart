// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MessageModel _$MessageModelFromJson(Map<String, dynamic> json) =>
    _MessageModel(
      id: json['id'] as String,
      chatId: json['chat_id'] as String,
      senderId: json['sender_id'] as String?,
      senderName: json['sender_name'] as String?,
      senderProfilePic: json['sender_profile_pic'] as String?,
      repliedTo: json['replied_to'] as String?,
      repliedToMessage: json['replied_to_message'] as Map<String, dynamic>?,
      type: json['type'] == null
          ? MessageType.text
          : _messageTypeFromJson(json['type']),
      body: json['body'] as String?,
      attachments: json['attachments'] as Map<String, dynamic>?,
      localMediaPath: json['local_media_path'] as String?,
      isFailed: json['is_failed'] as bool? ?? false,
      sentAt: json['sent_at'] as String,
      deletedAt: json['deleted_at'] as String?,
      expiresAt: json['expires_at'] as String?,
    );

Map<String, dynamic> _$MessageModelToJson(_MessageModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'chat_id': instance.chatId,
      'sender_id': instance.senderId,
      'sender_name': instance.senderName,
      'sender_profile_pic': instance.senderProfilePic,
      'replied_to': instance.repliedTo,
      'replied_to_message': instance.repliedToMessage,
      'type': _messageTypeToJson(instance.type),
      'body': instance.body,
      'attachments': instance.attachments,
      'local_media_path': instance.localMediaPath,
      'is_failed': instance.isFailed,
      'sent_at': instance.sentAt,
      'deleted_at': instance.deletedAt,
      'expires_at': instance.expiresAt,
    };

_MessagesAroundResponse _$MessagesAroundResponseFromJson(
  Map<String, dynamic> json,
) => _MessagesAroundResponse(
  messages: (json['messages'] as List<dynamic>)
      .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  members:
      (json['members'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const <Map<String, dynamic>>[],
  hasOlder: json['has_older'] as bool? ?? false,
  hasNewer: json['has_newer'] as bool? ?? false,
);

Map<String, dynamic> _$MessagesAroundResponseToJson(
  _MessagesAroundResponse instance,
) => <String, dynamic>{
  'messages': instance.messages,
  'members': instance.members,
  'has_older': instance.hasOlder,
  'has_newer': instance.hasNewer,
};

_ConversationHistoryResponse _$ConversationHistoryResponseFromJson(
  Map<String, dynamic> json,
) => _ConversationHistoryResponse(
  messages: (json['messages'] as List<dynamic>)
      .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  hasMore: json['has_more'] as bool? ?? false,
  members:
      (json['members'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const <Map<String, dynamic>>[],
);

Map<String, dynamic> _$ConversationHistoryResponseToJson(
  _ConversationHistoryResponse instance,
) => <String, dynamic>{
  'messages': instance.messages,
  'has_more': instance.hasMore,
  'members': instance.members,
};
