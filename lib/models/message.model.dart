import 'package:amigo/types/socket.types.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.model.freezed.dart';
part 'message.model.g.dart';

MessageType _messageTypeFromJson(dynamic v) =>
    MessageType.fromString(v?.toString()) ?? MessageType.text;
String _messageTypeToJson(MessageType t) => t.value;

@freezed
abstract class MessageModel with _$MessageModel {
  const MessageModel._();

  const factory MessageModel({
    required String id,
    @JsonKey(name: 'chat_id') required String chatId,
    @JsonKey(name: 'sender_id') String? senderId,
    @JsonKey(name: 'sender_name') String? senderName,
    @JsonKey(name: 'sender_profile_pic') String? senderProfilePic,
    @JsonKey(name: 'replied_to') String? repliedTo,
    // Server attaches a compact preview of the replied-to message so the
    // client can render the reply container immediately without waiting for
    // the original message to be paged into local DB. Untyped on purpose —
    // we transiently use it to upsert a row into the messages table on
    // insert, then it's not needed again.
    @JsonKey(name: 'replied_to_message') Map<String, dynamic>? repliedToMessage,
    @JsonKey(
      fromJson: _messageTypeFromJson,
      toJson: _messageTypeToJson,
    )
    @Default(MessageType.text)
    MessageType type,
    String? body,
    Map<String, dynamic>? attachments,
    @JsonKey(name: 'local_media_path') String? localMediaPath,
    @JsonKey(name: 'is_failed') @Default(false) bool isFailed,
    @JsonKey(name: 'sent_at') required String sentAt,
    @JsonKey(name: 'deleted_at') String? deletedAt,
    // Disappearing-messages deadline (ISO-8601). Server stamps this on
    // message:new when the chat has the feature enabled. The view layer
    // filters expired-but-not-deleted rows; the row is only soft-deleted
    // when the server's message:delete event arrives.
    @JsonKey(name: 'expires_at') String? expiresAt,
  }) = _MessageModel;

  factory MessageModel.fromJson(Map<String, dynamic> json) =>
      _$MessageModelFromJson(_normalize(json));

  /// Tolerate legacy / alternate keys from various server paths.
  static Map<String, dynamic> _normalize(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['message_id'] ?? '').toString();
    final chatId =
        (json['chat_id'] ?? json['conv_id'] ?? json['conversation_id'] ?? '')
            .toString();
    final sentAt = (json['sent_at'] ??
            json['created_at'] ??
            DateTime.now().toIso8601String())
        .toString();
    return <String, dynamic>{
      ...json,
      'id': id,
      'chat_id': chatId,
      'sender_id': json['sender_id']?.toString(),
      'sent_at': sentAt,
    };
  }

  bool get isText => type == MessageType.text;
  bool get isImage => type == MessageType.image;
  bool get isFile => type == MessageType.document;
  bool get isVideo => type == MessageType.video;
  bool get isAudio => type == MessageType.audio;
  bool get isReply => repliedTo != null;
  bool get isForwardedMessage => type == MessageType.forwarded;
  bool get isDeleted => deletedAt != null;

  /// Returns true when this message has a disappearing deadline that has
  /// already passed. Used by the view layer to hide expired messages until
  /// the authoritative server-side message:delete event arrives. The local
  /// row is intentionally NOT soft-deleted here — see chat.provider docs.
  bool isExpiredAt(DateTime now) {
    final exp = expiresAt;
    if (exp == null) return false;
    final dt = DateTime.tryParse(exp);
    return dt != null && !dt.isAfter(now);
  }
}

@freezed
abstract class MessagesAroundResponse with _$MessagesAroundResponse {
  const factory MessagesAroundResponse({
    required List<MessageModel> messages,
    @Default(<Map<String, dynamic>>[]) List<Map<String, dynamic>> members,
    @JsonKey(name: 'has_older') @Default(false) bool hasOlder,
    @JsonKey(name: 'has_newer') @Default(false) bool hasNewer,
  }) = _MessagesAroundResponse;

  factory MessagesAroundResponse.fromJson(Map<String, dynamic> json) =>
      _$MessagesAroundResponseFromJson(json);
}

@freezed
abstract class ConversationHistoryResponse with _$ConversationHistoryResponse {
  const factory ConversationHistoryResponse({
    required List<MessageModel> messages,
    @JsonKey(name: 'has_more') @Default(false) bool hasMore,
    @Default(<Map<String, dynamic>>[]) List<Map<String, dynamic>> members,
  }) = _ConversationHistoryResponse;

  factory ConversationHistoryResponse.fromJson(Map<String, dynamic> json) =>
      _$ConversationHistoryResponseFromJson(json);
}
