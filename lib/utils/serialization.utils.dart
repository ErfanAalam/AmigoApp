/// Recursively converts string ID values (from BigInt) back to int.
/// This is necessary because the backend converts BigInt to strings for JSON serialization,
/// but Dart code expects int values.
///
/// [value] - The value to convert (can be any type)
/// Returns the value with all string ID values converted to int
dynamic convertStringIdsToInt(dynamic value) {
  // Handle null and undefined
  if (value == null) {
    return value;
  }

  // Handle arrays
  if (value is List) {
    return value.map((item) => convertStringIdsToInt(item)).toList();
  }

  // Handle maps/objects
  if (value is Map) {
    final converted = <String, dynamic>{};

    value.forEach((key, val) {
      final stringKey = key.toString();

      // Check if this is an ID field that should be converted from string to int
      if (_isIdField(stringKey)) {
        if (val is String) {
          // Try to parse as int (handles BigInt strings)
          final parsed = int.tryParse(val);
          if (parsed != null) {
            converted[stringKey] = parsed;
          } else {
            // If parsing fails, keep original value and recurse
            converted[stringKey] = convertStringIdsToInt(val);
          }
        } else if (val is List) {
          // Handle arrays of IDs (e.g., forwarded_to)
          // Convert each string item in the array to int
          converted[stringKey] = val.map((item) {
            if (item is String) {
              final parsed = int.tryParse(item);
              return parsed ?? item;
            }
            return convertStringIdsToInt(item);
          }).toList();
        } else {
          // Not a string or array - recurse to handle nested structures
          converted[stringKey] = convertStringIdsToInt(val);
        }
      } else {
        // Not an ID field - recurse to handle nested structures
        converted[stringKey] = convertStringIdsToInt(val);
      }
    });

    return converted;
  }

  // Return primitive values as-is
  return value;
}

/// Recursively converts BigInt ID values to String.
/// This is necessary when sending data to the backend, as BigInt values
/// need to be converted to strings for JSON serialization.
///
/// [value] - The value to convert (can be any type)
/// Returns the value with all BigInt ID values converted to String
dynamic convertBigIntIdsToString(dynamic value) {
  // Handle null and undefined
  if (value == null) {
    return value;
  }

  // Handle arrays
  if (value is List) {
    return value.map((item) => convertBigIntIdsToString(item)).toList();
  }

  // Handle maps/objects
  if (value is Map) {
    final converted = <String, dynamic>{};

    value.forEach((key, val) {
      final stringKey = key.toString();

      // Check if this is an ID field that should be converted from BigInt to String
      if (_isIdField(stringKey)) {
        if (val is BigInt) {
          // Convert BigInt to String
          converted[stringKey] = val.toString();
        } else if (val is int) {
          // Convert int to String (for consistency, as ints can represent BigInt values)
          converted[stringKey] = val.toString();
        } else if (val is List) {
          // Handle arrays of IDs (e.g., forwarded_to)
          // Convert each BigInt or int item in the array to String
          converted[stringKey] = val.map((item) {
            if (item is BigInt) {
              return item.toString();
            } else if (item is int) {
              return item.toString();
            }
            return convertBigIntIdsToString(item);
          }).toList();
        } else {
          // Not a BigInt or array - recurse to handle nested structures
          converted[stringKey] = convertBigIntIdsToString(val);
        }
      } else {
        // Not an ID field - recurse to handle nested structures
        converted[stringKey] = convertBigIntIdsToString(val);
      }
    });

    return converted;
  }

  // Return primitive values as-is
  return value;
}

/// Check if a field name is an ID field that should be converted from string to int
bool _isIdField(String fieldName) {
  // Common ID field patterns
  final idFields = [
    'id',
    'new_id',
    'message_id',
    'message_ids',
    'last_message_id',
    'last_read_message_id',
    'last_delivered_message_id',
    'lasthistory_delivered_message_id',
    'pinned_message_id',
    'reply_to_message_id',
    'forward_message_id',
    'forward_message_ids',
    'newId',
    'messageId',
    'messageIds',
    'lastMessageId',
    'lastReadMessageId',
    'lastDeliveredMessageId',
    'lasthistoryDeliveredMessageId',
    'pinnedMessageId',
    'replyToMessageId',
    'forwardMessageId',
    'forwardMessageIds',
  ];

  // Check exact match
  if (idFields.contains(fieldName)) {
    return true;
  }

  // // Check if field name ends with _id
  // if (fieldName.endsWith('_id')) {
  //   return true;
  // }

  return false;
}
