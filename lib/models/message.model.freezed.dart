// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MessageModel {

 String get id;@JsonKey(name: 'chat_id') String get chatId;@JsonKey(name: 'sender_id') String? get senderId;@JsonKey(name: 'sender_name') String? get senderName;@JsonKey(name: 'sender_profile_pic') String? get senderProfilePic;@JsonKey(name: 'replied_to') String? get repliedTo;// Server attaches a compact preview of the replied-to message so the
// client can render the reply container immediately without waiting for
// the original message to be paged into local DB. Untyped on purpose —
// we transiently use it to upsert a row into the messages table on
// insert, then it's not needed again.
@JsonKey(name: 'replied_to_message') Map<String, dynamic>? get repliedToMessage;@JsonKey(fromJson: _messageTypeFromJson, toJson: _messageTypeToJson) MessageType get type; String? get body; Map<String, dynamic>? get attachments;@JsonKey(name: 'local_media_path') String? get localMediaPath;@JsonKey(name: 'is_failed') bool get isFailed;@JsonKey(name: 'sent_at') String get sentAt;@JsonKey(name: 'deleted_at') String? get deletedAt;
/// Create a copy of MessageModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageModelCopyWith<MessageModel> get copyWith => _$MessageModelCopyWithImpl<MessageModel>(this as MessageModel, _$identity);

  /// Serializes this MessageModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageModel&&(identical(other.id, id) || other.id == id)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.senderName, senderName) || other.senderName == senderName)&&(identical(other.senderProfilePic, senderProfilePic) || other.senderProfilePic == senderProfilePic)&&(identical(other.repliedTo, repliedTo) || other.repliedTo == repliedTo)&&const DeepCollectionEquality().equals(other.repliedToMessage, repliedToMessage)&&(identical(other.type, type) || other.type == type)&&(identical(other.body, body) || other.body == body)&&const DeepCollectionEquality().equals(other.attachments, attachments)&&(identical(other.localMediaPath, localMediaPath) || other.localMediaPath == localMediaPath)&&(identical(other.isFailed, isFailed) || other.isFailed == isFailed)&&(identical(other.sentAt, sentAt) || other.sentAt == sentAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,chatId,senderId,senderName,senderProfilePic,repliedTo,const DeepCollectionEquality().hash(repliedToMessage),type,body,const DeepCollectionEquality().hash(attachments),localMediaPath,isFailed,sentAt,deletedAt);

@override
String toString() {
  return 'MessageModel(id: $id, chatId: $chatId, senderId: $senderId, senderName: $senderName, senderProfilePic: $senderProfilePic, repliedTo: $repliedTo, repliedToMessage: $repliedToMessage, type: $type, body: $body, attachments: $attachments, localMediaPath: $localMediaPath, isFailed: $isFailed, sentAt: $sentAt, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $MessageModelCopyWith<$Res>  {
  factory $MessageModelCopyWith(MessageModel value, $Res Function(MessageModel) _then) = _$MessageModelCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'chat_id') String chatId,@JsonKey(name: 'sender_id') String? senderId,@JsonKey(name: 'sender_name') String? senderName,@JsonKey(name: 'sender_profile_pic') String? senderProfilePic,@JsonKey(name: 'replied_to') String? repliedTo,@JsonKey(name: 'replied_to_message') Map<String, dynamic>? repliedToMessage,@JsonKey(fromJson: _messageTypeFromJson, toJson: _messageTypeToJson) MessageType type, String? body, Map<String, dynamic>? attachments,@JsonKey(name: 'local_media_path') String? localMediaPath,@JsonKey(name: 'is_failed') bool isFailed,@JsonKey(name: 'sent_at') String sentAt,@JsonKey(name: 'deleted_at') String? deletedAt
});




}
/// @nodoc
class _$MessageModelCopyWithImpl<$Res>
    implements $MessageModelCopyWith<$Res> {
  _$MessageModelCopyWithImpl(this._self, this._then);

  final MessageModel _self;
  final $Res Function(MessageModel) _then;

/// Create a copy of MessageModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? chatId = null,Object? senderId = freezed,Object? senderName = freezed,Object? senderProfilePic = freezed,Object? repliedTo = freezed,Object? repliedToMessage = freezed,Object? type = null,Object? body = freezed,Object? attachments = freezed,Object? localMediaPath = freezed,Object? isFailed = null,Object? sentAt = null,Object? deletedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,senderId: freezed == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String?,senderName: freezed == senderName ? _self.senderName : senderName // ignore: cast_nullable_to_non_nullable
as String?,senderProfilePic: freezed == senderProfilePic ? _self.senderProfilePic : senderProfilePic // ignore: cast_nullable_to_non_nullable
as String?,repliedTo: freezed == repliedTo ? _self.repliedTo : repliedTo // ignore: cast_nullable_to_non_nullable
as String?,repliedToMessage: freezed == repliedToMessage ? _self.repliedToMessage : repliedToMessage // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as MessageType,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,attachments: freezed == attachments ? _self.attachments : attachments // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,localMediaPath: freezed == localMediaPath ? _self.localMediaPath : localMediaPath // ignore: cast_nullable_to_non_nullable
as String?,isFailed: null == isFailed ? _self.isFailed : isFailed // ignore: cast_nullable_to_non_nullable
as bool,sentAt: null == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as String,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageModel].
extension MessageModelPatterns on MessageModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageModel value)  $default,){
final _that = this;
switch (_that) {
case _MessageModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageModel value)?  $default,){
final _that = this;
switch (_that) {
case _MessageModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'chat_id')  String chatId, @JsonKey(name: 'sender_id')  String? senderId, @JsonKey(name: 'sender_name')  String? senderName, @JsonKey(name: 'sender_profile_pic')  String? senderProfilePic, @JsonKey(name: 'replied_to')  String? repliedTo, @JsonKey(name: 'replied_to_message')  Map<String, dynamic>? repliedToMessage, @JsonKey(fromJson: _messageTypeFromJson, toJson: _messageTypeToJson)  MessageType type,  String? body,  Map<String, dynamic>? attachments, @JsonKey(name: 'local_media_path')  String? localMediaPath, @JsonKey(name: 'is_failed')  bool isFailed, @JsonKey(name: 'sent_at')  String sentAt, @JsonKey(name: 'deleted_at')  String? deletedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageModel() when $default != null:
return $default(_that.id,_that.chatId,_that.senderId,_that.senderName,_that.senderProfilePic,_that.repliedTo,_that.repliedToMessage,_that.type,_that.body,_that.attachments,_that.localMediaPath,_that.isFailed,_that.sentAt,_that.deletedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'chat_id')  String chatId, @JsonKey(name: 'sender_id')  String? senderId, @JsonKey(name: 'sender_name')  String? senderName, @JsonKey(name: 'sender_profile_pic')  String? senderProfilePic, @JsonKey(name: 'replied_to')  String? repliedTo, @JsonKey(name: 'replied_to_message')  Map<String, dynamic>? repliedToMessage, @JsonKey(fromJson: _messageTypeFromJson, toJson: _messageTypeToJson)  MessageType type,  String? body,  Map<String, dynamic>? attachments, @JsonKey(name: 'local_media_path')  String? localMediaPath, @JsonKey(name: 'is_failed')  bool isFailed, @JsonKey(name: 'sent_at')  String sentAt, @JsonKey(name: 'deleted_at')  String? deletedAt)  $default,) {final _that = this;
switch (_that) {
case _MessageModel():
return $default(_that.id,_that.chatId,_that.senderId,_that.senderName,_that.senderProfilePic,_that.repliedTo,_that.repliedToMessage,_that.type,_that.body,_that.attachments,_that.localMediaPath,_that.isFailed,_that.sentAt,_that.deletedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'chat_id')  String chatId, @JsonKey(name: 'sender_id')  String? senderId, @JsonKey(name: 'sender_name')  String? senderName, @JsonKey(name: 'sender_profile_pic')  String? senderProfilePic, @JsonKey(name: 'replied_to')  String? repliedTo, @JsonKey(name: 'replied_to_message')  Map<String, dynamic>? repliedToMessage, @JsonKey(fromJson: _messageTypeFromJson, toJson: _messageTypeToJson)  MessageType type,  String? body,  Map<String, dynamic>? attachments, @JsonKey(name: 'local_media_path')  String? localMediaPath, @JsonKey(name: 'is_failed')  bool isFailed, @JsonKey(name: 'sent_at')  String sentAt, @JsonKey(name: 'deleted_at')  String? deletedAt)?  $default,) {final _that = this;
switch (_that) {
case _MessageModel() when $default != null:
return $default(_that.id,_that.chatId,_that.senderId,_that.senderName,_that.senderProfilePic,_that.repliedTo,_that.repliedToMessage,_that.type,_that.body,_that.attachments,_that.localMediaPath,_that.isFailed,_that.sentAt,_that.deletedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageModel extends MessageModel {
  const _MessageModel({required this.id, @JsonKey(name: 'chat_id') required this.chatId, @JsonKey(name: 'sender_id') this.senderId, @JsonKey(name: 'sender_name') this.senderName, @JsonKey(name: 'sender_profile_pic') this.senderProfilePic, @JsonKey(name: 'replied_to') this.repliedTo, @JsonKey(name: 'replied_to_message') final  Map<String, dynamic>? repliedToMessage, @JsonKey(fromJson: _messageTypeFromJson, toJson: _messageTypeToJson) this.type = MessageType.text, this.body, final  Map<String, dynamic>? attachments, @JsonKey(name: 'local_media_path') this.localMediaPath, @JsonKey(name: 'is_failed') this.isFailed = false, @JsonKey(name: 'sent_at') required this.sentAt, @JsonKey(name: 'deleted_at') this.deletedAt}): _repliedToMessage = repliedToMessage,_attachments = attachments,super._();
  factory _MessageModel.fromJson(Map<String, dynamic> json) => _$MessageModelFromJson(json);

@override final  String id;
@override@JsonKey(name: 'chat_id') final  String chatId;
@override@JsonKey(name: 'sender_id') final  String? senderId;
@override@JsonKey(name: 'sender_name') final  String? senderName;
@override@JsonKey(name: 'sender_profile_pic') final  String? senderProfilePic;
@override@JsonKey(name: 'replied_to') final  String? repliedTo;
// Server attaches a compact preview of the replied-to message so the
// client can render the reply container immediately without waiting for
// the original message to be paged into local DB. Untyped on purpose —
// we transiently use it to upsert a row into the messages table on
// insert, then it's not needed again.
 final  Map<String, dynamic>? _repliedToMessage;
// Server attaches a compact preview of the replied-to message so the
// client can render the reply container immediately without waiting for
// the original message to be paged into local DB. Untyped on purpose —
// we transiently use it to upsert a row into the messages table on
// insert, then it's not needed again.
@override@JsonKey(name: 'replied_to_message') Map<String, dynamic>? get repliedToMessage {
  final value = _repliedToMessage;
  if (value == null) return null;
  if (_repliedToMessage is EqualUnmodifiableMapView) return _repliedToMessage;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey(fromJson: _messageTypeFromJson, toJson: _messageTypeToJson) final  MessageType type;
@override final  String? body;
 final  Map<String, dynamic>? _attachments;
@override Map<String, dynamic>? get attachments {
  final value = _attachments;
  if (value == null) return null;
  if (_attachments is EqualUnmodifiableMapView) return _attachments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey(name: 'local_media_path') final  String? localMediaPath;
@override@JsonKey(name: 'is_failed') final  bool isFailed;
@override@JsonKey(name: 'sent_at') final  String sentAt;
@override@JsonKey(name: 'deleted_at') final  String? deletedAt;

/// Create a copy of MessageModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageModelCopyWith<_MessageModel> get copyWith => __$MessageModelCopyWithImpl<_MessageModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageModel&&(identical(other.id, id) || other.id == id)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.senderName, senderName) || other.senderName == senderName)&&(identical(other.senderProfilePic, senderProfilePic) || other.senderProfilePic == senderProfilePic)&&(identical(other.repliedTo, repliedTo) || other.repliedTo == repliedTo)&&const DeepCollectionEquality().equals(other._repliedToMessage, _repliedToMessage)&&(identical(other.type, type) || other.type == type)&&(identical(other.body, body) || other.body == body)&&const DeepCollectionEquality().equals(other._attachments, _attachments)&&(identical(other.localMediaPath, localMediaPath) || other.localMediaPath == localMediaPath)&&(identical(other.isFailed, isFailed) || other.isFailed == isFailed)&&(identical(other.sentAt, sentAt) || other.sentAt == sentAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,chatId,senderId,senderName,senderProfilePic,repliedTo,const DeepCollectionEquality().hash(_repliedToMessage),type,body,const DeepCollectionEquality().hash(_attachments),localMediaPath,isFailed,sentAt,deletedAt);

@override
String toString() {
  return 'MessageModel(id: $id, chatId: $chatId, senderId: $senderId, senderName: $senderName, senderProfilePic: $senderProfilePic, repliedTo: $repliedTo, repliedToMessage: $repliedToMessage, type: $type, body: $body, attachments: $attachments, localMediaPath: $localMediaPath, isFailed: $isFailed, sentAt: $sentAt, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class _$MessageModelCopyWith<$Res> implements $MessageModelCopyWith<$Res> {
  factory _$MessageModelCopyWith(_MessageModel value, $Res Function(_MessageModel) _then) = __$MessageModelCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'chat_id') String chatId,@JsonKey(name: 'sender_id') String? senderId,@JsonKey(name: 'sender_name') String? senderName,@JsonKey(name: 'sender_profile_pic') String? senderProfilePic,@JsonKey(name: 'replied_to') String? repliedTo,@JsonKey(name: 'replied_to_message') Map<String, dynamic>? repliedToMessage,@JsonKey(fromJson: _messageTypeFromJson, toJson: _messageTypeToJson) MessageType type, String? body, Map<String, dynamic>? attachments,@JsonKey(name: 'local_media_path') String? localMediaPath,@JsonKey(name: 'is_failed') bool isFailed,@JsonKey(name: 'sent_at') String sentAt,@JsonKey(name: 'deleted_at') String? deletedAt
});




}
/// @nodoc
class __$MessageModelCopyWithImpl<$Res>
    implements _$MessageModelCopyWith<$Res> {
  __$MessageModelCopyWithImpl(this._self, this._then);

  final _MessageModel _self;
  final $Res Function(_MessageModel) _then;

/// Create a copy of MessageModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? chatId = null,Object? senderId = freezed,Object? senderName = freezed,Object? senderProfilePic = freezed,Object? repliedTo = freezed,Object? repliedToMessage = freezed,Object? type = null,Object? body = freezed,Object? attachments = freezed,Object? localMediaPath = freezed,Object? isFailed = null,Object? sentAt = null,Object? deletedAt = freezed,}) {
  return _then(_MessageModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,senderId: freezed == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String?,senderName: freezed == senderName ? _self.senderName : senderName // ignore: cast_nullable_to_non_nullable
as String?,senderProfilePic: freezed == senderProfilePic ? _self.senderProfilePic : senderProfilePic // ignore: cast_nullable_to_non_nullable
as String?,repliedTo: freezed == repliedTo ? _self.repliedTo : repliedTo // ignore: cast_nullable_to_non_nullable
as String?,repliedToMessage: freezed == repliedToMessage ? _self._repliedToMessage : repliedToMessage // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as MessageType,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,attachments: freezed == attachments ? _self._attachments : attachments // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,localMediaPath: freezed == localMediaPath ? _self.localMediaPath : localMediaPath // ignore: cast_nullable_to_non_nullable
as String?,isFailed: null == isFailed ? _self.isFailed : isFailed // ignore: cast_nullable_to_non_nullable
as bool,sentAt: null == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as String,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$MessagesAroundResponse {

 List<MessageModel> get messages; List<Map<String, dynamic>> get members;@JsonKey(name: 'has_older') bool get hasOlder;@JsonKey(name: 'has_newer') bool get hasNewer;
/// Create a copy of MessagesAroundResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessagesAroundResponseCopyWith<MessagesAroundResponse> get copyWith => _$MessagesAroundResponseCopyWithImpl<MessagesAroundResponse>(this as MessagesAroundResponse, _$identity);

  /// Serializes this MessagesAroundResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagesAroundResponse&&const DeepCollectionEquality().equals(other.messages, messages)&&const DeepCollectionEquality().equals(other.members, members)&&(identical(other.hasOlder, hasOlder) || other.hasOlder == hasOlder)&&(identical(other.hasNewer, hasNewer) || other.hasNewer == hasNewer));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(messages),const DeepCollectionEquality().hash(members),hasOlder,hasNewer);

@override
String toString() {
  return 'MessagesAroundResponse(messages: $messages, members: $members, hasOlder: $hasOlder, hasNewer: $hasNewer)';
}


}

/// @nodoc
abstract mixin class $MessagesAroundResponseCopyWith<$Res>  {
  factory $MessagesAroundResponseCopyWith(MessagesAroundResponse value, $Res Function(MessagesAroundResponse) _then) = _$MessagesAroundResponseCopyWithImpl;
@useResult
$Res call({
 List<MessageModel> messages, List<Map<String, dynamic>> members,@JsonKey(name: 'has_older') bool hasOlder,@JsonKey(name: 'has_newer') bool hasNewer
});




}
/// @nodoc
class _$MessagesAroundResponseCopyWithImpl<$Res>
    implements $MessagesAroundResponseCopyWith<$Res> {
  _$MessagesAroundResponseCopyWithImpl(this._self, this._then);

  final MessagesAroundResponse _self;
  final $Res Function(MessagesAroundResponse) _then;

/// Create a copy of MessagesAroundResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messages = null,Object? members = null,Object? hasOlder = null,Object? hasNewer = null,}) {
  return _then(_self.copyWith(
messages: null == messages ? _self.messages : messages // ignore: cast_nullable_to_non_nullable
as List<MessageModel>,members: null == members ? _self.members : members // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,hasOlder: null == hasOlder ? _self.hasOlder : hasOlder // ignore: cast_nullable_to_non_nullable
as bool,hasNewer: null == hasNewer ? _self.hasNewer : hasNewer // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [MessagesAroundResponse].
extension MessagesAroundResponsePatterns on MessagesAroundResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessagesAroundResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessagesAroundResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessagesAroundResponse value)  $default,){
final _that = this;
switch (_that) {
case _MessagesAroundResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessagesAroundResponse value)?  $default,){
final _that = this;
switch (_that) {
case _MessagesAroundResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<MessageModel> messages,  List<Map<String, dynamic>> members, @JsonKey(name: 'has_older')  bool hasOlder, @JsonKey(name: 'has_newer')  bool hasNewer)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessagesAroundResponse() when $default != null:
return $default(_that.messages,_that.members,_that.hasOlder,_that.hasNewer);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<MessageModel> messages,  List<Map<String, dynamic>> members, @JsonKey(name: 'has_older')  bool hasOlder, @JsonKey(name: 'has_newer')  bool hasNewer)  $default,) {final _that = this;
switch (_that) {
case _MessagesAroundResponse():
return $default(_that.messages,_that.members,_that.hasOlder,_that.hasNewer);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<MessageModel> messages,  List<Map<String, dynamic>> members, @JsonKey(name: 'has_older')  bool hasOlder, @JsonKey(name: 'has_newer')  bool hasNewer)?  $default,) {final _that = this;
switch (_that) {
case _MessagesAroundResponse() when $default != null:
return $default(_that.messages,_that.members,_that.hasOlder,_that.hasNewer);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessagesAroundResponse implements MessagesAroundResponse {
  const _MessagesAroundResponse({required final  List<MessageModel> messages, final  List<Map<String, dynamic>> members = const <Map<String, dynamic>>[], @JsonKey(name: 'has_older') this.hasOlder = false, @JsonKey(name: 'has_newer') this.hasNewer = false}): _messages = messages,_members = members;
  factory _MessagesAroundResponse.fromJson(Map<String, dynamic> json) => _$MessagesAroundResponseFromJson(json);

 final  List<MessageModel> _messages;
@override List<MessageModel> get messages {
  if (_messages is EqualUnmodifiableListView) return _messages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messages);
}

 final  List<Map<String, dynamic>> _members;
@override@JsonKey() List<Map<String, dynamic>> get members {
  if (_members is EqualUnmodifiableListView) return _members;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_members);
}

@override@JsonKey(name: 'has_older') final  bool hasOlder;
@override@JsonKey(name: 'has_newer') final  bool hasNewer;

/// Create a copy of MessagesAroundResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessagesAroundResponseCopyWith<_MessagesAroundResponse> get copyWith => __$MessagesAroundResponseCopyWithImpl<_MessagesAroundResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessagesAroundResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessagesAroundResponse&&const DeepCollectionEquality().equals(other._messages, _messages)&&const DeepCollectionEquality().equals(other._members, _members)&&(identical(other.hasOlder, hasOlder) || other.hasOlder == hasOlder)&&(identical(other.hasNewer, hasNewer) || other.hasNewer == hasNewer));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_messages),const DeepCollectionEquality().hash(_members),hasOlder,hasNewer);

@override
String toString() {
  return 'MessagesAroundResponse(messages: $messages, members: $members, hasOlder: $hasOlder, hasNewer: $hasNewer)';
}


}

/// @nodoc
abstract mixin class _$MessagesAroundResponseCopyWith<$Res> implements $MessagesAroundResponseCopyWith<$Res> {
  factory _$MessagesAroundResponseCopyWith(_MessagesAroundResponse value, $Res Function(_MessagesAroundResponse) _then) = __$MessagesAroundResponseCopyWithImpl;
@override @useResult
$Res call({
 List<MessageModel> messages, List<Map<String, dynamic>> members,@JsonKey(name: 'has_older') bool hasOlder,@JsonKey(name: 'has_newer') bool hasNewer
});




}
/// @nodoc
class __$MessagesAroundResponseCopyWithImpl<$Res>
    implements _$MessagesAroundResponseCopyWith<$Res> {
  __$MessagesAroundResponseCopyWithImpl(this._self, this._then);

  final _MessagesAroundResponse _self;
  final $Res Function(_MessagesAroundResponse) _then;

/// Create a copy of MessagesAroundResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messages = null,Object? members = null,Object? hasOlder = null,Object? hasNewer = null,}) {
  return _then(_MessagesAroundResponse(
messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as List<MessageModel>,members: null == members ? _self._members : members // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,hasOlder: null == hasOlder ? _self.hasOlder : hasOlder // ignore: cast_nullable_to_non_nullable
as bool,hasNewer: null == hasNewer ? _self.hasNewer : hasNewer // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$ConversationHistoryResponse {

 List<MessageModel> get messages;@JsonKey(name: 'has_more') bool get hasMore; List<Map<String, dynamic>> get members;
/// Create a copy of ConversationHistoryResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationHistoryResponseCopyWith<ConversationHistoryResponse> get copyWith => _$ConversationHistoryResponseCopyWithImpl<ConversationHistoryResponse>(this as ConversationHistoryResponse, _$identity);

  /// Serializes this ConversationHistoryResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationHistoryResponse&&const DeepCollectionEquality().equals(other.messages, messages)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&const DeepCollectionEquality().equals(other.members, members));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(messages),hasMore,const DeepCollectionEquality().hash(members));

@override
String toString() {
  return 'ConversationHistoryResponse(messages: $messages, hasMore: $hasMore, members: $members)';
}


}

/// @nodoc
abstract mixin class $ConversationHistoryResponseCopyWith<$Res>  {
  factory $ConversationHistoryResponseCopyWith(ConversationHistoryResponse value, $Res Function(ConversationHistoryResponse) _then) = _$ConversationHistoryResponseCopyWithImpl;
@useResult
$Res call({
 List<MessageModel> messages,@JsonKey(name: 'has_more') bool hasMore, List<Map<String, dynamic>> members
});




}
/// @nodoc
class _$ConversationHistoryResponseCopyWithImpl<$Res>
    implements $ConversationHistoryResponseCopyWith<$Res> {
  _$ConversationHistoryResponseCopyWithImpl(this._self, this._then);

  final ConversationHistoryResponse _self;
  final $Res Function(ConversationHistoryResponse) _then;

/// Create a copy of ConversationHistoryResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messages = null,Object? hasMore = null,Object? members = null,}) {
  return _then(_self.copyWith(
messages: null == messages ? _self.messages : messages // ignore: cast_nullable_to_non_nullable
as List<MessageModel>,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,members: null == members ? _self.members : members // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,
  ));
}

}


/// Adds pattern-matching-related methods to [ConversationHistoryResponse].
extension ConversationHistoryResponsePatterns on ConversationHistoryResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConversationHistoryResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConversationHistoryResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConversationHistoryResponse value)  $default,){
final _that = this;
switch (_that) {
case _ConversationHistoryResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConversationHistoryResponse value)?  $default,){
final _that = this;
switch (_that) {
case _ConversationHistoryResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<MessageModel> messages, @JsonKey(name: 'has_more')  bool hasMore,  List<Map<String, dynamic>> members)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConversationHistoryResponse() when $default != null:
return $default(_that.messages,_that.hasMore,_that.members);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<MessageModel> messages, @JsonKey(name: 'has_more')  bool hasMore,  List<Map<String, dynamic>> members)  $default,) {final _that = this;
switch (_that) {
case _ConversationHistoryResponse():
return $default(_that.messages,_that.hasMore,_that.members);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<MessageModel> messages, @JsonKey(name: 'has_more')  bool hasMore,  List<Map<String, dynamic>> members)?  $default,) {final _that = this;
switch (_that) {
case _ConversationHistoryResponse() when $default != null:
return $default(_that.messages,_that.hasMore,_that.members);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ConversationHistoryResponse implements ConversationHistoryResponse {
  const _ConversationHistoryResponse({required final  List<MessageModel> messages, @JsonKey(name: 'has_more') this.hasMore = false, final  List<Map<String, dynamic>> members = const <Map<String, dynamic>>[]}): _messages = messages,_members = members;
  factory _ConversationHistoryResponse.fromJson(Map<String, dynamic> json) => _$ConversationHistoryResponseFromJson(json);

 final  List<MessageModel> _messages;
@override List<MessageModel> get messages {
  if (_messages is EqualUnmodifiableListView) return _messages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messages);
}

@override@JsonKey(name: 'has_more') final  bool hasMore;
 final  List<Map<String, dynamic>> _members;
@override@JsonKey() List<Map<String, dynamic>> get members {
  if (_members is EqualUnmodifiableListView) return _members;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_members);
}


/// Create a copy of ConversationHistoryResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConversationHistoryResponseCopyWith<_ConversationHistoryResponse> get copyWith => __$ConversationHistoryResponseCopyWithImpl<_ConversationHistoryResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConversationHistoryResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConversationHistoryResponse&&const DeepCollectionEquality().equals(other._messages, _messages)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&const DeepCollectionEquality().equals(other._members, _members));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_messages),hasMore,const DeepCollectionEquality().hash(_members));

@override
String toString() {
  return 'ConversationHistoryResponse(messages: $messages, hasMore: $hasMore, members: $members)';
}


}

/// @nodoc
abstract mixin class _$ConversationHistoryResponseCopyWith<$Res> implements $ConversationHistoryResponseCopyWith<$Res> {
  factory _$ConversationHistoryResponseCopyWith(_ConversationHistoryResponse value, $Res Function(_ConversationHistoryResponse) _then) = __$ConversationHistoryResponseCopyWithImpl;
@override @useResult
$Res call({
 List<MessageModel> messages,@JsonKey(name: 'has_more') bool hasMore, List<Map<String, dynamic>> members
});




}
/// @nodoc
class __$ConversationHistoryResponseCopyWithImpl<$Res>
    implements _$ConversationHistoryResponseCopyWith<$Res> {
  __$ConversationHistoryResponseCopyWithImpl(this._self, this._then);

  final _ConversationHistoryResponse _self;
  final $Res Function(_ConversationHistoryResponse) _then;

/// Create a copy of ConversationHistoryResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messages = null,Object? hasMore = null,Object? members = null,}) {
  return _then(_ConversationHistoryResponse(
messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as List<MessageModel>,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,members: null == members ? _self._members : members // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,
  ));
}


}

// dart format on
