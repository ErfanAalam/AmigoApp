// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserModel _$UserModelFromJson(Map<String, dynamic> json) => _UserModel(
  id: json['id'] as String,
  name: json['name'] as String,
  phone: json['phone'] as String,
  role: json['role'] as String?,
  profilePic: json['profile_pic'] as String?,
  isOnline: json['is_online'] as bool? ?? false,
  callAccess: json['call_access'] as bool?,
  updatedAt: json['updated_at'] as String?,
  createdAt: json['created_at'] as String?,
  lastSeen: json['last_seen'] as String?,
);

Map<String, dynamic> _$UserModelToJson(_UserModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'phone': instance.phone,
      'role': instance.role,
      'profile_pic': instance.profilePic,
      'is_online': instance.isOnline,
      'call_access': instance.callAccess,
      'updated_at': instance.updatedAt,
      'created_at': instance.createdAt,
      'last_seen': instance.lastSeen,
    };
