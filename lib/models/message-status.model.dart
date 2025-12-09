class MessageStatusModel {
  final BigInt id;
  final int conversationId;
  final int messageId;
  final int userId;
  final String? deliveredAt;
  final String? readAt;

  MessageStatusModel({
    required this.id,
    required this.conversationId,
    required this.messageId,
    required this.userId,
    this.deliveredAt,
    this.readAt,
  });

  factory MessageStatusModel.fromJson(Map<String, dynamic> json) {
    return MessageStatusModel(
      id: json['id'],
      conversationId: json['conversation_id'],
      messageId: json['message_id'],
      userId: json['user_id'],
      deliveredAt: json['delivered_at'],
      readAt: json['read_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'message_id': messageId,
      'user_id': userId,
      'delivered_at': deliveredAt,
      'read_at': readAt,
    };
  }

  MessageStatusModel copyWith({
    BigInt? id,
    int? conversationId,
    int? messageId,
    int? userId,
    String? deliveredAt,
    String? readAt,
  }) {
    return MessageStatusModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      messageId: messageId ?? this.messageId,
      userId: userId ?? this.userId,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
    );
  }
}
