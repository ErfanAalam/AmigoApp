// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'socket.types.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ConnectionStatusPayload {

@JsonKey(name: 'sender_id') String get senderId; String get status;
/// Create a copy of ConnectionStatusPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionStatusPayloadCopyWith<ConnectionStatusPayload> get copyWith => _$ConnectionStatusPayloadCopyWithImpl<ConnectionStatusPayload>(this as ConnectionStatusPayload, _$identity);

  /// Serializes this ConnectionStatusPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionStatusPayload&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,senderId,status);

@override
String toString() {
  return 'ConnectionStatusPayload(senderId: $senderId, status: $status)';
}


}

/// @nodoc
abstract mixin class $ConnectionStatusPayloadCopyWith<$Res>  {
  factory $ConnectionStatusPayloadCopyWith(ConnectionStatusPayload value, $Res Function(ConnectionStatusPayload) _then) = _$ConnectionStatusPayloadCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'sender_id') String senderId, String status
});




}
/// @nodoc
class _$ConnectionStatusPayloadCopyWithImpl<$Res>
    implements $ConnectionStatusPayloadCopyWith<$Res> {
  _$ConnectionStatusPayloadCopyWithImpl(this._self, this._then);

  final ConnectionStatusPayload _self;
  final $Res Function(ConnectionStatusPayload) _then;

/// Create a copy of ConnectionStatusPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? senderId = null,Object? status = null,}) {
  return _then(_self.copyWith(
senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ConnectionStatusPayload].
extension ConnectionStatusPayloadPatterns on ConnectionStatusPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConnectionStatusPayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConnectionStatusPayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConnectionStatusPayload value)  $default,){
final _that = this;
switch (_that) {
case _ConnectionStatusPayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConnectionStatusPayload value)?  $default,){
final _that = this;
switch (_that) {
case _ConnectionStatusPayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'sender_id')  String senderId,  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConnectionStatusPayload() when $default != null:
return $default(_that.senderId,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'sender_id')  String senderId,  String status)  $default,) {final _that = this;
switch (_that) {
case _ConnectionStatusPayload():
return $default(_that.senderId,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'sender_id')  String senderId,  String status)?  $default,) {final _that = this;
switch (_that) {
case _ConnectionStatusPayload() when $default != null:
return $default(_that.senderId,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ConnectionStatusPayload implements ConnectionStatusPayload {
  const _ConnectionStatusPayload({@JsonKey(name: 'sender_id') required this.senderId, required this.status});
  factory _ConnectionStatusPayload.fromJson(Map<String, dynamic> json) => _$ConnectionStatusPayloadFromJson(json);

@override@JsonKey(name: 'sender_id') final  String senderId;
@override final  String status;

/// Create a copy of ConnectionStatusPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConnectionStatusPayloadCopyWith<_ConnectionStatusPayload> get copyWith => __$ConnectionStatusPayloadCopyWithImpl<_ConnectionStatusPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConnectionStatusPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConnectionStatusPayload&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,senderId,status);

@override
String toString() {
  return 'ConnectionStatusPayload(senderId: $senderId, status: $status)';
}


}

/// @nodoc
abstract mixin class _$ConnectionStatusPayloadCopyWith<$Res> implements $ConnectionStatusPayloadCopyWith<$Res> {
  factory _$ConnectionStatusPayloadCopyWith(_ConnectionStatusPayload value, $Res Function(_ConnectionStatusPayload) _then) = __$ConnectionStatusPayloadCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'sender_id') String senderId, String status
});




}
/// @nodoc
class __$ConnectionStatusPayloadCopyWithImpl<$Res>
    implements _$ConnectionStatusPayloadCopyWith<$Res> {
  __$ConnectionStatusPayloadCopyWithImpl(this._self, this._then);

  final _ConnectionStatusPayload _self;
  final $Res Function(_ConnectionStatusPayload) _then;

/// Create a copy of ConnectionStatusPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? senderId = null,Object? status = null,}) {
  return _then(_ConnectionStatusPayload(
senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ConvJoinPayload {

@JsonKey(name: 'conv_id') String get convId;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'last_read_msg_id') String get lastReadMsgId;
/// Create a copy of ConvJoinPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConvJoinPayloadCopyWith<ConvJoinPayload> get copyWith => _$ConvJoinPayloadCopyWithImpl<ConvJoinPayload>(this as ConvJoinPayload, _$identity);

  /// Serializes this ConvJoinPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConvJoinPayload&&(identical(other.convId, convId) || other.convId == convId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.lastReadMsgId, lastReadMsgId) || other.lastReadMsgId == lastReadMsgId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,convId,userId,lastReadMsgId);

@override
String toString() {
  return 'ConvJoinPayload(convId: $convId, userId: $userId, lastReadMsgId: $lastReadMsgId)';
}


}

/// @nodoc
abstract mixin class $ConvJoinPayloadCopyWith<$Res>  {
  factory $ConvJoinPayloadCopyWith(ConvJoinPayload value, $Res Function(ConvJoinPayload) _then) = _$ConvJoinPayloadCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'conv_id') String convId,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'last_read_msg_id') String lastReadMsgId
});




}
/// @nodoc
class _$ConvJoinPayloadCopyWithImpl<$Res>
    implements $ConvJoinPayloadCopyWith<$Res> {
  _$ConvJoinPayloadCopyWithImpl(this._self, this._then);

  final ConvJoinPayload _self;
  final $Res Function(ConvJoinPayload) _then;

/// Create a copy of ConvJoinPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? convId = null,Object? userId = null,Object? lastReadMsgId = null,}) {
  return _then(_self.copyWith(
convId: null == convId ? _self.convId : convId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,lastReadMsgId: null == lastReadMsgId ? _self.lastReadMsgId : lastReadMsgId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ConvJoinPayload].
extension ConvJoinPayloadPatterns on ConvJoinPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConvJoinPayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConvJoinPayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConvJoinPayload value)  $default,){
final _that = this;
switch (_that) {
case _ConvJoinPayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConvJoinPayload value)?  $default,){
final _that = this;
switch (_that) {
case _ConvJoinPayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'last_read_msg_id')  String lastReadMsgId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConvJoinPayload() when $default != null:
return $default(_that.convId,_that.userId,_that.lastReadMsgId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'last_read_msg_id')  String lastReadMsgId)  $default,) {final _that = this;
switch (_that) {
case _ConvJoinPayload():
return $default(_that.convId,_that.userId,_that.lastReadMsgId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'last_read_msg_id')  String lastReadMsgId)?  $default,) {final _that = this;
switch (_that) {
case _ConvJoinPayload() when $default != null:
return $default(_that.convId,_that.userId,_that.lastReadMsgId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ConvJoinPayload implements ConvJoinPayload {
  const _ConvJoinPayload({@JsonKey(name: 'conv_id') required this.convId, @JsonKey(name: 'user_id') required this.userId, @JsonKey(name: 'last_read_msg_id') required this.lastReadMsgId});
  factory _ConvJoinPayload.fromJson(Map<String, dynamic> json) => _$ConvJoinPayloadFromJson(json);

@override@JsonKey(name: 'conv_id') final  String convId;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'last_read_msg_id') final  String lastReadMsgId;

/// Create a copy of ConvJoinPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConvJoinPayloadCopyWith<_ConvJoinPayload> get copyWith => __$ConvJoinPayloadCopyWithImpl<_ConvJoinPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConvJoinPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConvJoinPayload&&(identical(other.convId, convId) || other.convId == convId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.lastReadMsgId, lastReadMsgId) || other.lastReadMsgId == lastReadMsgId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,convId,userId,lastReadMsgId);

@override
String toString() {
  return 'ConvJoinPayload(convId: $convId, userId: $userId, lastReadMsgId: $lastReadMsgId)';
}


}

/// @nodoc
abstract mixin class _$ConvJoinPayloadCopyWith<$Res> implements $ConvJoinPayloadCopyWith<$Res> {
  factory _$ConvJoinPayloadCopyWith(_ConvJoinPayload value, $Res Function(_ConvJoinPayload) _then) = __$ConvJoinPayloadCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'conv_id') String convId,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'last_read_msg_id') String lastReadMsgId
});




}
/// @nodoc
class __$ConvJoinPayloadCopyWithImpl<$Res>
    implements _$ConvJoinPayloadCopyWith<$Res> {
  __$ConvJoinPayloadCopyWithImpl(this._self, this._then);

  final _ConvJoinPayload _self;
  final $Res Function(_ConvJoinPayload) _then;

/// Create a copy of ConvJoinPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? convId = null,Object? userId = null,Object? lastReadMsgId = null,}) {
  return _then(_ConvJoinPayload(
convId: null == convId ? _self.convId : convId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,lastReadMsgId: null == lastReadMsgId ? _self.lastReadMsgId : lastReadMsgId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ChatMessagePayload {

 String get id;@JsonKey(name: 'conv_id') String get convId;@JsonKey(name: 'sender_id') String get senderId;@JsonKey(name: 'msg_type')@MessageTypeConverter() MessageType get msgType; String? get body; dynamic get attachments;@JsonKey(name: 'replied_to') String? get repliedTo;// Pre-warmed compact preview of the replied-to message, attached by the
// server so the receiver can render the reply container without a local
// DB lookup falling through to "empty".
@JsonKey(name: 'replied_to_message') Map<String, dynamic>? get repliedToMessage;@JsonKey(name: 'sent_at') DateTime get sentAt;// Disappearing-messages deadline (server-stamped on broadcast). Null when
// the chat has the feature off. Persisted onto the local messages row.
@JsonKey(name: 'expires_at') DateTime? get expiresAt;
/// Create a copy of ChatMessagePayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatMessagePayloadCopyWith<ChatMessagePayload> get copyWith => _$ChatMessagePayloadCopyWithImpl<ChatMessagePayload>(this as ChatMessagePayload, _$identity);

  /// Serializes this ChatMessagePayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatMessagePayload&&(identical(other.id, id) || other.id == id)&&(identical(other.convId, convId) || other.convId == convId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.msgType, msgType) || other.msgType == msgType)&&(identical(other.body, body) || other.body == body)&&const DeepCollectionEquality().equals(other.attachments, attachments)&&(identical(other.repliedTo, repliedTo) || other.repliedTo == repliedTo)&&const DeepCollectionEquality().equals(other.repliedToMessage, repliedToMessage)&&(identical(other.sentAt, sentAt) || other.sentAt == sentAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,convId,senderId,msgType,body,const DeepCollectionEquality().hash(attachments),repliedTo,const DeepCollectionEquality().hash(repliedToMessage),sentAt,expiresAt);

@override
String toString() {
  return 'ChatMessagePayload(id: $id, convId: $convId, senderId: $senderId, msgType: $msgType, body: $body, attachments: $attachments, repliedTo: $repliedTo, repliedToMessage: $repliedToMessage, sentAt: $sentAt, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class $ChatMessagePayloadCopyWith<$Res>  {
  factory $ChatMessagePayloadCopyWith(ChatMessagePayload value, $Res Function(ChatMessagePayload) _then) = _$ChatMessagePayloadCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'conv_id') String convId,@JsonKey(name: 'sender_id') String senderId,@JsonKey(name: 'msg_type')@MessageTypeConverter() MessageType msgType, String? body, dynamic attachments,@JsonKey(name: 'replied_to') String? repliedTo,@JsonKey(name: 'replied_to_message') Map<String, dynamic>? repliedToMessage,@JsonKey(name: 'sent_at') DateTime sentAt,@JsonKey(name: 'expires_at') DateTime? expiresAt
});




}
/// @nodoc
class _$ChatMessagePayloadCopyWithImpl<$Res>
    implements $ChatMessagePayloadCopyWith<$Res> {
  _$ChatMessagePayloadCopyWithImpl(this._self, this._then);

  final ChatMessagePayload _self;
  final $Res Function(ChatMessagePayload) _then;

/// Create a copy of ChatMessagePayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? convId = null,Object? senderId = null,Object? msgType = null,Object? body = freezed,Object? attachments = freezed,Object? repliedTo = freezed,Object? repliedToMessage = freezed,Object? sentAt = null,Object? expiresAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,convId: null == convId ? _self.convId : convId // ignore: cast_nullable_to_non_nullable
as String,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,msgType: null == msgType ? _self.msgType : msgType // ignore: cast_nullable_to_non_nullable
as MessageType,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,attachments: freezed == attachments ? _self.attachments : attachments // ignore: cast_nullable_to_non_nullable
as dynamic,repliedTo: freezed == repliedTo ? _self.repliedTo : repliedTo // ignore: cast_nullable_to_non_nullable
as String?,repliedToMessage: freezed == repliedToMessage ? _self.repliedToMessage : repliedToMessage // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,sentAt: null == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatMessagePayload].
extension ChatMessagePayloadPatterns on ChatMessagePayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatMessagePayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatMessagePayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatMessagePayload value)  $default,){
final _that = this;
switch (_that) {
case _ChatMessagePayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatMessagePayload value)?  $default,){
final _that = this;
switch (_that) {
case _ChatMessagePayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'sender_id')  String senderId, @JsonKey(name: 'msg_type')@MessageTypeConverter()  MessageType msgType,  String? body,  dynamic attachments, @JsonKey(name: 'replied_to')  String? repliedTo, @JsonKey(name: 'replied_to_message')  Map<String, dynamic>? repliedToMessage, @JsonKey(name: 'sent_at')  DateTime sentAt, @JsonKey(name: 'expires_at')  DateTime? expiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatMessagePayload() when $default != null:
return $default(_that.id,_that.convId,_that.senderId,_that.msgType,_that.body,_that.attachments,_that.repliedTo,_that.repliedToMessage,_that.sentAt,_that.expiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'sender_id')  String senderId, @JsonKey(name: 'msg_type')@MessageTypeConverter()  MessageType msgType,  String? body,  dynamic attachments, @JsonKey(name: 'replied_to')  String? repliedTo, @JsonKey(name: 'replied_to_message')  Map<String, dynamic>? repliedToMessage, @JsonKey(name: 'sent_at')  DateTime sentAt, @JsonKey(name: 'expires_at')  DateTime? expiresAt)  $default,) {final _that = this;
switch (_that) {
case _ChatMessagePayload():
return $default(_that.id,_that.convId,_that.senderId,_that.msgType,_that.body,_that.attachments,_that.repliedTo,_that.repliedToMessage,_that.sentAt,_that.expiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'sender_id')  String senderId, @JsonKey(name: 'msg_type')@MessageTypeConverter()  MessageType msgType,  String? body,  dynamic attachments, @JsonKey(name: 'replied_to')  String? repliedTo, @JsonKey(name: 'replied_to_message')  Map<String, dynamic>? repliedToMessage, @JsonKey(name: 'sent_at')  DateTime sentAt, @JsonKey(name: 'expires_at')  DateTime? expiresAt)?  $default,) {final _that = this;
switch (_that) {
case _ChatMessagePayload() when $default != null:
return $default(_that.id,_that.convId,_that.senderId,_that.msgType,_that.body,_that.attachments,_that.repliedTo,_that.repliedToMessage,_that.sentAt,_that.expiresAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChatMessagePayload implements ChatMessagePayload {
  const _ChatMessagePayload({required this.id, @JsonKey(name: 'conv_id') required this.convId, @JsonKey(name: 'sender_id') required this.senderId, @JsonKey(name: 'msg_type')@MessageTypeConverter() required this.msgType, this.body, this.attachments, @JsonKey(name: 'replied_to') this.repliedTo, @JsonKey(name: 'replied_to_message') final  Map<String, dynamic>? repliedToMessage, @JsonKey(name: 'sent_at') required this.sentAt, @JsonKey(name: 'expires_at') this.expiresAt}): _repliedToMessage = repliedToMessage;
  factory _ChatMessagePayload.fromJson(Map<String, dynamic> json) => _$ChatMessagePayloadFromJson(json);

@override final  String id;
@override@JsonKey(name: 'conv_id') final  String convId;
@override@JsonKey(name: 'sender_id') final  String senderId;
@override@JsonKey(name: 'msg_type')@MessageTypeConverter() final  MessageType msgType;
@override final  String? body;
@override final  dynamic attachments;
@override@JsonKey(name: 'replied_to') final  String? repliedTo;
// Pre-warmed compact preview of the replied-to message, attached by the
// server so the receiver can render the reply container without a local
// DB lookup falling through to "empty".
 final  Map<String, dynamic>? _repliedToMessage;
// Pre-warmed compact preview of the replied-to message, attached by the
// server so the receiver can render the reply container without a local
// DB lookup falling through to "empty".
@override@JsonKey(name: 'replied_to_message') Map<String, dynamic>? get repliedToMessage {
  final value = _repliedToMessage;
  if (value == null) return null;
  if (_repliedToMessage is EqualUnmodifiableMapView) return _repliedToMessage;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey(name: 'sent_at') final  DateTime sentAt;
// Disappearing-messages deadline (server-stamped on broadcast). Null when
// the chat has the feature off. Persisted onto the local messages row.
@override@JsonKey(name: 'expires_at') final  DateTime? expiresAt;

/// Create a copy of ChatMessagePayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatMessagePayloadCopyWith<_ChatMessagePayload> get copyWith => __$ChatMessagePayloadCopyWithImpl<_ChatMessagePayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatMessagePayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatMessagePayload&&(identical(other.id, id) || other.id == id)&&(identical(other.convId, convId) || other.convId == convId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.msgType, msgType) || other.msgType == msgType)&&(identical(other.body, body) || other.body == body)&&const DeepCollectionEquality().equals(other.attachments, attachments)&&(identical(other.repliedTo, repliedTo) || other.repliedTo == repliedTo)&&const DeepCollectionEquality().equals(other._repliedToMessage, _repliedToMessage)&&(identical(other.sentAt, sentAt) || other.sentAt == sentAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,convId,senderId,msgType,body,const DeepCollectionEquality().hash(attachments),repliedTo,const DeepCollectionEquality().hash(_repliedToMessage),sentAt,expiresAt);

@override
String toString() {
  return 'ChatMessagePayload(id: $id, convId: $convId, senderId: $senderId, msgType: $msgType, body: $body, attachments: $attachments, repliedTo: $repliedTo, repliedToMessage: $repliedToMessage, sentAt: $sentAt, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class _$ChatMessagePayloadCopyWith<$Res> implements $ChatMessagePayloadCopyWith<$Res> {
  factory _$ChatMessagePayloadCopyWith(_ChatMessagePayload value, $Res Function(_ChatMessagePayload) _then) = __$ChatMessagePayloadCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'conv_id') String convId,@JsonKey(name: 'sender_id') String senderId,@JsonKey(name: 'msg_type')@MessageTypeConverter() MessageType msgType, String? body, dynamic attachments,@JsonKey(name: 'replied_to') String? repliedTo,@JsonKey(name: 'replied_to_message') Map<String, dynamic>? repliedToMessage,@JsonKey(name: 'sent_at') DateTime sentAt,@JsonKey(name: 'expires_at') DateTime? expiresAt
});




}
/// @nodoc
class __$ChatMessagePayloadCopyWithImpl<$Res>
    implements _$ChatMessagePayloadCopyWith<$Res> {
  __$ChatMessagePayloadCopyWithImpl(this._self, this._then);

  final _ChatMessagePayload _self;
  final $Res Function(_ChatMessagePayload) _then;

/// Create a copy of ChatMessagePayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? convId = null,Object? senderId = null,Object? msgType = null,Object? body = freezed,Object? attachments = freezed,Object? repliedTo = freezed,Object? repliedToMessage = freezed,Object? sentAt = null,Object? expiresAt = freezed,}) {
  return _then(_ChatMessagePayload(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,convId: null == convId ? _self.convId : convId // ignore: cast_nullable_to_non_nullable
as String,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,msgType: null == msgType ? _self.msgType : msgType // ignore: cast_nullable_to_non_nullable
as MessageType,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,attachments: freezed == attachments ? _self.attachments : attachments // ignore: cast_nullable_to_non_nullable
as dynamic,repliedTo: freezed == repliedTo ? _self.repliedTo : repliedTo // ignore: cast_nullable_to_non_nullable
as String?,repliedToMessage: freezed == repliedToMessage ? _self._repliedToMessage : repliedToMessage // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,sentAt: null == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$MessageSentAckPayload {

@JsonKey(name: 'msg_id') String get msgId;@JsonKey(name: 'conv_id') String get convId;@JsonKey(name: 'is_sent') bool get isSent;@JsonKey(name: 'error_code') int? get errorCode;@JsonKey(name: 'new_id') String? get newId;
/// Create a copy of MessageSentAckPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageSentAckPayloadCopyWith<MessageSentAckPayload> get copyWith => _$MessageSentAckPayloadCopyWithImpl<MessageSentAckPayload>(this as MessageSentAckPayload, _$identity);

  /// Serializes this MessageSentAckPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageSentAckPayload&&(identical(other.msgId, msgId) || other.msgId == msgId)&&(identical(other.convId, convId) || other.convId == convId)&&(identical(other.isSent, isSent) || other.isSent == isSent)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&(identical(other.newId, newId) || other.newId == newId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,msgId,convId,isSent,errorCode,newId);

@override
String toString() {
  return 'MessageSentAckPayload(msgId: $msgId, convId: $convId, isSent: $isSent, errorCode: $errorCode, newId: $newId)';
}


}

/// @nodoc
abstract mixin class $MessageSentAckPayloadCopyWith<$Res>  {
  factory $MessageSentAckPayloadCopyWith(MessageSentAckPayload value, $Res Function(MessageSentAckPayload) _then) = _$MessageSentAckPayloadCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'msg_id') String msgId,@JsonKey(name: 'conv_id') String convId,@JsonKey(name: 'is_sent') bool isSent,@JsonKey(name: 'error_code') int? errorCode,@JsonKey(name: 'new_id') String? newId
});




}
/// @nodoc
class _$MessageSentAckPayloadCopyWithImpl<$Res>
    implements $MessageSentAckPayloadCopyWith<$Res> {
  _$MessageSentAckPayloadCopyWithImpl(this._self, this._then);

  final MessageSentAckPayload _self;
  final $Res Function(MessageSentAckPayload) _then;

/// Create a copy of MessageSentAckPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? msgId = null,Object? convId = null,Object? isSent = null,Object? errorCode = freezed,Object? newId = freezed,}) {
  return _then(_self.copyWith(
msgId: null == msgId ? _self.msgId : msgId // ignore: cast_nullable_to_non_nullable
as String,convId: null == convId ? _self.convId : convId // ignore: cast_nullable_to_non_nullable
as String,isSent: null == isSent ? _self.isSent : isSent // ignore: cast_nullable_to_non_nullable
as bool,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as int?,newId: freezed == newId ? _self.newId : newId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageSentAckPayload].
extension MessageSentAckPayloadPatterns on MessageSentAckPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageSentAckPayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageSentAckPayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageSentAckPayload value)  $default,){
final _that = this;
switch (_that) {
case _MessageSentAckPayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageSentAckPayload value)?  $default,){
final _that = this;
switch (_that) {
case _MessageSentAckPayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'msg_id')  String msgId, @JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'is_sent')  bool isSent, @JsonKey(name: 'error_code')  int? errorCode, @JsonKey(name: 'new_id')  String? newId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageSentAckPayload() when $default != null:
return $default(_that.msgId,_that.convId,_that.isSent,_that.errorCode,_that.newId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'msg_id')  String msgId, @JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'is_sent')  bool isSent, @JsonKey(name: 'error_code')  int? errorCode, @JsonKey(name: 'new_id')  String? newId)  $default,) {final _that = this;
switch (_that) {
case _MessageSentAckPayload():
return $default(_that.msgId,_that.convId,_that.isSent,_that.errorCode,_that.newId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'msg_id')  String msgId, @JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'is_sent')  bool isSent, @JsonKey(name: 'error_code')  int? errorCode, @JsonKey(name: 'new_id')  String? newId)?  $default,) {final _that = this;
switch (_that) {
case _MessageSentAckPayload() when $default != null:
return $default(_that.msgId,_that.convId,_that.isSent,_that.errorCode,_that.newId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageSentAckPayload implements MessageSentAckPayload {
  const _MessageSentAckPayload({@JsonKey(name: 'msg_id') required this.msgId, @JsonKey(name: 'conv_id') required this.convId, @JsonKey(name: 'is_sent') required this.isSent, @JsonKey(name: 'error_code') this.errorCode, @JsonKey(name: 'new_id') this.newId});
  factory _MessageSentAckPayload.fromJson(Map<String, dynamic> json) => _$MessageSentAckPayloadFromJson(json);

@override@JsonKey(name: 'msg_id') final  String msgId;
@override@JsonKey(name: 'conv_id') final  String convId;
@override@JsonKey(name: 'is_sent') final  bool isSent;
@override@JsonKey(name: 'error_code') final  int? errorCode;
@override@JsonKey(name: 'new_id') final  String? newId;

/// Create a copy of MessageSentAckPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageSentAckPayloadCopyWith<_MessageSentAckPayload> get copyWith => __$MessageSentAckPayloadCopyWithImpl<_MessageSentAckPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageSentAckPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageSentAckPayload&&(identical(other.msgId, msgId) || other.msgId == msgId)&&(identical(other.convId, convId) || other.convId == convId)&&(identical(other.isSent, isSent) || other.isSent == isSent)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&(identical(other.newId, newId) || other.newId == newId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,msgId,convId,isSent,errorCode,newId);

@override
String toString() {
  return 'MessageSentAckPayload(msgId: $msgId, convId: $convId, isSent: $isSent, errorCode: $errorCode, newId: $newId)';
}


}

/// @nodoc
abstract mixin class _$MessageSentAckPayloadCopyWith<$Res> implements $MessageSentAckPayloadCopyWith<$Res> {
  factory _$MessageSentAckPayloadCopyWith(_MessageSentAckPayload value, $Res Function(_MessageSentAckPayload) _then) = __$MessageSentAckPayloadCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'msg_id') String msgId,@JsonKey(name: 'conv_id') String convId,@JsonKey(name: 'is_sent') bool isSent,@JsonKey(name: 'error_code') int? errorCode,@JsonKey(name: 'new_id') String? newId
});




}
/// @nodoc
class __$MessageSentAckPayloadCopyWithImpl<$Res>
    implements _$MessageSentAckPayloadCopyWith<$Res> {
  __$MessageSentAckPayloadCopyWithImpl(this._self, this._then);

  final _MessageSentAckPayload _self;
  final $Res Function(_MessageSentAckPayload) _then;

/// Create a copy of MessageSentAckPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? msgId = null,Object? convId = null,Object? isSent = null,Object? errorCode = freezed,Object? newId = freezed,}) {
  return _then(_MessageSentAckPayload(
msgId: null == msgId ? _self.msgId : msgId // ignore: cast_nullable_to_non_nullable
as String,convId: null == convId ? _self.convId : convId // ignore: cast_nullable_to_non_nullable
as String,isSent: null == isSent ? _self.isSent : isSent // ignore: cast_nullable_to_non_nullable
as bool,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as int?,newId: freezed == newId ? _self.newId : newId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$StatusAck {

@JsonKey(name: 'chat_id') String get chatId;@JsonKey(name: 'msg_ids') List<String> get msgIds; List<String> get status;
/// Create a copy of StatusAck
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StatusAckCopyWith<StatusAck> get copyWith => _$StatusAckCopyWithImpl<StatusAck>(this as StatusAck, _$identity);

  /// Serializes this StatusAck to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StatusAck&&(identical(other.chatId, chatId) || other.chatId == chatId)&&const DeepCollectionEquality().equals(other.msgIds, msgIds)&&const DeepCollectionEquality().equals(other.status, status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,chatId,const DeepCollectionEquality().hash(msgIds),const DeepCollectionEquality().hash(status));

@override
String toString() {
  return 'StatusAck(chatId: $chatId, msgIds: $msgIds, status: $status)';
}


}

/// @nodoc
abstract mixin class $StatusAckCopyWith<$Res>  {
  factory $StatusAckCopyWith(StatusAck value, $Res Function(StatusAck) _then) = _$StatusAckCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'chat_id') String chatId,@JsonKey(name: 'msg_ids') List<String> msgIds, List<String> status
});




}
/// @nodoc
class _$StatusAckCopyWithImpl<$Res>
    implements $StatusAckCopyWith<$Res> {
  _$StatusAckCopyWithImpl(this._self, this._then);

  final StatusAck _self;
  final $Res Function(StatusAck) _then;

/// Create a copy of StatusAck
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chatId = null,Object? msgIds = null,Object? status = null,}) {
  return _then(_self.copyWith(
chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,msgIds: null == msgIds ? _self.msgIds : msgIds // ignore: cast_nullable_to_non_nullable
as List<String>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [StatusAck].
extension StatusAckPatterns on StatusAck {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StatusAck value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StatusAck() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StatusAck value)  $default,){
final _that = this;
switch (_that) {
case _StatusAck():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StatusAck value)?  $default,){
final _that = this;
switch (_that) {
case _StatusAck() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'chat_id')  String chatId, @JsonKey(name: 'msg_ids')  List<String> msgIds,  List<String> status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StatusAck() when $default != null:
return $default(_that.chatId,_that.msgIds,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'chat_id')  String chatId, @JsonKey(name: 'msg_ids')  List<String> msgIds,  List<String> status)  $default,) {final _that = this;
switch (_that) {
case _StatusAck():
return $default(_that.chatId,_that.msgIds,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'chat_id')  String chatId, @JsonKey(name: 'msg_ids')  List<String> msgIds,  List<String> status)?  $default,) {final _that = this;
switch (_that) {
case _StatusAck() when $default != null:
return $default(_that.chatId,_that.msgIds,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StatusAck implements StatusAck {
  const _StatusAck({@JsonKey(name: 'chat_id') required this.chatId, @JsonKey(name: 'msg_ids') required final  List<String> msgIds, required final  List<String> status}): _msgIds = msgIds,_status = status;
  factory _StatusAck.fromJson(Map<String, dynamic> json) => _$StatusAckFromJson(json);

@override@JsonKey(name: 'chat_id') final  String chatId;
 final  List<String> _msgIds;
@override@JsonKey(name: 'msg_ids') List<String> get msgIds {
  if (_msgIds is EqualUnmodifiableListView) return _msgIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_msgIds);
}

 final  List<String> _status;
@override List<String> get status {
  if (_status is EqualUnmodifiableListView) return _status;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_status);
}


/// Create a copy of StatusAck
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StatusAckCopyWith<_StatusAck> get copyWith => __$StatusAckCopyWithImpl<_StatusAck>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StatusAckToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StatusAck&&(identical(other.chatId, chatId) || other.chatId == chatId)&&const DeepCollectionEquality().equals(other._msgIds, _msgIds)&&const DeepCollectionEquality().equals(other._status, _status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,chatId,const DeepCollectionEquality().hash(_msgIds),const DeepCollectionEquality().hash(_status));

@override
String toString() {
  return 'StatusAck(chatId: $chatId, msgIds: $msgIds, status: $status)';
}


}

/// @nodoc
abstract mixin class _$StatusAckCopyWith<$Res> implements $StatusAckCopyWith<$Res> {
  factory _$StatusAckCopyWith(_StatusAck value, $Res Function(_StatusAck) _then) = __$StatusAckCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'chat_id') String chatId,@JsonKey(name: 'msg_ids') List<String> msgIds, List<String> status
});




}
/// @nodoc
class __$StatusAckCopyWithImpl<$Res>
    implements _$StatusAckCopyWith<$Res> {
  __$StatusAckCopyWithImpl(this._self, this._then);

  final _StatusAck _self;
  final $Res Function(_StatusAck) _then;

/// Create a copy of StatusAck
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chatId = null,Object? msgIds = null,Object? status = null,}) {
  return _then(_StatusAck(
chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,msgIds: null == msgIds ? _self._msgIds : msgIds // ignore: cast_nullable_to_non_nullable
as List<String>,status: null == status ? _self._status : status // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$MessageStatusAckPayload {

@JsonKey(name: 'recipient_id') String get recipientId; DateTime get at; List<StatusAck> get acks;
/// Create a copy of MessageStatusAckPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageStatusAckPayloadCopyWith<MessageStatusAckPayload> get copyWith => _$MessageStatusAckPayloadCopyWithImpl<MessageStatusAckPayload>(this as MessageStatusAckPayload, _$identity);

  /// Serializes this MessageStatusAckPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageStatusAckPayload&&(identical(other.recipientId, recipientId) || other.recipientId == recipientId)&&(identical(other.at, at) || other.at == at)&&const DeepCollectionEquality().equals(other.acks, acks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,recipientId,at,const DeepCollectionEquality().hash(acks));

@override
String toString() {
  return 'MessageStatusAckPayload(recipientId: $recipientId, at: $at, acks: $acks)';
}


}

/// @nodoc
abstract mixin class $MessageStatusAckPayloadCopyWith<$Res>  {
  factory $MessageStatusAckPayloadCopyWith(MessageStatusAckPayload value, $Res Function(MessageStatusAckPayload) _then) = _$MessageStatusAckPayloadCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'recipient_id') String recipientId, DateTime at, List<StatusAck> acks
});




}
/// @nodoc
class _$MessageStatusAckPayloadCopyWithImpl<$Res>
    implements $MessageStatusAckPayloadCopyWith<$Res> {
  _$MessageStatusAckPayloadCopyWithImpl(this._self, this._then);

  final MessageStatusAckPayload _self;
  final $Res Function(MessageStatusAckPayload) _then;

/// Create a copy of MessageStatusAckPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? recipientId = null,Object? at = null,Object? acks = null,}) {
  return _then(_self.copyWith(
recipientId: null == recipientId ? _self.recipientId : recipientId // ignore: cast_nullable_to_non_nullable
as String,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,acks: null == acks ? _self.acks : acks // ignore: cast_nullable_to_non_nullable
as List<StatusAck>,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageStatusAckPayload].
extension MessageStatusAckPayloadPatterns on MessageStatusAckPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageStatusAckPayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageStatusAckPayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageStatusAckPayload value)  $default,){
final _that = this;
switch (_that) {
case _MessageStatusAckPayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageStatusAckPayload value)?  $default,){
final _that = this;
switch (_that) {
case _MessageStatusAckPayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'recipient_id')  String recipientId,  DateTime at,  List<StatusAck> acks)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageStatusAckPayload() when $default != null:
return $default(_that.recipientId,_that.at,_that.acks);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'recipient_id')  String recipientId,  DateTime at,  List<StatusAck> acks)  $default,) {final _that = this;
switch (_that) {
case _MessageStatusAckPayload():
return $default(_that.recipientId,_that.at,_that.acks);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'recipient_id')  String recipientId,  DateTime at,  List<StatusAck> acks)?  $default,) {final _that = this;
switch (_that) {
case _MessageStatusAckPayload() when $default != null:
return $default(_that.recipientId,_that.at,_that.acks);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageStatusAckPayload implements MessageStatusAckPayload {
  const _MessageStatusAckPayload({@JsonKey(name: 'recipient_id') required this.recipientId, required this.at, required final  List<StatusAck> acks}): _acks = acks;
  factory _MessageStatusAckPayload.fromJson(Map<String, dynamic> json) => _$MessageStatusAckPayloadFromJson(json);

@override@JsonKey(name: 'recipient_id') final  String recipientId;
@override final  DateTime at;
 final  List<StatusAck> _acks;
@override List<StatusAck> get acks {
  if (_acks is EqualUnmodifiableListView) return _acks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_acks);
}


/// Create a copy of MessageStatusAckPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageStatusAckPayloadCopyWith<_MessageStatusAckPayload> get copyWith => __$MessageStatusAckPayloadCopyWithImpl<_MessageStatusAckPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageStatusAckPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageStatusAckPayload&&(identical(other.recipientId, recipientId) || other.recipientId == recipientId)&&(identical(other.at, at) || other.at == at)&&const DeepCollectionEquality().equals(other._acks, _acks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,recipientId,at,const DeepCollectionEquality().hash(_acks));

@override
String toString() {
  return 'MessageStatusAckPayload(recipientId: $recipientId, at: $at, acks: $acks)';
}


}

/// @nodoc
abstract mixin class _$MessageStatusAckPayloadCopyWith<$Res> implements $MessageStatusAckPayloadCopyWith<$Res> {
  factory _$MessageStatusAckPayloadCopyWith(_MessageStatusAckPayload value, $Res Function(_MessageStatusAckPayload) _then) = __$MessageStatusAckPayloadCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'recipient_id') String recipientId, DateTime at, List<StatusAck> acks
});




}
/// @nodoc
class __$MessageStatusAckPayloadCopyWithImpl<$Res>
    implements _$MessageStatusAckPayloadCopyWith<$Res> {
  __$MessageStatusAckPayloadCopyWithImpl(this._self, this._then);

  final _MessageStatusAckPayload _self;
  final $Res Function(_MessageStatusAckPayload) _then;

/// Create a copy of MessageStatusAckPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? recipientId = null,Object? at = null,Object? acks = null,}) {
  return _then(_MessageStatusAckPayload(
recipientId: null == recipientId ? _self.recipientId : recipientId // ignore: cast_nullable_to_non_nullable
as String,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,acks: null == acks ? _self._acks : acks // ignore: cast_nullable_to_non_nullable
as List<StatusAck>,
  ));
}


}


/// @nodoc
mixin _$TypingPayload {

@JsonKey(name: 'conv_id') String get convId;@JsonKey(name: 'sender_id') String get senderId;
/// Create a copy of TypingPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TypingPayloadCopyWith<TypingPayload> get copyWith => _$TypingPayloadCopyWithImpl<TypingPayload>(this as TypingPayload, _$identity);

  /// Serializes this TypingPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TypingPayload&&(identical(other.convId, convId) || other.convId == convId)&&(identical(other.senderId, senderId) || other.senderId == senderId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,convId,senderId);

@override
String toString() {
  return 'TypingPayload(convId: $convId, senderId: $senderId)';
}


}

/// @nodoc
abstract mixin class $TypingPayloadCopyWith<$Res>  {
  factory $TypingPayloadCopyWith(TypingPayload value, $Res Function(TypingPayload) _then) = _$TypingPayloadCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'conv_id') String convId,@JsonKey(name: 'sender_id') String senderId
});




}
/// @nodoc
class _$TypingPayloadCopyWithImpl<$Res>
    implements $TypingPayloadCopyWith<$Res> {
  _$TypingPayloadCopyWithImpl(this._self, this._then);

  final TypingPayload _self;
  final $Res Function(TypingPayload) _then;

/// Create a copy of TypingPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? convId = null,Object? senderId = null,}) {
  return _then(_self.copyWith(
convId: null == convId ? _self.convId : convId // ignore: cast_nullable_to_non_nullable
as String,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TypingPayload].
extension TypingPayloadPatterns on TypingPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TypingPayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TypingPayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TypingPayload value)  $default,){
final _that = this;
switch (_that) {
case _TypingPayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TypingPayload value)?  $default,){
final _that = this;
switch (_that) {
case _TypingPayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'sender_id')  String senderId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TypingPayload() when $default != null:
return $default(_that.convId,_that.senderId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'sender_id')  String senderId)  $default,) {final _that = this;
switch (_that) {
case _TypingPayload():
return $default(_that.convId,_that.senderId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'sender_id')  String senderId)?  $default,) {final _that = this;
switch (_that) {
case _TypingPayload() when $default != null:
return $default(_that.convId,_that.senderId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TypingPayload implements TypingPayload {
  const _TypingPayload({@JsonKey(name: 'conv_id') required this.convId, @JsonKey(name: 'sender_id') required this.senderId});
  factory _TypingPayload.fromJson(Map<String, dynamic> json) => _$TypingPayloadFromJson(json);

@override@JsonKey(name: 'conv_id') final  String convId;
@override@JsonKey(name: 'sender_id') final  String senderId;

/// Create a copy of TypingPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TypingPayloadCopyWith<_TypingPayload> get copyWith => __$TypingPayloadCopyWithImpl<_TypingPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TypingPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TypingPayload&&(identical(other.convId, convId) || other.convId == convId)&&(identical(other.senderId, senderId) || other.senderId == senderId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,convId,senderId);

@override
String toString() {
  return 'TypingPayload(convId: $convId, senderId: $senderId)';
}


}

/// @nodoc
abstract mixin class _$TypingPayloadCopyWith<$Res> implements $TypingPayloadCopyWith<$Res> {
  factory _$TypingPayloadCopyWith(_TypingPayload value, $Res Function(_TypingPayload) _then) = __$TypingPayloadCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'conv_id') String convId,@JsonKey(name: 'sender_id') String senderId
});




}
/// @nodoc
class __$TypingPayloadCopyWithImpl<$Res>
    implements _$TypingPayloadCopyWith<$Res> {
  __$TypingPayloadCopyWithImpl(this._self, this._then);

  final _TypingPayload _self;
  final $Res Function(_TypingPayload) _then;

/// Create a copy of TypingPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? convId = null,Object? senderId = null,}) {
  return _then(_TypingPayload(
convId: null == convId ? _self.convId : convId // ignore: cast_nullable_to_non_nullable
as String,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$DeleteMessagePayload {

@JsonKey(name: 'conv_id') String get convId;@JsonKey(name: 'sender_id') String get senderId;@JsonKey(name: 'message_ids') List<String> get messageIds;
/// Create a copy of DeleteMessagePayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeleteMessagePayloadCopyWith<DeleteMessagePayload> get copyWith => _$DeleteMessagePayloadCopyWithImpl<DeleteMessagePayload>(this as DeleteMessagePayload, _$identity);

  /// Serializes this DeleteMessagePayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeleteMessagePayload&&(identical(other.convId, convId) || other.convId == convId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&const DeepCollectionEquality().equals(other.messageIds, messageIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,convId,senderId,const DeepCollectionEquality().hash(messageIds));

@override
String toString() {
  return 'DeleteMessagePayload(convId: $convId, senderId: $senderId, messageIds: $messageIds)';
}


}

/// @nodoc
abstract mixin class $DeleteMessagePayloadCopyWith<$Res>  {
  factory $DeleteMessagePayloadCopyWith(DeleteMessagePayload value, $Res Function(DeleteMessagePayload) _then) = _$DeleteMessagePayloadCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'conv_id') String convId,@JsonKey(name: 'sender_id') String senderId,@JsonKey(name: 'message_ids') List<String> messageIds
});




}
/// @nodoc
class _$DeleteMessagePayloadCopyWithImpl<$Res>
    implements $DeleteMessagePayloadCopyWith<$Res> {
  _$DeleteMessagePayloadCopyWithImpl(this._self, this._then);

  final DeleteMessagePayload _self;
  final $Res Function(DeleteMessagePayload) _then;

/// Create a copy of DeleteMessagePayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? convId = null,Object? senderId = null,Object? messageIds = null,}) {
  return _then(_self.copyWith(
convId: null == convId ? _self.convId : convId // ignore: cast_nullable_to_non_nullable
as String,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,messageIds: null == messageIds ? _self.messageIds : messageIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [DeleteMessagePayload].
extension DeleteMessagePayloadPatterns on DeleteMessagePayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeleteMessagePayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeleteMessagePayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeleteMessagePayload value)  $default,){
final _that = this;
switch (_that) {
case _DeleteMessagePayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeleteMessagePayload value)?  $default,){
final _that = this;
switch (_that) {
case _DeleteMessagePayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'sender_id')  String senderId, @JsonKey(name: 'message_ids')  List<String> messageIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeleteMessagePayload() when $default != null:
return $default(_that.convId,_that.senderId,_that.messageIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'sender_id')  String senderId, @JsonKey(name: 'message_ids')  List<String> messageIds)  $default,) {final _that = this;
switch (_that) {
case _DeleteMessagePayload():
return $default(_that.convId,_that.senderId,_that.messageIds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'sender_id')  String senderId, @JsonKey(name: 'message_ids')  List<String> messageIds)?  $default,) {final _that = this;
switch (_that) {
case _DeleteMessagePayload() when $default != null:
return $default(_that.convId,_that.senderId,_that.messageIds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeleteMessagePayload implements DeleteMessagePayload {
  const _DeleteMessagePayload({@JsonKey(name: 'conv_id') required this.convId, @JsonKey(name: 'sender_id') required this.senderId, @JsonKey(name: 'message_ids') required final  List<String> messageIds}): _messageIds = messageIds;
  factory _DeleteMessagePayload.fromJson(Map<String, dynamic> json) => _$DeleteMessagePayloadFromJson(json);

@override@JsonKey(name: 'conv_id') final  String convId;
@override@JsonKey(name: 'sender_id') final  String senderId;
 final  List<String> _messageIds;
@override@JsonKey(name: 'message_ids') List<String> get messageIds {
  if (_messageIds is EqualUnmodifiableListView) return _messageIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messageIds);
}


/// Create a copy of DeleteMessagePayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeleteMessagePayloadCopyWith<_DeleteMessagePayload> get copyWith => __$DeleteMessagePayloadCopyWithImpl<_DeleteMessagePayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeleteMessagePayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeleteMessagePayload&&(identical(other.convId, convId) || other.convId == convId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&const DeepCollectionEquality().equals(other._messageIds, _messageIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,convId,senderId,const DeepCollectionEquality().hash(_messageIds));

@override
String toString() {
  return 'DeleteMessagePayload(convId: $convId, senderId: $senderId, messageIds: $messageIds)';
}


}

/// @nodoc
abstract mixin class _$DeleteMessagePayloadCopyWith<$Res> implements $DeleteMessagePayloadCopyWith<$Res> {
  factory _$DeleteMessagePayloadCopyWith(_DeleteMessagePayload value, $Res Function(_DeleteMessagePayload) _then) = __$DeleteMessagePayloadCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'conv_id') String convId,@JsonKey(name: 'sender_id') String senderId,@JsonKey(name: 'message_ids') List<String> messageIds
});




}
/// @nodoc
class __$DeleteMessagePayloadCopyWithImpl<$Res>
    implements _$DeleteMessagePayloadCopyWith<$Res> {
  __$DeleteMessagePayloadCopyWithImpl(this._self, this._then);

  final _DeleteMessagePayload _self;
  final $Res Function(_DeleteMessagePayload) _then;

/// Create a copy of DeleteMessagePayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? convId = null,Object? senderId = null,Object? messageIds = null,}) {
  return _then(_DeleteMessagePayload(
convId: null == convId ? _self.convId : convId // ignore: cast_nullable_to_non_nullable
as String,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,messageIds: null == messageIds ? _self._messageIds : messageIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$MembersType {

@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'user_name') String get userName;@JsonKey(name: 'user_pfp') String? get userPfp;@ChatRoleTypeConverter() ChatRoleType get role;@JsonKey(name: 'joined_at') DateTime get joinedAt;
/// Create a copy of MembersType
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MembersTypeCopyWith<MembersType> get copyWith => _$MembersTypeCopyWithImpl<MembersType>(this as MembersType, _$identity);

  /// Serializes this MembersType to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MembersType&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.userPfp, userPfp) || other.userPfp == userPfp)&&(identical(other.role, role) || other.role == role)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,userName,userPfp,role,joinedAt);

@override
String toString() {
  return 'MembersType(userId: $userId, userName: $userName, userPfp: $userPfp, role: $role, joinedAt: $joinedAt)';
}


}

/// @nodoc
abstract mixin class $MembersTypeCopyWith<$Res>  {
  factory $MembersTypeCopyWith(MembersType value, $Res Function(MembersType) _then) = _$MembersTypeCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'user_name') String userName,@JsonKey(name: 'user_pfp') String? userPfp,@ChatRoleTypeConverter() ChatRoleType role,@JsonKey(name: 'joined_at') DateTime joinedAt
});




}
/// @nodoc
class _$MembersTypeCopyWithImpl<$Res>
    implements $MembersTypeCopyWith<$Res> {
  _$MembersTypeCopyWithImpl(this._self, this._then);

  final MembersType _self;
  final $Res Function(MembersType) _then;

/// Create a copy of MembersType
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? userName = null,Object? userPfp = freezed,Object? role = null,Object? joinedAt = null,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,userName: null == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String,userPfp: freezed == userPfp ? _self.userPfp : userPfp // ignore: cast_nullable_to_non_nullable
as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as ChatRoleType,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [MembersType].
extension MembersTypePatterns on MembersType {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MembersType value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MembersType() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MembersType value)  $default,){
final _that = this;
switch (_that) {
case _MembersType():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MembersType value)?  $default,){
final _that = this;
switch (_that) {
case _MembersType() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'user_name')  String userName, @JsonKey(name: 'user_pfp')  String? userPfp, @ChatRoleTypeConverter()  ChatRoleType role, @JsonKey(name: 'joined_at')  DateTime joinedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MembersType() when $default != null:
return $default(_that.userId,_that.userName,_that.userPfp,_that.role,_that.joinedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'user_name')  String userName, @JsonKey(name: 'user_pfp')  String? userPfp, @ChatRoleTypeConverter()  ChatRoleType role, @JsonKey(name: 'joined_at')  DateTime joinedAt)  $default,) {final _that = this;
switch (_that) {
case _MembersType():
return $default(_that.userId,_that.userName,_that.userPfp,_that.role,_that.joinedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'user_name')  String userName, @JsonKey(name: 'user_pfp')  String? userPfp, @ChatRoleTypeConverter()  ChatRoleType role, @JsonKey(name: 'joined_at')  DateTime joinedAt)?  $default,) {final _that = this;
switch (_that) {
case _MembersType() when $default != null:
return $default(_that.userId,_that.userName,_that.userPfp,_that.role,_that.joinedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MembersType implements MembersType {
  const _MembersType({@JsonKey(name: 'user_id') required this.userId, @JsonKey(name: 'user_name') required this.userName, @JsonKey(name: 'user_pfp') this.userPfp, @ChatRoleTypeConverter() required this.role, @JsonKey(name: 'joined_at') required this.joinedAt});
  factory _MembersType.fromJson(Map<String, dynamic> json) => _$MembersTypeFromJson(json);

@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'user_name') final  String userName;
@override@JsonKey(name: 'user_pfp') final  String? userPfp;
@override@ChatRoleTypeConverter() final  ChatRoleType role;
@override@JsonKey(name: 'joined_at') final  DateTime joinedAt;

/// Create a copy of MembersType
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MembersTypeCopyWith<_MembersType> get copyWith => __$MembersTypeCopyWithImpl<_MembersType>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MembersTypeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MembersType&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.userPfp, userPfp) || other.userPfp == userPfp)&&(identical(other.role, role) || other.role == role)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,userName,userPfp,role,joinedAt);

@override
String toString() {
  return 'MembersType(userId: $userId, userName: $userName, userPfp: $userPfp, role: $role, joinedAt: $joinedAt)';
}


}

/// @nodoc
abstract mixin class _$MembersTypeCopyWith<$Res> implements $MembersTypeCopyWith<$Res> {
  factory _$MembersTypeCopyWith(_MembersType value, $Res Function(_MembersType) _then) = __$MembersTypeCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'user_name') String userName,@JsonKey(name: 'user_pfp') String? userPfp,@ChatRoleTypeConverter() ChatRoleType role,@JsonKey(name: 'joined_at') DateTime joinedAt
});




}
/// @nodoc
class __$MembersTypeCopyWithImpl<$Res>
    implements _$MembersTypeCopyWith<$Res> {
  __$MembersTypeCopyWithImpl(this._self, this._then);

  final _MembersType _self;
  final $Res Function(_MembersType) _then;

/// Create a copy of MembersType
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? userName = null,Object? userPfp = freezed,Object? role = null,Object? joinedAt = null,}) {
  return _then(_MembersType(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,userName: null == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String,userPfp: freezed == userPfp ? _self.userPfp : userPfp // ignore: cast_nullable_to_non_nullable
as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as ChatRoleType,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$NewConversationPayload {

@JsonKey(name: 'conv_id') String get convId;@JsonKey(name: 'conv_type')@ChatTypeConverter() ChatType get convType; String? get title;@JsonKey(name: 'creater_id') String get createrId;@JsonKey(name: 'creater_name') String get createrName;@JsonKey(name: 'creater_phone') String get createrPhone;@JsonKey(name: 'creater_pfp') String? get createrPfp; List<MembersType>? get members;@JsonKey(name: 'joined_at') DateTime get joinedAt;
/// Create a copy of NewConversationPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewConversationPayloadCopyWith<NewConversationPayload> get copyWith => _$NewConversationPayloadCopyWithImpl<NewConversationPayload>(this as NewConversationPayload, _$identity);

  /// Serializes this NewConversationPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewConversationPayload&&(identical(other.convId, convId) || other.convId == convId)&&(identical(other.convType, convType) || other.convType == convType)&&(identical(other.title, title) || other.title == title)&&(identical(other.createrId, createrId) || other.createrId == createrId)&&(identical(other.createrName, createrName) || other.createrName == createrName)&&(identical(other.createrPhone, createrPhone) || other.createrPhone == createrPhone)&&(identical(other.createrPfp, createrPfp) || other.createrPfp == createrPfp)&&const DeepCollectionEquality().equals(other.members, members)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,convId,convType,title,createrId,createrName,createrPhone,createrPfp,const DeepCollectionEquality().hash(members),joinedAt);

@override
String toString() {
  return 'NewConversationPayload(convId: $convId, convType: $convType, title: $title, createrId: $createrId, createrName: $createrName, createrPhone: $createrPhone, createrPfp: $createrPfp, members: $members, joinedAt: $joinedAt)';
}


}

/// @nodoc
abstract mixin class $NewConversationPayloadCopyWith<$Res>  {
  factory $NewConversationPayloadCopyWith(NewConversationPayload value, $Res Function(NewConversationPayload) _then) = _$NewConversationPayloadCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'conv_id') String convId,@JsonKey(name: 'conv_type')@ChatTypeConverter() ChatType convType, String? title,@JsonKey(name: 'creater_id') String createrId,@JsonKey(name: 'creater_name') String createrName,@JsonKey(name: 'creater_phone') String createrPhone,@JsonKey(name: 'creater_pfp') String? createrPfp, List<MembersType>? members,@JsonKey(name: 'joined_at') DateTime joinedAt
});




}
/// @nodoc
class _$NewConversationPayloadCopyWithImpl<$Res>
    implements $NewConversationPayloadCopyWith<$Res> {
  _$NewConversationPayloadCopyWithImpl(this._self, this._then);

  final NewConversationPayload _self;
  final $Res Function(NewConversationPayload) _then;

/// Create a copy of NewConversationPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? convId = null,Object? convType = null,Object? title = freezed,Object? createrId = null,Object? createrName = null,Object? createrPhone = null,Object? createrPfp = freezed,Object? members = freezed,Object? joinedAt = null,}) {
  return _then(_self.copyWith(
convId: null == convId ? _self.convId : convId // ignore: cast_nullable_to_non_nullable
as String,convType: null == convType ? _self.convType : convType // ignore: cast_nullable_to_non_nullable
as ChatType,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,createrId: null == createrId ? _self.createrId : createrId // ignore: cast_nullable_to_non_nullable
as String,createrName: null == createrName ? _self.createrName : createrName // ignore: cast_nullable_to_non_nullable
as String,createrPhone: null == createrPhone ? _self.createrPhone : createrPhone // ignore: cast_nullable_to_non_nullable
as String,createrPfp: freezed == createrPfp ? _self.createrPfp : createrPfp // ignore: cast_nullable_to_non_nullable
as String?,members: freezed == members ? _self.members : members // ignore: cast_nullable_to_non_nullable
as List<MembersType>?,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [NewConversationPayload].
extension NewConversationPayloadPatterns on NewConversationPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NewConversationPayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NewConversationPayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NewConversationPayload value)  $default,){
final _that = this;
switch (_that) {
case _NewConversationPayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NewConversationPayload value)?  $default,){
final _that = this;
switch (_that) {
case _NewConversationPayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'conv_type')@ChatTypeConverter()  ChatType convType,  String? title, @JsonKey(name: 'creater_id')  String createrId, @JsonKey(name: 'creater_name')  String createrName, @JsonKey(name: 'creater_phone')  String createrPhone, @JsonKey(name: 'creater_pfp')  String? createrPfp,  List<MembersType>? members, @JsonKey(name: 'joined_at')  DateTime joinedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NewConversationPayload() when $default != null:
return $default(_that.convId,_that.convType,_that.title,_that.createrId,_that.createrName,_that.createrPhone,_that.createrPfp,_that.members,_that.joinedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'conv_type')@ChatTypeConverter()  ChatType convType,  String? title, @JsonKey(name: 'creater_id')  String createrId, @JsonKey(name: 'creater_name')  String createrName, @JsonKey(name: 'creater_phone')  String createrPhone, @JsonKey(name: 'creater_pfp')  String? createrPfp,  List<MembersType>? members, @JsonKey(name: 'joined_at')  DateTime joinedAt)  $default,) {final _that = this;
switch (_that) {
case _NewConversationPayload():
return $default(_that.convId,_that.convType,_that.title,_that.createrId,_that.createrName,_that.createrPhone,_that.createrPfp,_that.members,_that.joinedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'conv_type')@ChatTypeConverter()  ChatType convType,  String? title, @JsonKey(name: 'creater_id')  String createrId, @JsonKey(name: 'creater_name')  String createrName, @JsonKey(name: 'creater_phone')  String createrPhone, @JsonKey(name: 'creater_pfp')  String? createrPfp,  List<MembersType>? members, @JsonKey(name: 'joined_at')  DateTime joinedAt)?  $default,) {final _that = this;
switch (_that) {
case _NewConversationPayload() when $default != null:
return $default(_that.convId,_that.convType,_that.title,_that.createrId,_that.createrName,_that.createrPhone,_that.createrPfp,_that.members,_that.joinedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NewConversationPayload implements NewConversationPayload {
  const _NewConversationPayload({@JsonKey(name: 'conv_id') required this.convId, @JsonKey(name: 'conv_type')@ChatTypeConverter() required this.convType, this.title, @JsonKey(name: 'creater_id') required this.createrId, @JsonKey(name: 'creater_name') required this.createrName, @JsonKey(name: 'creater_phone') required this.createrPhone, @JsonKey(name: 'creater_pfp') this.createrPfp, final  List<MembersType>? members, @JsonKey(name: 'joined_at') required this.joinedAt}): _members = members;
  factory _NewConversationPayload.fromJson(Map<String, dynamic> json) => _$NewConversationPayloadFromJson(json);

@override@JsonKey(name: 'conv_id') final  String convId;
@override@JsonKey(name: 'conv_type')@ChatTypeConverter() final  ChatType convType;
@override final  String? title;
@override@JsonKey(name: 'creater_id') final  String createrId;
@override@JsonKey(name: 'creater_name') final  String createrName;
@override@JsonKey(name: 'creater_phone') final  String createrPhone;
@override@JsonKey(name: 'creater_pfp') final  String? createrPfp;
 final  List<MembersType>? _members;
@override List<MembersType>? get members {
  final value = _members;
  if (value == null) return null;
  if (_members is EqualUnmodifiableListView) return _members;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey(name: 'joined_at') final  DateTime joinedAt;

/// Create a copy of NewConversationPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NewConversationPayloadCopyWith<_NewConversationPayload> get copyWith => __$NewConversationPayloadCopyWithImpl<_NewConversationPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NewConversationPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NewConversationPayload&&(identical(other.convId, convId) || other.convId == convId)&&(identical(other.convType, convType) || other.convType == convType)&&(identical(other.title, title) || other.title == title)&&(identical(other.createrId, createrId) || other.createrId == createrId)&&(identical(other.createrName, createrName) || other.createrName == createrName)&&(identical(other.createrPhone, createrPhone) || other.createrPhone == createrPhone)&&(identical(other.createrPfp, createrPfp) || other.createrPfp == createrPfp)&&const DeepCollectionEquality().equals(other._members, _members)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,convId,convType,title,createrId,createrName,createrPhone,createrPfp,const DeepCollectionEquality().hash(_members),joinedAt);

@override
String toString() {
  return 'NewConversationPayload(convId: $convId, convType: $convType, title: $title, createrId: $createrId, createrName: $createrName, createrPhone: $createrPhone, createrPfp: $createrPfp, members: $members, joinedAt: $joinedAt)';
}


}

/// @nodoc
abstract mixin class _$NewConversationPayloadCopyWith<$Res> implements $NewConversationPayloadCopyWith<$Res> {
  factory _$NewConversationPayloadCopyWith(_NewConversationPayload value, $Res Function(_NewConversationPayload) _then) = __$NewConversationPayloadCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'conv_id') String convId,@JsonKey(name: 'conv_type')@ChatTypeConverter() ChatType convType, String? title,@JsonKey(name: 'creater_id') String createrId,@JsonKey(name: 'creater_name') String createrName,@JsonKey(name: 'creater_phone') String createrPhone,@JsonKey(name: 'creater_pfp') String? createrPfp, List<MembersType>? members,@JsonKey(name: 'joined_at') DateTime joinedAt
});




}
/// @nodoc
class __$NewConversationPayloadCopyWithImpl<$Res>
    implements _$NewConversationPayloadCopyWith<$Res> {
  __$NewConversationPayloadCopyWithImpl(this._self, this._then);

  final _NewConversationPayload _self;
  final $Res Function(_NewConversationPayload) _then;

/// Create a copy of NewConversationPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? convId = null,Object? convType = null,Object? title = freezed,Object? createrId = null,Object? createrName = null,Object? createrPhone = null,Object? createrPfp = freezed,Object? members = freezed,Object? joinedAt = null,}) {
  return _then(_NewConversationPayload(
convId: null == convId ? _self.convId : convId // ignore: cast_nullable_to_non_nullable
as String,convType: null == convType ? _self.convType : convType // ignore: cast_nullable_to_non_nullable
as ChatType,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,createrId: null == createrId ? _self.createrId : createrId // ignore: cast_nullable_to_non_nullable
as String,createrName: null == createrName ? _self.createrName : createrName // ignore: cast_nullable_to_non_nullable
as String,createrPhone: null == createrPhone ? _self.createrPhone : createrPhone // ignore: cast_nullable_to_non_nullable
as String,createrPfp: freezed == createrPfp ? _self.createrPfp : createrPfp // ignore: cast_nullable_to_non_nullable
as String?,members: freezed == members ? _self._members : members // ignore: cast_nullable_to_non_nullable
as List<MembersType>?,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$ConversationActionPayload {

@JsonKey(name: 'event_id') String get eventId;@JsonKey(name: 'conv_id') String get convId;@JsonKey(name: 'conv_type')@ChatTypeConverter() ChatType get convType;@ConversationActionTypeConverter() ConversationActionType get action; List<MembersType> get members;@JsonKey(name: 'actor_id') String? get actorId; String get message;@JsonKey(name: 'action_at') DateTime get actionAt;// chat_details:update fields. Only set when at least one of title /
// profilePic changed. profilePic == null with profilePicChanged = true
// means the admin cleared the avatar.
 String? get title;@JsonKey(name: 'profile_pic') String? get profilePic;// Previous profile pic URL — used as the key to evict the old image
// from the on-disk CachedNetworkImage cache when the pfp changes.
@JsonKey(name: 'previous_profile_pic') String? get previousProfilePic;// Explicit "pfp column was touched in this update" flag. Needed because
// profilePic == null can mean either "cleared" or "absent from payload",
// and the on-the-wire JSON collapses those two cases.
@JsonKey(name: 'profile_pic_changed') bool get profilePicChanged;
/// Create a copy of ConversationActionPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationActionPayloadCopyWith<ConversationActionPayload> get copyWith => _$ConversationActionPayloadCopyWithImpl<ConversationActionPayload>(this as ConversationActionPayload, _$identity);

  /// Serializes this ConversationActionPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationActionPayload&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.convId, convId) || other.convId == convId)&&(identical(other.convType, convType) || other.convType == convType)&&(identical(other.action, action) || other.action == action)&&const DeepCollectionEquality().equals(other.members, members)&&(identical(other.actorId, actorId) || other.actorId == actorId)&&(identical(other.message, message) || other.message == message)&&(identical(other.actionAt, actionAt) || other.actionAt == actionAt)&&(identical(other.title, title) || other.title == title)&&(identical(other.profilePic, profilePic) || other.profilePic == profilePic)&&(identical(other.previousProfilePic, previousProfilePic) || other.previousProfilePic == previousProfilePic)&&(identical(other.profilePicChanged, profilePicChanged) || other.profilePicChanged == profilePicChanged));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,eventId,convId,convType,action,const DeepCollectionEquality().hash(members),actorId,message,actionAt,title,profilePic,previousProfilePic,profilePicChanged);

@override
String toString() {
  return 'ConversationActionPayload(eventId: $eventId, convId: $convId, convType: $convType, action: $action, members: $members, actorId: $actorId, message: $message, actionAt: $actionAt, title: $title, profilePic: $profilePic, previousProfilePic: $previousProfilePic, profilePicChanged: $profilePicChanged)';
}


}

/// @nodoc
abstract mixin class $ConversationActionPayloadCopyWith<$Res>  {
  factory $ConversationActionPayloadCopyWith(ConversationActionPayload value, $Res Function(ConversationActionPayload) _then) = _$ConversationActionPayloadCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'event_id') String eventId,@JsonKey(name: 'conv_id') String convId,@JsonKey(name: 'conv_type')@ChatTypeConverter() ChatType convType,@ConversationActionTypeConverter() ConversationActionType action, List<MembersType> members,@JsonKey(name: 'actor_id') String? actorId, String message,@JsonKey(name: 'action_at') DateTime actionAt, String? title,@JsonKey(name: 'profile_pic') String? profilePic,@JsonKey(name: 'previous_profile_pic') String? previousProfilePic,@JsonKey(name: 'profile_pic_changed') bool profilePicChanged
});




}
/// @nodoc
class _$ConversationActionPayloadCopyWithImpl<$Res>
    implements $ConversationActionPayloadCopyWith<$Res> {
  _$ConversationActionPayloadCopyWithImpl(this._self, this._then);

  final ConversationActionPayload _self;
  final $Res Function(ConversationActionPayload) _then;

/// Create a copy of ConversationActionPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? eventId = null,Object? convId = null,Object? convType = null,Object? action = null,Object? members = null,Object? actorId = freezed,Object? message = null,Object? actionAt = null,Object? title = freezed,Object? profilePic = freezed,Object? previousProfilePic = freezed,Object? profilePicChanged = null,}) {
  return _then(_self.copyWith(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as String,convId: null == convId ? _self.convId : convId // ignore: cast_nullable_to_non_nullable
as String,convType: null == convType ? _self.convType : convType // ignore: cast_nullable_to_non_nullable
as ChatType,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as ConversationActionType,members: null == members ? _self.members : members // ignore: cast_nullable_to_non_nullable
as List<MembersType>,actorId: freezed == actorId ? _self.actorId : actorId // ignore: cast_nullable_to_non_nullable
as String?,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,actionAt: null == actionAt ? _self.actionAt : actionAt // ignore: cast_nullable_to_non_nullable
as DateTime,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,profilePic: freezed == profilePic ? _self.profilePic : profilePic // ignore: cast_nullable_to_non_nullable
as String?,previousProfilePic: freezed == previousProfilePic ? _self.previousProfilePic : previousProfilePic // ignore: cast_nullable_to_non_nullable
as String?,profilePicChanged: null == profilePicChanged ? _self.profilePicChanged : profilePicChanged // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ConversationActionPayload].
extension ConversationActionPayloadPatterns on ConversationActionPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConversationActionPayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConversationActionPayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConversationActionPayload value)  $default,){
final _that = this;
switch (_that) {
case _ConversationActionPayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConversationActionPayload value)?  $default,){
final _that = this;
switch (_that) {
case _ConversationActionPayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'event_id')  String eventId, @JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'conv_type')@ChatTypeConverter()  ChatType convType, @ConversationActionTypeConverter()  ConversationActionType action,  List<MembersType> members, @JsonKey(name: 'actor_id')  String? actorId,  String message, @JsonKey(name: 'action_at')  DateTime actionAt,  String? title, @JsonKey(name: 'profile_pic')  String? profilePic, @JsonKey(name: 'previous_profile_pic')  String? previousProfilePic, @JsonKey(name: 'profile_pic_changed')  bool profilePicChanged)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConversationActionPayload() when $default != null:
return $default(_that.eventId,_that.convId,_that.convType,_that.action,_that.members,_that.actorId,_that.message,_that.actionAt,_that.title,_that.profilePic,_that.previousProfilePic,_that.profilePicChanged);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'event_id')  String eventId, @JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'conv_type')@ChatTypeConverter()  ChatType convType, @ConversationActionTypeConverter()  ConversationActionType action,  List<MembersType> members, @JsonKey(name: 'actor_id')  String? actorId,  String message, @JsonKey(name: 'action_at')  DateTime actionAt,  String? title, @JsonKey(name: 'profile_pic')  String? profilePic, @JsonKey(name: 'previous_profile_pic')  String? previousProfilePic, @JsonKey(name: 'profile_pic_changed')  bool profilePicChanged)  $default,) {final _that = this;
switch (_that) {
case _ConversationActionPayload():
return $default(_that.eventId,_that.convId,_that.convType,_that.action,_that.members,_that.actorId,_that.message,_that.actionAt,_that.title,_that.profilePic,_that.previousProfilePic,_that.profilePicChanged);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'event_id')  String eventId, @JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'conv_type')@ChatTypeConverter()  ChatType convType, @ConversationActionTypeConverter()  ConversationActionType action,  List<MembersType> members, @JsonKey(name: 'actor_id')  String? actorId,  String message, @JsonKey(name: 'action_at')  DateTime actionAt,  String? title, @JsonKey(name: 'profile_pic')  String? profilePic, @JsonKey(name: 'previous_profile_pic')  String? previousProfilePic, @JsonKey(name: 'profile_pic_changed')  bool profilePicChanged)?  $default,) {final _that = this;
switch (_that) {
case _ConversationActionPayload() when $default != null:
return $default(_that.eventId,_that.convId,_that.convType,_that.action,_that.members,_that.actorId,_that.message,_that.actionAt,_that.title,_that.profilePic,_that.previousProfilePic,_that.profilePicChanged);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ConversationActionPayload implements ConversationActionPayload {
  const _ConversationActionPayload({@JsonKey(name: 'event_id') required this.eventId, @JsonKey(name: 'conv_id') required this.convId, @JsonKey(name: 'conv_type')@ChatTypeConverter() required this.convType, @ConversationActionTypeConverter() required this.action, final  List<MembersType> members = const <MembersType>[], @JsonKey(name: 'actor_id') this.actorId, required this.message, @JsonKey(name: 'action_at') required this.actionAt, this.title, @JsonKey(name: 'profile_pic') this.profilePic, @JsonKey(name: 'previous_profile_pic') this.previousProfilePic, @JsonKey(name: 'profile_pic_changed') this.profilePicChanged = false}): _members = members;
  factory _ConversationActionPayload.fromJson(Map<String, dynamic> json) => _$ConversationActionPayloadFromJson(json);

@override@JsonKey(name: 'event_id') final  String eventId;
@override@JsonKey(name: 'conv_id') final  String convId;
@override@JsonKey(name: 'conv_type')@ChatTypeConverter() final  ChatType convType;
@override@ConversationActionTypeConverter() final  ConversationActionType action;
 final  List<MembersType> _members;
@override@JsonKey() List<MembersType> get members {
  if (_members is EqualUnmodifiableListView) return _members;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_members);
}

@override@JsonKey(name: 'actor_id') final  String? actorId;
@override final  String message;
@override@JsonKey(name: 'action_at') final  DateTime actionAt;
// chat_details:update fields. Only set when at least one of title /
// profilePic changed. profilePic == null with profilePicChanged = true
// means the admin cleared the avatar.
@override final  String? title;
@override@JsonKey(name: 'profile_pic') final  String? profilePic;
// Previous profile pic URL — used as the key to evict the old image
// from the on-disk CachedNetworkImage cache when the pfp changes.
@override@JsonKey(name: 'previous_profile_pic') final  String? previousProfilePic;
// Explicit "pfp column was touched in this update" flag. Needed because
// profilePic == null can mean either "cleared" or "absent from payload",
// and the on-the-wire JSON collapses those two cases.
@override@JsonKey(name: 'profile_pic_changed') final  bool profilePicChanged;

/// Create a copy of ConversationActionPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConversationActionPayloadCopyWith<_ConversationActionPayload> get copyWith => __$ConversationActionPayloadCopyWithImpl<_ConversationActionPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConversationActionPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConversationActionPayload&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.convId, convId) || other.convId == convId)&&(identical(other.convType, convType) || other.convType == convType)&&(identical(other.action, action) || other.action == action)&&const DeepCollectionEquality().equals(other._members, _members)&&(identical(other.actorId, actorId) || other.actorId == actorId)&&(identical(other.message, message) || other.message == message)&&(identical(other.actionAt, actionAt) || other.actionAt == actionAt)&&(identical(other.title, title) || other.title == title)&&(identical(other.profilePic, profilePic) || other.profilePic == profilePic)&&(identical(other.previousProfilePic, previousProfilePic) || other.previousProfilePic == previousProfilePic)&&(identical(other.profilePicChanged, profilePicChanged) || other.profilePicChanged == profilePicChanged));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,eventId,convId,convType,action,const DeepCollectionEquality().hash(_members),actorId,message,actionAt,title,profilePic,previousProfilePic,profilePicChanged);

@override
String toString() {
  return 'ConversationActionPayload(eventId: $eventId, convId: $convId, convType: $convType, action: $action, members: $members, actorId: $actorId, message: $message, actionAt: $actionAt, title: $title, profilePic: $profilePic, previousProfilePic: $previousProfilePic, profilePicChanged: $profilePicChanged)';
}


}

/// @nodoc
abstract mixin class _$ConversationActionPayloadCopyWith<$Res> implements $ConversationActionPayloadCopyWith<$Res> {
  factory _$ConversationActionPayloadCopyWith(_ConversationActionPayload value, $Res Function(_ConversationActionPayload) _then) = __$ConversationActionPayloadCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'event_id') String eventId,@JsonKey(name: 'conv_id') String convId,@JsonKey(name: 'conv_type')@ChatTypeConverter() ChatType convType,@ConversationActionTypeConverter() ConversationActionType action, List<MembersType> members,@JsonKey(name: 'actor_id') String? actorId, String message,@JsonKey(name: 'action_at') DateTime actionAt, String? title,@JsonKey(name: 'profile_pic') String? profilePic,@JsonKey(name: 'previous_profile_pic') String? previousProfilePic,@JsonKey(name: 'profile_pic_changed') bool profilePicChanged
});




}
/// @nodoc
class __$ConversationActionPayloadCopyWithImpl<$Res>
    implements _$ConversationActionPayloadCopyWith<$Res> {
  __$ConversationActionPayloadCopyWithImpl(this._self, this._then);

  final _ConversationActionPayload _self;
  final $Res Function(_ConversationActionPayload) _then;

/// Create a copy of ConversationActionPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventId = null,Object? convId = null,Object? convType = null,Object? action = null,Object? members = null,Object? actorId = freezed,Object? message = null,Object? actionAt = null,Object? title = freezed,Object? profilePic = freezed,Object? previousProfilePic = freezed,Object? profilePicChanged = null,}) {
  return _then(_ConversationActionPayload(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as String,convId: null == convId ? _self.convId : convId // ignore: cast_nullable_to_non_nullable
as String,convType: null == convType ? _self.convType : convType // ignore: cast_nullable_to_non_nullable
as ChatType,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as ConversationActionType,members: null == members ? _self._members : members // ignore: cast_nullable_to_non_nullable
as List<MembersType>,actorId: freezed == actorId ? _self.actorId : actorId // ignore: cast_nullable_to_non_nullable
as String?,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,actionAt: null == actionAt ? _self.actionAt : actionAt // ignore: cast_nullable_to_non_nullable
as DateTime,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,profilePic: freezed == profilePic ? _self.profilePic : profilePic // ignore: cast_nullable_to_non_nullable
as String?,previousProfilePic: freezed == previousProfilePic ? _self.previousProfilePic : previousProfilePic // ignore: cast_nullable_to_non_nullable
as String?,profilePicChanged: null == profilePicChanged ? _self.profilePicChanged : profilePicChanged // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$MiscPayload {

 String? get message; dynamic get data; int? get code; dynamic get error;
/// Create a copy of MiscPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MiscPayloadCopyWith<MiscPayload> get copyWith => _$MiscPayloadCopyWithImpl<MiscPayload>(this as MiscPayload, _$identity);

  /// Serializes this MiscPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MiscPayload&&(identical(other.message, message) || other.message == message)&&const DeepCollectionEquality().equals(other.data, data)&&(identical(other.code, code) || other.code == code)&&const DeepCollectionEquality().equals(other.error, error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message,const DeepCollectionEquality().hash(data),code,const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'MiscPayload(message: $message, data: $data, code: $code, error: $error)';
}


}

/// @nodoc
abstract mixin class $MiscPayloadCopyWith<$Res>  {
  factory $MiscPayloadCopyWith(MiscPayload value, $Res Function(MiscPayload) _then) = _$MiscPayloadCopyWithImpl;
@useResult
$Res call({
 String? message, dynamic data, int? code, dynamic error
});




}
/// @nodoc
class _$MiscPayloadCopyWithImpl<$Res>
    implements $MiscPayloadCopyWith<$Res> {
  _$MiscPayloadCopyWithImpl(this._self, this._then);

  final MiscPayload _self;
  final $Res Function(MiscPayload) _then;

/// Create a copy of MiscPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = freezed,Object? data = freezed,Object? code = freezed,Object? error = freezed,}) {
  return _then(_self.copyWith(
message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as dynamic,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as int?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}

}


/// Adds pattern-matching-related methods to [MiscPayload].
extension MiscPayloadPatterns on MiscPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MiscPayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MiscPayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MiscPayload value)  $default,){
final _that = this;
switch (_that) {
case _MiscPayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MiscPayload value)?  $default,){
final _that = this;
switch (_that) {
case _MiscPayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? message,  dynamic data,  int? code,  dynamic error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MiscPayload() when $default != null:
return $default(_that.message,_that.data,_that.code,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? message,  dynamic data,  int? code,  dynamic error)  $default,) {final _that = this;
switch (_that) {
case _MiscPayload():
return $default(_that.message,_that.data,_that.code,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? message,  dynamic data,  int? code,  dynamic error)?  $default,) {final _that = this;
switch (_that) {
case _MiscPayload() when $default != null:
return $default(_that.message,_that.data,_that.code,_that.error);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MiscPayload implements MiscPayload {
  const _MiscPayload({this.message, this.data, this.code, this.error});
  factory _MiscPayload.fromJson(Map<String, dynamic> json) => _$MiscPayloadFromJson(json);

@override final  String? message;
@override final  dynamic data;
@override final  int? code;
@override final  dynamic error;

/// Create a copy of MiscPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MiscPayloadCopyWith<_MiscPayload> get copyWith => __$MiscPayloadCopyWithImpl<_MiscPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MiscPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MiscPayload&&(identical(other.message, message) || other.message == message)&&const DeepCollectionEquality().equals(other.data, data)&&(identical(other.code, code) || other.code == code)&&const DeepCollectionEquality().equals(other.error, error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message,const DeepCollectionEquality().hash(data),code,const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'MiscPayload(message: $message, data: $data, code: $code, error: $error)';
}


}

/// @nodoc
abstract mixin class _$MiscPayloadCopyWith<$Res> implements $MiscPayloadCopyWith<$Res> {
  factory _$MiscPayloadCopyWith(_MiscPayload value, $Res Function(_MiscPayload) _then) = __$MiscPayloadCopyWithImpl;
@override @useResult
$Res call({
 String? message, dynamic data, int? code, dynamic error
});




}
/// @nodoc
class __$MiscPayloadCopyWithImpl<$Res>
    implements _$MiscPayloadCopyWith<$Res> {
  __$MiscPayloadCopyWithImpl(this._self, this._then);

  final _MiscPayload _self;
  final $Res Function(_MiscPayload) _then;

/// Create a copy of MiscPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = freezed,Object? data = freezed,Object? code = freezed,Object? error = freezed,}) {
  return _then(_MiscPayload(
message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as dynamic,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as int?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}


}


/// @nodoc
mixin _$MessagePinPayload {

@JsonKey(name: 'conv_id') String get convId;@JsonKey(name: 'message_id') String get messageId;@JsonKey(name: 'message_type')@MessageTypeConverter() MessageType get messageType;@JsonKey(name: 'sender_id') String get senderId; bool get pin;
/// Create a copy of MessagePinPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessagePinPayloadCopyWith<MessagePinPayload> get copyWith => _$MessagePinPayloadCopyWithImpl<MessagePinPayload>(this as MessagePinPayload, _$identity);

  /// Serializes this MessagePinPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagePinPayload&&(identical(other.convId, convId) || other.convId == convId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.messageType, messageType) || other.messageType == messageType)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.pin, pin) || other.pin == pin));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,convId,messageId,messageType,senderId,pin);

@override
String toString() {
  return 'MessagePinPayload(convId: $convId, messageId: $messageId, messageType: $messageType, senderId: $senderId, pin: $pin)';
}


}

/// @nodoc
abstract mixin class $MessagePinPayloadCopyWith<$Res>  {
  factory $MessagePinPayloadCopyWith(MessagePinPayload value, $Res Function(MessagePinPayload) _then) = _$MessagePinPayloadCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'conv_id') String convId,@JsonKey(name: 'message_id') String messageId,@JsonKey(name: 'message_type')@MessageTypeConverter() MessageType messageType,@JsonKey(name: 'sender_id') String senderId, bool pin
});




}
/// @nodoc
class _$MessagePinPayloadCopyWithImpl<$Res>
    implements $MessagePinPayloadCopyWith<$Res> {
  _$MessagePinPayloadCopyWithImpl(this._self, this._then);

  final MessagePinPayload _self;
  final $Res Function(MessagePinPayload) _then;

/// Create a copy of MessagePinPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? convId = null,Object? messageId = null,Object? messageType = null,Object? senderId = null,Object? pin = null,}) {
  return _then(_self.copyWith(
convId: null == convId ? _self.convId : convId // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,messageType: null == messageType ? _self.messageType : messageType // ignore: cast_nullable_to_non_nullable
as MessageType,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,pin: null == pin ? _self.pin : pin // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [MessagePinPayload].
extension MessagePinPayloadPatterns on MessagePinPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessagePinPayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessagePinPayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessagePinPayload value)  $default,){
final _that = this;
switch (_that) {
case _MessagePinPayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessagePinPayload value)?  $default,){
final _that = this;
switch (_that) {
case _MessagePinPayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'message_id')  String messageId, @JsonKey(name: 'message_type')@MessageTypeConverter()  MessageType messageType, @JsonKey(name: 'sender_id')  String senderId,  bool pin)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessagePinPayload() when $default != null:
return $default(_that.convId,_that.messageId,_that.messageType,_that.senderId,_that.pin);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'message_id')  String messageId, @JsonKey(name: 'message_type')@MessageTypeConverter()  MessageType messageType, @JsonKey(name: 'sender_id')  String senderId,  bool pin)  $default,) {final _that = this;
switch (_that) {
case _MessagePinPayload():
return $default(_that.convId,_that.messageId,_that.messageType,_that.senderId,_that.pin);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'message_id')  String messageId, @JsonKey(name: 'message_type')@MessageTypeConverter()  MessageType messageType, @JsonKey(name: 'sender_id')  String senderId,  bool pin)?  $default,) {final _that = this;
switch (_that) {
case _MessagePinPayload() when $default != null:
return $default(_that.convId,_that.messageId,_that.messageType,_that.senderId,_that.pin);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessagePinPayload implements MessagePinPayload {
  const _MessagePinPayload({@JsonKey(name: 'conv_id') required this.convId, @JsonKey(name: 'message_id') required this.messageId, @JsonKey(name: 'message_type')@MessageTypeConverter() required this.messageType, @JsonKey(name: 'sender_id') required this.senderId, required this.pin});
  factory _MessagePinPayload.fromJson(Map<String, dynamic> json) => _$MessagePinPayloadFromJson(json);

@override@JsonKey(name: 'conv_id') final  String convId;
@override@JsonKey(name: 'message_id') final  String messageId;
@override@JsonKey(name: 'message_type')@MessageTypeConverter() final  MessageType messageType;
@override@JsonKey(name: 'sender_id') final  String senderId;
@override final  bool pin;

/// Create a copy of MessagePinPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessagePinPayloadCopyWith<_MessagePinPayload> get copyWith => __$MessagePinPayloadCopyWithImpl<_MessagePinPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessagePinPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessagePinPayload&&(identical(other.convId, convId) || other.convId == convId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.messageType, messageType) || other.messageType == messageType)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.pin, pin) || other.pin == pin));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,convId,messageId,messageType,senderId,pin);

@override
String toString() {
  return 'MessagePinPayload(convId: $convId, messageId: $messageId, messageType: $messageType, senderId: $senderId, pin: $pin)';
}


}

/// @nodoc
abstract mixin class _$MessagePinPayloadCopyWith<$Res> implements $MessagePinPayloadCopyWith<$Res> {
  factory _$MessagePinPayloadCopyWith(_MessagePinPayload value, $Res Function(_MessagePinPayload) _then) = __$MessagePinPayloadCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'conv_id') String convId,@JsonKey(name: 'message_id') String messageId,@JsonKey(name: 'message_type')@MessageTypeConverter() MessageType messageType,@JsonKey(name: 'sender_id') String senderId, bool pin
});




}
/// @nodoc
class __$MessagePinPayloadCopyWithImpl<$Res>
    implements _$MessagePinPayloadCopyWith<$Res> {
  __$MessagePinPayloadCopyWithImpl(this._self, this._then);

  final _MessagePinPayload _self;
  final $Res Function(_MessagePinPayload) _then;

/// Create a copy of MessagePinPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? convId = null,Object? messageId = null,Object? messageType = null,Object? senderId = null,Object? pin = null,}) {
  return _then(_MessagePinPayload(
convId: null == convId ? _self.convId : convId // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,messageType: null == messageType ? _self.messageType : messageType // ignore: cast_nullable_to_non_nullable
as MessageType,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,pin: null == pin ? _self.pin : pin // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$MessageForwardPayload {

@JsonKey(name: 'source_conv_id') String get sourceConvId;@JsonKey(name: 'forwarder_id') String get forwarderId;@JsonKey(name: 'forwarder_name') String? get forwarderName;@JsonKey(name: 'forwarded_message_ids') List<String> get forwardedMessageIds;@JsonKey(name: 'target_conv_ids') List<String> get targetConvIds;
/// Create a copy of MessageForwardPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageForwardPayloadCopyWith<MessageForwardPayload> get copyWith => _$MessageForwardPayloadCopyWithImpl<MessageForwardPayload>(this as MessageForwardPayload, _$identity);

  /// Serializes this MessageForwardPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageForwardPayload&&(identical(other.sourceConvId, sourceConvId) || other.sourceConvId == sourceConvId)&&(identical(other.forwarderId, forwarderId) || other.forwarderId == forwarderId)&&(identical(other.forwarderName, forwarderName) || other.forwarderName == forwarderName)&&const DeepCollectionEquality().equals(other.forwardedMessageIds, forwardedMessageIds)&&const DeepCollectionEquality().equals(other.targetConvIds, targetConvIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sourceConvId,forwarderId,forwarderName,const DeepCollectionEquality().hash(forwardedMessageIds),const DeepCollectionEquality().hash(targetConvIds));

@override
String toString() {
  return 'MessageForwardPayload(sourceConvId: $sourceConvId, forwarderId: $forwarderId, forwarderName: $forwarderName, forwardedMessageIds: $forwardedMessageIds, targetConvIds: $targetConvIds)';
}


}

/// @nodoc
abstract mixin class $MessageForwardPayloadCopyWith<$Res>  {
  factory $MessageForwardPayloadCopyWith(MessageForwardPayload value, $Res Function(MessageForwardPayload) _then) = _$MessageForwardPayloadCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'source_conv_id') String sourceConvId,@JsonKey(name: 'forwarder_id') String forwarderId,@JsonKey(name: 'forwarder_name') String? forwarderName,@JsonKey(name: 'forwarded_message_ids') List<String> forwardedMessageIds,@JsonKey(name: 'target_conv_ids') List<String> targetConvIds
});




}
/// @nodoc
class _$MessageForwardPayloadCopyWithImpl<$Res>
    implements $MessageForwardPayloadCopyWith<$Res> {
  _$MessageForwardPayloadCopyWithImpl(this._self, this._then);

  final MessageForwardPayload _self;
  final $Res Function(MessageForwardPayload) _then;

/// Create a copy of MessageForwardPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sourceConvId = null,Object? forwarderId = null,Object? forwarderName = freezed,Object? forwardedMessageIds = null,Object? targetConvIds = null,}) {
  return _then(_self.copyWith(
sourceConvId: null == sourceConvId ? _self.sourceConvId : sourceConvId // ignore: cast_nullable_to_non_nullable
as String,forwarderId: null == forwarderId ? _self.forwarderId : forwarderId // ignore: cast_nullable_to_non_nullable
as String,forwarderName: freezed == forwarderName ? _self.forwarderName : forwarderName // ignore: cast_nullable_to_non_nullable
as String?,forwardedMessageIds: null == forwardedMessageIds ? _self.forwardedMessageIds : forwardedMessageIds // ignore: cast_nullable_to_non_nullable
as List<String>,targetConvIds: null == targetConvIds ? _self.targetConvIds : targetConvIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageForwardPayload].
extension MessageForwardPayloadPatterns on MessageForwardPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageForwardPayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageForwardPayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageForwardPayload value)  $default,){
final _that = this;
switch (_that) {
case _MessageForwardPayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageForwardPayload value)?  $default,){
final _that = this;
switch (_that) {
case _MessageForwardPayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'source_conv_id')  String sourceConvId, @JsonKey(name: 'forwarder_id')  String forwarderId, @JsonKey(name: 'forwarder_name')  String? forwarderName, @JsonKey(name: 'forwarded_message_ids')  List<String> forwardedMessageIds, @JsonKey(name: 'target_conv_ids')  List<String> targetConvIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageForwardPayload() when $default != null:
return $default(_that.sourceConvId,_that.forwarderId,_that.forwarderName,_that.forwardedMessageIds,_that.targetConvIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'source_conv_id')  String sourceConvId, @JsonKey(name: 'forwarder_id')  String forwarderId, @JsonKey(name: 'forwarder_name')  String? forwarderName, @JsonKey(name: 'forwarded_message_ids')  List<String> forwardedMessageIds, @JsonKey(name: 'target_conv_ids')  List<String> targetConvIds)  $default,) {final _that = this;
switch (_that) {
case _MessageForwardPayload():
return $default(_that.sourceConvId,_that.forwarderId,_that.forwarderName,_that.forwardedMessageIds,_that.targetConvIds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'source_conv_id')  String sourceConvId, @JsonKey(name: 'forwarder_id')  String forwarderId, @JsonKey(name: 'forwarder_name')  String? forwarderName, @JsonKey(name: 'forwarded_message_ids')  List<String> forwardedMessageIds, @JsonKey(name: 'target_conv_ids')  List<String> targetConvIds)?  $default,) {final _that = this;
switch (_that) {
case _MessageForwardPayload() when $default != null:
return $default(_that.sourceConvId,_that.forwarderId,_that.forwarderName,_that.forwardedMessageIds,_that.targetConvIds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageForwardPayload implements MessageForwardPayload {
  const _MessageForwardPayload({@JsonKey(name: 'source_conv_id') required this.sourceConvId, @JsonKey(name: 'forwarder_id') required this.forwarderId, @JsonKey(name: 'forwarder_name') this.forwarderName, @JsonKey(name: 'forwarded_message_ids') required final  List<String> forwardedMessageIds, @JsonKey(name: 'target_conv_ids') required final  List<String> targetConvIds}): _forwardedMessageIds = forwardedMessageIds,_targetConvIds = targetConvIds;
  factory _MessageForwardPayload.fromJson(Map<String, dynamic> json) => _$MessageForwardPayloadFromJson(json);

@override@JsonKey(name: 'source_conv_id') final  String sourceConvId;
@override@JsonKey(name: 'forwarder_id') final  String forwarderId;
@override@JsonKey(name: 'forwarder_name') final  String? forwarderName;
 final  List<String> _forwardedMessageIds;
@override@JsonKey(name: 'forwarded_message_ids') List<String> get forwardedMessageIds {
  if (_forwardedMessageIds is EqualUnmodifiableListView) return _forwardedMessageIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_forwardedMessageIds);
}

 final  List<String> _targetConvIds;
@override@JsonKey(name: 'target_conv_ids') List<String> get targetConvIds {
  if (_targetConvIds is EqualUnmodifiableListView) return _targetConvIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_targetConvIds);
}


/// Create a copy of MessageForwardPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageForwardPayloadCopyWith<_MessageForwardPayload> get copyWith => __$MessageForwardPayloadCopyWithImpl<_MessageForwardPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageForwardPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageForwardPayload&&(identical(other.sourceConvId, sourceConvId) || other.sourceConvId == sourceConvId)&&(identical(other.forwarderId, forwarderId) || other.forwarderId == forwarderId)&&(identical(other.forwarderName, forwarderName) || other.forwarderName == forwarderName)&&const DeepCollectionEquality().equals(other._forwardedMessageIds, _forwardedMessageIds)&&const DeepCollectionEquality().equals(other._targetConvIds, _targetConvIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sourceConvId,forwarderId,forwarderName,const DeepCollectionEquality().hash(_forwardedMessageIds),const DeepCollectionEquality().hash(_targetConvIds));

@override
String toString() {
  return 'MessageForwardPayload(sourceConvId: $sourceConvId, forwarderId: $forwarderId, forwarderName: $forwarderName, forwardedMessageIds: $forwardedMessageIds, targetConvIds: $targetConvIds)';
}


}

/// @nodoc
abstract mixin class _$MessageForwardPayloadCopyWith<$Res> implements $MessageForwardPayloadCopyWith<$Res> {
  factory _$MessageForwardPayloadCopyWith(_MessageForwardPayload value, $Res Function(_MessageForwardPayload) _then) = __$MessageForwardPayloadCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'source_conv_id') String sourceConvId,@JsonKey(name: 'forwarder_id') String forwarderId,@JsonKey(name: 'forwarder_name') String? forwarderName,@JsonKey(name: 'forwarded_message_ids') List<String> forwardedMessageIds,@JsonKey(name: 'target_conv_ids') List<String> targetConvIds
});




}
/// @nodoc
class __$MessageForwardPayloadCopyWithImpl<$Res>
    implements _$MessageForwardPayloadCopyWith<$Res> {
  __$MessageForwardPayloadCopyWithImpl(this._self, this._then);

  final _MessageForwardPayload _self;
  final $Res Function(_MessageForwardPayload) _then;

/// Create a copy of MessageForwardPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sourceConvId = null,Object? forwarderId = null,Object? forwarderName = freezed,Object? forwardedMessageIds = null,Object? targetConvIds = null,}) {
  return _then(_MessageForwardPayload(
sourceConvId: null == sourceConvId ? _self.sourceConvId : sourceConvId // ignore: cast_nullable_to_non_nullable
as String,forwarderId: null == forwarderId ? _self.forwarderId : forwarderId // ignore: cast_nullable_to_non_nullable
as String,forwarderName: freezed == forwarderName ? _self.forwarderName : forwarderName // ignore: cast_nullable_to_non_nullable
as String?,forwardedMessageIds: null == forwardedMessageIds ? _self._forwardedMessageIds : forwardedMessageIds // ignore: cast_nullable_to_non_nullable
as List<String>,targetConvIds: null == targetConvIds ? _self._targetConvIds : targetConvIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$MessageReactPayload {

@JsonKey(name: 'message_id') String get messageId;@JsonKey(name: 'conv_id') String get convId;@JsonKey(name: 'sender_id') String get senderId; String get emoji; String get action;
/// Create a copy of MessageReactPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageReactPayloadCopyWith<MessageReactPayload> get copyWith => _$MessageReactPayloadCopyWithImpl<MessageReactPayload>(this as MessageReactPayload, _$identity);

  /// Serializes this MessageReactPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageReactPayload&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.convId, convId) || other.convId == convId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.emoji, emoji) || other.emoji == emoji)&&(identical(other.action, action) || other.action == action));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,messageId,convId,senderId,emoji,action);

@override
String toString() {
  return 'MessageReactPayload(messageId: $messageId, convId: $convId, senderId: $senderId, emoji: $emoji, action: $action)';
}


}

/// @nodoc
abstract mixin class $MessageReactPayloadCopyWith<$Res>  {
  factory $MessageReactPayloadCopyWith(MessageReactPayload value, $Res Function(MessageReactPayload) _then) = _$MessageReactPayloadCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'message_id') String messageId,@JsonKey(name: 'conv_id') String convId,@JsonKey(name: 'sender_id') String senderId, String emoji, String action
});




}
/// @nodoc
class _$MessageReactPayloadCopyWithImpl<$Res>
    implements $MessageReactPayloadCopyWith<$Res> {
  _$MessageReactPayloadCopyWithImpl(this._self, this._then);

  final MessageReactPayload _self;
  final $Res Function(MessageReactPayload) _then;

/// Create a copy of MessageReactPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageId = null,Object? convId = null,Object? senderId = null,Object? emoji = null,Object? action = null,}) {
  return _then(_self.copyWith(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,convId: null == convId ? _self.convId : convId // ignore: cast_nullable_to_non_nullable
as String,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,emoji: null == emoji ? _self.emoji : emoji // ignore: cast_nullable_to_non_nullable
as String,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageReactPayload].
extension MessageReactPayloadPatterns on MessageReactPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageReactPayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageReactPayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageReactPayload value)  $default,){
final _that = this;
switch (_that) {
case _MessageReactPayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageReactPayload value)?  $default,){
final _that = this;
switch (_that) {
case _MessageReactPayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'message_id')  String messageId, @JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'sender_id')  String senderId,  String emoji,  String action)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageReactPayload() when $default != null:
return $default(_that.messageId,_that.convId,_that.senderId,_that.emoji,_that.action);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'message_id')  String messageId, @JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'sender_id')  String senderId,  String emoji,  String action)  $default,) {final _that = this;
switch (_that) {
case _MessageReactPayload():
return $default(_that.messageId,_that.convId,_that.senderId,_that.emoji,_that.action);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'message_id')  String messageId, @JsonKey(name: 'conv_id')  String convId, @JsonKey(name: 'sender_id')  String senderId,  String emoji,  String action)?  $default,) {final _that = this;
switch (_that) {
case _MessageReactPayload() when $default != null:
return $default(_that.messageId,_that.convId,_that.senderId,_that.emoji,_that.action);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageReactPayload implements MessageReactPayload {
  const _MessageReactPayload({@JsonKey(name: 'message_id') required this.messageId, @JsonKey(name: 'conv_id') required this.convId, @JsonKey(name: 'sender_id') required this.senderId, required this.emoji, required this.action});
  factory _MessageReactPayload.fromJson(Map<String, dynamic> json) => _$MessageReactPayloadFromJson(json);

@override@JsonKey(name: 'message_id') final  String messageId;
@override@JsonKey(name: 'conv_id') final  String convId;
@override@JsonKey(name: 'sender_id') final  String senderId;
@override final  String emoji;
@override final  String action;

/// Create a copy of MessageReactPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageReactPayloadCopyWith<_MessageReactPayload> get copyWith => __$MessageReactPayloadCopyWithImpl<_MessageReactPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageReactPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageReactPayload&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.convId, convId) || other.convId == convId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.emoji, emoji) || other.emoji == emoji)&&(identical(other.action, action) || other.action == action));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,messageId,convId,senderId,emoji,action);

@override
String toString() {
  return 'MessageReactPayload(messageId: $messageId, convId: $convId, senderId: $senderId, emoji: $emoji, action: $action)';
}


}

/// @nodoc
abstract mixin class _$MessageReactPayloadCopyWith<$Res> implements $MessageReactPayloadCopyWith<$Res> {
  factory _$MessageReactPayloadCopyWith(_MessageReactPayload value, $Res Function(_MessageReactPayload) _then) = __$MessageReactPayloadCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'message_id') String messageId,@JsonKey(name: 'conv_id') String convId,@JsonKey(name: 'sender_id') String senderId, String emoji, String action
});




}
/// @nodoc
class __$MessageReactPayloadCopyWithImpl<$Res>
    implements _$MessageReactPayloadCopyWith<$Res> {
  __$MessageReactPayloadCopyWithImpl(this._self, this._then);

  final _MessageReactPayload _self;
  final $Res Function(_MessageReactPayload) _then;

/// Create a copy of MessageReactPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageId = null,Object? convId = null,Object? senderId = null,Object? emoji = null,Object? action = null,}) {
  return _then(_MessageReactPayload(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,convId: null == convId ? _self.convId : convId // ignore: cast_nullable_to_non_nullable
as String,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,emoji: null == emoji ? _self.emoji : emoji // ignore: cast_nullable_to_non_nullable
as String,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$CallPayload {

@JsonKey(name: 'call_id') String? get callId;@JsonKey(name: 'caller_id') String get callerId;@JsonKey(name: 'caller_name') String? get callerName;@JsonKey(name: 'caller_pfp') String? get callerPfp;@JsonKey(name: 'callee_id') String get calleeId;@JsonKey(name: 'callee_name') String? get calleeName;@JsonKey(name: 'callee_pfp') String? get calleePfp;@JsonKey(name: 'callType') String? get callType; dynamic get data; dynamic get error; DateTime? get timestamp;
/// Create a copy of CallPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CallPayloadCopyWith<CallPayload> get copyWith => _$CallPayloadCopyWithImpl<CallPayload>(this as CallPayload, _$identity);

  /// Serializes this CallPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CallPayload&&(identical(other.callId, callId) || other.callId == callId)&&(identical(other.callerId, callerId) || other.callerId == callerId)&&(identical(other.callerName, callerName) || other.callerName == callerName)&&(identical(other.callerPfp, callerPfp) || other.callerPfp == callerPfp)&&(identical(other.calleeId, calleeId) || other.calleeId == calleeId)&&(identical(other.calleeName, calleeName) || other.calleeName == calleeName)&&(identical(other.calleePfp, calleePfp) || other.calleePfp == calleePfp)&&(identical(other.callType, callType) || other.callType == callType)&&const DeepCollectionEquality().equals(other.data, data)&&const DeepCollectionEquality().equals(other.error, error)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,callId,callerId,callerName,callerPfp,calleeId,calleeName,calleePfp,callType,const DeepCollectionEquality().hash(data),const DeepCollectionEquality().hash(error),timestamp);

@override
String toString() {
  return 'CallPayload(callId: $callId, callerId: $callerId, callerName: $callerName, callerPfp: $callerPfp, calleeId: $calleeId, calleeName: $calleeName, calleePfp: $calleePfp, callType: $callType, data: $data, error: $error, timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class $CallPayloadCopyWith<$Res>  {
  factory $CallPayloadCopyWith(CallPayload value, $Res Function(CallPayload) _then) = _$CallPayloadCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'call_id') String? callId,@JsonKey(name: 'caller_id') String callerId,@JsonKey(name: 'caller_name') String? callerName,@JsonKey(name: 'caller_pfp') String? callerPfp,@JsonKey(name: 'callee_id') String calleeId,@JsonKey(name: 'callee_name') String? calleeName,@JsonKey(name: 'callee_pfp') String? calleePfp,@JsonKey(name: 'callType') String? callType, dynamic data, dynamic error, DateTime? timestamp
});




}
/// @nodoc
class _$CallPayloadCopyWithImpl<$Res>
    implements $CallPayloadCopyWith<$Res> {
  _$CallPayloadCopyWithImpl(this._self, this._then);

  final CallPayload _self;
  final $Res Function(CallPayload) _then;

/// Create a copy of CallPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? callId = freezed,Object? callerId = null,Object? callerName = freezed,Object? callerPfp = freezed,Object? calleeId = null,Object? calleeName = freezed,Object? calleePfp = freezed,Object? callType = freezed,Object? data = freezed,Object? error = freezed,Object? timestamp = freezed,}) {
  return _then(_self.copyWith(
callId: freezed == callId ? _self.callId : callId // ignore: cast_nullable_to_non_nullable
as String?,callerId: null == callerId ? _self.callerId : callerId // ignore: cast_nullable_to_non_nullable
as String,callerName: freezed == callerName ? _self.callerName : callerName // ignore: cast_nullable_to_non_nullable
as String?,callerPfp: freezed == callerPfp ? _self.callerPfp : callerPfp // ignore: cast_nullable_to_non_nullable
as String?,calleeId: null == calleeId ? _self.calleeId : calleeId // ignore: cast_nullable_to_non_nullable
as String,calleeName: freezed == calleeName ? _self.calleeName : calleeName // ignore: cast_nullable_to_non_nullable
as String?,calleePfp: freezed == calleePfp ? _self.calleePfp : calleePfp // ignore: cast_nullable_to_non_nullable
as String?,callType: freezed == callType ? _self.callType : callType // ignore: cast_nullable_to_non_nullable
as String?,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as dynamic,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as dynamic,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [CallPayload].
extension CallPayloadPatterns on CallPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CallPayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CallPayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CallPayload value)  $default,){
final _that = this;
switch (_that) {
case _CallPayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CallPayload value)?  $default,){
final _that = this;
switch (_that) {
case _CallPayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'call_id')  String? callId, @JsonKey(name: 'caller_id')  String callerId, @JsonKey(name: 'caller_name')  String? callerName, @JsonKey(name: 'caller_pfp')  String? callerPfp, @JsonKey(name: 'callee_id')  String calleeId, @JsonKey(name: 'callee_name')  String? calleeName, @JsonKey(name: 'callee_pfp')  String? calleePfp, @JsonKey(name: 'callType')  String? callType,  dynamic data,  dynamic error,  DateTime? timestamp)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CallPayload() when $default != null:
return $default(_that.callId,_that.callerId,_that.callerName,_that.callerPfp,_that.calleeId,_that.calleeName,_that.calleePfp,_that.callType,_that.data,_that.error,_that.timestamp);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'call_id')  String? callId, @JsonKey(name: 'caller_id')  String callerId, @JsonKey(name: 'caller_name')  String? callerName, @JsonKey(name: 'caller_pfp')  String? callerPfp, @JsonKey(name: 'callee_id')  String calleeId, @JsonKey(name: 'callee_name')  String? calleeName, @JsonKey(name: 'callee_pfp')  String? calleePfp, @JsonKey(name: 'callType')  String? callType,  dynamic data,  dynamic error,  DateTime? timestamp)  $default,) {final _that = this;
switch (_that) {
case _CallPayload():
return $default(_that.callId,_that.callerId,_that.callerName,_that.callerPfp,_that.calleeId,_that.calleeName,_that.calleePfp,_that.callType,_that.data,_that.error,_that.timestamp);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'call_id')  String? callId, @JsonKey(name: 'caller_id')  String callerId, @JsonKey(name: 'caller_name')  String? callerName, @JsonKey(name: 'caller_pfp')  String? callerPfp, @JsonKey(name: 'callee_id')  String calleeId, @JsonKey(name: 'callee_name')  String? calleeName, @JsonKey(name: 'callee_pfp')  String? calleePfp, @JsonKey(name: 'callType')  String? callType,  dynamic data,  dynamic error,  DateTime? timestamp)?  $default,) {final _that = this;
switch (_that) {
case _CallPayload() when $default != null:
return $default(_that.callId,_that.callerId,_that.callerName,_that.callerPfp,_that.calleeId,_that.calleeName,_that.calleePfp,_that.callType,_that.data,_that.error,_that.timestamp);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CallPayload implements CallPayload {
  const _CallPayload({@JsonKey(name: 'call_id') this.callId, @JsonKey(name: 'caller_id') required this.callerId, @JsonKey(name: 'caller_name') this.callerName, @JsonKey(name: 'caller_pfp') this.callerPfp, @JsonKey(name: 'callee_id') required this.calleeId, @JsonKey(name: 'callee_name') this.calleeName, @JsonKey(name: 'callee_pfp') this.calleePfp, @JsonKey(name: 'callType') this.callType, this.data, this.error, this.timestamp});
  factory _CallPayload.fromJson(Map<String, dynamic> json) => _$CallPayloadFromJson(json);

@override@JsonKey(name: 'call_id') final  String? callId;
@override@JsonKey(name: 'caller_id') final  String callerId;
@override@JsonKey(name: 'caller_name') final  String? callerName;
@override@JsonKey(name: 'caller_pfp') final  String? callerPfp;
@override@JsonKey(name: 'callee_id') final  String calleeId;
@override@JsonKey(name: 'callee_name') final  String? calleeName;
@override@JsonKey(name: 'callee_pfp') final  String? calleePfp;
@override@JsonKey(name: 'callType') final  String? callType;
@override final  dynamic data;
@override final  dynamic error;
@override final  DateTime? timestamp;

/// Create a copy of CallPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CallPayloadCopyWith<_CallPayload> get copyWith => __$CallPayloadCopyWithImpl<_CallPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CallPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CallPayload&&(identical(other.callId, callId) || other.callId == callId)&&(identical(other.callerId, callerId) || other.callerId == callerId)&&(identical(other.callerName, callerName) || other.callerName == callerName)&&(identical(other.callerPfp, callerPfp) || other.callerPfp == callerPfp)&&(identical(other.calleeId, calleeId) || other.calleeId == calleeId)&&(identical(other.calleeName, calleeName) || other.calleeName == calleeName)&&(identical(other.calleePfp, calleePfp) || other.calleePfp == calleePfp)&&(identical(other.callType, callType) || other.callType == callType)&&const DeepCollectionEquality().equals(other.data, data)&&const DeepCollectionEquality().equals(other.error, error)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,callId,callerId,callerName,callerPfp,calleeId,calleeName,calleePfp,callType,const DeepCollectionEquality().hash(data),const DeepCollectionEquality().hash(error),timestamp);

@override
String toString() {
  return 'CallPayload(callId: $callId, callerId: $callerId, callerName: $callerName, callerPfp: $callerPfp, calleeId: $calleeId, calleeName: $calleeName, calleePfp: $calleePfp, callType: $callType, data: $data, error: $error, timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class _$CallPayloadCopyWith<$Res> implements $CallPayloadCopyWith<$Res> {
  factory _$CallPayloadCopyWith(_CallPayload value, $Res Function(_CallPayload) _then) = __$CallPayloadCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'call_id') String? callId,@JsonKey(name: 'caller_id') String callerId,@JsonKey(name: 'caller_name') String? callerName,@JsonKey(name: 'caller_pfp') String? callerPfp,@JsonKey(name: 'callee_id') String calleeId,@JsonKey(name: 'callee_name') String? calleeName,@JsonKey(name: 'callee_pfp') String? calleePfp,@JsonKey(name: 'callType') String? callType, dynamic data, dynamic error, DateTime? timestamp
});




}
/// @nodoc
class __$CallPayloadCopyWithImpl<$Res>
    implements _$CallPayloadCopyWith<$Res> {
  __$CallPayloadCopyWithImpl(this._self, this._then);

  final _CallPayload _self;
  final $Res Function(_CallPayload) _then;

/// Create a copy of CallPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? callId = freezed,Object? callerId = null,Object? callerName = freezed,Object? callerPfp = freezed,Object? calleeId = null,Object? calleeName = freezed,Object? calleePfp = freezed,Object? callType = freezed,Object? data = freezed,Object? error = freezed,Object? timestamp = freezed,}) {
  return _then(_CallPayload(
callId: freezed == callId ? _self.callId : callId // ignore: cast_nullable_to_non_nullable
as String?,callerId: null == callerId ? _self.callerId : callerId // ignore: cast_nullable_to_non_nullable
as String,callerName: freezed == callerName ? _self.callerName : callerName // ignore: cast_nullable_to_non_nullable
as String?,callerPfp: freezed == callerPfp ? _self.callerPfp : callerPfp // ignore: cast_nullable_to_non_nullable
as String?,calleeId: null == calleeId ? _self.calleeId : calleeId // ignore: cast_nullable_to_non_nullable
as String,calleeName: freezed == calleeName ? _self.calleeName : calleeName // ignore: cast_nullable_to_non_nullable
as String?,calleePfp: freezed == calleePfp ? _self.calleePfp : calleePfp // ignore: cast_nullable_to_non_nullable
as String?,callType: freezed == callType ? _self.callType : callType // ignore: cast_nullable_to_non_nullable
as String?,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as dynamic,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as dynamic,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$MediaResponse {

 String get url; String get key; String get category;@JsonKey(name: 'file_name') String get fileName;@JsonKey(name: 'file_size') int get fileSize;@JsonKey(name: 'mime_type') String get mimeType;
/// Create a copy of MediaResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MediaResponseCopyWith<MediaResponse> get copyWith => _$MediaResponseCopyWithImpl<MediaResponse>(this as MediaResponse, _$identity);

  /// Serializes this MediaResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaResponse&&(identical(other.url, url) || other.url == url)&&(identical(other.key, key) || other.key == key)&&(identical(other.category, category) || other.category == category)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,url,key,category,fileName,fileSize,mimeType);

@override
String toString() {
  return 'MediaResponse(url: $url, key: $key, category: $category, fileName: $fileName, fileSize: $fileSize, mimeType: $mimeType)';
}


}

/// @nodoc
abstract mixin class $MediaResponseCopyWith<$Res>  {
  factory $MediaResponseCopyWith(MediaResponse value, $Res Function(MediaResponse) _then) = _$MediaResponseCopyWithImpl;
@useResult
$Res call({
 String url, String key, String category,@JsonKey(name: 'file_name') String fileName,@JsonKey(name: 'file_size') int fileSize,@JsonKey(name: 'mime_type') String mimeType
});




}
/// @nodoc
class _$MediaResponseCopyWithImpl<$Res>
    implements $MediaResponseCopyWith<$Res> {
  _$MediaResponseCopyWithImpl(this._self, this._then);

  final MediaResponse _self;
  final $Res Function(MediaResponse) _then;

/// Create a copy of MediaResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,Object? key = null,Object? category = null,Object? fileName = null,Object? fileSize = null,Object? mimeType = null,}) {
  return _then(_self.copyWith(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,fileSize: null == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MediaResponse].
extension MediaResponsePatterns on MediaResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MediaResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MediaResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MediaResponse value)  $default,){
final _that = this;
switch (_that) {
case _MediaResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MediaResponse value)?  $default,){
final _that = this;
switch (_that) {
case _MediaResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String url,  String key,  String category, @JsonKey(name: 'file_name')  String fileName, @JsonKey(name: 'file_size')  int fileSize, @JsonKey(name: 'mime_type')  String mimeType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MediaResponse() when $default != null:
return $default(_that.url,_that.key,_that.category,_that.fileName,_that.fileSize,_that.mimeType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String url,  String key,  String category, @JsonKey(name: 'file_name')  String fileName, @JsonKey(name: 'file_size')  int fileSize, @JsonKey(name: 'mime_type')  String mimeType)  $default,) {final _that = this;
switch (_that) {
case _MediaResponse():
return $default(_that.url,_that.key,_that.category,_that.fileName,_that.fileSize,_that.mimeType);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String url,  String key,  String category, @JsonKey(name: 'file_name')  String fileName, @JsonKey(name: 'file_size')  int fileSize, @JsonKey(name: 'mime_type')  String mimeType)?  $default,) {final _that = this;
switch (_that) {
case _MediaResponse() when $default != null:
return $default(_that.url,_that.key,_that.category,_that.fileName,_that.fileSize,_that.mimeType);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MediaResponse implements MediaResponse {
  const _MediaResponse({required this.url, required this.key, required this.category, @JsonKey(name: 'file_name') required this.fileName, @JsonKey(name: 'file_size') required this.fileSize, @JsonKey(name: 'mime_type') required this.mimeType});
  factory _MediaResponse.fromJson(Map<String, dynamic> json) => _$MediaResponseFromJson(json);

@override final  String url;
@override final  String key;
@override final  String category;
@override@JsonKey(name: 'file_name') final  String fileName;
@override@JsonKey(name: 'file_size') final  int fileSize;
@override@JsonKey(name: 'mime_type') final  String mimeType;

/// Create a copy of MediaResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MediaResponseCopyWith<_MediaResponse> get copyWith => __$MediaResponseCopyWithImpl<_MediaResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MediaResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MediaResponse&&(identical(other.url, url) || other.url == url)&&(identical(other.key, key) || other.key == key)&&(identical(other.category, category) || other.category == category)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,url,key,category,fileName,fileSize,mimeType);

@override
String toString() {
  return 'MediaResponse(url: $url, key: $key, category: $category, fileName: $fileName, fileSize: $fileSize, mimeType: $mimeType)';
}


}

/// @nodoc
abstract mixin class _$MediaResponseCopyWith<$Res> implements $MediaResponseCopyWith<$Res> {
  factory _$MediaResponseCopyWith(_MediaResponse value, $Res Function(_MediaResponse) _then) = __$MediaResponseCopyWithImpl;
@override @useResult
$Res call({
 String url, String key, String category,@JsonKey(name: 'file_name') String fileName,@JsonKey(name: 'file_size') int fileSize,@JsonKey(name: 'mime_type') String mimeType
});




}
/// @nodoc
class __$MediaResponseCopyWithImpl<$Res>
    implements _$MediaResponseCopyWith<$Res> {
  __$MediaResponseCopyWithImpl(this._self, this._then);

  final _MediaResponse _self;
  final $Res Function(_MediaResponse) _then;

/// Create a copy of MediaResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = null,Object? key = null,Object? category = null,Object? fileName = null,Object? fileSize = null,Object? mimeType = null,}) {
  return _then(_MediaResponse(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,fileSize: null == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
