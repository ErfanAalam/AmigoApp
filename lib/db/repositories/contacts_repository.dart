import 'package:amigo/models/user_model.dart';
import 'package:drift/drift.dart';
import '../sqlite.db.dart';
import '../sqlite.schema.dart';

class ContactsRepository {
  final sqliteDatabase = SqliteDatabase.instance;

  /// Insert a single contact
  Future<void> insertContact(UserModel contact) async {
    final db = sqliteDatabase.database;
    final contactCompanion = ContactsCompanion.insert(
      id: Value(contact.id),
      name: contact.name,
      phone: contact.phone,
      profilePic: Value(contact.profilePic),
    );

    await db.into(db.contacts).insertOnConflictUpdate(contactCompanion);
  }

  /// Insert multiple contacts (bulk insert)
  Future<void> insertContacts(List<UserModel> contacts) async {
    final db = sqliteDatabase.database;

    for (final contact in contacts) {
      final contactCompanion = ContactsCompanion.insert(
        id: Value(contact.id),
        name: contact.name,
        phone: contact.phone,
        profilePic: Value(contact.profilePic),
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
        callAccess:
            false, // Default since Contacts table doesn't have callAccess
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
