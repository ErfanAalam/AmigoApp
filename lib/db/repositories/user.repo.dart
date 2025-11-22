import 'package:amigo/models/user_model.dart';
import 'package:drift/drift.dart';
import '../sqlite.db.dart';
import '../sqlite.schema.dart';

class UserRepository {
  final sqliteDatabase = SqliteDatabase.instance;

  /// Helper method to convert User row to UserModel
  UserModel _userToModel(User user) {
    return UserModel(
      id: user.id,
      name: user.name,
      phone: user.phone,
      role: user.role,
      profilePic: user.profilePic,
      isOnline: user.isOnline,
      callAccess: user.callAccess,
    );
  }

  /// Insert a single user
  Future<void> insertUser(UserModel user) async {
    final db = sqliteDatabase.database;

    // Check if user already exists to preserve existing values
    final existingUser = await getUserById(user.id);

    // For required fields (name, phone), preserve if new value is empty
    // For optional fields, preserve if new value is null
    final userCompanion = UsersCompanion.insert(
      id: Value(user.id),
      name: user.name.isEmpty && existingUser != null
          ? existingUser.name
          : user.name,
      phone: user.phone.isEmpty && existingUser != null
          ? existingUser.phone
          : user.phone,
      role: Value(user.role ?? existingUser?.role),
      profilePic: Value(user.profilePic ?? existingUser?.profilePic),
      isOnline: existingUser != null ? existingUser.isOnline : user.isOnline,
      callAccess: Value(user.callAccess ?? existingUser?.callAccess ?? false),
    );

    await db.into(db.users).insertOnConflictUpdate(userCompanion);
  }

  /// Insert multiple users (bulk insert)
  Future<void> insertUsers(List<UserModel> users) async {
    final db = sqliteDatabase.database;

    for (final user in users) {
      // Check if user already exists to preserve existing values
      final existingUser = await getUserById(user.id);

      // For required fields (name, phone), preserve if new value is empty
      // For optional fields, preserve if new value is null
      final userCompanion = UsersCompanion.insert(
        id: Value(user.id),
        name: user.name.isEmpty && existingUser != null
            ? existingUser.name
            : user.name,
        phone: user.phone.isEmpty && existingUser != null
            ? existingUser.phone
            : user.phone,
        role: Value(user.role ?? existingUser?.role),
        profilePic: Value(user.profilePic ?? existingUser?.profilePic),
        isOnline: existingUser != null ? existingUser.isOnline : user.isOnline,
        callAccess: Value(user.callAccess ?? existingUser?.callAccess ?? false),
      );
      await db.into(db.users).insertOnConflictUpdate(userCompanion);
    }
  }

  /// Get all users
  Future<List<UserModel>> getAllUsers() async {
    final db = sqliteDatabase.database;
    final users = await db.select(db.users).get();

    return users.map((user) => _userToModel(user)).toList();
  }

  /// Get a user by ID
  Future<UserModel?> getUserById(int userId) async {
    final db = sqliteDatabase.database;

    final user = await (db.select(
      db.users,
    )..where((t) => t.id.equals(userId))).getSingleOrNull();

    if (user == null) return null;

    return _userToModel(user);
  }

  /// Get a user by phone number
  Future<UserModel?> getUserByPhone(String phone) async {
    final db = sqliteDatabase.database;

    final user = await (db.select(
      db.users,
    )..where((t) => t.phone.equals(phone))).getSingleOrNull();

    if (user == null) return null;

    return _userToModel(user);
  }

  /// Get users by role
  Future<List<UserModel>> getUsersByRole(String role) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.users)
      ..where((t) => t.role.equals(role))
      ..orderBy([
        (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
      ]);

    final users = await query.get();

    return users.map((user) => _userToModel(user)).toList();
  }

  /// Search users by name (case-insensitive partial match)
  Future<List<UserModel>> searchUsersByName(String searchQuery) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.users)
      ..where((t) => t.name.like('%$searchQuery%'))
      ..orderBy([
        (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
      ]);

    final users = await query.get();

    return users.map((user) => _userToModel(user)).toList();
  }

  /// Search users by phone number (partial match)
  Future<List<UserModel>> searchUsersByPhone(String searchQuery) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.users)
      ..where((t) => t.phone.like('%$searchQuery%'))
      ..orderBy([
        (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
      ]);

    final users = await query.get();

    return users.map((user) => _userToModel(user)).toList();
  }

  /// Search users by name or phone (case-insensitive partial match)
  Future<List<UserModel>> searchUsers(String searchQuery) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.users)
      ..where(
        (t) => t.name.like('%$searchQuery%') | t.phone.like('%$searchQuery%'),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
      ]);

    final users = await query.get();

    return users.map((user) => _userToModel(user)).toList();
  }

  /// Get multiple users by their IDs
  Future<List<UserModel>> getUsersByIds(List<int> userIds) async {
    if (userIds.isEmpty) return [];

    final db = sqliteDatabase.database;

    final query = db.select(db.users)
      ..where((t) => t.id.isIn(userIds))
      ..orderBy([
        (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
      ]);

    final users = await query.get();

    return users.map((user) => _userToModel(user)).toList();
  }

  /// Update a user
  Future<void> updateUser(UserModel user) async {
    final db = sqliteDatabase.database;

    // Get existing user to preserve values not provided
    final existingUser = await getUserById(user.id);
    if (existingUser == null) return;

    // Only update fields that are explicitly provided (non-empty for required fields)
    final companion = UsersCompanion(
      id: Value(user.id),
      name: user.name.isNotEmpty ? Value(user.name) : const Value.absent(),
      phone: user.phone.isNotEmpty ? Value(user.phone) : const Value.absent(),
      role: user.role != null ? Value(user.role) : const Value.absent(),
      profilePic: user.profilePic != null
          ? Value(user.profilePic)
          : const Value.absent(),
      isOnline: const Value.absent(), // Preserve existing isOnline
      callAccess: user.callAccess != null
          ? Value(user.callAccess)
          : const Value.absent(),
    );

    // Use update instead of replace to preserve existing values
    await (db.update(
      db.users,
    )..where((t) => t.id.equals(user.id))).write(companion);
  }

  /// Update user's name
  Future<void> updateUserName(int userId, String name) async {
    final db = sqliteDatabase.database;
    await (db.update(db.users)..where((t) => t.id.equals(userId))).write(
      UsersCompanion(name: Value(name)),
    );
  }

  /// Update user's phone number
  Future<void> updateUserPhone(int userId, String phone) async {
    final db = sqliteDatabase.database;
    await (db.update(db.users)..where((t) => t.id.equals(userId))).write(
      UsersCompanion(phone: Value(phone)),
    );
  }

  /// Update user's role
  Future<void> updateUserRole(int userId, String role) async {
    final db = sqliteDatabase.database;
    await (db.update(db.users)..where((t) => t.id.equals(userId))).write(
      UsersCompanion(role: Value(role)),
    );
  }

  /// Update user's profile picture
  Future<void> updateUserProfilePic(int userId, String? profilePic) async {
    final db = sqliteDatabase.database;
    await (db.update(db.users)..where((t) => t.id.equals(userId))).write(
      UsersCompanion(profilePic: Value(profilePic)),
    );
  }

  /// Update user's online status
  Future<void> updateUserOnlineStatus(int userId, bool isOnline) async {
    final db = sqliteDatabase.database;
    await (db.update(db.users)..where((t) => t.id.equals(userId))).write(
      UsersCompanion(isOnline: Value(isOnline)),
    );
  }

  /// Delete a user by ID
  Future<bool> deleteUser(int userId) async {
    final db = sqliteDatabase.database;
    final deleted = await (db.delete(
      db.users,
    )..where((t) => t.id.equals(userId))).go();
    return deleted > 0;
  }

  /// Delete multiple users by their IDs
  Future<int> deleteUsers(List<int> userIds) async {
    if (userIds.isEmpty) return 0;

    final db = sqliteDatabase.database;
    final deleted = await (db.delete(
      db.users,
    )..where((t) => t.id.isIn(userIds))).go();
    return deleted;
  }

  /// Clear all users from the database
  Future<void> clearAllUsers() async {
    final db = sqliteDatabase.database;
    await db.delete(db.users).go();
  }

  /// Replace all users (clear existing and insert new ones)
  Future<void> replaceAllUsers(List<UserModel> users) async {
    final db = sqliteDatabase.database;

    await db.transaction(() async {
      // Clear all existing users
      await db.delete(db.users).go();

      // Insert new users
      for (final user in users) {
        final userCompanion = UsersCompanion.insert(
          id: Value(user.id),
          name: user.name,
          phone: user.phone,
          role: Value(user.role),
          profilePic: Value(user.profilePic),
          isOnline: user.isOnline,
          callAccess: Value(user.callAccess),
        );
        await db.into(db.users).insert(userCompanion);
      }
    });
  }

  /// Check if a user exists by ID
  Future<bool> userExists(int userId) async {
    final db = sqliteDatabase.database;
    final user = await (db.select(
      db.users,
    )..where((t) => t.id.equals(userId))).getSingleOrNull();
    return user != null;
  }

  /// Check if a user exists by phone number
  Future<bool> userExistsByPhone(String phone) async {
    final db = sqliteDatabase.database;
    final user = await (db.select(
      db.users,
    )..where((t) => t.phone.equals(phone))).getSingleOrNull();
    return user != null;
  }

  /// Get the total count of users
  Future<int> getUserCount() async {
    final db = sqliteDatabase.database;
    final users = await db.select(db.users).get();
    return users.length;
  }

  /// Get users with pagination
  Future<List<UserModel>> getUsersPaginated({
    required int limit,
    int offset = 0,
    String? orderBy,
    bool ascending = true,
  }) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.users)..limit(limit, offset: offset);

    // Order by specified field or default to name
    if (orderBy == 'phone') {
      query.orderBy([
        (t) => OrderingTerm(
          expression: t.phone,
          mode: ascending ? OrderingMode.asc : OrderingMode.desc,
        ),
      ]);
    } else if (orderBy == 'role') {
      query.orderBy([
        (t) => OrderingTerm(
          expression: t.role,
          mode: ascending ? OrderingMode.asc : OrderingMode.desc,
        ),
      ]);
    } else {
      // Default: order by name
      query.orderBy([
        (t) => OrderingTerm(
          expression: t.name,
          mode: ascending ? OrderingMode.asc : OrderingMode.desc,
        ),
      ]);
    }

    final users = await query.get();

    return users.map((user) => _userToModel(user)).toList();
  }

  /// Get users who have a profile picture
  Future<List<UserModel>> getUsersWithProfilePic() async {
    final db = sqliteDatabase.database;

    final query = db.select(db.users)
      ..where((t) => t.profilePic.isNotNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
      ]);

    final users = await query.get();

    return users.map((user) => _userToModel(user)).toList();
  }

  /// Get users who don't have a profile picture
  Future<List<UserModel>> getUsersWithoutProfilePic() async {
    final db = sqliteDatabase.database;

    final query = db.select(db.users)
      ..where((t) => t.profilePic.isNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
      ]);

    final users = await query.get();

    return users.map((user) => _userToModel(user)).toList();
  }
}
