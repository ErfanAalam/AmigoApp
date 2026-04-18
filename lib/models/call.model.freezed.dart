// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'call.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CallModel {

 String get id;@JsonKey(name: 'caller_id') String get callerId;@JsonKey(name: 'callee_id') String get calleeId;@JsonKey(name: 'contact_id') String get contactId;@JsonKey(name: 'contact_name') String get contactName;@JsonKey(name: 'contact_profile_pic') String? get contactProfilePic;@JsonKey(name: 'started_at') DateTime get startedAt;@JsonKey(name: 'answered_at') DateTime? get answeredAt;@JsonKey(name: 'ended_at') DateTime? get endedAt;@JsonKey(name: 'duration_seconds') int get durationSeconds; CallStatus get status; String? get reason;@JsonKey(name: 'call_type') CallType get callType;@JsonKey(name: 'created_at') DateTime get createdAt;
/// Create a copy of CallModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CallModelCopyWith<CallModel> get copyWith => _$CallModelCopyWithImpl<CallModel>(this as CallModel, _$identity);

  /// Serializes this CallModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CallModel&&(identical(other.id, id) || other.id == id)&&(identical(other.callerId, callerId) || other.callerId == callerId)&&(identical(other.calleeId, calleeId) || other.calleeId == calleeId)&&(identical(other.contactId, contactId) || other.contactId == contactId)&&(identical(other.contactName, contactName) || other.contactName == contactName)&&(identical(other.contactProfilePic, contactProfilePic) || other.contactProfilePic == contactProfilePic)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.answeredAt, answeredAt) || other.answeredAt == answeredAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.status, status) || other.status == status)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.callType, callType) || other.callType == callType)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,callerId,calleeId,contactId,contactName,contactProfilePic,startedAt,answeredAt,endedAt,durationSeconds,status,reason,callType,createdAt);

@override
String toString() {
  return 'CallModel(id: $id, callerId: $callerId, calleeId: $calleeId, contactId: $contactId, contactName: $contactName, contactProfilePic: $contactProfilePic, startedAt: $startedAt, answeredAt: $answeredAt, endedAt: $endedAt, durationSeconds: $durationSeconds, status: $status, reason: $reason, callType: $callType, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $CallModelCopyWith<$Res>  {
  factory $CallModelCopyWith(CallModel value, $Res Function(CallModel) _then) = _$CallModelCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'caller_id') String callerId,@JsonKey(name: 'callee_id') String calleeId,@JsonKey(name: 'contact_id') String contactId,@JsonKey(name: 'contact_name') String contactName,@JsonKey(name: 'contact_profile_pic') String? contactProfilePic,@JsonKey(name: 'started_at') DateTime startedAt,@JsonKey(name: 'answered_at') DateTime? answeredAt,@JsonKey(name: 'ended_at') DateTime? endedAt,@JsonKey(name: 'duration_seconds') int durationSeconds, CallStatus status, String? reason,@JsonKey(name: 'call_type') CallType callType,@JsonKey(name: 'created_at') DateTime createdAt
});




}
/// @nodoc
class _$CallModelCopyWithImpl<$Res>
    implements $CallModelCopyWith<$Res> {
  _$CallModelCopyWithImpl(this._self, this._then);

  final CallModel _self;
  final $Res Function(CallModel) _then;

/// Create a copy of CallModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? callerId = null,Object? calleeId = null,Object? contactId = null,Object? contactName = null,Object? contactProfilePic = freezed,Object? startedAt = null,Object? answeredAt = freezed,Object? endedAt = freezed,Object? durationSeconds = null,Object? status = null,Object? reason = freezed,Object? callType = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,callerId: null == callerId ? _self.callerId : callerId // ignore: cast_nullable_to_non_nullable
as String,calleeId: null == calleeId ? _self.calleeId : calleeId // ignore: cast_nullable_to_non_nullable
as String,contactId: null == contactId ? _self.contactId : contactId // ignore: cast_nullable_to_non_nullable
as String,contactName: null == contactName ? _self.contactName : contactName // ignore: cast_nullable_to_non_nullable
as String,contactProfilePic: freezed == contactProfilePic ? _self.contactProfilePic : contactProfilePic // ignore: cast_nullable_to_non_nullable
as String?,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,answeredAt: freezed == answeredAt ? _self.answeredAt : answeredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,durationSeconds: null == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CallStatus,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,callType: null == callType ? _self.callType : callType // ignore: cast_nullable_to_non_nullable
as CallType,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [CallModel].
extension CallModelPatterns on CallModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CallModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CallModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CallModel value)  $default,){
final _that = this;
switch (_that) {
case _CallModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CallModel value)?  $default,){
final _that = this;
switch (_that) {
case _CallModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'caller_id')  String callerId, @JsonKey(name: 'callee_id')  String calleeId, @JsonKey(name: 'contact_id')  String contactId, @JsonKey(name: 'contact_name')  String contactName, @JsonKey(name: 'contact_profile_pic')  String? contactProfilePic, @JsonKey(name: 'started_at')  DateTime startedAt, @JsonKey(name: 'answered_at')  DateTime? answeredAt, @JsonKey(name: 'ended_at')  DateTime? endedAt, @JsonKey(name: 'duration_seconds')  int durationSeconds,  CallStatus status,  String? reason, @JsonKey(name: 'call_type')  CallType callType, @JsonKey(name: 'created_at')  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CallModel() when $default != null:
return $default(_that.id,_that.callerId,_that.calleeId,_that.contactId,_that.contactName,_that.contactProfilePic,_that.startedAt,_that.answeredAt,_that.endedAt,_that.durationSeconds,_that.status,_that.reason,_that.callType,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'caller_id')  String callerId, @JsonKey(name: 'callee_id')  String calleeId, @JsonKey(name: 'contact_id')  String contactId, @JsonKey(name: 'contact_name')  String contactName, @JsonKey(name: 'contact_profile_pic')  String? contactProfilePic, @JsonKey(name: 'started_at')  DateTime startedAt, @JsonKey(name: 'answered_at')  DateTime? answeredAt, @JsonKey(name: 'ended_at')  DateTime? endedAt, @JsonKey(name: 'duration_seconds')  int durationSeconds,  CallStatus status,  String? reason, @JsonKey(name: 'call_type')  CallType callType, @JsonKey(name: 'created_at')  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _CallModel():
return $default(_that.id,_that.callerId,_that.calleeId,_that.contactId,_that.contactName,_that.contactProfilePic,_that.startedAt,_that.answeredAt,_that.endedAt,_that.durationSeconds,_that.status,_that.reason,_that.callType,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'caller_id')  String callerId, @JsonKey(name: 'callee_id')  String calleeId, @JsonKey(name: 'contact_id')  String contactId, @JsonKey(name: 'contact_name')  String contactName, @JsonKey(name: 'contact_profile_pic')  String? contactProfilePic, @JsonKey(name: 'started_at')  DateTime startedAt, @JsonKey(name: 'answered_at')  DateTime? answeredAt, @JsonKey(name: 'ended_at')  DateTime? endedAt, @JsonKey(name: 'duration_seconds')  int durationSeconds,  CallStatus status,  String? reason, @JsonKey(name: 'call_type')  CallType callType, @JsonKey(name: 'created_at')  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _CallModel() when $default != null:
return $default(_that.id,_that.callerId,_that.calleeId,_that.contactId,_that.contactName,_that.contactProfilePic,_that.startedAt,_that.answeredAt,_that.endedAt,_that.durationSeconds,_that.status,_that.reason,_that.callType,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CallModel extends CallModel {
  const _CallModel({required this.id, @JsonKey(name: 'caller_id') required this.callerId, @JsonKey(name: 'callee_id') required this.calleeId, @JsonKey(name: 'contact_id') required this.contactId, @JsonKey(name: 'contact_name') this.contactName = 'Unknown', @JsonKey(name: 'contact_profile_pic') this.contactProfilePic, @JsonKey(name: 'started_at') required this.startedAt, @JsonKey(name: 'answered_at') this.answeredAt, @JsonKey(name: 'ended_at') this.endedAt, @JsonKey(name: 'duration_seconds') this.durationSeconds = 0, this.status = CallStatus.ended, this.reason, @JsonKey(name: 'call_type') this.callType = CallType.outgoing, @JsonKey(name: 'created_at') required this.createdAt}): super._();
  factory _CallModel.fromJson(Map<String, dynamic> json) => _$CallModelFromJson(json);

@override final  String id;
@override@JsonKey(name: 'caller_id') final  String callerId;
@override@JsonKey(name: 'callee_id') final  String calleeId;
@override@JsonKey(name: 'contact_id') final  String contactId;
@override@JsonKey(name: 'contact_name') final  String contactName;
@override@JsonKey(name: 'contact_profile_pic') final  String? contactProfilePic;
@override@JsonKey(name: 'started_at') final  DateTime startedAt;
@override@JsonKey(name: 'answered_at') final  DateTime? answeredAt;
@override@JsonKey(name: 'ended_at') final  DateTime? endedAt;
@override@JsonKey(name: 'duration_seconds') final  int durationSeconds;
@override@JsonKey() final  CallStatus status;
@override final  String? reason;
@override@JsonKey(name: 'call_type') final  CallType callType;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;

/// Create a copy of CallModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CallModelCopyWith<_CallModel> get copyWith => __$CallModelCopyWithImpl<_CallModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CallModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CallModel&&(identical(other.id, id) || other.id == id)&&(identical(other.callerId, callerId) || other.callerId == callerId)&&(identical(other.calleeId, calleeId) || other.calleeId == calleeId)&&(identical(other.contactId, contactId) || other.contactId == contactId)&&(identical(other.contactName, contactName) || other.contactName == contactName)&&(identical(other.contactProfilePic, contactProfilePic) || other.contactProfilePic == contactProfilePic)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.answeredAt, answeredAt) || other.answeredAt == answeredAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.status, status) || other.status == status)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.callType, callType) || other.callType == callType)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,callerId,calleeId,contactId,contactName,contactProfilePic,startedAt,answeredAt,endedAt,durationSeconds,status,reason,callType,createdAt);

@override
String toString() {
  return 'CallModel(id: $id, callerId: $callerId, calleeId: $calleeId, contactId: $contactId, contactName: $contactName, contactProfilePic: $contactProfilePic, startedAt: $startedAt, answeredAt: $answeredAt, endedAt: $endedAt, durationSeconds: $durationSeconds, status: $status, reason: $reason, callType: $callType, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$CallModelCopyWith<$Res> implements $CallModelCopyWith<$Res> {
  factory _$CallModelCopyWith(_CallModel value, $Res Function(_CallModel) _then) = __$CallModelCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'caller_id') String callerId,@JsonKey(name: 'callee_id') String calleeId,@JsonKey(name: 'contact_id') String contactId,@JsonKey(name: 'contact_name') String contactName,@JsonKey(name: 'contact_profile_pic') String? contactProfilePic,@JsonKey(name: 'started_at') DateTime startedAt,@JsonKey(name: 'answered_at') DateTime? answeredAt,@JsonKey(name: 'ended_at') DateTime? endedAt,@JsonKey(name: 'duration_seconds') int durationSeconds, CallStatus status, String? reason,@JsonKey(name: 'call_type') CallType callType,@JsonKey(name: 'created_at') DateTime createdAt
});




}
/// @nodoc
class __$CallModelCopyWithImpl<$Res>
    implements _$CallModelCopyWith<$Res> {
  __$CallModelCopyWithImpl(this._self, this._then);

  final _CallModel _self;
  final $Res Function(_CallModel) _then;

/// Create a copy of CallModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? callerId = null,Object? calleeId = null,Object? contactId = null,Object? contactName = null,Object? contactProfilePic = freezed,Object? startedAt = null,Object? answeredAt = freezed,Object? endedAt = freezed,Object? durationSeconds = null,Object? status = null,Object? reason = freezed,Object? callType = null,Object? createdAt = null,}) {
  return _then(_CallModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,callerId: null == callerId ? _self.callerId : callerId // ignore: cast_nullable_to_non_nullable
as String,calleeId: null == calleeId ? _self.calleeId : calleeId // ignore: cast_nullable_to_non_nullable
as String,contactId: null == contactId ? _self.contactId : contactId // ignore: cast_nullable_to_non_nullable
as String,contactName: null == contactName ? _self.contactName : contactName // ignore: cast_nullable_to_non_nullable
as String,contactProfilePic: freezed == contactProfilePic ? _self.contactProfilePic : contactProfilePic // ignore: cast_nullable_to_non_nullable
as String?,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,answeredAt: freezed == answeredAt ? _self.answeredAt : answeredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,durationSeconds: null == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CallStatus,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,callType: null == callType ? _self.callType : callType // ignore: cast_nullable_to_non_nullable
as CallType,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
