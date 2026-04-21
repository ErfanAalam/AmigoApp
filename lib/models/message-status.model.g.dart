// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message-status.model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MessageInfoModel _$MessageInfoModelFromJson(Map<String, dynamic> json) =>
    _MessageInfoModel(
      chatId: json['chat_id'] as String,
      messageId: json['message_id'] as String,
      userId: json['user_id'] as String,
      deliveredAt: json['delivered_at'] as String?,
      readAt: json['read_at'] as String?,
      reaction: json['reaction'] as String?,
      deletedAt: json['deleted_at'] as String?,
    );

Map<String, dynamic> _$MessageInfoModelToJson(_MessageInfoModel instance) =>
    <String, dynamic>{
      'chat_id': instance.chatId,
      'message_id': instance.messageId,
      'user_id': instance.userId,
      'delivered_at': instance.deliveredAt,
      'read_at': instance.readAt,
      'reaction': instance.reaction,
      'deleted_at': instance.deletedAt,
    };
