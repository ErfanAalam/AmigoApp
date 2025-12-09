import 'package:drift/drift.dart';
import '../../models/user.model.dart';
import '../sqlite.db.dart';
import '../sqlite.schema.dart';

class ContactsRepository {
  final sqliteDatabase = SqliteDatabase.instance;

  /// Insert multiple contacts (bulk insert)
  Future<void> insertContacts(List<UserModel> contacts) async {
    final db = sqliteDatabase.database;

    for (final contact in contacts) {
      // Check if contact already exists to preserve existing values
      final existingContact = await (db.select(
        db.contacts,
      )..where((t) => t.id.equals(contact.id))).getSingleOrNull();

      // For required fields (name, phone), preserve if new value is empty
      final contactCompanion = ContactsCompanion.insert(
        id: Value(contact.id),
        name: contact.name.isEmpty && existingContact != null
            ? existingContact.name
            : contact.name,
        phone: contact.phone.isEmpty && existingContact != null
            ? existingContact.phone
            : contact.phone,
        profilePic: Value(contact.profilePic ?? existingContact?.profilePic),
      );
      await db.into(db.contacts).insertOnConflictUpdate(contactCompanion);
    }
  }

  /// Get all contacts and convert to UserModel list
  Future<List<UserModel>> getAllContacts() async {
    final db = sqliteDatabase.database;
    final contacts = await db.select(db.contacts).get();

    // Convert Contact (Drift data class) to UserModel
    return contacts.map((contact) {
      return UserModel(
        id: contact.id,
        name: contact.name,
        phone: contact.phone,
        role: 'User', // Default role since Contacts table doesn't have role
        profilePic: contact.profilePic,
        isOnline: false,
        callAccess: false,
      );
    }).toList();
  }

  /// Replace all contacts (clear existing and insert new ones)
  Future<void> replaceAllContacts(List<UserModel> contacts) async {
    final db = sqliteDatabase.database;

    await db.transaction(() async {
      // Clear all existing contacts
      await db.delete(db.contacts).go();

      // Insert new contacts
      for (final contact in contacts) {
        final contactCompanion = ContactsCompanion.insert(
          id: Value(contact.id),
          name: contact.name,
          phone: contact.phone,
          profilePic: Value(contact.profilePic),
        );
        await db.into(db.contacts).insert(contactCompanion);
      }
    });
  }

  /// Clear all contacts
  Future<void> clearAllContacts() async {
    final db = sqliteDatabase.database;
    await db.delete(db.contacts).go();
  }
}
