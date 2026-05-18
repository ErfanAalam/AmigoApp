// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GroupModel {

@JsonKey(name: 'chat_id') String get chatId; String get title;@JsonKey(name: 'profile_pic') String? get profilePic; List<GroupMember>? get members; GroupMetadata? get metadata;@JsonKey(name: 'last_msg_id') String? get lastMsgId;@JsonKey(name: 'last_msg_type') String? get lastMsgType;@JsonKey(name: 'last_msg_body') String? get lastMsgBody;@JsonKey(name: 'last_msg_at') String? get lastMsgAt;@JsonKey(name: 'pinned_msg_id') String? get pinnedMsgId; String? get role;@JsonKey(name: 'unread_count') int get unreadCount;// Client-only pin-to-top. Null = unpinned. Pinned chats sort above
// non-pinned chats by descending pinnedAt — most recently pinned first.
@JsonKey(name: 'pinned_at') String? get pinnedAt;@JsonKey(name: 'is_muted') bool get isMuted;@JsonKey(name: 'is_favorite') bool get isFavorite;@JsonKey(name: 'joined_at') String get joinedAt;// Disappearing-messages duration in seconds; null = off. Mirrors the
// chats table column. Drives the avatar timer-badge + input-border UI.
@JsonKey(name: 'disappearing_after_sec') int? get disappearingAfterSec;
/// Create a copy of GroupModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupModelCopyWith<GroupModel> get copyWith => _$GroupModelCopyWithImpl<GroupModel>(this as GroupModel, _$identity);

  /// Serializes this GroupModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupModel&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.title, title) || other.title == title)&&(identical(other.profilePic, profilePic) || other.profilePic == profilePic)&&const DeepCollectionEquality().equals(other.members, members)&&(identical(other.metadata, metadata) || other.metadata == metadata)&&(identical(other.lastMsgId, lastMsgId) || other.lastMsgId == lastMsgId)&&(identical(other.lastMsgType, lastMsgType) || other.lastMsgType == lastMsgType)&&(identical(other.lastMsgBody, lastMsgBody) || other.lastMsgBody == lastMsgBody)&&(identical(other.lastMsgAt, lastMsgAt) || other.lastMsgAt == lastMsgAt)&&(identical(other.pinnedMsgId, pinnedMsgId) || other.pinnedMsgId == pinnedMsgId)&&(identical(other.role, role) || other.role == role)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.pinnedAt, pinnedAt) || other.pinnedAt == pinnedAt)&&(identical(other.isMuted, isMuted) || other.isMuted == isMuted)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.disappearingAfterSec, disappearingAfterSec) || other.disappearingAfterSec == disappearingAfterSec));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,chatId,title,profilePic,const DeepCollectionEquality().hash(members),metadata,lastMsgId,lastMsgType,lastMsgBody,lastMsgAt,pinnedMsgId,role,unreadCount,pinnedAt,isMuted,isFavorite,joinedAt,disappearingAfterSec);

@override
String toString() {
  return 'GroupModel(chatId: $chatId, title: $title, profilePic: $profilePic, members: $members, metadata: $metadata, lastMsgId: $lastMsgId, lastMsgType: $lastMsgType, lastMsgBody: $lastMsgBody, lastMsgAt: $lastMsgAt, pinnedMsgId: $pinnedMsgId, role: $role, unreadCount: $unreadCount, pinnedAt: $pinnedAt, isMuted: $isMuted, isFavorite: $isFavorite, joinedAt: $joinedAt, disappearingAfterSec: $disappearingAfterSec)';
}


}

/// @nodoc
abstract mixin class $GroupModelCopyWith<$Res>  {
  factory $GroupModelCopyWith(GroupModel value, $Res Function(GroupModel) _then) = _$GroupModelCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'chat_id') String chatId, String title,@JsonKey(name: 'profile_pic') String? profilePic, List<GroupMember>? members, GroupMetadata? metadata,@JsonKey(name: 'last_msg_id') String? lastMsgId,@JsonKey(name: 'last_msg_type') String? lastMsgType,@JsonKey(name: 'last_msg_body') String? lastMsgBody,@JsonKey(name: 'last_msg_at') String? lastMsgAt,@JsonKey(name: 'pinned_msg_id') String? pinnedMsgId, String? role,@JsonKey(name: 'unread_count') int unreadCount,@JsonKey(name: 'pinned_at') String? pinnedAt,@JsonKey(name: 'is_muted') bool isMuted,@JsonKey(name: 'is_favorite') bool isFavorite,@JsonKey(name: 'joined_at') String joinedAt,@JsonKey(name: 'disappearing_after_sec') int? disappearingAfterSec
});


$GroupMetadataCopyWith<$Res>? get metadata;

}
/// @nodoc
class _$GroupModelCopyWithImpl<$Res>
    implements $GroupModelCopyWith<$Res> {
  _$GroupModelCopyWithImpl(this._self, this._then);

  final GroupModel _self;
  final $Res Function(GroupModel) _then;

/// Create a copy of GroupModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chatId = null,Object? title = null,Object? profilePic = freezed,Object? members = freezed,Object? metadata = freezed,Object? lastMsgId = freezed,Object? lastMsgType = freezed,Object? lastMsgBody = freezed,Object? lastMsgAt = freezed,Object? pinnedMsgId = freezed,Object? role = freezed,Object? unreadCount = null,Object? pinnedAt = freezed,Object? isMuted = null,Object? isFavorite = null,Object? joinedAt = null,Object? disappearingAfterSec = freezed,}) {
  return _then(_self.copyWith(
chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,profilePic: freezed == profilePic ? _self.profilePic : profilePic // ignore: cast_nullable_to_non_nullable
as String?,members: freezed == members ? _self.members : members // ignore: cast_nullable_to_non_nullable
as List<GroupMember>?,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as GroupMetadata?,lastMsgId: freezed == lastMsgId ? _self.lastMsgId : lastMsgId // ignore: cast_nullable_to_non_nullable
as String?,lastMsgType: freezed == lastMsgType ? _self.lastMsgType : lastMsgType // ignore: cast_nullable_to_non_nullable
as String?,lastMsgBody: freezed == lastMsgBody ? _self.lastMsgBody : lastMsgBody // ignore: cast_nullable_to_non_nullable
as String?,lastMsgAt: freezed == lastMsgAt ? _self.lastMsgAt : lastMsgAt // ignore: cast_nullable_to_non_nullable
as String?,pinnedMsgId: freezed == pinnedMsgId ? _self.pinnedMsgId : pinnedMsgId // ignore: cast_nullable_to_non_nullable
as String?,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,pinnedAt: freezed == pinnedAt ? _self.pinnedAt : pinnedAt // ignore: cast_nullable_to_non_nullable
as String?,isMuted: null == isMuted ? _self.isMuted : isMuted // ignore: cast_nullable_to_non_nullable
as bool,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as String,disappearingAfterSec: freezed == disappearingAfterSec ? _self.disappearingAfterSec : disappearingAfterSec // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of GroupModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GroupMetadataCopyWith<$Res>? get metadata {
    if (_self.metadata == null) {
    return null;
  }

  return $GroupMetadataCopyWith<$Res>(_self.metadata!, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}
}


/// Adds pattern-matching-related methods to [GroupModel].
extension GroupModelPatterns on GroupModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GroupModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GroupModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GroupModel value)  $default,){
final _that = this;
switch (_that) {
case _GroupModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GroupModel value)?  $default,){
final _that = this;
switch (_that) {
case _GroupModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'chat_id')  String chatId,  String title, @JsonKey(name: 'profile_pic')  String? profilePic,  List<GroupMember>? members,  GroupMetadata? metadata, @JsonKey(name: 'last_msg_id')  String? lastMsgId, @JsonKey(name: 'last_msg_type')  String? lastMsgType, @JsonKey(name: 'last_msg_body')  String? lastMsgBody, @JsonKey(name: 'last_msg_at')  String? lastMsgAt, @JsonKey(name: 'pinned_msg_id')  String? pinnedMsgId,  String? role, @JsonKey(name: 'unread_count')  int unreadCount, @JsonKey(name: 'pinned_at')  String? pinnedAt, @JsonKey(name: 'is_muted')  bool isMuted, @JsonKey(name: 'is_favorite')  bool isFavorite, @JsonKey(name: 'joined_at')  String joinedAt, @JsonKey(name: 'disappearing_after_sec')  int? disappearingAfterSec)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GroupModel() when $default != null:
return $default(_that.chatId,_that.title,_that.profilePic,_that.members,_that.metadata,_that.lastMsgId,_that.lastMsgType,_that.lastMsgBody,_that.lastMsgAt,_that.pinnedMsgId,_that.role,_that.unreadCount,_that.pinnedAt,_that.isMuted,_that.isFavorite,_that.joinedAt,_that.disappearingAfterSec);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'chat_id')  String chatId,  String title, @JsonKey(name: 'profile_pic')  String? profilePic,  List<GroupMember>? members,  GroupMetadata? metadata, @JsonKey(name: 'last_msg_id')  String? lastMsgId, @JsonKey(name: 'last_msg_type')  String? lastMsgType, @JsonKey(name: 'last_msg_body')  String? lastMsgBody, @JsonKey(name: 'last_msg_at')  String? lastMsgAt, @JsonKey(name: 'pinned_msg_id')  String? pinnedMsgId,  String? role, @JsonKey(name: 'unread_count')  int unreadCount, @JsonKey(name: 'pinned_at')  String? pinnedAt, @JsonKey(name: 'is_muted')  bool isMuted, @JsonKey(name: 'is_favorite')  bool isFavorite, @JsonKey(name: 'joined_at')  String joinedAt, @JsonKey(name: 'disappearing_after_sec')  int? disappearingAfterSec)  $default,) {final _that = this;
switch (_that) {
case _GroupModel():
return $default(_that.chatId,_that.title,_that.profilePic,_that.members,_that.metadata,_that.lastMsgId,_that.lastMsgType,_that.lastMsgBody,_that.lastMsgAt,_that.pinnedMsgId,_that.role,_that.unreadCount,_that.pinnedAt,_that.isMuted,_that.isFavorite,_that.joinedAt,_that.disappearingAfterSec);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'chat_id')  String chatId,  String title, @JsonKey(name: 'profile_pic')  String? profilePic,  List<GroupMember>? members,  GroupMetadata? metadata, @JsonKey(name: 'last_msg_id')  String? lastMsgId, @JsonKey(name: 'last_msg_type')  String? lastMsgType, @JsonKey(name: 'last_msg_body')  String? lastMsgBody, @JsonKey(name: 'last_msg_at')  String? lastMsgAt, @JsonKey(name: 'pinned_msg_id')  String? pinnedMsgId,  String? role, @JsonKey(name: 'unread_count')  int unreadCount, @JsonKey(name: 'pinned_at')  String? pinnedAt, @JsonKey(name: 'is_muted')  bool isMuted, @JsonKey(name: 'is_favorite')  bool isFavorite, @JsonKey(name: 'joined_at')  String joinedAt, @JsonKey(name: 'disappearing_after_sec')  int? disappearingAfterSec)?  $default,) {final _that = this;
switch (_that) {
case _GroupModel() when $default != null:
return $default(_that.chatId,_that.title,_that.profilePic,_that.members,_that.metadata,_that.lastMsgId,_that.lastMsgType,_that.lastMsgBody,_that.lastMsgAt,_that.pinnedMsgId,_that.role,_that.unreadCount,_that.pinnedAt,_that.isMuted,_that.isFavorite,_that.joinedAt,_that.disappearingAfterSec);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GroupModel extends GroupModel {
  const _GroupModel({@JsonKey(name: 'chat_id') required this.chatId, this.title = '', @JsonKey(name: 'profile_pic') this.profilePic, final  List<GroupMember>? members, this.metadata, @JsonKey(name: 'last_msg_id') this.lastMsgId, @JsonKey(name: 'last_msg_type') this.lastMsgType, @JsonKey(name: 'last_msg_body') this.lastMsgBody, @JsonKey(name: 'last_msg_at') this.lastMsgAt, @JsonKey(name: 'pinned_msg_id') this.pinnedMsgId, this.role, @JsonKey(name: 'unread_count') this.unreadCount = 0, @JsonKey(name: 'pinned_at') this.pinnedAt, @JsonKey(name: 'is_muted') this.isMuted = false, @JsonKey(name: 'is_favorite') this.isFavorite = false, @JsonKey(name: 'joined_at') this.joinedAt = '', @JsonKey(name: 'disappearing_after_sec') this.disappearingAfterSec}): _members = members,super._();
  factory _GroupModel.fromJson(Map<String, dynamic> json) => _$GroupModelFromJson(json);

@override@JsonKey(name: 'chat_id') final  String chatId;
@override@JsonKey() final  String title;
@override@JsonKey(name: 'profile_pic') final  String? profilePic;
 final  List<GroupMember>? _members;
@override List<GroupMember>? get members {
  final value = _members;
  if (value == null) return null;
  if (_members is EqualUnmodifiableListView) return _members;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  GroupMetadata? metadata;
@override@JsonKey(name: 'last_msg_id') final  String? lastMsgId;
@override@JsonKey(name: 'last_msg_type') final  String? lastMsgType;
@override@JsonKey(name: 'last_msg_body') final  String? lastMsgBody;
@override@JsonKey(name: 'last_msg_at') final  String? lastMsgAt;
@override@JsonKey(name: 'pinned_msg_id') final  String? pinnedMsgId;
@override final  String? role;
@override@JsonKey(name: 'unread_count') final  int unreadCount;
// Client-only pin-to-top. Null = unpinned. Pinned chats sort above
// non-pinned chats by descending pinnedAt — most recently pinned first.
@override@JsonKey(name: 'pinned_at') final  String? pinnedAt;
@override@JsonKey(name: 'is_muted') final  bool isMuted;
@override@JsonKey(name: 'is_favorite') final  bool isFavorite;
@override@JsonKey(name: 'joined_at') final  String joinedAt;
// Disappearing-messages duration in seconds; null = off. Mirrors the
// chats table column. Drives the avatar timer-badge + input-border UI.
@override@JsonKey(name: 'disappearing_after_sec') final  int? disappearingAfterSec;

/// Create a copy of GroupModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GroupModelCopyWith<_GroupModel> get copyWith => __$GroupModelCopyWithImpl<_GroupModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GroupModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GroupModel&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.title, title) || other.title == title)&&(identical(other.profilePic, profilePic) || other.profilePic == profilePic)&&const DeepCollectionEquality().equals(other._members, _members)&&(identical(other.metadata, metadata) || other.metadata == metadata)&&(identical(other.lastMsgId, lastMsgId) || other.lastMsgId == lastMsgId)&&(identical(other.lastMsgType, lastMsgType) || other.lastMsgType == lastMsgType)&&(identical(other.lastMsgBody, lastMsgBody) || other.lastMsgBody == lastMsgBody)&&(identical(other.lastMsgAt, lastMsgAt) || other.lastMsgAt == lastMsgAt)&&(identical(other.pinnedMsgId, pinnedMsgId) || other.pinnedMsgId == pinnedMsgId)&&(identical(other.role, role) || other.role == role)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.pinnedAt, pinnedAt) || other.pinnedAt == pinnedAt)&&(identical(other.isMuted, isMuted) || other.isMuted == isMuted)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.disappearingAfterSec, disappearingAfterSec) || other.disappearingAfterSec == disappearingAfterSec));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,chatId,title,profilePic,const DeepCollectionEquality().hash(_members),metadata,lastMsgId,lastMsgType,lastMsgBody,lastMsgAt,pinnedMsgId,role,unreadCount,pinnedAt,isMuted,isFavorite,joinedAt,disappearingAfterSec);

@override
String toString() {
  return 'GroupModel(chatId: $chatId, title: $title, profilePic: $profilePic, members: $members, metadata: $metadata, lastMsgId: $lastMsgId, lastMsgType: $lastMsgType, lastMsgBody: $lastMsgBody, lastMsgAt: $lastMsgAt, pinnedMsgId: $pinnedMsgId, role: $role, unreadCount: $unreadCount, pinnedAt: $pinnedAt, isMuted: $isMuted, isFavorite: $isFavorite, joinedAt: $joinedAt, disappearingAfterSec: $disappearingAfterSec)';
}


}

/// @nodoc
abstract mixin class _$GroupModelCopyWith<$Res> implements $GroupModelCopyWith<$Res> {
  factory _$GroupModelCopyWith(_GroupModel value, $Res Function(_GroupModel) _then) = __$GroupModelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'chat_id') String chatId, String title,@JsonKey(name: 'profile_pic') String? profilePic, List<GroupMember>? members, GroupMetadata? metadata,@JsonKey(name: 'last_msg_id') String? lastMsgId,@JsonKey(name: 'last_msg_type') String? lastMsgType,@JsonKey(name: 'last_msg_body') String? lastMsgBody,@JsonKey(name: 'last_msg_at') String? lastMsgAt,@JsonKey(name: 'pinned_msg_id') String? pinnedMsgId, String? role,@JsonKey(name: 'unread_count') int unreadCount,@JsonKey(name: 'pinned_at') String? pinnedAt,@JsonKey(name: 'is_muted') bool isMuted,@JsonKey(name: 'is_favorite') bool isFavorite,@JsonKey(name: 'joined_at') String joinedAt,@JsonKey(name: 'disappearing_after_sec') int? disappearingAfterSec
});


@override $GroupMetadataCopyWith<$Res>? get metadata;

}
/// @nodoc
class __$GroupModelCopyWithImpl<$Res>
    implements _$GroupModelCopyWith<$Res> {
  __$GroupModelCopyWithImpl(this._self, this._then);

  final _GroupModel _self;
  final $Res Function(_GroupModel) _then;

/// Create a copy of GroupModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chatId = null,Object? title = null,Object? profilePic = freezed,Object? members = freezed,Object? metadata = freezed,Object? lastMsgId = freezed,Object? lastMsgType = freezed,Object? lastMsgBody = freezed,Object? lastMsgAt = freezed,Object? pinnedMsgId = freezed,Object? role = freezed,Object? unreadCount = null,Object? pinnedAt = freezed,Object? isMuted = null,Object? isFavorite = null,Object? joinedAt = null,Object? disappearingAfterSec = freezed,}) {
  return _then(_GroupModel(
chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,profilePic: freezed == profilePic ? _self.profilePic : profilePic // ignore: cast_nullable_to_non_nullable
as String?,members: freezed == members ? _self._members : members // ignore: cast_nullable_to_non_nullable
as List<GroupMember>?,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as GroupMetadata?,lastMsgId: freezed == lastMsgId ? _self.lastMsgId : lastMsgId // ignore: cast_nullable_to_non_nullable
as String?,lastMsgType: freezed == lastMsgType ? _self.lastMsgType : lastMsgType // ignore: cast_nullable_to_non_nullable
as String?,lastMsgBody: freezed == lastMsgBody ? _self.lastMsgBody : lastMsgBody // ignore: cast_nullable_to_non_nullable
as String?,lastMsgAt: freezed == lastMsgAt ? _self.lastMsgAt : lastMsgAt // ignore: cast_nullable_to_non_nullable
as String?,pinnedMsgId: freezed == pinnedMsgId ? _self.pinnedMsgId : pinnedMsgId // ignore: cast_nullable_to_non_nullable
as String?,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,pinnedAt: freezed == pinnedAt ? _self.pinnedAt : pinnedAt // ignore: cast_nullable_to_non_nullable
as String?,isMuted: null == isMuted ? _self.isMuted : isMuted // ignore: cast_nullable_to_non_nullable
as bool,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as String,disappearingAfterSec: freezed == disappearingAfterSec ? _self.disappearingAfterSec : disappearingAfterSec // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of GroupModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GroupMetadataCopyWith<$Res>? get metadata {
    if (_self.metadata == null) {
    return null;
  }

  return $GroupMetadataCopyWith<$Res>(_self.metadata!, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}
}


/// @nodoc
mixin _$GroupMember {

@JsonKey(name: 'user_id') String get userId; String get name;@JsonKey(name: 'profile_pic') String? get profilePic; String get role;@JsonKey(name: 'joined_at') String? get joinedAt;
/// Create a copy of GroupMember
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupMemberCopyWith<GroupMember> get copyWith => _$GroupMemberCopyWithImpl<GroupMember>(this as GroupMember, _$identity);

  /// Serializes this GroupMember to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupMember&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.name, name) || other.name == name)&&(identical(other.profilePic, profilePic) || other.profilePic == profilePic)&&(identical(other.role, role) || other.role == role)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,name,profilePic,role,joinedAt);

@override
String toString() {
  return 'GroupMember(userId: $userId, name: $name, profilePic: $profilePic, role: $role, joinedAt: $joinedAt)';
}


}

/// @nodoc
abstract mixin class $GroupMemberCopyWith<$Res>  {
  factory $GroupMemberCopyWith(GroupMember value, $Res Function(GroupMember) _then) = _$GroupMemberCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'user_id') String userId, String name,@JsonKey(name: 'profile_pic') String? profilePic, String role,@JsonKey(name: 'joined_at') String? joinedAt
});




}
/// @nodoc
class _$GroupMemberCopyWithImpl<$Res>
    implements $GroupMemberCopyWith<$Res> {
  _$GroupMemberCopyWithImpl(this._self, this._then);

  final GroupMember _self;
  final $Res Function(GroupMember) _then;

/// Create a copy of GroupMember
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? name = null,Object? profilePic = freezed,Object? role = null,Object? joinedAt = freezed,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,profilePic: freezed == profilePic ? _self.profilePic : profilePic // ignore: cast_nullable_to_non_nullable
as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,joinedAt: freezed == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GroupMember].
extension GroupMemberPatterns on GroupMember {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GroupMember value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GroupMember() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GroupMember value)  $default,){
final _that = this;
switch (_that) {
case _GroupMember():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GroupMember value)?  $default,){
final _that = this;
switch (_that) {
case _GroupMember() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'user_id')  String userId,  String name, @JsonKey(name: 'profile_pic')  String? profilePic,  String role, @JsonKey(name: 'joined_at')  String? joinedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GroupMember() when $default != null:
return $default(_that.userId,_that.name,_that.profilePic,_that.role,_that.joinedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'user_id')  String userId,  String name, @JsonKey(name: 'profile_pic')  String? profilePic,  String role, @JsonKey(name: 'joined_at')  String? joinedAt)  $default,) {final _that = this;
switch (_that) {
case _GroupMember():
return $default(_that.userId,_that.name,_that.profilePic,_that.role,_that.joinedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'user_id')  String userId,  String name, @JsonKey(name: 'profile_pic')  String? profilePic,  String role, @JsonKey(name: 'joined_at')  String? joinedAt)?  $default,) {final _that = this;
switch (_that) {
case _GroupMember() when $default != null:
return $default(_that.userId,_that.name,_that.profilePic,_that.role,_that.joinedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GroupMember implements GroupMember {
  const _GroupMember({@JsonKey(name: 'user_id') required this.userId, required this.name, @JsonKey(name: 'profile_pic') this.profilePic, this.role = 'member', @JsonKey(name: 'joined_at') this.joinedAt});
  factory _GroupMember.fromJson(Map<String, dynamic> json) => _$GroupMemberFromJson(json);

@override@JsonKey(name: 'user_id') final  String userId;
@override final  String name;
@override@JsonKey(name: 'profile_pic') final  String? profilePic;
@override@JsonKey() final  String role;
@override@JsonKey(name: 'joined_at') final  String? joinedAt;

/// Create a copy of GroupMember
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GroupMemberCopyWith<_GroupMember> get copyWith => __$GroupMemberCopyWithImpl<_GroupMember>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GroupMemberToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GroupMember&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.name, name) || other.name == name)&&(identical(other.profilePic, profilePic) || other.profilePic == profilePic)&&(identical(other.role, role) || other.role == role)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,name,profilePic,role,joinedAt);

@override
String toString() {
  return 'GroupMember(userId: $userId, name: $name, profilePic: $profilePic, role: $role, joinedAt: $joinedAt)';
}


}

/// @nodoc
abstract mixin class _$GroupMemberCopyWith<$Res> implements $GroupMemberCopyWith<$Res> {
  factory _$GroupMemberCopyWith(_GroupMember value, $Res Function(_GroupMember) _then) = __$GroupMemberCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'user_id') String userId, String name,@JsonKey(name: 'profile_pic') String? profilePic, String role,@JsonKey(name: 'joined_at') String? joinedAt
});




}
/// @nodoc
class __$GroupMemberCopyWithImpl<$Res>
    implements _$GroupMemberCopyWith<$Res> {
  __$GroupMemberCopyWithImpl(this._self, this._then);

  final _GroupMember _self;
  final $Res Function(_GroupMember) _then;

/// Create a copy of GroupMember
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? name = null,Object? profilePic = freezed,Object? role = null,Object? joinedAt = freezed,}) {
  return _then(_GroupMember(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,profilePic: freezed == profilePic ? _self.profilePic : profilePic // ignore: cast_nullable_to_non_nullable
as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,joinedAt: freezed == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$GroupMetadata {

@JsonKey(name: 'last_message') GroupLastMessage? get lastMessage;@JsonKey(name: 'total_messages') int get totalMessages;@JsonKey(name: 'created_at') String? get createdAt;@JsonKey(name: 'created_by') String? get createdBy;@JsonKey(name: 'pinned_message') GroupPinnedMessage? get pinnedMessage;
/// Create a copy of GroupMetadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupMetadataCopyWith<GroupMetadata> get copyWith => _$GroupMetadataCopyWithImpl<GroupMetadata>(this as GroupMetadata, _$identity);

  /// Serializes this GroupMetadata to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupMetadata&&(identical(other.lastMessage, lastMessage) || other.lastMessage == lastMessage)&&(identical(other.totalMessages, totalMessages) || other.totalMessages == totalMessages)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.pinnedMessage, pinnedMessage) || other.pinnedMessage == pinnedMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lastMessage,totalMessages,createdAt,createdBy,pinnedMessage);

@override
String toString() {
  return 'GroupMetadata(lastMessage: $lastMessage, totalMessages: $totalMessages, createdAt: $createdAt, createdBy: $createdBy, pinnedMessage: $pinnedMessage)';
}


}

/// @nodoc
abstract mixin class $GroupMetadataCopyWith<$Res>  {
  factory $GroupMetadataCopyWith(GroupMetadata value, $Res Function(GroupMetadata) _then) = _$GroupMetadataCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'last_message') GroupLastMessage? lastMessage,@JsonKey(name: 'total_messages') int totalMessages,@JsonKey(name: 'created_at') String? createdAt,@JsonKey(name: 'created_by') String? createdBy,@JsonKey(name: 'pinned_message') GroupPinnedMessage? pinnedMessage
});


$GroupLastMessageCopyWith<$Res>? get lastMessage;$GroupPinnedMessageCopyWith<$Res>? get pinnedMessage;

}
/// @nodoc
class _$GroupMetadataCopyWithImpl<$Res>
    implements $GroupMetadataCopyWith<$Res> {
  _$GroupMetadataCopyWithImpl(this._self, this._then);

  final GroupMetadata _self;
  final $Res Function(GroupMetadata) _then;

/// Create a copy of GroupMetadata
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lastMessage = freezed,Object? totalMessages = null,Object? createdAt = freezed,Object? createdBy = freezed,Object? pinnedMessage = freezed,}) {
  return _then(_self.copyWith(
lastMessage: freezed == lastMessage ? _self.lastMessage : lastMessage // ignore: cast_nullable_to_non_nullable
as GroupLastMessage?,totalMessages: null == totalMessages ? _self.totalMessages : totalMessages // ignore: cast_nullable_to_non_nullable
as int,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,createdBy: freezed == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String?,pinnedMessage: freezed == pinnedMessage ? _self.pinnedMessage : pinnedMessage // ignore: cast_nullable_to_non_nullable
as GroupPinnedMessage?,
  ));
}
/// Create a copy of GroupMetadata
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GroupLastMessageCopyWith<$Res>? get lastMessage {
    if (_self.lastMessage == null) {
    return null;
  }

  return $GroupLastMessageCopyWith<$Res>(_self.lastMessage!, (value) {
    return _then(_self.copyWith(lastMessage: value));
  });
}/// Create a copy of GroupMetadata
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GroupPinnedMessageCopyWith<$Res>? get pinnedMessage {
    if (_self.pinnedMessage == null) {
    return null;
  }

  return $GroupPinnedMessageCopyWith<$Res>(_self.pinnedMessage!, (value) {
    return _then(_self.copyWith(pinnedMessage: value));
  });
}
}


/// Adds pattern-matching-related methods to [GroupMetadata].
extension GroupMetadataPatterns on GroupMetadata {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GroupMetadata value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GroupMetadata() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GroupMetadata value)  $default,){
final _that = this;
switch (_that) {
case _GroupMetadata():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GroupMetadata value)?  $default,){
final _that = this;
switch (_that) {
case _GroupMetadata() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'last_message')  GroupLastMessage? lastMessage, @JsonKey(name: 'total_messages')  int totalMessages, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'created_by')  String? createdBy, @JsonKey(name: 'pinned_message')  GroupPinnedMessage? pinnedMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GroupMetadata() when $default != null:
return $default(_that.lastMessage,_that.totalMessages,_that.createdAt,_that.createdBy,_that.pinnedMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'last_message')  GroupLastMessage? lastMessage, @JsonKey(name: 'total_messages')  int totalMessages, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'created_by')  String? createdBy, @JsonKey(name: 'pinned_message')  GroupPinnedMessage? pinnedMessage)  $default,) {final _that = this;
switch (_that) {
case _GroupMetadata():
return $default(_that.lastMessage,_that.totalMessages,_that.createdAt,_that.createdBy,_that.pinnedMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'last_message')  GroupLastMessage? lastMessage, @JsonKey(name: 'total_messages')  int totalMessages, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'created_by')  String? createdBy, @JsonKey(name: 'pinned_message')  GroupPinnedMessage? pinnedMessage)?  $default,) {final _that = this;
switch (_that) {
case _GroupMetadata() when $default != null:
return $default(_that.lastMessage,_that.totalMessages,_that.createdAt,_that.createdBy,_that.pinnedMessage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GroupMetadata implements GroupMetadata {
  const _GroupMetadata({@JsonKey(name: 'last_message') this.lastMessage, @JsonKey(name: 'total_messages') this.totalMessages = 0, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'created_by') this.createdBy, @JsonKey(name: 'pinned_message') this.pinnedMessage});
  factory _GroupMetadata.fromJson(Map<String, dynamic> json) => _$GroupMetadataFromJson(json);

@override@JsonKey(name: 'last_message') final  GroupLastMessage? lastMessage;
@override@JsonKey(name: 'total_messages') final  int totalMessages;
@override@JsonKey(name: 'created_at') final  String? createdAt;
@override@JsonKey(name: 'created_by') final  String? createdBy;
@override@JsonKey(name: 'pinned_message') final  GroupPinnedMessage? pinnedMessage;

/// Create a copy of GroupMetadata
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GroupMetadataCopyWith<_GroupMetadata> get copyWith => __$GroupMetadataCopyWithImpl<_GroupMetadata>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GroupMetadataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GroupMetadata&&(identical(other.lastMessage, lastMessage) || other.lastMessage == lastMessage)&&(identical(other.totalMessages, totalMessages) || other.totalMessages == totalMessages)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.pinnedMessage, pinnedMessage) || other.pinnedMessage == pinnedMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lastMessage,totalMessages,createdAt,createdBy,pinnedMessage);

@override
String toString() {
  return 'GroupMetadata(lastMessage: $lastMessage, totalMessages: $totalMessages, createdAt: $createdAt, createdBy: $createdBy, pinnedMessage: $pinnedMessage)';
}


}

/// @nodoc
abstract mixin class _$GroupMetadataCopyWith<$Res> implements $GroupMetadataCopyWith<$Res> {
  factory _$GroupMetadataCopyWith(_GroupMetadata value, $Res Function(_GroupMetadata) _then) = __$GroupMetadataCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'last_message') GroupLastMessage? lastMessage,@JsonKey(name: 'total_messages') int totalMessages,@JsonKey(name: 'created_at') String? createdAt,@JsonKey(name: 'created_by') String? createdBy,@JsonKey(name: 'pinned_message') GroupPinnedMessage? pinnedMessage
});


@override $GroupLastMessageCopyWith<$Res>? get lastMessage;@override $GroupPinnedMessageCopyWith<$Res>? get pinnedMessage;

}
/// @nodoc
class __$GroupMetadataCopyWithImpl<$Res>
    implements _$GroupMetadataCopyWith<$Res> {
  __$GroupMetadataCopyWithImpl(this._self, this._then);

  final _GroupMetadata _self;
  final $Res Function(_GroupMetadata) _then;

/// Create a copy of GroupMetadata
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lastMessage = freezed,Object? totalMessages = null,Object? createdAt = freezed,Object? createdBy = freezed,Object? pinnedMessage = freezed,}) {
  return _then(_GroupMetadata(
lastMessage: freezed == lastMessage ? _self.lastMessage : lastMessage // ignore: cast_nullable_to_non_nullable
as GroupLastMessage?,totalMessages: null == totalMessages ? _self.totalMessages : totalMessages // ignore: cast_nullable_to_non_nullable
as int,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,createdBy: freezed == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String?,pinnedMessage: freezed == pinnedMessage ? _self.pinnedMessage : pinnedMessage // ignore: cast_nullable_to_non_nullable
as GroupPinnedMessage?,
  ));
}

/// Create a copy of GroupMetadata
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GroupLastMessageCopyWith<$Res>? get lastMessage {
    if (_self.lastMessage == null) {
    return null;
  }

  return $GroupLastMessageCopyWith<$Res>(_self.lastMessage!, (value) {
    return _then(_self.copyWith(lastMessage: value));
  });
}/// Create a copy of GroupMetadata
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GroupPinnedMessageCopyWith<$Res>? get pinnedMessage {
    if (_self.pinnedMessage == null) {
    return null;
  }

  return $GroupPinnedMessageCopyWith<$Res>(_self.pinnedMessage!, (value) {
    return _then(_self.copyWith(pinnedMessage: value));
  });
}
}


/// @nodoc
mixin _$GroupLastMessage {

 String get id; String? get body; String get type;@JsonKey(name: 'sender_id') String? get senderId;@JsonKey(name: 'sender_name') String? get senderName;@JsonKey(name: 'created_at') String get createdAt;@JsonKey(name: 'chat_id') String? get chatId;@JsonKey(name: 'attachments') Map<String, dynamic>? get attachmentData;
/// Create a copy of GroupLastMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupLastMessageCopyWith<GroupLastMessage> get copyWith => _$GroupLastMessageCopyWithImpl<GroupLastMessage>(this as GroupLastMessage, _$identity);

  /// Serializes this GroupLastMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupLastMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.body, body) || other.body == body)&&(identical(other.type, type) || other.type == type)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.senderName, senderName) || other.senderName == senderName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&const DeepCollectionEquality().equals(other.attachmentData, attachmentData));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,body,type,senderId,senderName,createdAt,chatId,const DeepCollectionEquality().hash(attachmentData));

@override
String toString() {
  return 'GroupLastMessage(id: $id, body: $body, type: $type, senderId: $senderId, senderName: $senderName, createdAt: $createdAt, chatId: $chatId, attachmentData: $attachmentData)';
}


}

/// @nodoc
abstract mixin class $GroupLastMessageCopyWith<$Res>  {
  factory $GroupLastMessageCopyWith(GroupLastMessage value, $Res Function(GroupLastMessage) _then) = _$GroupLastMessageCopyWithImpl;
@useResult
$Res call({
 String id, String? body, String type,@JsonKey(name: 'sender_id') String? senderId,@JsonKey(name: 'sender_name') String? senderName,@JsonKey(name: 'created_at') String createdAt,@JsonKey(name: 'chat_id') String? chatId,@JsonKey(name: 'attachments') Map<String, dynamic>? attachmentData
});




}
/// @nodoc
class _$GroupLastMessageCopyWithImpl<$Res>
    implements $GroupLastMessageCopyWith<$Res> {
  _$GroupLastMessageCopyWithImpl(this._self, this._then);

  final GroupLastMessage _self;
  final $Res Function(GroupLastMessage) _then;

/// Create a copy of GroupLastMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? body = freezed,Object? type = null,Object? senderId = freezed,Object? senderName = freezed,Object? createdAt = null,Object? chatId = freezed,Object? attachmentData = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,senderId: freezed == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String?,senderName: freezed == senderName ? _self.senderName : senderName // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,chatId: freezed == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String?,attachmentData: freezed == attachmentData ? _self.attachmentData : attachmentData // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

}


/// Adds pattern-matching-related methods to [GroupLastMessage].
extension GroupLastMessagePatterns on GroupLastMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GroupLastMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GroupLastMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GroupLastMessage value)  $default,){
final _that = this;
switch (_that) {
case _GroupLastMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GroupLastMessage value)?  $default,){
final _that = this;
switch (_that) {
case _GroupLastMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? body,  String type, @JsonKey(name: 'sender_id')  String? senderId, @JsonKey(name: 'sender_name')  String? senderName, @JsonKey(name: 'created_at')  String createdAt, @JsonKey(name: 'chat_id')  String? chatId, @JsonKey(name: 'attachments')  Map<String, dynamic>? attachmentData)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GroupLastMessage() when $default != null:
return $default(_that.id,_that.body,_that.type,_that.senderId,_that.senderName,_that.createdAt,_that.chatId,_that.attachmentData);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? body,  String type, @JsonKey(name: 'sender_id')  String? senderId, @JsonKey(name: 'sender_name')  String? senderName, @JsonKey(name: 'created_at')  String createdAt, @JsonKey(name: 'chat_id')  String? chatId, @JsonKey(name: 'attachments')  Map<String, dynamic>? attachmentData)  $default,) {final _that = this;
switch (_that) {
case _GroupLastMessage():
return $default(_that.id,_that.body,_that.type,_that.senderId,_that.senderName,_that.createdAt,_that.chatId,_that.attachmentData);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? body,  String type, @JsonKey(name: 'sender_id')  String? senderId, @JsonKey(name: 'sender_name')  String? senderName, @JsonKey(name: 'created_at')  String createdAt, @JsonKey(name: 'chat_id')  String? chatId, @JsonKey(name: 'attachments')  Map<String, dynamic>? attachmentData)?  $default,) {final _that = this;
switch (_that) {
case _GroupLastMessage() when $default != null:
return $default(_that.id,_that.body,_that.type,_that.senderId,_that.senderName,_that.createdAt,_that.chatId,_that.attachmentData);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GroupLastMessage implements GroupLastMessage {
  const _GroupLastMessage({required this.id, this.body, this.type = 'text', @JsonKey(name: 'sender_id') this.senderId, @JsonKey(name: 'sender_name') this.senderName, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'chat_id') this.chatId, @JsonKey(name: 'attachments') final  Map<String, dynamic>? attachmentData}): _attachmentData = attachmentData;
  factory _GroupLastMessage.fromJson(Map<String, dynamic> json) => _$GroupLastMessageFromJson(json);

@override final  String id;
@override final  String? body;
@override@JsonKey() final  String type;
@override@JsonKey(name: 'sender_id') final  String? senderId;
@override@JsonKey(name: 'sender_name') final  String? senderName;
@override@JsonKey(name: 'created_at') final  String createdAt;
@override@JsonKey(name: 'chat_id') final  String? chatId;
 final  Map<String, dynamic>? _attachmentData;
@override@JsonKey(name: 'attachments') Map<String, dynamic>? get attachmentData {
  final value = _attachmentData;
  if (value == null) return null;
  if (_attachmentData is EqualUnmodifiableMapView) return _attachmentData;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of GroupLastMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GroupLastMessageCopyWith<_GroupLastMessage> get copyWith => __$GroupLastMessageCopyWithImpl<_GroupLastMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GroupLastMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GroupLastMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.body, body) || other.body == body)&&(identical(other.type, type) || other.type == type)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.senderName, senderName) || other.senderName == senderName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&const DeepCollectionEquality().equals(other._attachmentData, _attachmentData));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,body,type,senderId,senderName,createdAt,chatId,const DeepCollectionEquality().hash(_attachmentData));

@override
String toString() {
  return 'GroupLastMessage(id: $id, body: $body, type: $type, senderId: $senderId, senderName: $senderName, createdAt: $createdAt, chatId: $chatId, attachmentData: $attachmentData)';
}


}

/// @nodoc
abstract mixin class _$GroupLastMessageCopyWith<$Res> implements $GroupLastMessageCopyWith<$Res> {
  factory _$GroupLastMessageCopyWith(_GroupLastMessage value, $Res Function(_GroupLastMessage) _then) = __$GroupLastMessageCopyWithImpl;
@override @useResult
$Res call({
 String id, String? body, String type,@JsonKey(name: 'sender_id') String? senderId,@JsonKey(name: 'sender_name') String? senderName,@JsonKey(name: 'created_at') String createdAt,@JsonKey(name: 'chat_id') String? chatId,@JsonKey(name: 'attachments') Map<String, dynamic>? attachmentData
});




}
/// @nodoc
class __$GroupLastMessageCopyWithImpl<$Res>
    implements _$GroupLastMessageCopyWith<$Res> {
  __$GroupLastMessageCopyWithImpl(this._self, this._then);

  final _GroupLastMessage _self;
  final $Res Function(_GroupLastMessage) _then;

/// Create a copy of GroupLastMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? body = freezed,Object? type = null,Object? senderId = freezed,Object? senderName = freezed,Object? createdAt = null,Object? chatId = freezed,Object? attachmentData = freezed,}) {
  return _then(_GroupLastMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,senderId: freezed == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String?,senderName: freezed == senderName ? _self.senderName : senderName // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,chatId: freezed == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String?,attachmentData: freezed == attachmentData ? _self._attachmentData : attachmentData // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}


}


/// @nodoc
mixin _$GroupPinnedMessage {

@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'message_id') String get messageId;@JsonKey(name: 'pinned_at') String get pinnedAt;
/// Create a copy of GroupPinnedMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupPinnedMessageCopyWith<GroupPinnedMessage> get copyWith => _$GroupPinnedMessageCopyWithImpl<GroupPinnedMessage>(this as GroupPinnedMessage, _$identity);

  /// Serializes this GroupPinnedMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupPinnedMessage&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.pinnedAt, pinnedAt) || other.pinnedAt == pinnedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,messageId,pinnedAt);

@override
String toString() {
  return 'GroupPinnedMessage(userId: $userId, messageId: $messageId, pinnedAt: $pinnedAt)';
}


}

/// @nodoc
abstract mixin class $GroupPinnedMessageCopyWith<$Res>  {
  factory $GroupPinnedMessageCopyWith(GroupPinnedMessage value, $Res Function(GroupPinnedMessage) _then) = _$GroupPinnedMessageCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'message_id') String messageId,@JsonKey(name: 'pinned_at') String pinnedAt
});




}
/// @nodoc
class _$GroupPinnedMessageCopyWithImpl<$Res>
    implements $GroupPinnedMessageCopyWith<$Res> {
  _$GroupPinnedMessageCopyWithImpl(this._self, this._then);

  final GroupPinnedMessage _self;
  final $Res Function(GroupPinnedMessage) _then;

/// Create a copy of GroupPinnedMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? messageId = null,Object? pinnedAt = null,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,pinnedAt: null == pinnedAt ? _self.pinnedAt : pinnedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [GroupPinnedMessage].
extension GroupPinnedMessagePatterns on GroupPinnedMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GroupPinnedMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GroupPinnedMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GroupPinnedMessage value)  $default,){
final _that = this;
switch (_that) {
case _GroupPinnedMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GroupPinnedMessage value)?  $default,){
final _that = this;
switch (_that) {
case _GroupPinnedMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'message_id')  String messageId, @JsonKey(name: 'pinned_at')  String pinnedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GroupPinnedMessage() when $default != null:
return $default(_that.userId,_that.messageId,_that.pinnedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'message_id')  String messageId, @JsonKey(name: 'pinned_at')  String pinnedAt)  $default,) {final _that = this;
switch (_that) {
case _GroupPinnedMessage():
return $default(_that.userId,_that.messageId,_that.pinnedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'message_id')  String messageId, @JsonKey(name: 'pinned_at')  String pinnedAt)?  $default,) {final _that = this;
switch (_that) {
case _GroupPinnedMessage() when $default != null:
return $default(_that.userId,_that.messageId,_that.pinnedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GroupPinnedMessage implements GroupPinnedMessage {
  const _GroupPinnedMessage({@JsonKey(name: 'user_id') required this.userId, @JsonKey(name: 'message_id') required this.messageId, @JsonKey(name: 'pinned_at') required this.pinnedAt});
  factory _GroupPinnedMessage.fromJson(Map<String, dynamic> json) => _$GroupPinnedMessageFromJson(json);

@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'message_id') final  String messageId;
@override@JsonKey(name: 'pinned_at') final  String pinnedAt;

/// Create a copy of GroupPinnedMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GroupPinnedMessageCopyWith<_GroupPinnedMessage> get copyWith => __$GroupPinnedMessageCopyWithImpl<_GroupPinnedMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GroupPinnedMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GroupPinnedMessage&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.pinnedAt, pinnedAt) || other.pinnedAt == pinnedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,messageId,pinnedAt);

@override
String toString() {
  return 'GroupPinnedMessage(userId: $userId, messageId: $messageId, pinnedAt: $pinnedAt)';
}


}

/// @nodoc
abstract mixin class _$GroupPinnedMessageCopyWith<$Res> implements $GroupPinnedMessageCopyWith<$Res> {
  factory _$GroupPinnedMessageCopyWith(_GroupPinnedMessage value, $Res Function(_GroupPinnedMessage) _then) = __$GroupPinnedMessageCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'message_id') String messageId,@JsonKey(name: 'pinned_at') String pinnedAt
});




}
/// @nodoc
class __$GroupPinnedMessageCopyWithImpl<$Res>
    implements _$GroupPinnedMessageCopyWith<$Res> {
  __$GroupPinnedMessageCopyWithImpl(this._self, this._then);

  final _GroupPinnedMessage _self;
  final $Res Function(_GroupPinnedMessage) _then;

/// Create a copy of GroupPinnedMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? messageId = null,Object? pinnedAt = null,}) {
  return _then(_GroupPinnedMessage(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,pinnedAt: null == pinnedAt ? _self.pinnedAt : pinnedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
