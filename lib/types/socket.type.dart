/// Chat type enum
enum ChatType {
  dm('dm'),
  group('group'),
  communityGroup('community_group');

  final String value;
  const ChatType(this.value);

  static ChatType? fromString(String? value) {
    if (value == null) return null;
    return ChatType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ChatType.dm,
    );
  }
}

/// Connection status enum
enum ConnectionStatusType {
  forground('foreground'),
  background('background'),
  disconnected('disconnected'),
  stale('stale');

  final String value;
  const ConnectionStatusType(this.value);

  static ConnectionStatusType? fromString(String? value) {
    if (value == null) return null;
    return ConnectionStatusType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ConnectionStatusType.background,
    );
  }
}

/// Message type enum
enum MessageType {
  text('text'),
  image('image'),
  video('video'),
  audio('audio'),
  document('document'),
  reply('reply'),
  forwarded('forwarded'),
  system('system'),
  attachment('attachment'),
  reaction('reaction');

  final String value;
  const MessageType(this.value);

  static MessageType? fromString(String? value) {
    if (value == null) return null;
    return MessageType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MessageType.text,
    );
  }
}

/// Message status type enum
enum MessageStatusType {
  unsent('unsent'),
  sent('sent'),
  delivered('delivered'),
  read('read'),
  failed('failed');

  final String value;
  const MessageStatusType(this.value);

  static MessageStatusType? fromString(String? value) {
    if (value == null) return null;
    return MessageStatusType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MessageStatusType.sent,
    );
  }
}

/// Chat role type enum
enum ChatRoleType {
  member('member'),
  admin('admin');

  final String value;
  const ChatRoleType(this.value);

  static ChatRoleType? fromString(String? value) {
    if (value == null) return null;
    return ChatRoleType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ChatRoleType.member,
    );
  }
}

/// WebSocket message type enum
enum WSMessageType {
  connectionStatus('connection:status'),
  conversationJoin('conversation:join'),
  conversationLeave('conversation:leave'),
  conversationNew('conversation:new'),
  conversationTyping('conversation:typing'),
  messageNew('message:new'),
  messageAck('message:ack'),
  messagePin('message:pin'),
  messageReply('message:reply'),
  messageForward('message:forward'),
  messageDelete('message:delete'),
  callInit('call:init'),
  callInitAck('call:init:ack'),
  callOffer('call:offer'),
  callAnswer('call:answer'),
  callIce('call:ice'),
  callAccept('call:accept'),
  callDecline('call:decline'),
  callEnd('call:end'),
  callRinging('call:ringing'),
  callMissed('call:missed'),
  callError('call:error'),
  socketHealthCheck('socket:health_check'),
  ping('ping'),
  pong('pong'),
  socketError('socket:error');

  final String value;
  const WSMessageType(this.value);

  static WSMessageType? fromString(String? value) {
    if (value == null) return null;
    try {
      return WSMessageType.values.firstWhere((e) => e.value == value);
    } catch (e) {
      return null;
    }
  }
}

/// Online status payload
class ConnectionStatus {
  final int senderId;
  final String status;

  ConnectionStatus({required this.senderId, required this.status});

  factory ConnectionStatus.fromJson(Map<String, dynamic> json) {
    return ConnectionStatus(
      senderId: json['sender_id'] as int,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'sender_id': senderId, 'status': status};
  }
}

/// Join/Leave payload
class JoinLeavePayload {
  final int convId;
  final ChatType convType;
  final int userId;
  final String? userName;

  JoinLeavePayload({
    required this.convId,
    required this.convType,
    required this.userId,
    this.userName,
  });

  factory JoinLeavePayload.fromJson(Map<String, dynamic> json) {
    return JoinLeavePayload(
      convId: json['conv_id'] as int,
      convType:
          ChatType.fromString(json['conv_type'] as String?) ?? ChatType.dm,
      userId: json['user_id'] as int,
      userName: json['user_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conv_id': convId,
      'conv_type': convType.value,
      'user_id': userId,
      if (userName != null) 'user_name': userName,
    };
  }
}

/// Chat message payload
class ChatMessagePayload {
  final int optimisticId;
  final int? canonicalId;
  final int senderId;
  final String? senderName;
  final int convId;
  final ChatType convType;
  final MessageType msgType;
  final String? body;
  final dynamic attachments;
  final dynamic metadata;
  final int? replyToMessageId;
  final DateTime sentAt;

  ChatMessagePayload({
    required this.optimisticId,
    this.canonicalId,
    required this.senderId,
    this.senderName,
    required this.convId,
    required this.convType,
    required this.msgType,
    this.body,
    this.attachments,
    this.metadata,
    this.replyToMessageId,
    required this.sentAt,
  });

  factory ChatMessagePayload.fromJson(Map<String, dynamic> json) {
    DateTime sentAt;
    try {
      final sentAtData = json['sent_at'];
      if (sentAtData is String) {
        sentAt = DateTime.parse(sentAtData);
      } else if (sentAtData is DateTime) {
        sentAt = sentAtData;
      } else {
        sentAt = DateTime.now();
      }
    } catch (e) {
      sentAt = DateTime.now();
    }

    return ChatMessagePayload(
      optimisticId: json['optimistic_id'] as int,
      canonicalId: json['canonical_id'] as int?,
      senderId: json['sender_id'] as int,
      senderName: json['sender_name'] as String?,
      convId: json['conv_id'] as int,
      convType:
          ChatType.fromString(json['conv_type'] as String?) ?? ChatType.dm,
      msgType:
          MessageType.fromString(json['msg_type'] as String?) ??
          MessageType.text,
      body: json['body'] as String?,
      attachments: json['attachments'],
      metadata: json['metadata'],
      replyToMessageId: json['reply_to_message_id'] as int?,
      sentAt: sentAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'optimistic_id': optimisticId,
      if (canonicalId != null) 'canonical_id': canonicalId,
      'sender_id': senderId,
      if (senderName != null) 'sender_name': senderName,
      'conv_id': convId,
      'conv_type': convType.value,
      'msg_type': msgType.value,
      if (body != null) 'body': body,
      if (attachments != null) 'attachments': attachments,
      if (metadata != null) 'metadata': metadata,
      if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      'sent_at': sentAt.toIso8601String(),
    };
  }
}

/// Chat message acknowledgment payload
class ChatMessageAckPayload {
  final int optimisticId;
  final int canonicalId;
  final int convId;
  final int senderId;
  final DateTime deliveredAt;
  final List<int>? deliveredTo;
  final List<int>? readBy;
  final List<int>? offlineUsers;

  ChatMessageAckPayload({
    required this.optimisticId,
    required this.canonicalId,
    required this.convId,
    required this.senderId,
    required this.deliveredAt,
    this.deliveredTo,
    this.readBy,
    this.offlineUsers,
  });

  factory ChatMessageAckPayload.fromJson(Map<String, dynamic> json) {
    DateTime deliveredAt;
    try {
      // Try delivered_at first, then sent_at as fallback, then use current time
      final deliveredAtData = json['delivered_at'] ?? json['sent_at'];
      if (deliveredAtData is String) {
        deliveredAt = DateTime.parse(deliveredAtData);
      } else if (deliveredAtData is DateTime) {
        deliveredAt = deliveredAtData;
      } else {
        deliveredAt = DateTime.now();
      }
    } catch (e) {
      deliveredAt = DateTime.now();
    }

    return ChatMessageAckPayload(
      optimisticId: json['optimistic_id'] as int,
      canonicalId: json['canonical_id'] as int,
      convId: json['conv_id'] as int,
      senderId: json['sender_id'] as int,
      deliveredAt: deliveredAt,
      deliveredTo: json['delivered_to'] != null
          ? (json['delivered_to'] as List<dynamic>)
                .map((e) => e as int)
                .toList()
          : null,
      readBy: json['read_by'] != null
          ? (json['read_by'] as List<dynamic>).map((e) => e as int).toList()
          : null,
      offlineUsers: json['offline_users'] != null
          ? (json['offline_users'] as List<dynamic>)
                .map((e) => e as int)
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'optimistic_id': optimisticId,
      'canonical_id': canonicalId,
      'conv_id': convId,
      'sender_id': senderId,
      'delivered_at': deliveredAt.toIso8601String(),
      if (deliveredTo != null) 'delivered_to': deliveredTo,
      if (readBy != null) 'read_by': readBy,
      if (offlineUsers != null) 'offline_users': offlineUsers,
    };
  }
}

/// Typing payload for conversation typing indicators
class TypingPayload {
  final int convId;
  final int senderId;
  final String? senderName;
  final String? senderPfp;
  final bool isTyping;

  TypingPayload({
    required this.convId,
    required this.senderId,
    this.senderName,
    this.senderPfp,
    required this.isTyping,
  });

  /// Create TypingPayload from JSON/Map
  factory TypingPayload.fromJson(Map<String, dynamic> json) {
    return TypingPayload(
      convId: json['conv_id'] as int,
      senderId: json['sender_id'] as int,
      senderName: json['sender_name'] as String?,
      senderPfp: json['sender_pfp'] as String?,
      isTyping: json['is_typing'] as bool,
    );
  }

  /// Convert TypingPayload to JSON/Map
  Map<String, dynamic> toJson() {
    return {
      'conv_id': convId,
      'sender_id': senderId,
      if (senderName != null) 'sender_name': senderName,
      if (senderPfp != null) 'sender_pfp': senderPfp,
      'is_typing': isTyping,
    };
  }
}

/// Delete message payload
class DeleteMessagePayload {
  final int convId;
  final int senderId;
  final List<int> messageIds;

  DeleteMessagePayload({
    required this.convId,
    required this.senderId,
    required this.messageIds,
  });

  factory DeleteMessagePayload.fromJson(Map<String, dynamic> json) {
    return DeleteMessagePayload(
      convId: json['conv_id'] as int,
      senderId: json['sender_id'] as int,
      messageIds: (json['message_ids'] as List<dynamic>)
          .map((e) => e as int)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conv_id': convId,
      'sender_id': senderId,
      'message_ids': messageIds,
    };
  }
}

/// Member type for conversation members
class MembersType {
  final int userId;
  final String userName;
  final String? userPfp;
  final ChatRoleType role;
  final DateTime joinedAt;

  MembersType({
    required this.userId,
    required this.userName,
    this.userPfp,
    required this.role,
    required this.joinedAt,
  });

  factory MembersType.fromJson(Map<String, dynamic> json) {
    DateTime joinedAt;
    try {
      final joinedAtData = json['joined_at'];
      if (joinedAtData is String) {
        joinedAt = DateTime.parse(joinedAtData);
      } else if (joinedAtData is DateTime) {
        joinedAt = joinedAtData;
      } else {
        joinedAt = DateTime.now();
      }
    } catch (e) {
      joinedAt = DateTime.now();
    }

    return MembersType(
      userId: json['user_id'] as int,
      userName: json['user_name'] as String,
      userPfp: json['user_pfp'] as String?,
      role:
          ChatRoleType.fromString(json['role'] as String?) ??
          ChatRoleType.member,
      joinedAt: joinedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      if (userPfp != null) 'user_pfp': userPfp,
      'role': role.value,
      'joined_at': joinedAt.toIso8601String(),
    };
  }
}

/// New conversation payload
class NewConversationPayload {
  final int convId;
  final ChatType convType;
  final String? title;
  final int createrId;
  final String createrName;
  final String createrPhone;
  final String? createrPfp;
  final List<MembersType>? members;
  final DateTime joinedAt;

  NewConversationPayload({
    required this.convId,
    required this.convType,
    this.title,
    required this.createrId,
    required this.createrName,
    required this.createrPhone,
    this.createrPfp,
    this.members,
    required this.joinedAt,
  });

  factory NewConversationPayload.fromJson(Map<String, dynamic> json) {
    DateTime joinedAt;
    try {
      final joinedAtData = json['joined_at'];
      if (joinedAtData is String) {
        joinedAt = DateTime.parse(joinedAtData);
      } else if (joinedAtData is DateTime) {
        joinedAt = joinedAtData;
      } else {
        joinedAt = DateTime.now();
      }
    } catch (e) {
      joinedAt = DateTime.now();
    }

    return NewConversationPayload(
      convId: json['conv_id'] as int,
      convType:
          ChatType.fromString(json['conv_type'] as String?) ?? ChatType.dm,
      title: json['title'] as String?,
      createrId: json['creater_id'] as int,
      createrName: json['creater_name'] as String,
      createrPhone: json['creater_phone'] as String,
      createrPfp: json['creater_pfp'] as String?,
      members: json['members'] != null
          ? (json['members'] as List<dynamic>)
                .map((e) => MembersType.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
      joinedAt: joinedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conv_id': convId,
      'conv_type': convType.value,
      if (title != null) 'title': title,
      'creater_id': createrId,
      'creater_name': createrName,
      'creater_phone': createrPhone,
      if (createrPfp != null) 'creater_pfp': createrPfp,
      if (members != null) 'members': members!.map((e) => e.toJson()).toList(),
      'joined_at': joinedAt.toIso8601String(),
    };
  }
}

/// Miscellaneous payload
class MiscPayload {
  final String message;
  final dynamic data;
  final int? code;
  final dynamic error;

  MiscPayload({required this.message, this.data, this.code, this.error});

  factory MiscPayload.fromJson(Map<String, dynamic> json) {
    return MiscPayload(
      message: json['message'] as String,
      data: json['data'],
      code: json['code'] as int?,
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      if (data != null) 'data': data,
      if (code != null) 'code': code,
      if (error != null) 'error': error,
    };
  }
}

/// Message pin payload
class MessagePinPayload {
  final int convId;
  final int messageId;
  final MessageType messageType;
  final int senderId;
  final String? senderName;
  final String? senderPfp;
  final bool pin;

  MessagePinPayload({
    required this.convId,
    required this.messageId,
    required this.messageType,
    required this.senderId,
    this.senderName,
    this.senderPfp,
    required this.pin,
  });

  factory MessagePinPayload.fromJson(Map<String, dynamic> json) {
    return MessagePinPayload(
      convId: json['conv_id'] as int,
      messageId: json['message_id'] as int,
      messageType:
          MessageType.fromString(json['message_type'] as String?) ??
          MessageType.text,
      senderId: json['sender_id'] as int,
      senderName: json['sender_name'] as String?,
      senderPfp: json['sender_pfp'] as String?,
      pin: json['pin'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conv_id': convId,
      'message_id': messageId,
      'message_type': messageType.value,
      'sender_id': senderId,
      if (senderName != null) 'sender_name': senderName,
      if (senderPfp != null) 'sender_pfp': senderPfp,
      'pin': pin,
    };
  }
}

/// Message forward payload
class MessageForwardPayload {
  final int sourceConvId;
  final int forwarderId;
  final String? forwarderName;
  final List<int> forwardedMessageIds;
  final List<int> targetConvIds;

  MessageForwardPayload({
    required this.sourceConvId,
    required this.forwarderId,
    this.forwarderName,
    required this.forwardedMessageIds,
    required this.targetConvIds,
  });

  factory MessageForwardPayload.fromJson(Map<String, dynamic> json) {
    return MessageForwardPayload(
      sourceConvId: json['source_conv_id'] as int,
      forwarderId: json['forwarder_id'] as int,
      forwarderName: json['forwarder_name'] as String?,
      forwardedMessageIds: (json['forwarded_message_ids'] as List<dynamic>)
          .map((e) => e as int)
          .toList(),
      targetConvIds: (json['target_conv_ids'] as List<dynamic>)
          .map((e) => e as int)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source_conv_id': sourceConvId,
      'forwarder_id': forwarderId,
      if (forwarderName != null) 'forwarder_name': forwarderName,
      'forwarded_message_ids': forwardedMessageIds,
      'target_conv_ids': targetConvIds,
    };
  }
}

/// Call payload
class CallPayload {
  final int? callId;
  final int callerId;
  final String? callerName;
  final String? callerPfp;
  final int calleeId;
  final String? calleeName;
  final String? calleePfp;
  final dynamic data;
  final dynamic error;
  final DateTime? timestamp;

  CallPayload({
    this.callId,
    required this.callerId,
    this.callerName,
    this.callerPfp,
    required this.calleeId,
    this.calleeName,
    this.calleePfp,
    this.data,
    this.error,
    this.timestamp,
  });

  factory CallPayload.fromJson(Map<String, dynamic> json) {
    DateTime? timestamp;
    try {
      final timestampData = json['timestamp'];
      if (timestampData != null) {
        if (timestampData is String) {
          timestamp = DateTime.parse(timestampData);
        } else if (timestampData is DateTime) {
          timestamp = timestampData;
        }
      }
    } catch (e) {
      // Ignore timestamp parsing errors
    }

    return CallPayload(
      callId: json['call_id'] as int?,
      callerId: json['caller_id'] as int,
      callerName: json['caller_name'] as String?,
      callerPfp: json['caller_pfp'] as String?,
      calleeId: json['callee_id'] as int,
      calleeName: json['callee_name'] as String?,
      calleePfp: json['callee_pfp'] as String?,
      data: json['data'],
      error: json['error'],
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (callId != null) 'call_id': callId,
      'caller_id': callerId,
      if (callerName != null) 'caller_name': callerName,
      if (callerPfp != null) 'caller_pfp': callerPfp,
      'callee_id': calleeId,
      if (calleeName != null) 'callee_name': calleeName,
      if (calleePfp != null) 'callee_pfp': calleePfp,
      if (data != null) 'data': data,
      if (error != null) 'error': error,
      if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
    };
  }
}

/// Media response type from the server

class MediaResponse {
  final String url;
  final String key;
  final String category;
  final String fileName;
  final int fileSize;
  final String mimeType;

  MediaResponse({
    required this.url,
    required this.key,
    required this.category,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
  });

  factory MediaResponse.fromJson(Map<String, dynamic> json) {
    return MediaResponse(
      url: json['url'] as String,
      key: json['key'] as String,
      category: json['category'] as String,
      fileName: json['file_name'] as String,
      fileSize: json['file_size'] as int,
      mimeType: json['mime_type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'key': key,
      'category': category,
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
    };
  }
}

/// WebSocket message wrapper
class WSMessage {
  final WSMessageType type;
  final dynamic payload; // Can be any of the payload types
  final DateTime? wsTimestamp;

  WSMessage({required this.type, this.payload, this.wsTimestamp});

  factory WSMessage.fromJson(Map<String, dynamic> json) {
    final typeString = json['type'] as String?;
    final type = WSMessageType.fromString(typeString);

    if (type == null) {
      throw FormatException('Unknown WebSocket message type: $typeString');
    }

    dynamic payload;
    final payloadData = json['payload'];
    if (payloadData != null && payloadData is Map<String, dynamic>) {
      try {
        payload = _parsePayload(type, payloadData);
      } catch (e) {
        // If payload parsing fails, keep raw payload
        payload = payloadData;
      }
    }

    DateTime? wsTimestamp;
    final timestampData = json['ws_timestamp'];
    if (timestampData != null) {
      try {
        if (timestampData is String) {
          wsTimestamp = DateTime.parse(timestampData);
        } else if (timestampData is DateTime) {
          wsTimestamp = timestampData;
        }
      } catch (e) {
        // Ignore timestamp parsing errors
      }
    }

    return WSMessage(type: type, payload: payload, wsTimestamp: wsTimestamp);
  }

  static dynamic _parsePayload(
    WSMessageType type,
    Map<String, dynamic> payloadJson,
  ) {
    switch (type) {
      case WSMessageType.connectionStatus:
        return ConnectionStatus.fromJson(payloadJson);
      case WSMessageType.conversationJoin:
        return JoinLeavePayload.fromJson(payloadJson);
      case WSMessageType.conversationLeave:
        return JoinLeavePayload.fromJson(payloadJson);
      case WSMessageType.conversationNew:
        return NewConversationPayload.fromJson(payloadJson);
      case WSMessageType.conversationTyping:
        return TypingPayload.fromJson(payloadJson);
      case WSMessageType.messageNew:
        return ChatMessagePayload.fromJson(payloadJson);
      case WSMessageType.messageAck:
        return ChatMessageAckPayload.fromJson(payloadJson);
      case WSMessageType.messagePin:
        return MessagePinPayload.fromJson(payloadJson);
      case WSMessageType.messageForward:
        return MessageForwardPayload.fromJson(payloadJson);
      case WSMessageType.messageDelete:
        return DeleteMessagePayload.fromJson(payloadJson);
      case WSMessageType.callInit:
      case WSMessageType.callInitAck:
      case WSMessageType.callOffer:
      case WSMessageType.callAnswer:
      case WSMessageType.callIce:
      case WSMessageType.callAccept:
      case WSMessageType.callDecline:
      case WSMessageType.callEnd:
      case WSMessageType.callRinging:
      case WSMessageType.callMissed:
      case WSMessageType.callError:
        try {
          return CallPayload.fromJson(payloadJson);
        } catch (e) {
          // If parsing fails, return raw payload
          return payloadJson;
        }
      case WSMessageType.ping:
      case WSMessageType.pong:
      case WSMessageType.socketHealthCheck:
      case WSMessageType.socketError:
        return MiscPayload.fromJson(payloadJson);
      default:
        // For other types, return raw payload
        return payloadJson;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      if (payload != null) 'payload': _payloadToJson(payload),
      if (wsTimestamp != null) 'ws_timestamp': wsTimestamp!.toIso8601String(),
    };
  }

  dynamic _payloadToJson(dynamic payload) {
    if (payload is ConnectionStatus) return payload.toJson();
    if (payload is JoinLeavePayload) return payload.toJson();
    if (payload is ChatMessagePayload) return payload.toJson();
    if (payload is ChatMessageAckPayload) return payload.toJson();
    if (payload is TypingPayload) return payload.toJson();
    if (payload is DeleteMessagePayload) return payload.toJson();
    if (payload is NewConversationPayload) return payload.toJson();
    if (payload is MiscPayload) return payload.toJson();
    if (payload is MessagePinPayload) return payload.toJson();
    if (payload is MessageForwardPayload) return payload.toJson();
    if (payload is CallPayload) return payload.toJson();
    return payload;
  }

  /// Type-safe getters for payloads
  ConnectionStatus? get onlineStatusPayload =>
      payload is ConnectionStatus ? payload : null;

  JoinLeavePayload? get joinLeavePayload =>
      payload is JoinLeavePayload ? payload : null;

  ChatMessagePayload? get chatMessagePayload =>
      payload is ChatMessagePayload ? payload : null;

  ChatMessageAckPayload? get chatMessageAckPayload =>
      payload is ChatMessageAckPayload ? payload : null;

  TypingPayload? get typingPayload => payload is TypingPayload ? payload : null;

  DeleteMessagePayload? get deleteMessagePayload =>
      payload is DeleteMessagePayload ? payload : null;

  NewConversationPayload? get newConversationPayload =>
      payload is NewConversationPayload ? payload : null;

  MiscPayload? get miscPayload => payload is MiscPayload ? payload : null;

  MessagePinPayload? get messagePinPayload =>
      payload is MessagePinPayload ? payload : null;

  MessageForwardPayload? get messageForwardPayload =>
      payload is MessageForwardPayload ? payload : null;

  CallPayload? get callPayload => payload is CallPayload ? payload : null;
}
