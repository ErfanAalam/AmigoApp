import 'package:freezed_annotation/freezed_annotation.dart';

part 'call.model.freezed.dart';
part 'call.model.g.dart';

enum CallStatus {
  initiated('initiated'),
  ringing('ringing'),
  connecting('connecting'),
  answered('answered'),
  ended('ended'),
  missed('missed'),
  declined('declined');

  const CallStatus(this.value);
  final String value;

  static CallStatus fromString(String? status) {
    final value = status ?? 'ended';
    for (final s in CallStatus.values) {
      if (s.value == value) return s;
    }
    return CallStatus.ended;
  }
}

enum CallType { outgoing, incoming }

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  if (s.isEmpty) return null;
  try {
    return DateTime.parse(s);
  } catch (_) {
    return null;
  }
}

@freezed
abstract class CallModel with _$CallModel {
  const CallModel._();

  const factory CallModel({
    required String id,
    @JsonKey(name: 'caller_id') required String callerId,
    @JsonKey(name: 'callee_id') required String calleeId,
    @JsonKey(name: 'contact_id') required String contactId,
    @JsonKey(name: 'contact_name') @Default('Unknown') String contactName,
    @JsonKey(name: 'contact_profile_pic') String? contactProfilePic,
    @JsonKey(name: 'started_at') required DateTime startedAt,
    @JsonKey(name: 'answered_at') DateTime? answeredAt,
    @JsonKey(name: 'ended_at') DateTime? endedAt,
    @JsonKey(name: 'duration_seconds') @Default(0) int durationSeconds,
    @Default(CallStatus.ended) CallStatus status,
    String? reason,
    @JsonKey(name: 'call_type') @Default(CallType.outgoing) CallType callType,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _CallModel;

  factory CallModel.fromJson(Map<String, dynamic> json) =>
      _$CallModelFromJson(json);

  /// Build a CallModel from a backend JSON blob, deriving [callType] from
  /// [currentUserId] when present.
  factory CallModel.fromBackend(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final callerId = json['caller_id']?.toString() ?? '';
    final calleeId = json['callee_id']?.toString() ?? '';
    final CallType callType;
    if (currentUserId != null) {
      callType = calleeId == currentUserId
          ? CallType.incoming
          : CallType.outgoing;
    } else {
      final s = (json['call_type'] ?? 'outgoing').toString();
      callType = s == 'incoming' ? CallType.incoming : CallType.outgoing;
    }
    final contactIdRaw = json['contact_id']?.toString();
    final contactId = (contactIdRaw != null && contactIdRaw.isNotEmpty)
        ? contactIdRaw
        : (callerId == currentUserId ? calleeId : callerId);
    final statusStr = json['status']?.toString();
    return CallModel(
      id: json['id']?.toString() ?? '',
      callerId: callerId,
      calleeId: calleeId,
      contactId: contactId,
      contactName: json['contact_name']?.toString() ?? 'Unknown',
      contactProfilePic: json['contact_profile_pic']?.toString(),
      startedAt: _parseDate(json['started_at']) ?? DateTime.now(),
      answeredAt: _parseDate(json['answered_at']),
      endedAt: _parseDate(json['ended_at']),
      durationSeconds: (json['duration_seconds'] is int)
          ? json['duration_seconds'] as int
          : int.tryParse(json['duration_seconds']?.toString() ?? '0') ?? 0,
      status: CallStatus.fromString(statusStr),
      reason: json['reason']?.toString(),
      callType: callType,
      createdAt: _parseDate(json['created_at']) ??
          _parseDate(json['started_at']) ??
          DateTime.now(),
    );
  }
}

class CallSignalingMessage {
  final String type;
  final String? callId;
  final String? from;
  final String? to;
  final Map<String, dynamic>? payload;
  final String? timestamp;

  CallSignalingMessage({
    required this.type,
    this.callId,
    this.from,
    this.to,
    this.payload,
    this.timestamp,
  });

  factory CallSignalingMessage.fromJson(Map<String, dynamic> json) {
    return CallSignalingMessage(
      type: json['type']?.toString() ?? '',
      callId: json['callId']?.toString(),
      from: json['from']?.toString(),
      to: json['to']?.toString(),
      payload: json['payload'] as Map<String, dynamic>?,
      timestamp: json['timestamp']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'callId': callId,
      'from': from,
      'to': to,
      'payload': payload,
      'timestamp': timestamp,
    };
  }
}

class ActiveCallState {
  final String callId;
  final String userId;
  final String userName;
  final String? userProfilePic;
  final CallType callType;
  final CallStatus status;
  final DateTime startTime;
  final Duration? duration;
  final bool isMuted;
  final bool isSpeakerOn;
  final bool isOnHold;

  ActiveCallState({
    required this.callId,
    required this.userId,
    required this.userName,
    this.userProfilePic,
    required this.callType,
    required this.status,
    required this.startTime,
    this.duration,
    this.isMuted = false,
    this.isSpeakerOn = false,
    this.isOnHold = false,
  });

  ActiveCallState copyWith({
    String? callId,
    String? userId,
    String? userName,
    String? userProfilePic,
    CallType? callType,
    CallStatus? status,
    DateTime? startTime,
    Duration? duration,
    bool? isMuted,
    bool? isSpeakerOn,
    bool? isOnHold,
  }) {
    return ActiveCallState(
      callId: callId ?? this.callId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userProfilePic: userProfilePic ?? this.userProfilePic,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isOnHold: isOnHold ?? this.isOnHold,
    );
  }
}

class CallDetails {
  final String? callId;
  final String? callerId;
  final String? callerName;
  final String? callerProfilePic;
  final String? callStatus;

  CallDetails({
    this.callId,
    this.callerId,
    this.callerName,
    this.callerProfilePic,
    this.callStatus,
  });

  factory CallDetails.fromJson(Map<String, dynamic> json) {
    return CallDetails(
      callId: json['call_id']?.toString(),
      callerId: json['caller_id']?.toString(),
      callerName: json['caller_name']?.toString(),
      callerProfilePic: json['caller_profile_pic']?.toString(),
      callStatus: json['call_status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'call_id': callId,
        'caller_id': callerId,
        'caller_name': callerName,
        'caller_profile_pic': callerProfilePic,
        'call_status': callStatus,
      };

  CallDetails copyWith({
    String? callId,
    String? callerId,
    String? callerName,
    String? callerProfilePic,
    String? callStatus,
  }) {
    return CallDetails(
      callId: callId ?? this.callId,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerProfilePic: callerProfilePic ?? this.callerProfilePic,
      callStatus: callStatus ?? this.callStatus,
    );
  }

  CallStatus? get statusEnum =>
      callStatus == null ? null : CallStatus.fromString(callStatus);

  bool get isActive => callStatus == 'ringing' || callStatus == 'answered';
}
