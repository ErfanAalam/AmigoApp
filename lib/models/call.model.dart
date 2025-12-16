class CallModel {
  final int id;
  final int callerId;
  final int calleeId;
  final int contactId;
  final String contactName;
  final String? contactProfilePic;
  final DateTime startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final CallStatus status;
  final String? reason;
  final CallType callType;
  final DateTime createdAt;

  CallModel({
    required this.id,
    required this.callerId,
    required this.calleeId,
    required this.contactId,
    required this.contactName,
    this.contactProfilePic,
    required this.startedAt,
    this.answeredAt,
    this.endedAt,
    required this.durationSeconds,
    required this.status,
    this.reason,
    required this.callType,
    required this.createdAt,
  });

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  factory CallModel.fromJson(Map<String, dynamic> json) {
    DateTime? tryParseDate(dynamic value) {
      if (value == null) return null;
      final s = value.toString();
      if (s.isEmpty) return null;
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    final String callTypeStr =
        (json['call_type'] ?? json['callType'] ?? 'outgoing').toString();

    return CallModel(
      id: _parseInt(json['id']),
      callerId: _parseInt(json['caller_id']),
      calleeId: _parseInt(json['callee_id']),
      contactId: _parseInt(json['contact_id']),
      contactName: json['contact_name']?.toString() ?? 'Unknown',
      contactProfilePic: json['contact_profile_pic']?.toString(),
      startedAt: tryParseDate(json['started_at']) ?? DateTime.now(),
      answeredAt: tryParseDate(json['answered_at']),
      endedAt: tryParseDate(json['ended_at']),
      durationSeconds: _parseInt(json['duration_seconds']),
      status: CallStatus.fromString(json['status']?.toString()),
      reason: json['reason']?.toString(),
      callType: callTypeStr == 'incoming'
          ? CallType.incoming
          : CallType.outgoing,
      createdAt:
          tryParseDate(json['created_at']) ??
          tryParseDate(json['started_at']) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caller_id': callerId,
      'callee_id': calleeId,
      'contact_id': contactId,
      'contact_name': contactName,
      'contact_profile_pic': contactProfilePic,
      'started_at': startedAt.toIso8601String(),
      'answered_at': answeredAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'status': status.value,
      'reason': reason,
      'call_type': callType == CallType.incoming ? 'incoming' : 'outgoing',
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

  static CallStatus fromString(String? status) {
    final String value = status ?? 'ended';
    for (final CallStatus s in CallStatus.values) {
      if (s.value == value) return s;
    }
    return CallStatus.ended;
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

class CallDetails {
  final int? callId;
  final int? callerId;
  final String? callerName;
  final String? callerProfilePic;
  final String?
  callStatus; // Stored as string: 'ringing', 'answered', 'declined', 'missed', 'ended'

  CallDetails({
    this.callId,
    this.callerId,
    this.callerName,
    this.callerProfilePic,
    this.callStatus,
  });

  factory CallDetails.fromJson(Map<String, dynamic> json) {
    return CallDetails(
      callId: json['call_id'] != null
          ? (json['call_id'] is int
                ? json['call_id']
                : int.tryParse(json['call_id'].toString()))
          : null,
      callerId: json['caller_id'] != null
          ? (json['caller_id'] is int
                ? json['caller_id']
                : int.tryParse(json['caller_id'].toString()))
          : null,
      callerName: json['caller_name']?.toString(),
      callerProfilePic: json['caller_profile_pic']?.toString(),
      callStatus: json['call_status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'call_id': callId,
      'caller_id': callerId,
      'caller_name': callerName,
      'caller_profile_pic': callerProfilePic,
      'call_status': callStatus,
    };
  }

  CallDetails copyWith({
    int? callId,
    int? callerId,
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

  // Helper method to convert callStatus string to CallStatus enum
  CallStatus? get statusEnum {
    if (callStatus == null) return null;
    return CallStatus.fromString(callStatus);
  }

  // Helper method to check if call is active
  bool get isActive {
    return callStatus == 'ringing' || callStatus == 'answered';
  }

  @override
  String toString() {
    return 'CallDetails(callId: $callId, callerId: $callerId, callerName: $callerName, callerProfilePic: $callerProfilePic, callStatus: $callStatus)';
  }
}
