class CallModel {
  final int id;
  final int callerId;
  final int calleeId;
  final DateTime startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final CallStatus status;
  final String? reason;
  final DateTime createdAt;

  CallModel({
    required this.id,
    required this.callerId,
    required this.calleeId,
    required this.startedAt,
    this.answeredAt,
    this.endedAt,
    required this.durationSeconds,
    required this.status,
    this.reason,
    required this.createdAt,
  });

  factory CallModel.fromJson(Map<String, dynamic> json) {
    return CallModel(
      id: json['id'],
      callerId: json['caller_id'],
      calleeId: json['callee_id'],
      startedAt: DateTime.parse(json['started_at']),
      answeredAt: json['answered_at'] != null
          ? DateTime.parse(json['answered_at'])
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'])
          : null,
      durationSeconds: json['duration_seconds'] ?? 0,
      status: CallStatus.fromString(json['status']),
      reason: json['reason'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caller_id': callerId,
      'callee_id': calleeId,
      'started_at': startedAt.toIso8601String(),
      'answered_at': answeredAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'status': status.value,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

enum CallStatus {
  initiated('initiated'),
  ringing('ringing'),
  answered('answered'),
  ended('ended'),
  missed('missed'),
  declined('declined');

  const CallStatus(this.value);
  final String value;

  static CallStatus fromString(String status) {
    return CallStatus.values.firstWhere((e) => e.value == status);
  }
}

enum CallType { outgoing, incoming }

class CallSignalingMessage {
  final String type;
  final int? callId;
  final int? from;
  final int? to;
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
      type: json['type'],
      callId: json['callId'],
      from: json['from'],
      to: json['to'],
      payload: json['payload'],
      timestamp: json['timestamp'],
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
  final int callId;
  final int userId;
  final String userName;
  final String? userProfilePic;
  final CallType callType;
  final CallStatus status;
  final DateTime startTime;
  final Duration? duration;
  final bool isMuted;
  final bool isSpeakerOn;

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
  });

  ActiveCallState copyWith({
    int? callId,
    int? userId,
    String? userName,
    String? userProfilePic,
    CallType? callType,
    CallStatus? status,
    DateTime? startTime,
    Duration? duration,
    bool? isMuted,
    bool? isSpeakerOn,
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
    );
  }
}
