import 'package:freezed_annotation/freezed_annotation.dart';

part 'message-status.model.freezed.dart';
part 'message-status.model.g.dart';

/// Per-user message state: delivery, read, reaction, "delete for me".
/// Mirrors the backend `message_info` table.
@freezed
abstract class MessageInfoModel with _$MessageInfoModel {
  const factory MessageInfoModel({
    required String id,
    @JsonKey(name: 'chat_id') required String chatId,
    @JsonKey(name: 'message_id') required String messageId,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'delivered_at') String? deliveredAt,
    @JsonKey(name: 'read_at') String? readAt,
    String? reaction,
    @JsonKey(name: 'deleted_at') String? deletedAt,
  }) = _MessageInfoModel;

  factory MessageInfoModel.fromJson(Map<String, dynamic> json) =>
      _$MessageInfoModelFromJson(json);
}

typedef MessageStatusModel = MessageInfoModel;
