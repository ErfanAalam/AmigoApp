// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conversations.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChatModel {

 String get id; String get type; String? get title;@JsonKey(name: 'creater_id') String? get createrId;@JsonKey(name: 'unread_count') int? get unreadCount;@JsonKey(name: 'last_msg_id') String? get lastMsgId;@JsonKey(name: 'last_msg_at') String? get lastMsgAt;@JsonKey(name: 'pinned_msg_id') String? get pinnedMsgId;@JsonKey(name: 'deleted_at') String? get deletedAt;@JsonKey(name: 'is_pinned') bool get isPinned;@JsonKey(name: 'is_favorite') bool get isFavorite;@JsonKey(name: 'is_muted') bool get isMuted;@JsonKey(name: 'created_at') String? get createdAt;@JsonKey(name: 'updated_at') String? get updatedAt;@JsonKey(name: 'need_sync') bool get needSync;
/// Create a copy of ChatModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatModelCopyWith<ChatModel> get copyWith => _$ChatModelCopyWithImpl<ChatModel>(this as ChatModel, _$identity);

  /// Serializes this ChatModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatModel&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.title, title) || other.title == title)&&(identical(other.createrId, createrId) || other.createrId == createrId)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.lastMsgId, lastMsgId) || other.lastMsgId == lastMsgId)&&(identical(other.lastMsgAt, lastMsgAt) || other.lastMsgAt == lastMsgAt)&&(identical(other.pinnedMsgId, pinnedMsgId) || other.pinnedMsgId == pinnedMsgId)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.isPinned, isPinned) || other.isPinned == isPinned)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.isMuted, isMuted) || other.isMuted == isMuted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.needSync, needSync) || other.needSync == needSync));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,title,createrId,unreadCount,lastMsgId,lastMsgAt,pinnedMsgId,deletedAt,isPinned,isFavorite,isMuted,createdAt,updatedAt,needSync);

@override
String toString() {
  return 'ChatModel(id: $id, type: $type, title: $title, createrId: $createrId, unreadCount: $unreadCount, lastMsgId: $lastMsgId, lastMsgAt: $lastMsgAt, pinnedMsgId: $pinnedMsgId, deletedAt: $deletedAt, isPinned: $isPinned, isFavorite: $isFavorite, isMuted: $isMuted, createdAt: $createdAt, updatedAt: $updatedAt, needSync: $needSync)';
}


}

/// @nodoc
abstract mixin class $ChatModelCopyWith<$Res>  {
  factory $ChatModelCopyWith(ChatModel value, $Res Function(ChatModel) _then) = _$ChatModelCopyWithImpl;
@useResult
$Res call({
 String id, String type, String? title,@JsonKey(name: 'creater_id') String? createrId,@JsonKey(name: 'unread_count') int? unreadCount,@JsonKey(name: 'last_msg_id') String? lastMsgId,@JsonKey(name: 'last_msg_at') String? lastMsgAt,@JsonKey(name: 'pinned_msg_id') String? pinnedMsgId,@JsonKey(name: 'deleted_at') String? deletedAt,@JsonKey(name: 'is_pinned') bool isPinned,@JsonKey(name: 'is_favorite') bool isFavorite,@JsonKey(name: 'is_muted') bool isMuted,@JsonKey(name: 'created_at') String? createdAt,@JsonKey(name: 'updated_at') String? updatedAt,@JsonKey(name: 'need_sync') bool needSync
});




}
/// @nodoc
class _$ChatModelCopyWithImpl<$Res>
    implements $ChatModelCopyWith<$Res> {
  _$ChatModelCopyWithImpl(this._self, this._then);

  final ChatModel _self;
  final $Res Function(ChatModel) _then;

/// Create a copy of ChatModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? title = freezed,Object? createrId = freezed,Object? unreadCount = freezed,Object? lastMsgId = freezed,Object? lastMsgAt = freezed,Object? pinnedMsgId = freezed,Object? deletedAt = freezed,Object? isPinned = null,Object? isFavorite = null,Object? isMuted = null,Object? createdAt = freezed,Object? updatedAt = freezed,Object? needSync = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,createrId: freezed == createrId ? _self.createrId : createrId // ignore: cast_nullable_to_non_nullable
as String?,unreadCount: freezed == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int?,lastMsgId: freezed == lastMsgId ? _self.lastMsgId : lastMsgId // ignore: cast_nullable_to_non_nullable
as String?,lastMsgAt: freezed == lastMsgAt ? _self.lastMsgAt : lastMsgAt // ignore: cast_nullable_to_non_nullable
as String?,pinnedMsgId: freezed == pinnedMsgId ? _self.pinnedMsgId : pinnedMsgId // ignore: cast_nullable_to_non_nullable
as String?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as String?,isPinned: null == isPinned ? _self.isPinned : isPinned // ignore: cast_nullable_to_non_nullable
as bool,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,isMuted: null == isMuted ? _self.isMuted : isMuted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,needSync: null == needSync ? _self.needSync : needSync // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatModel].
extension ChatModelPatterns on ChatModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatModel value)  $default,){
final _that = this;
switch (_that) {
case _ChatModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatModel value)?  $default,){
final _that = this;
switch (_that) {
case _ChatModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String type,  String? title, @JsonKey(name: 'creater_id')  String? createrId, @JsonKey(name: 'unread_count')  int? unreadCount, @JsonKey(name: 'last_msg_id')  String? lastMsgId, @JsonKey(name: 'last_msg_at')  String? lastMsgAt, @JsonKey(name: 'pinned_msg_id')  String? pinnedMsgId, @JsonKey(name: 'deleted_at')  String? deletedAt, @JsonKey(name: 'is_pinned')  bool isPinned, @JsonKey(name: 'is_favorite')  bool isFavorite, @JsonKey(name: 'is_muted')  bool isMuted, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'updated_at')  String? updatedAt, @JsonKey(name: 'need_sync')  bool needSync)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatModel() when $default != null:
return $default(_that.id,_that.type,_that.title,_that.createrId,_that.unreadCount,_that.lastMsgId,_that.lastMsgAt,_that.pinnedMsgId,_that.deletedAt,_that.isPinned,_that.isFavorite,_that.isMuted,_that.createdAt,_that.updatedAt,_that.needSync);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String type,  String? title, @JsonKey(name: 'creater_id')  String? createrId, @JsonKey(name: 'unread_count')  int? unreadCount, @JsonKey(name: 'last_msg_id')  String? lastMsgId, @JsonKey(name: 'last_msg_at')  String? lastMsgAt, @JsonKey(name: 'pinned_msg_id')  String? pinnedMsgId, @JsonKey(name: 'deleted_at')  String? deletedAt, @JsonKey(name: 'is_pinned')  bool isPinned, @JsonKey(name: 'is_favorite')  bool isFavorite, @JsonKey(name: 'is_muted')  bool isMuted, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'updated_at')  String? updatedAt, @JsonKey(name: 'need_sync')  bool needSync)  $default,) {final _that = this;
switch (_that) {
case _ChatModel():
return $default(_that.id,_that.type,_that.title,_that.createrId,_that.unreadCount,_that.lastMsgId,_that.lastMsgAt,_that.pinnedMsgId,_that.deletedAt,_that.isPinned,_that.isFavorite,_that.isMuted,_that.createdAt,_that.updatedAt,_that.needSync);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String type,  String? title, @JsonKey(name: 'creater_id')  String? createrId, @JsonKey(name: 'unread_count')  int? unreadCount, @JsonKey(name: 'last_msg_id')  String? lastMsgId, @JsonKey(name: 'last_msg_at')  String? lastMsgAt, @JsonKey(name: 'pinned_msg_id')  String? pinnedMsgId, @JsonKey(name: 'deleted_at')  String? deletedAt, @JsonKey(name: 'is_pinned')  bool isPinned, @JsonKey(name: 'is_favorite')  bool isFavorite, @JsonKey(name: 'is_muted')  bool isMuted, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'updated_at')  String? updatedAt, @JsonKey(name: 'need_sync')  bool needSync)?  $default,) {final _that = this;
switch (_that) {
case _ChatModel() when $default != null:
return $default(_that.id,_that.type,_that.title,_that.createrId,_that.unreadCount,_that.lastMsgId,_that.lastMsgAt,_that.pinnedMsgId,_that.deletedAt,_that.isPinned,_that.isFavorite,_that.isMuted,_that.createdAt,_that.updatedAt,_that.needSync);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChatModel implements ChatModel {
  const _ChatModel({required this.id, required this.type, this.title, @JsonKey(name: 'creater_id') this.createrId, @JsonKey(name: 'unread_count') this.unreadCount, @JsonKey(name: 'last_msg_id') this.lastMsgId, @JsonKey(name: 'last_msg_at') this.lastMsgAt, @JsonKey(name: 'pinned_msg_id') this.pinnedMsgId, @JsonKey(name: 'deleted_at') this.deletedAt, @JsonKey(name: 'is_pinned') this.isPinned = false, @JsonKey(name: 'is_favorite') this.isFavorite = false, @JsonKey(name: 'is_muted') this.isMuted = false, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt, @JsonKey(name: 'need_sync') this.needSync = true});
  factory _ChatModel.fromJson(Map<String, dynamic> json) => _$ChatModelFromJson(json);

@override final  String id;
@override final  String type;
@override final  String? title;
@override@JsonKey(name: 'creater_id') final  String? createrId;
@override@JsonKey(name: 'unread_count') final  int? unreadCount;
@override@JsonKey(name: 'last_msg_id') final  String? lastMsgId;
@override@JsonKey(name: 'last_msg_at') final  String? lastMsgAt;
@override@JsonKey(name: 'pinned_msg_id') final  String? pinnedMsgId;
@override@JsonKey(name: 'deleted_at') final  String? deletedAt;
@override@JsonKey(name: 'is_pinned') final  bool isPinned;
@override@JsonKey(name: 'is_favorite') final  bool isFavorite;
@override@JsonKey(name: 'is_muted') final  bool isMuted;
@override@JsonKey(name: 'created_at') final  String? createdAt;
@override@JsonKey(name: 'updated_at') final  String? updatedAt;
@override@JsonKey(name: 'need_sync') final  bool needSync;

/// Create a copy of ChatModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatModelCopyWith<_ChatModel> get copyWith => __$ChatModelCopyWithImpl<_ChatModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatModel&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.title, title) || other.title == title)&&(identical(other.createrId, createrId) || other.createrId == createrId)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.lastMsgId, lastMsgId) || other.lastMsgId == lastMsgId)&&(identical(other.lastMsgAt, lastMsgAt) || other.lastMsgAt == lastMsgAt)&&(identical(other.pinnedMsgId, pinnedMsgId) || other.pinnedMsgId == pinnedMsgId)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.isPinned, isPinned) || other.isPinned == isPinned)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.isMuted, isMuted) || other.isMuted == isMuted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.needSync, needSync) || other.needSync == needSync));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,title,createrId,unreadCount,lastMsgId,lastMsgAt,pinnedMsgId,deletedAt,isPinned,isFavorite,isMuted,createdAt,updatedAt,needSync);

@override
String toString() {
  return 'ChatModel(id: $id, type: $type, title: $title, createrId: $createrId, unreadCount: $unreadCount, lastMsgId: $lastMsgId, lastMsgAt: $lastMsgAt, pinnedMsgId: $pinnedMsgId, deletedAt: $deletedAt, isPinned: $isPinned, isFavorite: $isFavorite, isMuted: $isMuted, createdAt: $createdAt, updatedAt: $updatedAt, needSync: $needSync)';
}


}

/// @nodoc
abstract mixin class _$ChatModelCopyWith<$Res> implements $ChatModelCopyWith<$Res> {
  factory _$ChatModelCopyWith(_ChatModel value, $Res Function(_ChatModel) _then) = __$ChatModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String type, String? title,@JsonKey(name: 'creater_id') String? createrId,@JsonKey(name: 'unread_count') int? unreadCount,@JsonKey(name: 'last_msg_id') String? lastMsgId,@JsonKey(name: 'last_msg_at') String? lastMsgAt,@JsonKey(name: 'pinned_msg_id') String? pinnedMsgId,@JsonKey(name: 'deleted_at') String? deletedAt,@JsonKey(name: 'is_pinned') bool isPinned,@JsonKey(name: 'is_favorite') bool isFavorite,@JsonKey(name: 'is_muted') bool isMuted,@JsonKey(name: 'created_at') String? createdAt,@JsonKey(name: 'updated_at') String? updatedAt,@JsonKey(name: 'need_sync') bool needSync
});




}
/// @nodoc
class __$ChatModelCopyWithImpl<$Res>
    implements _$ChatModelCopyWith<$Res> {
  __$ChatModelCopyWithImpl(this._self, this._then);

  final _ChatModel _self;
  final $Res Function(_ChatModel) _then;

/// Create a copy of ChatModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? title = freezed,Object? createrId = freezed,Object? unreadCount = freezed,Object? lastMsgId = freezed,Object? lastMsgAt = freezed,Object? pinnedMsgId = freezed,Object? deletedAt = freezed,Object? isPinned = null,Object? isFavorite = null,Object? isMuted = null,Object? createdAt = freezed,Object? updatedAt = freezed,Object? needSync = null,}) {
  return _then(_ChatModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,createrId: freezed == createrId ? _self.createrId : createrId // ignore: cast_nullable_to_non_nullable
as String?,unreadCount: freezed == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int?,lastMsgId: freezed == lastMsgId ? _self.lastMsgId : lastMsgId // ignore: cast_nullable_to_non_nullable
as String?,lastMsgAt: freezed == lastMsgAt ? _self.lastMsgAt : lastMsgAt // ignore: cast_nullable_to_non_nullable
as String?,pinnedMsgId: freezed == pinnedMsgId ? _self.pinnedMsgId : pinnedMsgId // ignore: cast_nullable_to_non_nullable
as String?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as String?,isPinned: null == isPinned ? _self.isPinned : isPinned // ignore: cast_nullable_to_non_nullable
as bool,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,isMuted: null == isMuted ? _self.isMuted : isMuted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,needSync: null == needSync ? _self.needSync : needSync // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$DmModel {

@JsonKey(name: 'chat_id') String get chatId;@JsonKey(name: 'recipient_id') String get recipientId;@JsonKey(name: 'recipient_name') String get recipientName;@JsonKey(name: 'recipient_phone') String get recipientPhone;@JsonKey(name: 'recipient_profile_pic') String? get recipientProfilePic;@JsonKey(name: 'last_msg_id') String? get lastMsgId;@JsonKey(name: 'last_msg_type') String? get lastMsgType;@JsonKey(name: 'last_msg_body') String? get lastMsgBody;@JsonKey(name: 'last_msg_at') String? get lastMsgAt;@JsonKey(name: 'pinned_msg_id') String? get pinnedMsgId;@JsonKey(name: 'unread_count') int? get unreadCount;@JsonKey(name: 'is_online') bool get isRecipientOnline;@JsonKey(name: 'deleted_at') String? get deletedAt;@JsonKey(name: 'is_pinned') bool get isPinned;@JsonKey(name: 'is_muted') bool get isMuted;@JsonKey(name: 'is_favorite') bool get isFavorite;@JsonKey(name: 'created_at') String get createdAt;
/// Create a copy of DmModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DmModelCopyWith<DmModel> get copyWith => _$DmModelCopyWithImpl<DmModel>(this as DmModel, _$identity);

  /// Serializes this DmModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DmModel&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.recipientId, recipientId) || other.recipientId == recipientId)&&(identical(other.recipientName, recipientName) || other.recipientName == recipientName)&&(identical(other.recipientPhone, recipientPhone) || other.recipientPhone == recipientPhone)&&(identical(other.recipientProfilePic, recipientProfilePic) || other.recipientProfilePic == recipientProfilePic)&&(identical(other.lastMsgId, lastMsgId) || other.lastMsgId == lastMsgId)&&(identical(other.lastMsgType, lastMsgType) || other.lastMsgType == lastMsgType)&&(identical(other.lastMsgBody, lastMsgBody) || other.lastMsgBody == lastMsgBody)&&(identical(other.lastMsgAt, lastMsgAt) || other.lastMsgAt == lastMsgAt)&&(identical(other.pinnedMsgId, pinnedMsgId) || other.pinnedMsgId == pinnedMsgId)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.isRecipientOnline, isRecipientOnline) || other.isRecipientOnline == isRecipientOnline)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.isPinned, isPinned) || other.isPinned == isPinned)&&(identical(other.isMuted, isMuted) || other.isMuted == isMuted)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,chatId,recipientId,recipientName,recipientPhone,recipientProfilePic,lastMsgId,lastMsgType,lastMsgBody,lastMsgAt,pinnedMsgId,unreadCount,isRecipientOnline,deletedAt,isPinned,isMuted,isFavorite,createdAt);

@override
String toString() {
  return 'DmModel(chatId: $chatId, recipientId: $recipientId, recipientName: $recipientName, recipientPhone: $recipientPhone, recipientProfilePic: $recipientProfilePic, lastMsgId: $lastMsgId, lastMsgType: $lastMsgType, lastMsgBody: $lastMsgBody, lastMsgAt: $lastMsgAt, pinnedMsgId: $pinnedMsgId, unreadCount: $unreadCount, isRecipientOnline: $isRecipientOnline, deletedAt: $deletedAt, isPinned: $isPinned, isMuted: $isMuted, isFavorite: $isFavorite, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $DmModelCopyWith<$Res>  {
  factory $DmModelCopyWith(DmModel value, $Res Function(DmModel) _then) = _$DmModelCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'chat_id') String chatId,@JsonKey(name: 'recipient_id') String recipientId,@JsonKey(name: 'recipient_name') String recipientName,@JsonKey(name: 'recipient_phone') String recipientPhone,@JsonKey(name: 'recipient_profile_pic') String? recipientProfilePic,@JsonKey(name: 'last_msg_id') String? lastMsgId,@JsonKey(name: 'last_msg_type') String? lastMsgType,@JsonKey(name: 'last_msg_body') String? lastMsgBody,@JsonKey(name: 'last_msg_at') String? lastMsgAt,@JsonKey(name: 'pinned_msg_id') String? pinnedMsgId,@JsonKey(name: 'unread_count') int? unreadCount,@JsonKey(name: 'is_online') bool isRecipientOnline,@JsonKey(name: 'deleted_at') String? deletedAt,@JsonKey(name: 'is_pinned') bool isPinned,@JsonKey(name: 'is_muted') bool isMuted,@JsonKey(name: 'is_favorite') bool isFavorite,@JsonKey(name: 'created_at') String createdAt
});




}
/// @nodoc
class _$DmModelCopyWithImpl<$Res>
    implements $DmModelCopyWith<$Res> {
  _$DmModelCopyWithImpl(this._self, this._then);

  final DmModel _self;
  final $Res Function(DmModel) _then;

/// Create a copy of DmModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chatId = null,Object? recipientId = null,Object? recipientName = null,Object? recipientPhone = null,Object? recipientProfilePic = freezed,Object? lastMsgId = freezed,Object? lastMsgType = freezed,Object? lastMsgBody = freezed,Object? lastMsgAt = freezed,Object? pinnedMsgId = freezed,Object? unreadCount = freezed,Object? isRecipientOnline = null,Object? deletedAt = freezed,Object? isPinned = null,Object? isMuted = null,Object? isFavorite = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,recipientId: null == recipientId ? _self.recipientId : recipientId // ignore: cast_nullable_to_non_nullable
as String,recipientName: null == recipientName ? _self.recipientName : recipientName // ignore: cast_nullable_to_non_nullable
as String,recipientPhone: null == recipientPhone ? _self.recipientPhone : recipientPhone // ignore: cast_nullable_to_non_nullable
as String,recipientProfilePic: freezed == recipientProfilePic ? _self.recipientProfilePic : recipientProfilePic // ignore: cast_nullable_to_non_nullable
as String?,lastMsgId: freezed == lastMsgId ? _self.lastMsgId : lastMsgId // ignore: cast_nullable_to_non_nullable
as String?,lastMsgType: freezed == lastMsgType ? _self.lastMsgType : lastMsgType // ignore: cast_nullable_to_non_nullable
as String?,lastMsgBody: freezed == lastMsgBody ? _self.lastMsgBody : lastMsgBody // ignore: cast_nullable_to_non_nullable
as String?,lastMsgAt: freezed == lastMsgAt ? _self.lastMsgAt : lastMsgAt // ignore: cast_nullable_to_non_nullable
as String?,pinnedMsgId: freezed == pinnedMsgId ? _self.pinnedMsgId : pinnedMsgId // ignore: cast_nullable_to_non_nullable
as String?,unreadCount: freezed == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int?,isRecipientOnline: null == isRecipientOnline ? _self.isRecipientOnline : isRecipientOnline // ignore: cast_nullable_to_non_nullable
as bool,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as String?,isPinned: null == isPinned ? _self.isPinned : isPinned // ignore: cast_nullable_to_non_nullable
as bool,isMuted: null == isMuted ? _self.isMuted : isMuted // ignore: cast_nullable_to_non_nullable
as bool,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DmModel].
extension DmModelPatterns on DmModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DmModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DmModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DmModel value)  $default,){
final _that = this;
switch (_that) {
case _DmModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DmModel value)?  $default,){
final _that = this;
switch (_that) {
case _DmModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'chat_id')  String chatId, @JsonKey(name: 'recipient_id')  String recipientId, @JsonKey(name: 'recipient_name')  String recipientName, @JsonKey(name: 'recipient_phone')  String recipientPhone, @JsonKey(name: 'recipient_profile_pic')  String? recipientProfilePic, @JsonKey(name: 'last_msg_id')  String? lastMsgId, @JsonKey(name: 'last_msg_type')  String? lastMsgType, @JsonKey(name: 'last_msg_body')  String? lastMsgBody, @JsonKey(name: 'last_msg_at')  String? lastMsgAt, @JsonKey(name: 'pinned_msg_id')  String? pinnedMsgId, @JsonKey(name: 'unread_count')  int? unreadCount, @JsonKey(name: 'is_online')  bool isRecipientOnline, @JsonKey(name: 'deleted_at')  String? deletedAt, @JsonKey(name: 'is_pinned')  bool isPinned, @JsonKey(name: 'is_muted')  bool isMuted, @JsonKey(name: 'is_favorite')  bool isFavorite, @JsonKey(name: 'created_at')  String createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DmModel() when $default != null:
return $default(_that.chatId,_that.recipientId,_that.recipientName,_that.recipientPhone,_that.recipientProfilePic,_that.lastMsgId,_that.lastMsgType,_that.lastMsgBody,_that.lastMsgAt,_that.pinnedMsgId,_that.unreadCount,_that.isRecipientOnline,_that.deletedAt,_that.isPinned,_that.isMuted,_that.isFavorite,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'chat_id')  String chatId, @JsonKey(name: 'recipient_id')  String recipientId, @JsonKey(name: 'recipient_name')  String recipientName, @JsonKey(name: 'recipient_phone')  String recipientPhone, @JsonKey(name: 'recipient_profile_pic')  String? recipientProfilePic, @JsonKey(name: 'last_msg_id')  String? lastMsgId, @JsonKey(name: 'last_msg_type')  String? lastMsgType, @JsonKey(name: 'last_msg_body')  String? lastMsgBody, @JsonKey(name: 'last_msg_at')  String? lastMsgAt, @JsonKey(name: 'pinned_msg_id')  String? pinnedMsgId, @JsonKey(name: 'unread_count')  int? unreadCount, @JsonKey(name: 'is_online')  bool isRecipientOnline, @JsonKey(name: 'deleted_at')  String? deletedAt, @JsonKey(name: 'is_pinned')  bool isPinned, @JsonKey(name: 'is_muted')  bool isMuted, @JsonKey(name: 'is_favorite')  bool isFavorite, @JsonKey(name: 'created_at')  String createdAt)  $default,) {final _that = this;
switch (_that) {
case _DmModel():
return $default(_that.chatId,_that.recipientId,_that.recipientName,_that.recipientPhone,_that.recipientProfilePic,_that.lastMsgId,_that.lastMsgType,_that.lastMsgBody,_that.lastMsgAt,_that.pinnedMsgId,_that.unreadCount,_that.isRecipientOnline,_that.deletedAt,_that.isPinned,_that.isMuted,_that.isFavorite,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'chat_id')  String chatId, @JsonKey(name: 'recipient_id')  String recipientId, @JsonKey(name: 'recipient_name')  String recipientName, @JsonKey(name: 'recipient_phone')  String recipientPhone, @JsonKey(name: 'recipient_profile_pic')  String? recipientProfilePic, @JsonKey(name: 'last_msg_id')  String? lastMsgId, @JsonKey(name: 'last_msg_type')  String? lastMsgType, @JsonKey(name: 'last_msg_body')  String? lastMsgBody, @JsonKey(name: 'last_msg_at')  String? lastMsgAt, @JsonKey(name: 'pinned_msg_id')  String? pinnedMsgId, @JsonKey(name: 'unread_count')  int? unreadCount, @JsonKey(name: 'is_online')  bool isRecipientOnline, @JsonKey(name: 'deleted_at')  String? deletedAt, @JsonKey(name: 'is_pinned')  bool isPinned, @JsonKey(name: 'is_muted')  bool isMuted, @JsonKey(name: 'is_favorite')  bool isFavorite, @JsonKey(name: 'created_at')  String createdAt)?  $default,) {final _that = this;
switch (_that) {
case _DmModel() when $default != null:
return $default(_that.chatId,_that.recipientId,_that.recipientName,_that.recipientPhone,_that.recipientProfilePic,_that.lastMsgId,_that.lastMsgType,_that.lastMsgBody,_that.lastMsgAt,_that.pinnedMsgId,_that.unreadCount,_that.isRecipientOnline,_that.deletedAt,_that.isPinned,_that.isMuted,_that.isFavorite,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DmModel implements DmModel {
  const _DmModel({@JsonKey(name: 'chat_id') required this.chatId, @JsonKey(name: 'recipient_id') required this.recipientId, @JsonKey(name: 'recipient_name') required this.recipientName, @JsonKey(name: 'recipient_phone') required this.recipientPhone, @JsonKey(name: 'recipient_profile_pic') this.recipientProfilePic, @JsonKey(name: 'last_msg_id') this.lastMsgId, @JsonKey(name: 'last_msg_type') this.lastMsgType, @JsonKey(name: 'last_msg_body') this.lastMsgBody, @JsonKey(name: 'last_msg_at') this.lastMsgAt, @JsonKey(name: 'pinned_msg_id') this.pinnedMsgId, @JsonKey(name: 'unread_count') this.unreadCount, @JsonKey(name: 'is_online') this.isRecipientOnline = false, @JsonKey(name: 'deleted_at') this.deletedAt, @JsonKey(name: 'is_pinned') this.isPinned = false, @JsonKey(name: 'is_muted') this.isMuted = false, @JsonKey(name: 'is_favorite') this.isFavorite = false, @JsonKey(name: 'created_at') required this.createdAt});
  factory _DmModel.fromJson(Map<String, dynamic> json) => _$DmModelFromJson(json);

@override@JsonKey(name: 'chat_id') final  String chatId;
@override@JsonKey(name: 'recipient_id') final  String recipientId;
@override@JsonKey(name: 'recipient_name') final  String recipientName;
@override@JsonKey(name: 'recipient_phone') final  String recipientPhone;
@override@JsonKey(name: 'recipient_profile_pic') final  String? recipientProfilePic;
@override@JsonKey(name: 'last_msg_id') final  String? lastMsgId;
@override@JsonKey(name: 'last_msg_type') final  String? lastMsgType;
@override@JsonKey(name: 'last_msg_body') final  String? lastMsgBody;
@override@JsonKey(name: 'last_msg_at') final  String? lastMsgAt;
@override@JsonKey(name: 'pinned_msg_id') final  String? pinnedMsgId;
@override@JsonKey(name: 'unread_count') final  int? unreadCount;
@override@JsonKey(name: 'is_online') final  bool isRecipientOnline;
@override@JsonKey(name: 'deleted_at') final  String? deletedAt;
@override@JsonKey(name: 'is_pinned') final  bool isPinned;
@override@JsonKey(name: 'is_muted') final  bool isMuted;
@override@JsonKey(name: 'is_favorite') final  bool isFavorite;
@override@JsonKey(name: 'created_at') final  String createdAt;

/// Create a copy of DmModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DmModelCopyWith<_DmModel> get copyWith => __$DmModelCopyWithImpl<_DmModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DmModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DmModel&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.recipientId, recipientId) || other.recipientId == recipientId)&&(identical(other.recipientName, recipientName) || other.recipientName == recipientName)&&(identical(other.recipientPhone, recipientPhone) || other.recipientPhone == recipientPhone)&&(identical(other.recipientProfilePic, recipientProfilePic) || other.recipientProfilePic == recipientProfilePic)&&(identical(other.lastMsgId, lastMsgId) || other.lastMsgId == lastMsgId)&&(identical(other.lastMsgType, lastMsgType) || other.lastMsgType == lastMsgType)&&(identical(other.lastMsgBody, lastMsgBody) || other.lastMsgBody == lastMsgBody)&&(identical(other.lastMsgAt, lastMsgAt) || other.lastMsgAt == lastMsgAt)&&(identical(other.pinnedMsgId, pinnedMsgId) || other.pinnedMsgId == pinnedMsgId)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.isRecipientOnline, isRecipientOnline) || other.isRecipientOnline == isRecipientOnline)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.isPinned, isPinned) || other.isPinned == isPinned)&&(identical(other.isMuted, isMuted) || other.isMuted == isMuted)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,chatId,recipientId,recipientName,recipientPhone,recipientProfilePic,lastMsgId,lastMsgType,lastMsgBody,lastMsgAt,pinnedMsgId,unreadCount,isRecipientOnline,deletedAt,isPinned,isMuted,isFavorite,createdAt);

@override
String toString() {
  return 'DmModel(chatId: $chatId, recipientId: $recipientId, recipientName: $recipientName, recipientPhone: $recipientPhone, recipientProfilePic: $recipientProfilePic, lastMsgId: $lastMsgId, lastMsgType: $lastMsgType, lastMsgBody: $lastMsgBody, lastMsgAt: $lastMsgAt, pinnedMsgId: $pinnedMsgId, unreadCount: $unreadCount, isRecipientOnline: $isRecipientOnline, deletedAt: $deletedAt, isPinned: $isPinned, isMuted: $isMuted, isFavorite: $isFavorite, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$DmModelCopyWith<$Res> implements $DmModelCopyWith<$Res> {
  factory _$DmModelCopyWith(_DmModel value, $Res Function(_DmModel) _then) = __$DmModelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'chat_id') String chatId,@JsonKey(name: 'recipient_id') String recipientId,@JsonKey(name: 'recipient_name') String recipientName,@JsonKey(name: 'recipient_phone') String recipientPhone,@JsonKey(name: 'recipient_profile_pic') String? recipientProfilePic,@JsonKey(name: 'last_msg_id') String? lastMsgId,@JsonKey(name: 'last_msg_type') String? lastMsgType,@JsonKey(name: 'last_msg_body') String? lastMsgBody,@JsonKey(name: 'last_msg_at') String? lastMsgAt,@JsonKey(name: 'pinned_msg_id') String? pinnedMsgId,@JsonKey(name: 'unread_count') int? unreadCount,@JsonKey(name: 'is_online') bool isRecipientOnline,@JsonKey(name: 'deleted_at') String? deletedAt,@JsonKey(name: 'is_pinned') bool isPinned,@JsonKey(name: 'is_muted') bool isMuted,@JsonKey(name: 'is_favorite') bool isFavorite,@JsonKey(name: 'created_at') String createdAt
});




}
/// @nodoc
class __$DmModelCopyWithImpl<$Res>
    implements _$DmModelCopyWith<$Res> {
  __$DmModelCopyWithImpl(this._self, this._then);

  final _DmModel _self;
  final $Res Function(_DmModel) _then;

/// Create a copy of DmModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chatId = null,Object? recipientId = null,Object? recipientName = null,Object? recipientPhone = null,Object? recipientProfilePic = freezed,Object? lastMsgId = freezed,Object? lastMsgType = freezed,Object? lastMsgBody = freezed,Object? lastMsgAt = freezed,Object? pinnedMsgId = freezed,Object? unreadCount = freezed,Object? isRecipientOnline = null,Object? deletedAt = freezed,Object? isPinned = null,Object? isMuted = null,Object? isFavorite = null,Object? createdAt = null,}) {
  return _then(_DmModel(
chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,recipientId: null == recipientId ? _self.recipientId : recipientId // ignore: cast_nullable_to_non_nullable
as String,recipientName: null == recipientName ? _self.recipientName : recipientName // ignore: cast_nullable_to_non_nullable
as String,recipientPhone: null == recipientPhone ? _self.recipientPhone : recipientPhone // ignore: cast_nullable_to_non_nullable
as String,recipientProfilePic: freezed == recipientProfilePic ? _self.recipientProfilePic : recipientProfilePic // ignore: cast_nullable_to_non_nullable
as String?,lastMsgId: freezed == lastMsgId ? _self.lastMsgId : lastMsgId // ignore: cast_nullable_to_non_nullable
as String?,lastMsgType: freezed == lastMsgType ? _self.lastMsgType : lastMsgType // ignore: cast_nullable_to_non_nullable
as String?,lastMsgBody: freezed == lastMsgBody ? _self.lastMsgBody : lastMsgBody // ignore: cast_nullable_to_non_nullable
as String?,lastMsgAt: freezed == lastMsgAt ? _self.lastMsgAt : lastMsgAt // ignore: cast_nullable_to_non_nullable
as String?,pinnedMsgId: freezed == pinnedMsgId ? _self.pinnedMsgId : pinnedMsgId // ignore: cast_nullable_to_non_nullable
as String?,unreadCount: freezed == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int?,isRecipientOnline: null == isRecipientOnline ? _self.isRecipientOnline : isRecipientOnline // ignore: cast_nullable_to_non_nullable
as bool,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as String?,isPinned: null == isPinned ? _self.isPinned : isPinned // ignore: cast_nullable_to_non_nullable
as bool,isMuted: null == isMuted ? _self.isMuted : isMuted // ignore: cast_nullable_to_non_nullable
as bool,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ChatMemberModel {

 String? get id;@JsonKey(name: 'chat_id') String get chatId;@JsonKey(name: 'user_id') String get userId; String get role;@JsonKey(name: 'joined_at') String? get joinedAt;@JsonKey(name: 'removed_at') String? get removedAt;@JsonKey(name: 'last_read_msg_id') String? get lastReadMsgId;@JsonKey(name: 'last_delivered_msg_id') String? get lastDeliveredMsgId;
/// Create a copy of ChatMemberModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatMemberModelCopyWith<ChatMemberModel> get copyWith => _$ChatMemberModelCopyWithImpl<ChatMemberModel>(this as ChatMemberModel, _$identity);

  /// Serializes this ChatMemberModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatMemberModel&&(identical(other.id, id) || other.id == id)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.role, role) || other.role == role)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.removedAt, removedAt) || other.removedAt == removedAt)&&(identical(other.lastReadMsgId, lastReadMsgId) || other.lastReadMsgId == lastReadMsgId)&&(identical(other.lastDeliveredMsgId, lastDeliveredMsgId) || other.lastDeliveredMsgId == lastDeliveredMsgId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,chatId,userId,role,joinedAt,removedAt,lastReadMsgId,lastDeliveredMsgId);

@override
String toString() {
  return 'ChatMemberModel(id: $id, chatId: $chatId, userId: $userId, role: $role, joinedAt: $joinedAt, removedAt: $removedAt, lastReadMsgId: $lastReadMsgId, lastDeliveredMsgId: $lastDeliveredMsgId)';
}


}

/// @nodoc
abstract mixin class $ChatMemberModelCopyWith<$Res>  {
  factory $ChatMemberModelCopyWith(ChatMemberModel value, $Res Function(ChatMemberModel) _then) = _$ChatMemberModelCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'chat_id') String chatId,@JsonKey(name: 'user_id') String userId, String role,@JsonKey(name: 'joined_at') String? joinedAt,@JsonKey(name: 'removed_at') String? removedAt,@JsonKey(name: 'last_read_msg_id') String? lastReadMsgId,@JsonKey(name: 'last_delivered_msg_id') String? lastDeliveredMsgId
});




}
/// @nodoc
class _$ChatMemberModelCopyWithImpl<$Res>
    implements $ChatMemberModelCopyWith<$Res> {
  _$ChatMemberModelCopyWithImpl(this._self, this._then);

  final ChatMemberModel _self;
  final $Res Function(ChatMemberModel) _then;

/// Create a copy of ChatMemberModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? chatId = null,Object? userId = null,Object? role = null,Object? joinedAt = freezed,Object? removedAt = freezed,Object? lastReadMsgId = freezed,Object? lastDeliveredMsgId = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,joinedAt: freezed == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as String?,removedAt: freezed == removedAt ? _self.removedAt : removedAt // ignore: cast_nullable_to_non_nullable
as String?,lastReadMsgId: freezed == lastReadMsgId ? _self.lastReadMsgId : lastReadMsgId // ignore: cast_nullable_to_non_nullable
as String?,lastDeliveredMsgId: freezed == lastDeliveredMsgId ? _self.lastDeliveredMsgId : lastDeliveredMsgId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatMemberModel].
extension ChatMemberModelPatterns on ChatMemberModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatMemberModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatMemberModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatMemberModel value)  $default,){
final _that = this;
switch (_that) {
case _ChatMemberModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatMemberModel value)?  $default,){
final _that = this;
switch (_that) {
case _ChatMemberModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'chat_id')  String chatId, @JsonKey(name: 'user_id')  String userId,  String role, @JsonKey(name: 'joined_at')  String? joinedAt, @JsonKey(name: 'removed_at')  String? removedAt, @JsonKey(name: 'last_read_msg_id')  String? lastReadMsgId, @JsonKey(name: 'last_delivered_msg_id')  String? lastDeliveredMsgId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatMemberModel() when $default != null:
return $default(_that.id,_that.chatId,_that.userId,_that.role,_that.joinedAt,_that.removedAt,_that.lastReadMsgId,_that.lastDeliveredMsgId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'chat_id')  String chatId, @JsonKey(name: 'user_id')  String userId,  String role, @JsonKey(name: 'joined_at')  String? joinedAt, @JsonKey(name: 'removed_at')  String? removedAt, @JsonKey(name: 'last_read_msg_id')  String? lastReadMsgId, @JsonKey(name: 'last_delivered_msg_id')  String? lastDeliveredMsgId)  $default,) {final _that = this;
switch (_that) {
case _ChatMemberModel():
return $default(_that.id,_that.chatId,_that.userId,_that.role,_that.joinedAt,_that.removedAt,_that.lastReadMsgId,_that.lastDeliveredMsgId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'chat_id')  String chatId, @JsonKey(name: 'user_id')  String userId,  String role, @JsonKey(name: 'joined_at')  String? joinedAt, @JsonKey(name: 'removed_at')  String? removedAt, @JsonKey(name: 'last_read_msg_id')  String? lastReadMsgId, @JsonKey(name: 'last_delivered_msg_id')  String? lastDeliveredMsgId)?  $default,) {final _that = this;
switch (_that) {
case _ChatMemberModel() when $default != null:
return $default(_that.id,_that.chatId,_that.userId,_that.role,_that.joinedAt,_that.removedAt,_that.lastReadMsgId,_that.lastDeliveredMsgId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChatMemberModel implements ChatMemberModel {
  const _ChatMemberModel({this.id, @JsonKey(name: 'chat_id') required this.chatId, @JsonKey(name: 'user_id') required this.userId, required this.role, @JsonKey(name: 'joined_at') this.joinedAt, @JsonKey(name: 'removed_at') this.removedAt, @JsonKey(name: 'last_read_msg_id') this.lastReadMsgId, @JsonKey(name: 'last_delivered_msg_id') this.lastDeliveredMsgId});
  factory _ChatMemberModel.fromJson(Map<String, dynamic> json) => _$ChatMemberModelFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'chat_id') final  String chatId;
@override@JsonKey(name: 'user_id') final  String userId;
@override final  String role;
@override@JsonKey(name: 'joined_at') final  String? joinedAt;
@override@JsonKey(name: 'removed_at') final  String? removedAt;
@override@JsonKey(name: 'last_read_msg_id') final  String? lastReadMsgId;
@override@JsonKey(name: 'last_delivered_msg_id') final  String? lastDeliveredMsgId;

/// Create a copy of ChatMemberModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatMemberModelCopyWith<_ChatMemberModel> get copyWith => __$ChatMemberModelCopyWithImpl<_ChatMemberModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatMemberModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatMemberModel&&(identical(other.id, id) || other.id == id)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.role, role) || other.role == role)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.removedAt, removedAt) || other.removedAt == removedAt)&&(identical(other.lastReadMsgId, lastReadMsgId) || other.lastReadMsgId == lastReadMsgId)&&(identical(other.lastDeliveredMsgId, lastDeliveredMsgId) || other.lastDeliveredMsgId == lastDeliveredMsgId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,chatId,userId,role,joinedAt,removedAt,lastReadMsgId,lastDeliveredMsgId);

@override
String toString() {
  return 'ChatMemberModel(id: $id, chatId: $chatId, userId: $userId, role: $role, joinedAt: $joinedAt, removedAt: $removedAt, lastReadMsgId: $lastReadMsgId, lastDeliveredMsgId: $lastDeliveredMsgId)';
}


}

/// @nodoc
abstract mixin class _$ChatMemberModelCopyWith<$Res> implements $ChatMemberModelCopyWith<$Res> {
  factory _$ChatMemberModelCopyWith(_ChatMemberModel value, $Res Function(_ChatMemberModel) _then) = __$ChatMemberModelCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'chat_id') String chatId,@JsonKey(name: 'user_id') String userId, String role,@JsonKey(name: 'joined_at') String? joinedAt,@JsonKey(name: 'removed_at') String? removedAt,@JsonKey(name: 'last_read_msg_id') String? lastReadMsgId,@JsonKey(name: 'last_delivered_msg_id') String? lastDeliveredMsgId
});




}
/// @nodoc
class __$ChatMemberModelCopyWithImpl<$Res>
    implements _$ChatMemberModelCopyWith<$Res> {
  __$ChatMemberModelCopyWithImpl(this._self, this._then);

  final _ChatMemberModel _self;
  final $Res Function(_ChatMemberModel) _then;

/// Create a copy of ChatMemberModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? chatId = null,Object? userId = null,Object? role = null,Object? joinedAt = freezed,Object? removedAt = freezed,Object? lastReadMsgId = freezed,Object? lastDeliveredMsgId = freezed,}) {
  return _then(_ChatMemberModel(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,joinedAt: freezed == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as String?,removedAt: freezed == removedAt ? _self.removedAt : removedAt // ignore: cast_nullable_to_non_nullable
as String?,lastReadMsgId: freezed == lastReadMsgId ? _self.lastReadMsgId : lastReadMsgId // ignore: cast_nullable_to_non_nullable
as String?,lastDeliveredMsgId: freezed == lastDeliveredMsgId ? _self.lastDeliveredMsgId : lastDeliveredMsgId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
