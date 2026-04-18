import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Client-generated monotonic message ID. One ID per message, used end-to-end
/// (optimistic row, WS payload, server PK). Never rewritten on ACK.
String newMessageId() => _uuid.v7();

/// Random client event / correlation ID. Not monotonic.
String newClientEventId() => _uuid.v4();

/// Per-event correlation ID used to tie ACKs back to the originating send.
String correlationId(String userId, String event, String msgId) =>
    '$userId:$event:$msgId';
