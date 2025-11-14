import 'package:amigo/models/user_model.dart';
import '../sqlite.db.dart';
import '../sqlite.schema.dart';

class ContactsRepository {
  final sqliteDatabase = SqliteDatabase.instance;

  Future<void> insertContacts(UserModel contacts) async {
    final db = sqliteDatabase.database;
    final contact = ContactsCompanion.insert(
      name: contacts.name,
      phone: contacts.phone,
    );
    // await db.insert(db.contacts, contact);
  }
}
