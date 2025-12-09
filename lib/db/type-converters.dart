import 'dart:convert';
import 'package:drift/drift.dart';

// Converter for Map<String, dynamic> (JSON objects)
class JsonMapConverter extends TypeConverter<Map<String, dynamic>?, String?> {
  const JsonMapConverter();

  @override
  Map<String, dynamic>? fromSql(String? fromDb) {
    if (fromDb == null) return null;
    try {
      return jsonDecode(fromDb) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  @override
  String? toSql(Map<String, dynamic>? value) {
    if (value == null) return null;
    return jsonEncode(value);
  }
}

// Converter for List<Map<String, dynamic>> (JSON arrays of objects)
class JsonListConverter
    extends TypeConverter<List<Map<String, dynamic>>?, String?> {
  const JsonListConverter();

  @override
  List<Map<String, dynamic>>? fromSql(String? fromDb) {
    if (fromDb == null) return null;
    try {
      final decoded = jsonDecode(fromDb);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  String? toSql(List<Map<String, dynamic>>? value) {
    if (value == null) return null;
    return jsonEncode(value);
  }
}
