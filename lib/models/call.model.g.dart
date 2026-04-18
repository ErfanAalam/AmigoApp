// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'call.model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CallModel _$CallModelFromJson(Map<String, dynamic> json) => _CallModel(
  id: json['id'] as String,
  callerId: json['caller_id'] as String,
  calleeId: json['callee_id'] as String,
  contactId: json['contact_id'] as String,
  contactName: json['contact_name'] as String? ?? 'Unknown',
  contactProfilePic: json['contact_profile_pic'] as String?,
  startedAt: DateTime.parse(json['started_at'] as String),
  answeredAt: json['answered_at'] == null
      ? null
      : DateTime.parse(json['answered_at'] as String),
  endedAt: json['ended_at'] == null
      ? null
      : DateTime.parse(json['ended_at'] as String),
  durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
  status:
      $enumDecodeNullable(_$CallStatusEnumMap, json['status']) ??
      CallStatus.ended,
  reason: json['reason'] as String?,
  callType:
      $enumDecodeNullable(_$CallTypeEnumMap, json['call_type']) ??
      CallType.outgoing,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$CallModelToJson(_CallModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'caller_id': instance.callerId,
      'callee_id': instance.calleeId,
      'contact_id': instance.contactId,
      'contact_name': instance.contactName,
      'contact_profile_pic': instance.contactProfilePic,
      'started_at': instance.startedAt.toIso8601String(),
      'answered_at': instance.answeredAt?.toIso8601String(),
      'ended_at': instance.endedAt?.toIso8601String(),
      'duration_seconds': instance.durationSeconds,
      'status': _$CallStatusEnumMap[instance.status]!,
      'reason': instance.reason,
      'call_type': _$CallTypeEnumMap[instance.callType]!,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$CallStatusEnumMap = {
  CallStatus.initiated: 'initiated',
  CallStatus.ringing: 'ringing',
  CallStatus.connecting: 'connecting',
  CallStatus.answered: 'answered',
  CallStatus.ended: 'ended',
  CallStatus.missed: 'missed',
  CallStatus.declined: 'declined',
};

const _$CallTypeEnumMap = {
  CallType.outgoing: 'outgoing',
  CallType.incoming: 'incoming',
};
