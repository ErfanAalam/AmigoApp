// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message-status.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MessageInfoModel {

@JsonKey(name: 'chat_id') String get chatId;@JsonKey(name: 'message_id') String get messageId;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'delivered_at') String? get deliveredAt;@JsonKey(name: 'read_at') String? get readAt; String? get reaction;@JsonKey(name: 'deleted_at') String? get deletedAt;
/// Create a copy of MessageInfoModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageInfoModelCopyWith<MessageInfoModel> get copyWith => _$MessageInfoModelCopyWithImpl<MessageInfoModel>(this as MessageInfoModel, _$identity);

  /// Serializes this MessageInfoModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageInfoModel&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.deliveredAt, deliveredAt) || other.deliveredAt == deliveredAt)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&(identical(other.reaction, reaction) || other.reaction == reaction)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,chatId,messageId,userId,deliveredAt,readAt,reaction,deletedAt);

@override
String toString() {
  return 'MessageInfoModel(chatId: $chatId, messageId: $messageId, userId: $userId, deliveredAt: $deliveredAt, readAt: $readAt, reaction: $reaction, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $MessageInfoModelCopyWith<$Res>  {
  factory $MessageInfoModelCopyWith(MessageInfoModel value, $Res Function(MessageInfoModel) _then) = _$MessageInfoModelCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'chat_id') String chatId,@JsonKey(name: 'message_id') String messageId,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'delivered_at') String? deliveredAt,@JsonKey(name: 'read_at') String? readAt, String? reaction,@JsonKey(name: 'deleted_at') String? deletedAt
});




}
/// @nodoc
class _$MessageInfoModelCopyWithImpl<$Res>
    implements $MessageInfoModelCopyWith<$Res> {
  _$MessageInfoModelCopyWithImpl(this._self, this._then);

  final MessageInfoModel _self;
  final $Res Function(MessageInfoModel) _then;

/// Create a copy of MessageInfoModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chatId = null,Object? messageId = null,Object? userId = null,Object? deliveredAt = freezed,Object? readAt = freezed,Object? reaction = freezed,Object? deletedAt = freezed,}) {
  return _then(_self.copyWith(
chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,deliveredAt: freezed == deliveredAt ? _self.deliveredAt : deliveredAt // ignore: cast_nullable_to_non_nullable
as String?,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as String?,reaction: freezed == reaction ? _self.reaction : reaction // ignore: cast_nullable_to_non_nullable
as String?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageInfoModel].
extension MessageInfoModelPatterns on MessageInfoModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageInfoModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageInfoModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageInfoModel value)  $default,){
final _that = this;
switch (_that) {
case _MessageInfoModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageInfoModel value)?  $default,){
final _that = this;
switch (_that) {
case _MessageInfoModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'chat_id')  String chatId, @JsonKey(name: 'message_id')  String messageId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'delivered_at')  String? deliveredAt, @JsonKey(name: 'read_at')  String? readAt,  String? reaction, @JsonKey(name: 'deleted_at')  String? deletedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageInfoModel() when $default != null:
return $default(_that.chatId,_that.messageId,_that.userId,_that.deliveredAt,_that.readAt,_that.reaction,_that.deletedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'chat_id')  String chatId, @JsonKey(name: 'message_id')  String messageId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'delivered_at')  String? deliveredAt, @JsonKey(name: 'read_at')  String? readAt,  String? reaction, @JsonKey(name: 'deleted_at')  String? deletedAt)  $default,) {final _that = this;
switch (_that) {
case _MessageInfoModel():
return $default(_that.chatId,_that.messageId,_that.userId,_that.deliveredAt,_that.readAt,_that.reaction,_that.deletedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'chat_id')  String chatId, @JsonKey(name: 'message_id')  String messageId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'delivered_at')  String? deliveredAt, @JsonKey(name: 'read_at')  String? readAt,  String? reaction, @JsonKey(name: 'deleted_at')  String? deletedAt)?  $default,) {final _that = this;
switch (_that) {
case _MessageInfoModel() when $default != null:
return $default(_that.chatId,_that.messageId,_that.userId,_that.deliveredAt,_that.readAt,_that.reaction,_that.deletedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageInfoModel implements MessageInfoModel {
  const _MessageInfoModel({@JsonKey(name: 'chat_id') required this.chatId, @JsonKey(name: 'message_id') required this.messageId, @JsonKey(name: 'user_id') required this.userId, @JsonKey(name: 'delivered_at') this.deliveredAt, @JsonKey(name: 'read_at') this.readAt, this.reaction, @JsonKey(name: 'deleted_at') this.deletedAt});
  factory _MessageInfoModel.fromJson(Map<String, dynamic> json) => _$MessageInfoModelFromJson(json);

@override@JsonKey(name: 'chat_id') final  String chatId;
@override@JsonKey(name: 'message_id') final  String messageId;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'delivered_at') final  String? deliveredAt;
@override@JsonKey(name: 'read_at') final  String? readAt;
@override final  String? reaction;
@override@JsonKey(name: 'deleted_at') final  String? deletedAt;

/// Create a copy of MessageInfoModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageInfoModelCopyWith<_MessageInfoModel> get copyWith => __$MessageInfoModelCopyWithImpl<_MessageInfoModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageInfoModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageInfoModel&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.deliveredAt, deliveredAt) || other.deliveredAt == deliveredAt)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&(identical(other.reaction, reaction) || other.reaction == reaction)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,chatId,messageId,userId,deliveredAt,readAt,reaction,deletedAt);

@override
String toString() {
  return 'MessageInfoModel(chatId: $chatId, messageId: $messageId, userId: $userId, deliveredAt: $deliveredAt, readAt: $readAt, reaction: $reaction, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class _$MessageInfoModelCopyWith<$Res> implements $MessageInfoModelCopyWith<$Res> {
  factory _$MessageInfoModelCopyWith(_MessageInfoModel value, $Res Function(_MessageInfoModel) _then) = __$MessageInfoModelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'chat_id') String chatId,@JsonKey(name: 'message_id') String messageId,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'delivered_at') String? deliveredAt,@JsonKey(name: 'read_at') String? readAt, String? reaction,@JsonKey(name: 'deleted_at') String? deletedAt
});




}
/// @nodoc
class __$MessageInfoModelCopyWithImpl<$Res>
    implements _$MessageInfoModelCopyWith<$Res> {
  __$MessageInfoModelCopyWithImpl(this._self, this._then);

  final _MessageInfoModel _self;
  final $Res Function(_MessageInfoModel) _then;

/// Create a copy of MessageInfoModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chatId = null,Object? messageId = null,Object? userId = null,Object? deliveredAt = freezed,Object? readAt = freezed,Object? reaction = freezed,Object? deletedAt = freezed,}) {
  return _then(_MessageInfoModel(
chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,deliveredAt: freezed == deliveredAt ? _self.deliveredAt : deliveredAt // ignore: cast_nullable_to_non_nullable
as String?,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as String?,reaction: freezed == reaction ? _self.reaction : reaction // ignore: cast_nullable_to_non_nullable
as String?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
