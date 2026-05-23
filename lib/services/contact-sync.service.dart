import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../db/sqlite.db.dart';
import '../db/sqlite.schema.dart';

/// Reconciles the local `contacts` table with the device address book + the
/// rows currently in the `users` table. Pure offline operation — no backend
/// hit. The backend is only needed to find new available users; renames /
/// deletions / additions in the device address book are picked up here for
/// users we already know about.
///
/// Reactive consumers pick up the changes automatically:
///   • `watchMessages`, `watchStarredMessages`, `watchActiveGroupMembers`
///     already JOIN contacts in their Drift query → Drift re-fires the
///     stream when the contacts table is written.
///   • `watchDmConversations` / `watchGroupConversations` use `asyncMap`
///     with imperative contact lookups, so Drift can't see the dependency.
///     We patch that by calling `db.markTablesUpdated({db.chats})` after a
///     successful sync — that re-fires those watchers manually.
class ContactSyncService {
  static final ContactSyncService _instance = ContactSyncService._internal();
  factory ContactSyncService() => _instance;
  ContactSyncService._internal();

  /// Last successful sync timestamp; used to debounce app-resume triggers.
  DateTime? _lastSyncAt;

  /// Guards against re-entry when two triggers fire close together (e.g.
  /// app-resume right after the post-launch sync).
  bool _inFlight = false;

  /// Minimum gap between two automatic syncs. Manual triggers (e.g. pull
  /// to refresh on the contacts page) should pass `force: true`.
  static const Duration _debounce = Duration(seconds: 30);

  /// Run a full local sync. Returns true if the contacts table actually
  /// changed (so callers can log / react if they care).
  ///
  /// `force` skips the debounce — use from explicit user actions.
  Future<bool> sync({bool force = false}) async {
    if (_inFlight) return false;
    final now = DateTime.now();
    if (!force &&
        _lastSyncAt != null &&
        now.difference(_lastSyncAt!) < _debounce) {
      return false;
    }
    _inFlight = true;
    try {
      final changed = await _runSync();
      _lastSyncAt = DateTime.now();
      return changed;
    } catch (e) {
      debugPrint('[ContactSync] sync failed: $e');
      return false;
    } finally {
      _inFlight = false;
    }
  }

  Future<bool> _runSync() async {
    // We never want this service to prompt for the permission — that flow
    // belongs to the contacts screen. If the user hasn't granted it yet
    // there's nothing to sync against.
    final hasPermission = await FlutterContacts.requestPermission(
      readonly: true,
    );
    if (!hasPermission) return false;

    // Pull only what we need (display name + phones). withProperties=true is
    // required for phones to be present on the returned contacts.
    final deviceContacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );

    // phone → device-contact display name. A device contact may list
    // multiple phone numbers; index each so users matched on any number
    // resolve correctly. Empty display names are ignored — they'd give us
    // a blank label.
    final phoneToName = <String, String>{};
    for (final c in deviceContacts) {
      final name = c.displayName.trim();
      if (name.isEmpty) continue;
      for (final p in c.phones) {
        final raw = p.number.trim();
        if (raw.isEmpty) continue;
        // Index both the raw and the digits-only form so different stored
        // formats ("+1 415 555…", "+14155551234") still match against the
        // server-stored phone.
        phoneToName.putIfAbsent(raw, () => name);
        final digits = _digitsOnly(raw);
        if (digits.isNotEmpty) phoneToName.putIfAbsent(digits, () => name);
      }
    }

    final db = SqliteDatabase.instance.database;
    final users = await db.select(db.users).get();
    final existingContacts = await db.select(db.contacts).get();
    final existingById = {for (final c in existingContacts) c.id: c};

    final toUpsert = <ContactsCompanion>[];
    final desiredIds = <String>{};

    for (final user in users) {
      final matched = _lookupName(phoneToName, user.phone);
      if (matched == null) continue;
      desiredIds.add(user.id);

      final existing = existingById[user.id];
      if (existing != null &&
          existing.name == matched &&
          existing.phone == user.phone &&
          existing.profilePic == user.profilePic) {
        continue; // unchanged, skip
      }
      toUpsert.add(
        ContactsCompanion.insert(
          id: user.id,
          name: matched,
          phone: user.phone,
          profilePic: Value(user.profilePic),
        ),
      );
    }

    // Rows in the contacts table whose user no longer has a matching device
    // contact — drop them so the server name takes over again.
    final toDeleteIds = existingById.keys
        .where((id) => !desiredIds.contains(id))
        .toList();

    final changed = toUpsert.isNotEmpty || toDeleteIds.isNotEmpty;
    if (!changed) return false;

    await db.transaction(() async {
      for (final companion in toUpsert) {
        await db.into(db.contacts).insertOnConflictUpdate(companion);
      }
      if (toDeleteIds.isNotEmpty) {
        await (db.delete(
          db.contacts,
        )..where((t) => t.id.isIn(toDeleteIds))).go();
      }
    });

    // The DM/group list watchers can't see the contacts dependency (they
    // use asyncMap with imperative lookups). Force them to re-emit so the
    // new contact names propagate to those screens immediately.
    db.markTablesUpdated({db.chats});

    debugPrint(
      '[ContactSync] applied ${toUpsert.length} upserts, '
      '${toDeleteIds.length} deletions',
    );
    return true;
  }

  /// Server-stored phones aren't normalized. Try the raw match first, then
  /// fall back to a digits-only comparison.
  String? _lookupName(Map<String, String> phoneToName, String userPhone) {
    final direct = phoneToName[userPhone];
    if (direct != null) return direct;
    final digits = _digitsOnly(userPhone);
    if (digits.isEmpty) return null;
    return phoneToName[digits];
  }

  String _digitsOnly(String input) {
    final sb = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final c = input.codeUnitAt(i);
      if (c >= 0x30 && c <= 0x39) sb.writeCharCode(c);
    }
    return sb.toString();
  }
}
