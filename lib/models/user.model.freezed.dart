// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserModel {

 String get id; String get name; String? get username; String get phone; String? get role;@JsonKey(name: 'profile_pic') String? get profilePic;@JsonKey(name: 'is_online') bool get isOnline;@JsonKey(name: 'call_access') bool? get callAccess;@JsonKey(name: 'updated_at') String? get updatedAt;@JsonKey(name: 'created_at') String? get createdAt;@JsonKey(name: 'last_seen') String? get lastSeen;
/// Create a copy of UserModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserModelCopyWith<UserModel> get copyWith => _$UserModelCopyWithImpl<UserModel>(this as UserModel, _$identity);

  /// Serializes this UserModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.username, username) || other.username == username)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.role, role) || other.role == role)&&(identical(other.profilePic, profilePic) || other.profilePic == profilePic)&&(identical(other.isOnline, isOnline) || other.isOnline == isOnline)&&(identical(other.callAccess, callAccess) || other.callAccess == callAccess)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.lastSeen, lastSeen) || other.lastSeen == lastSeen));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,username,phone,role,profilePic,isOnline,callAccess,updatedAt,createdAt,lastSeen);

@override
String toString() {
  return 'UserModel(id: $id, name: $name, username: $username, phone: $phone, role: $role, profilePic: $profilePic, isOnline: $isOnline, callAccess: $callAccess, updatedAt: $updatedAt, createdAt: $createdAt, lastSeen: $lastSeen)';
}


}

/// @nodoc
abstract mixin class $UserModelCopyWith<$Res>  {
  factory $UserModelCopyWith(UserModel value, $Res Function(UserModel) _then) = _$UserModelCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? username, String phone, String? role,@JsonKey(name: 'profile_pic') String? profilePic,@JsonKey(name: 'is_online') bool isOnline,@JsonKey(name: 'call_access') bool? callAccess,@JsonKey(name: 'updated_at') String? updatedAt,@JsonKey(name: 'created_at') String? createdAt,@JsonKey(name: 'last_seen') String? lastSeen
});




}
/// @nodoc
class _$UserModelCopyWithImpl<$Res>
    implements $UserModelCopyWith<$Res> {
  _$UserModelCopyWithImpl(this._self, this._then);

  final UserModel _self;
  final $Res Function(UserModel) _then;

/// Create a copy of UserModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? username = freezed,Object? phone = null,Object? role = freezed,Object? profilePic = freezed,Object? isOnline = null,Object? callAccess = freezed,Object? updatedAt = freezed,Object? createdAt = freezed,Object? lastSeen = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,profilePic: freezed == profilePic ? _self.profilePic : profilePic // ignore: cast_nullable_to_non_nullable
as String?,isOnline: null == isOnline ? _self.isOnline : isOnline // ignore: cast_nullable_to_non_nullable
as bool,callAccess: freezed == callAccess ? _self.callAccess : callAccess // ignore: cast_nullable_to_non_nullable
as bool?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,lastSeen: freezed == lastSeen ? _self.lastSeen : lastSeen // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [UserModel].
extension UserModelPatterns on UserModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserModel value)  $default,){
final _that = this;
switch (_that) {
case _UserModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserModel value)?  $default,){
final _that = this;
switch (_that) {
case _UserModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? username,  String phone,  String? role, @JsonKey(name: 'profile_pic')  String? profilePic, @JsonKey(name: 'is_online')  bool isOnline, @JsonKey(name: 'call_access')  bool? callAccess, @JsonKey(name: 'updated_at')  String? updatedAt, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'last_seen')  String? lastSeen)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserModel() when $default != null:
return $default(_that.id,_that.name,_that.username,_that.phone,_that.role,_that.profilePic,_that.isOnline,_that.callAccess,_that.updatedAt,_that.createdAt,_that.lastSeen);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? username,  String phone,  String? role, @JsonKey(name: 'profile_pic')  String? profilePic, @JsonKey(name: 'is_online')  bool isOnline, @JsonKey(name: 'call_access')  bool? callAccess, @JsonKey(name: 'updated_at')  String? updatedAt, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'last_seen')  String? lastSeen)  $default,) {final _that = this;
switch (_that) {
case _UserModel():
return $default(_that.id,_that.name,_that.username,_that.phone,_that.role,_that.profilePic,_that.isOnline,_that.callAccess,_that.updatedAt,_that.createdAt,_that.lastSeen);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? username,  String phone,  String? role, @JsonKey(name: 'profile_pic')  String? profilePic, @JsonKey(name: 'is_online')  bool isOnline, @JsonKey(name: 'call_access')  bool? callAccess, @JsonKey(name: 'updated_at')  String? updatedAt, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'last_seen')  String? lastSeen)?  $default,) {final _that = this;
switch (_that) {
case _UserModel() when $default != null:
return $default(_that.id,_that.name,_that.username,_that.phone,_that.role,_that.profilePic,_that.isOnline,_that.callAccess,_that.updatedAt,_that.createdAt,_that.lastSeen);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserModel extends UserModel {
  const _UserModel({required this.id, required this.name, this.username, required this.phone, this.role, @JsonKey(name: 'profile_pic') this.profilePic, @JsonKey(name: 'is_online') this.isOnline = false, @JsonKey(name: 'call_access') this.callAccess, @JsonKey(name: 'updated_at') this.updatedAt, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'last_seen') this.lastSeen}): super._();
  factory _UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? username;
@override final  String phone;
@override final  String? role;
@override@JsonKey(name: 'profile_pic') final  String? profilePic;
@override@JsonKey(name: 'is_online') final  bool isOnline;
@override@JsonKey(name: 'call_access') final  bool? callAccess;
@override@JsonKey(name: 'updated_at') final  String? updatedAt;
@override@JsonKey(name: 'created_at') final  String? createdAt;
@override@JsonKey(name: 'last_seen') final  String? lastSeen;

/// Create a copy of UserModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserModelCopyWith<_UserModel> get copyWith => __$UserModelCopyWithImpl<_UserModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.username, username) || other.username == username)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.role, role) || other.role == role)&&(identical(other.profilePic, profilePic) || other.profilePic == profilePic)&&(identical(other.isOnline, isOnline) || other.isOnline == isOnline)&&(identical(other.callAccess, callAccess) || other.callAccess == callAccess)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.lastSeen, lastSeen) || other.lastSeen == lastSeen));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,username,phone,role,profilePic,isOnline,callAccess,updatedAt,createdAt,lastSeen);

@override
String toString() {
  return 'UserModel(id: $id, name: $name, username: $username, phone: $phone, role: $role, profilePic: $profilePic, isOnline: $isOnline, callAccess: $callAccess, updatedAt: $updatedAt, createdAt: $createdAt, lastSeen: $lastSeen)';
}


}

/// @nodoc
abstract mixin class _$UserModelCopyWith<$Res> implements $UserModelCopyWith<$Res> {
  factory _$UserModelCopyWith(_UserModel value, $Res Function(_UserModel) _then) = __$UserModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? username, String phone, String? role,@JsonKey(name: 'profile_pic') String? profilePic,@JsonKey(name: 'is_online') bool isOnline,@JsonKey(name: 'call_access') bool? callAccess,@JsonKey(name: 'updated_at') String? updatedAt,@JsonKey(name: 'created_at') String? createdAt,@JsonKey(name: 'last_seen') String? lastSeen
});




}
/// @nodoc
class __$UserModelCopyWithImpl<$Res>
    implements _$UserModelCopyWith<$Res> {
  __$UserModelCopyWithImpl(this._self, this._then);

  final _UserModel _self;
  final $Res Function(_UserModel) _then;

/// Create a copy of UserModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? username = freezed,Object? phone = null,Object? role = freezed,Object? profilePic = freezed,Object? isOnline = null,Object? callAccess = freezed,Object? updatedAt = freezed,Object? createdAt = freezed,Object? lastSeen = freezed,}) {
  return _then(_UserModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,profilePic: freezed == profilePic ? _self.profilePic : profilePic // ignore: cast_nullable_to_non_nullable
as String?,isOnline: null == isOnline ? _self.isOnline : isOnline // ignore: cast_nullable_to_non_nullable
as bool,callAccess: freezed == callAccess ? _self.callAccess : callAccess // ignore: cast_nullable_to_non_nullable
as bool?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,lastSeen: freezed == lastSeen ? _self.lastSeen : lastSeen // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
