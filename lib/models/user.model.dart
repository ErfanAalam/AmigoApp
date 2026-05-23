import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.model.freezed.dart';
part 'user.model.g.dart';

@freezed
abstract class UserModel with _$UserModel {
  const UserModel._();

  const factory UserModel({
    required String id,
    required String name,
    required String phone,
    String? role,
    @JsonKey(name: 'profile_pic') String? profilePic,
    @JsonKey(name: 'is_online') @Default(false) bool isOnline,
    @JsonKey(name: 'call_access') bool? callAccess,
    @JsonKey(name: 'updated_at') String? updatedAt,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'last_seen') String? lastSeen,
    // Local contact name from the device's address book. Transient — populated
    // by UserRepository via a join against the contacts table, never persisted
    // to the users table and not part of JSON round-trips.
    @JsonKey(includeFromJson: false, includeToJson: false) String? contactName,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  String get displayName => contactName ?? name;
}
