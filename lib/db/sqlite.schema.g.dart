// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sqlite.schema.dart';

// ignore_for_file: type=lint
class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isOnlineMeta = const VerificationMeta(
    'isOnline',
  );
  @override
  late final GeneratedColumn<bool> isOnline = GeneratedColumn<bool>(
    'is_online',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_online" IN (0, 1))',
    ),
  );
  static const VerificationMeta _profilePicMeta = const VerificationMeta(
    'profilePic',
  );
  @override
  late final GeneratedColumn<String> profilePic = GeneratedColumn<String>(
    'profile_pic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _callAccessMeta = const VerificationMeta(
    'callAccess',
  );
  @override
  late final GeneratedColumn<bool> callAccess = GeneratedColumn<bool>(
    'call_access',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("call_access" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<String> lastSeen = GeneratedColumn<String>(
    'last_seen',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    username,
    phone,
    role,
    isOnline,
    profilePic,
    callAccess,
    lastSeen,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<User> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    } else if (isInserting) {
      context.missing(_phoneMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('is_online')) {
      context.handle(
        _isOnlineMeta,
        isOnline.isAcceptableOrUnknown(data['is_online']!, _isOnlineMeta),
      );
    } else if (isInserting) {
      context.missing(_isOnlineMeta);
    }
    if (data.containsKey('profile_pic')) {
      context.handle(
        _profilePicMeta,
        profilePic.isAcceptableOrUnknown(data['profile_pic']!, _profilePicMeta),
      );
    }
    if (data.containsKey('call_access')) {
      context.handle(
        _callAccessMeta,
        callAccess.isAcceptableOrUnknown(data['call_access']!, _callAccessMeta),
      );
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      ),
      isOnline: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_online'],
      )!,
      profilePic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_pic'],
      ),
      callAccess: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}call_access'],
      ),
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_seen'],
      ),
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class User extends DataClass implements Insertable<User> {
  final String id;
  final String name;
  final String? username;
  final String phone;
  final String? role;
  final bool isOnline;
  final String? profilePic;
  final bool? callAccess;
  final String? lastSeen;
  const User({
    required this.id,
    required this.name,
    this.username,
    required this.phone,
    this.role,
    required this.isOnline,
    this.profilePic,
    this.callAccess,
    this.lastSeen,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || username != null) {
      map['username'] = Variable<String>(username);
    }
    map['phone'] = Variable<String>(phone);
    if (!nullToAbsent || role != null) {
      map['role'] = Variable<String>(role);
    }
    map['is_online'] = Variable<bool>(isOnline);
    if (!nullToAbsent || profilePic != null) {
      map['profile_pic'] = Variable<String>(profilePic);
    }
    if (!nullToAbsent || callAccess != null) {
      map['call_access'] = Variable<bool>(callAccess);
    }
    if (!nullToAbsent || lastSeen != null) {
      map['last_seen'] = Variable<String>(lastSeen);
    }
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      name: Value(name),
      username: username == null && nullToAbsent
          ? const Value.absent()
          : Value(username),
      phone: Value(phone),
      role: role == null && nullToAbsent ? const Value.absent() : Value(role),
      isOnline: Value(isOnline),
      profilePic: profilePic == null && nullToAbsent
          ? const Value.absent()
          : Value(profilePic),
      callAccess: callAccess == null && nullToAbsent
          ? const Value.absent()
          : Value(callAccess),
      lastSeen: lastSeen == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeen),
    );
  }

  factory User.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      username: serializer.fromJson<String?>(json['username']),
      phone: serializer.fromJson<String>(json['phone']),
      role: serializer.fromJson<String?>(json['role']),
      isOnline: serializer.fromJson<bool>(json['isOnline']),
      profilePic: serializer.fromJson<String?>(json['profilePic']),
      callAccess: serializer.fromJson<bool?>(json['callAccess']),
      lastSeen: serializer.fromJson<String?>(json['lastSeen']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'username': serializer.toJson<String?>(username),
      'phone': serializer.toJson<String>(phone),
      'role': serializer.toJson<String?>(role),
      'isOnline': serializer.toJson<bool>(isOnline),
      'profilePic': serializer.toJson<String?>(profilePic),
      'callAccess': serializer.toJson<bool?>(callAccess),
      'lastSeen': serializer.toJson<String?>(lastSeen),
    };
  }

  User copyWith({
    String? id,
    String? name,
    Value<String?> username = const Value.absent(),
    String? phone,
    Value<String?> role = const Value.absent(),
    bool? isOnline,
    Value<String?> profilePic = const Value.absent(),
    Value<bool?> callAccess = const Value.absent(),
    Value<String?> lastSeen = const Value.absent(),
  }) => User(
    id: id ?? this.id,
    name: name ?? this.name,
    username: username.present ? username.value : this.username,
    phone: phone ?? this.phone,
    role: role.present ? role.value : this.role,
    isOnline: isOnline ?? this.isOnline,
    profilePic: profilePic.present ? profilePic.value : this.profilePic,
    callAccess: callAccess.present ? callAccess.value : this.callAccess,
    lastSeen: lastSeen.present ? lastSeen.value : this.lastSeen,
  );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      username: data.username.present ? data.username.value : this.username,
      phone: data.phone.present ? data.phone.value : this.phone,
      role: data.role.present ? data.role.value : this.role,
      isOnline: data.isOnline.present ? data.isOnline.value : this.isOnline,
      profilePic: data.profilePic.present
          ? data.profilePic.value
          : this.profilePic,
      callAccess: data.callAccess.present
          ? data.callAccess.value
          : this.callAccess,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('username: $username, ')
          ..write('phone: $phone, ')
          ..write('role: $role, ')
          ..write('isOnline: $isOnline, ')
          ..write('profilePic: $profilePic, ')
          ..write('callAccess: $callAccess, ')
          ..write('lastSeen: $lastSeen')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    username,
    phone,
    role,
    isOnline,
    profilePic,
    callAccess,
    lastSeen,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == this.id &&
          other.name == this.name &&
          other.username == this.username &&
          other.phone == this.phone &&
          other.role == this.role &&
          other.isOnline == this.isOnline &&
          other.profilePic == this.profilePic &&
          other.callAccess == this.callAccess &&
          other.lastSeen == this.lastSeen);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> username;
  final Value<String> phone;
  final Value<String?> role;
  final Value<bool> isOnline;
  final Value<String?> profilePic;
  final Value<bool?> callAccess;
  final Value<String?> lastSeen;
  final Value<int> rowid;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.username = const Value.absent(),
    this.phone = const Value.absent(),
    this.role = const Value.absent(),
    this.isOnline = const Value.absent(),
    this.profilePic = const Value.absent(),
    this.callAccess = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsersCompanion.insert({
    required String id,
    required String name,
    this.username = const Value.absent(),
    required String phone,
    this.role = const Value.absent(),
    required bool isOnline,
    this.profilePic = const Value.absent(),
    this.callAccess = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       phone = Value(phone),
       isOnline = Value(isOnline);
  static Insertable<User> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? username,
    Expression<String>? phone,
    Expression<String>? role,
    Expression<bool>? isOnline,
    Expression<String>? profilePic,
    Expression<bool>? callAccess,
    Expression<String>? lastSeen,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (username != null) 'username': username,
      if (phone != null) 'phone': phone,
      if (role != null) 'role': role,
      if (isOnline != null) 'is_online': isOnline,
      if (profilePic != null) 'profile_pic': profilePic,
      if (callAccess != null) 'call_access': callAccess,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? username,
    Value<String>? phone,
    Value<String?>? role,
    Value<bool>? isOnline,
    Value<String?>? profilePic,
    Value<bool?>? callAccess,
    Value<String?>? lastSeen,
    Value<int>? rowid,
  }) {
    return UsersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isOnline: isOnline ?? this.isOnline,
      profilePic: profilePic ?? this.profilePic,
      callAccess: callAccess ?? this.callAccess,
      lastSeen: lastSeen ?? this.lastSeen,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (isOnline.present) {
      map['is_online'] = Variable<bool>(isOnline.value);
    }
    if (profilePic.present) {
      map['profile_pic'] = Variable<String>(profilePic.value);
    }
    if (callAccess.present) {
      map['call_access'] = Variable<bool>(callAccess.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<String>(lastSeen.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('username: $username, ')
          ..write('phone: $phone, ')
          ..write('role: $role, ')
          ..write('isOnline: $isOnline, ')
          ..write('profilePic: $profilePic, ')
          ..write('callAccess: $callAccess, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContactsTable extends Contacts with TableInfo<$ContactsTable, Contact> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profilePicMeta = const VerificationMeta(
    'profilePic',
  );
  @override
  late final GeneratedColumn<String> profilePic = GeneratedColumn<String>(
    'profile_pic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, phone, profilePic];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contacts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Contact> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    } else if (isInserting) {
      context.missing(_phoneMeta);
    }
    if (data.containsKey('profile_pic')) {
      context.handle(
        _profilePicMeta,
        profilePic.isAcceptableOrUnknown(data['profile_pic']!, _profilePicMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Contact map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Contact(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      profilePic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_pic'],
      ),
    );
  }

  @override
  $ContactsTable createAlias(String alias) {
    return $ContactsTable(attachedDatabase, alias);
  }
}

class Contact extends DataClass implements Insertable<Contact> {
  final String id;
  final String name;
  final String phone;
  final String? profilePic;
  const Contact({
    required this.id,
    required this.name,
    required this.phone,
    this.profilePic,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['phone'] = Variable<String>(phone);
    if (!nullToAbsent || profilePic != null) {
      map['profile_pic'] = Variable<String>(profilePic);
    }
    return map;
  }

  ContactsCompanion toCompanion(bool nullToAbsent) {
    return ContactsCompanion(
      id: Value(id),
      name: Value(name),
      phone: Value(phone),
      profilePic: profilePic == null && nullToAbsent
          ? const Value.absent()
          : Value(profilePic),
    );
  }

  factory Contact.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Contact(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String>(json['phone']),
      profilePic: serializer.fromJson<String?>(json['profilePic']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String>(phone),
      'profilePic': serializer.toJson<String?>(profilePic),
    };
  }

  Contact copyWith({
    String? id,
    String? name,
    String? phone,
    Value<String?> profilePic = const Value.absent(),
  }) => Contact(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    profilePic: profilePic.present ? profilePic.value : this.profilePic,
  );
  Contact copyWithCompanion(ContactsCompanion data) {
    return Contact(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      profilePic: data.profilePic.present
          ? data.profilePic.value
          : this.profilePic,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Contact(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('profilePic: $profilePic')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, phone, profilePic);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Contact &&
          other.id == this.id &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.profilePic == this.profilePic);
}

class ContactsCompanion extends UpdateCompanion<Contact> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> phone;
  final Value<String?> profilePic;
  final Value<int> rowid;
  const ContactsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.profilePic = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContactsCompanion.insert({
    required String id,
    required String name,
    required String phone,
    this.profilePic = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       phone = Value(phone);
  static Insertable<Contact> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? profilePic,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (profilePic != null) 'profile_pic': profilePic,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContactsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? phone,
    Value<String?>? profilePic,
    Value<int>? rowid,
  }) {
    return ContactsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      profilePic: profilePic ?? this.profilePic,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (profilePic.present) {
      map['profile_pic'] = Variable<String>(profilePic.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContactsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('profilePic: $profilePic, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CallsTable extends Calls with TableInfo<$CallsTable, Call> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CallsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _callerIdMeta = const VerificationMeta(
    'callerId',
  );
  @override
  late final GeneratedColumn<String> callerId = GeneratedColumn<String>(
    'caller_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _calleeIdMeta = const VerificationMeta(
    'calleeId',
  );
  @override
  late final GeneratedColumn<String> calleeId = GeneratedColumn<String>(
    'callee_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<String> startedAt = GeneratedColumn<String>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answeredAtMeta = const VerificationMeta(
    'answeredAt',
  );
  @override
  late final GeneratedColumn<String> answeredAt = GeneratedColumn<String>(
    'answered_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<String> endedAt = GeneratedColumn<String>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    callerId,
    calleeId,
    startedAt,
    answeredAt,
    endedAt,
    durationSeconds,
    status,
    reason,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calls';
  @override
  VerificationContext validateIntegrity(
    Insertable<Call> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('caller_id')) {
      context.handle(
        _callerIdMeta,
        callerId.isAcceptableOrUnknown(data['caller_id']!, _callerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_callerIdMeta);
    }
    if (data.containsKey('callee_id')) {
      context.handle(
        _calleeIdMeta,
        calleeId.isAcceptableOrUnknown(data['callee_id']!, _calleeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_calleeIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('answered_at')) {
      context.handle(
        _answeredAtMeta,
        answeredAt.isAcceptableOrUnknown(data['answered_at']!, _answeredAtMeta),
      );
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Call map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Call(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      callerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}caller_id'],
      )!,
      calleeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}callee_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}started_at'],
      )!,
      answeredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answered_at'],
      ),
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ended_at'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CallsTable createAlias(String alias) {
    return $CallsTable(attachedDatabase, alias);
  }
}

class Call extends DataClass implements Insertable<Call> {
  final String id;
  final String callerId;
  final String calleeId;
  final String startedAt;
  final String? answeredAt;
  final String? endedAt;
  final int durationSeconds;
  final String status;
  final String? reason;
  final String createdAt;
  const Call({
    required this.id,
    required this.callerId,
    required this.calleeId,
    required this.startedAt,
    this.answeredAt,
    this.endedAt,
    required this.durationSeconds,
    required this.status,
    this.reason,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['caller_id'] = Variable<String>(callerId);
    map['callee_id'] = Variable<String>(calleeId);
    map['started_at'] = Variable<String>(startedAt);
    if (!nullToAbsent || answeredAt != null) {
      map['answered_at'] = Variable<String>(answeredAt);
    }
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<String>(endedAt);
    }
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  CallsCompanion toCompanion(bool nullToAbsent) {
    return CallsCompanion(
      id: Value(id),
      callerId: Value(callerId),
      calleeId: Value(calleeId),
      startedAt: Value(startedAt),
      answeredAt: answeredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(answeredAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      durationSeconds: Value(durationSeconds),
      status: Value(status),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
      createdAt: Value(createdAt),
    );
  }

  factory Call.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Call(
      id: serializer.fromJson<String>(json['id']),
      callerId: serializer.fromJson<String>(json['callerId']),
      calleeId: serializer.fromJson<String>(json['calleeId']),
      startedAt: serializer.fromJson<String>(json['startedAt']),
      answeredAt: serializer.fromJson<String?>(json['answeredAt']),
      endedAt: serializer.fromJson<String?>(json['endedAt']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      status: serializer.fromJson<String>(json['status']),
      reason: serializer.fromJson<String?>(json['reason']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'callerId': serializer.toJson<String>(callerId),
      'calleeId': serializer.toJson<String>(calleeId),
      'startedAt': serializer.toJson<String>(startedAt),
      'answeredAt': serializer.toJson<String?>(answeredAt),
      'endedAt': serializer.toJson<String?>(endedAt),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'status': serializer.toJson<String>(status),
      'reason': serializer.toJson<String?>(reason),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  Call copyWith({
    String? id,
    String? callerId,
    String? calleeId,
    String? startedAt,
    Value<String?> answeredAt = const Value.absent(),
    Value<String?> endedAt = const Value.absent(),
    int? durationSeconds,
    String? status,
    Value<String?> reason = const Value.absent(),
    String? createdAt,
  }) => Call(
    id: id ?? this.id,
    callerId: callerId ?? this.callerId,
    calleeId: calleeId ?? this.calleeId,
    startedAt: startedAt ?? this.startedAt,
    answeredAt: answeredAt.present ? answeredAt.value : this.answeredAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    status: status ?? this.status,
    reason: reason.present ? reason.value : this.reason,
    createdAt: createdAt ?? this.createdAt,
  );
  Call copyWithCompanion(CallsCompanion data) {
    return Call(
      id: data.id.present ? data.id.value : this.id,
      callerId: data.callerId.present ? data.callerId.value : this.callerId,
      calleeId: data.calleeId.present ? data.calleeId.value : this.calleeId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      answeredAt: data.answeredAt.present
          ? data.answeredAt.value
          : this.answeredAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      status: data.status.present ? data.status.value : this.status,
      reason: data.reason.present ? data.reason.value : this.reason,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Call(')
          ..write('id: $id, ')
          ..write('callerId: $callerId, ')
          ..write('calleeId: $calleeId, ')
          ..write('startedAt: $startedAt, ')
          ..write('answeredAt: $answeredAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('status: $status, ')
          ..write('reason: $reason, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    callerId,
    calleeId,
    startedAt,
    answeredAt,
    endedAt,
    durationSeconds,
    status,
    reason,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Call &&
          other.id == this.id &&
          other.callerId == this.callerId &&
          other.calleeId == this.calleeId &&
          other.startedAt == this.startedAt &&
          other.answeredAt == this.answeredAt &&
          other.endedAt == this.endedAt &&
          other.durationSeconds == this.durationSeconds &&
          other.status == this.status &&
          other.reason == this.reason &&
          other.createdAt == this.createdAt);
}

class CallsCompanion extends UpdateCompanion<Call> {
  final Value<String> id;
  final Value<String> callerId;
  final Value<String> calleeId;
  final Value<String> startedAt;
  final Value<String?> answeredAt;
  final Value<String?> endedAt;
  final Value<int> durationSeconds;
  final Value<String> status;
  final Value<String?> reason;
  final Value<String> createdAt;
  final Value<int> rowid;
  const CallsCompanion({
    this.id = const Value.absent(),
    this.callerId = const Value.absent(),
    this.calleeId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.answeredAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.status = const Value.absent(),
    this.reason = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CallsCompanion.insert({
    required String id,
    required String callerId,
    required String calleeId,
    required String startedAt,
    this.answeredAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    required String status,
    this.reason = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       callerId = Value(callerId),
       calleeId = Value(calleeId),
       startedAt = Value(startedAt),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<Call> custom({
    Expression<String>? id,
    Expression<String>? callerId,
    Expression<String>? calleeId,
    Expression<String>? startedAt,
    Expression<String>? answeredAt,
    Expression<String>? endedAt,
    Expression<int>? durationSeconds,
    Expression<String>? status,
    Expression<String>? reason,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (callerId != null) 'caller_id': callerId,
      if (calleeId != null) 'callee_id': calleeId,
      if (startedAt != null) 'started_at': startedAt,
      if (answeredAt != null) 'answered_at': answeredAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (status != null) 'status': status,
      if (reason != null) 'reason': reason,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CallsCompanion copyWith({
    Value<String>? id,
    Value<String>? callerId,
    Value<String>? calleeId,
    Value<String>? startedAt,
    Value<String?>? answeredAt,
    Value<String?>? endedAt,
    Value<int>? durationSeconds,
    Value<String>? status,
    Value<String?>? reason,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return CallsCompanion(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      calleeId: calleeId ?? this.calleeId,
      startedAt: startedAt ?? this.startedAt,
      answeredAt: answeredAt ?? this.answeredAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (callerId.present) {
      map['caller_id'] = Variable<String>(callerId.value);
    }
    if (calleeId.present) {
      map['callee_id'] = Variable<String>(calleeId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<String>(startedAt.value);
    }
    if (answeredAt.present) {
      map['answered_at'] = Variable<String>(answeredAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<String>(endedAt.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CallsCompanion(')
          ..write('id: $id, ')
          ..write('callerId: $callerId, ')
          ..write('calleeId: $calleeId, ')
          ..write('startedAt: $startedAt, ')
          ..write('answeredAt: $answeredAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('status: $status, ')
          ..write('reason: $reason, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatsTable extends Chats with TableInfo<$ChatsTable, Chat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createrIdMeta = const VerificationMeta(
    'createrId',
  );
  @override
  late final GeneratedColumn<String> createrId = GeneratedColumn<String>(
    'creater_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unreadCountMeta = const VerificationMeta(
    'unreadCount',
  );
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
    'unread_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastMsgIdMeta = const VerificationMeta(
    'lastMsgId',
  );
  @override
  late final GeneratedColumn<String> lastMsgId = GeneratedColumn<String>(
    'last_msg_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastMsgAtMeta = const VerificationMeta(
    'lastMsgAt',
  );
  @override
  late final GeneratedColumn<String> lastMsgAt = GeneratedColumn<String>(
    'last_msg_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pinnedMsgIdMeta = const VerificationMeta(
    'pinnedMsgId',
  );
  @override
  late final GeneratedColumn<String> pinnedMsgId = GeneratedColumn<String>(
    'pinned_msg_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isMutedMeta = const VerificationMeta(
    'isMuted',
  );
  @override
  late final GeneratedColumn<bool> isMuted = GeneratedColumn<bool>(
    'is_muted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_muted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _needSyncMeta = const VerificationMeta(
    'needSync',
  );
  @override
  late final GeneratedColumn<bool> needSync = GeneratedColumn<bool>(
    'need_sync',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("need_sync" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _disappearingAfterSecMeta =
      const VerificationMeta('disappearingAfterSec');
  @override
  late final GeneratedColumn<int> disappearingAfterSec = GeneratedColumn<int>(
    'disappearing_after_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    title,
    createrId,
    unreadCount,
    lastMsgId,
    lastMsgAt,
    pinnedMsgId,
    deletedAt,
    isPinned,
    isFavorite,
    isMuted,
    createdAt,
    updatedAt,
    needSync,
    disappearingAfterSec,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chats';
  @override
  VerificationContext validateIntegrity(
    Insertable<Chat> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('creater_id')) {
      context.handle(
        _createrIdMeta,
        createrId.isAcceptableOrUnknown(data['creater_id']!, _createrIdMeta),
      );
    }
    if (data.containsKey('unread_count')) {
      context.handle(
        _unreadCountMeta,
        unreadCount.isAcceptableOrUnknown(
          data['unread_count']!,
          _unreadCountMeta,
        ),
      );
    }
    if (data.containsKey('last_msg_id')) {
      context.handle(
        _lastMsgIdMeta,
        lastMsgId.isAcceptableOrUnknown(data['last_msg_id']!, _lastMsgIdMeta),
      );
    }
    if (data.containsKey('last_msg_at')) {
      context.handle(
        _lastMsgAtMeta,
        lastMsgAt.isAcceptableOrUnknown(data['last_msg_at']!, _lastMsgAtMeta),
      );
    }
    if (data.containsKey('pinned_msg_id')) {
      context.handle(
        _pinnedMsgIdMeta,
        pinnedMsgId.isAcceptableOrUnknown(
          data['pinned_msg_id']!,
          _pinnedMsgIdMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('is_muted')) {
      context.handle(
        _isMutedMeta,
        isMuted.isAcceptableOrUnknown(data['is_muted']!, _isMutedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('need_sync')) {
      context.handle(
        _needSyncMeta,
        needSync.isAcceptableOrUnknown(data['need_sync']!, _needSyncMeta),
      );
    }
    if (data.containsKey('disappearing_after_sec')) {
      context.handle(
        _disappearingAfterSecMeta,
        disappearingAfterSec.isAcceptableOrUnknown(
          data['disappearing_after_sec']!,
          _disappearingAfterSecMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Chat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Chat(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      createrId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creater_id'],
      ),
      unreadCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unread_count'],
      ),
      lastMsgId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_msg_id'],
      ),
      lastMsgAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_msg_at'],
      ),
      pinnedMsgId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pinned_msg_id'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      isMuted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_muted'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      needSync: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}need_sync'],
      )!,
      disappearingAfterSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}disappearing_after_sec'],
      ),
    );
  }

  @override
  $ChatsTable createAlias(String alias) {
    return $ChatsTable(attachedDatabase, alias);
  }
}

class Chat extends DataClass implements Insertable<Chat> {
  final String id;
  final String type;
  final String? title;
  final String? createrId;
  final int? unreadCount;
  final String? lastMsgId;
  final String? lastMsgAt;
  final String? pinnedMsgId;
  final String? deletedAt;
  final bool isPinned;
  final bool isFavorite;
  final bool isMuted;
  final String? createdAt;
  final String? updatedAt;
  final bool needSync;
  final int? disappearingAfterSec;
  const Chat({
    required this.id,
    required this.type,
    this.title,
    this.createrId,
    this.unreadCount,
    this.lastMsgId,
    this.lastMsgAt,
    this.pinnedMsgId,
    this.deletedAt,
    required this.isPinned,
    required this.isFavorite,
    required this.isMuted,
    this.createdAt,
    this.updatedAt,
    required this.needSync,
    this.disappearingAfterSec,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || createrId != null) {
      map['creater_id'] = Variable<String>(createrId);
    }
    if (!nullToAbsent || unreadCount != null) {
      map['unread_count'] = Variable<int>(unreadCount);
    }
    if (!nullToAbsent || lastMsgId != null) {
      map['last_msg_id'] = Variable<String>(lastMsgId);
    }
    if (!nullToAbsent || lastMsgAt != null) {
      map['last_msg_at'] = Variable<String>(lastMsgAt);
    }
    if (!nullToAbsent || pinnedMsgId != null) {
      map['pinned_msg_id'] = Variable<String>(pinnedMsgId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['is_muted'] = Variable<bool>(isMuted);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    map['need_sync'] = Variable<bool>(needSync);
    if (!nullToAbsent || disappearingAfterSec != null) {
      map['disappearing_after_sec'] = Variable<int>(disappearingAfterSec);
    }
    return map;
  }

  ChatsCompanion toCompanion(bool nullToAbsent) {
    return ChatsCompanion(
      id: Value(id),
      type: Value(type),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      createrId: createrId == null && nullToAbsent
          ? const Value.absent()
          : Value(createrId),
      unreadCount: unreadCount == null && nullToAbsent
          ? const Value.absent()
          : Value(unreadCount),
      lastMsgId: lastMsgId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMsgId),
      lastMsgAt: lastMsgAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMsgAt),
      pinnedMsgId: pinnedMsgId == null && nullToAbsent
          ? const Value.absent()
          : Value(pinnedMsgId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      isPinned: Value(isPinned),
      isFavorite: Value(isFavorite),
      isMuted: Value(isMuted),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      needSync: Value(needSync),
      disappearingAfterSec: disappearingAfterSec == null && nullToAbsent
          ? const Value.absent()
          : Value(disappearingAfterSec),
    );
  }

  factory Chat.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Chat(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String?>(json['title']),
      createrId: serializer.fromJson<String?>(json['createrId']),
      unreadCount: serializer.fromJson<int?>(json['unreadCount']),
      lastMsgId: serializer.fromJson<String?>(json['lastMsgId']),
      lastMsgAt: serializer.fromJson<String?>(json['lastMsgAt']),
      pinnedMsgId: serializer.fromJson<String?>(json['pinnedMsgId']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      isMuted: serializer.fromJson<bool>(json['isMuted']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      needSync: serializer.fromJson<bool>(json['needSync']),
      disappearingAfterSec: serializer.fromJson<int?>(
        json['disappearingAfterSec'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String?>(title),
      'createrId': serializer.toJson<String?>(createrId),
      'unreadCount': serializer.toJson<int?>(unreadCount),
      'lastMsgId': serializer.toJson<String?>(lastMsgId),
      'lastMsgAt': serializer.toJson<String?>(lastMsgAt),
      'pinnedMsgId': serializer.toJson<String?>(pinnedMsgId),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'isMuted': serializer.toJson<bool>(isMuted),
      'createdAt': serializer.toJson<String?>(createdAt),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'needSync': serializer.toJson<bool>(needSync),
      'disappearingAfterSec': serializer.toJson<int?>(disappearingAfterSec),
    };
  }

  Chat copyWith({
    String? id,
    String? type,
    Value<String?> title = const Value.absent(),
    Value<String?> createrId = const Value.absent(),
    Value<int?> unreadCount = const Value.absent(),
    Value<String?> lastMsgId = const Value.absent(),
    Value<String?> lastMsgAt = const Value.absent(),
    Value<String?> pinnedMsgId = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
    bool? isPinned,
    bool? isFavorite,
    bool? isMuted,
    Value<String?> createdAt = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
    bool? needSync,
    Value<int?> disappearingAfterSec = const Value.absent(),
  }) => Chat(
    id: id ?? this.id,
    type: type ?? this.type,
    title: title.present ? title.value : this.title,
    createrId: createrId.present ? createrId.value : this.createrId,
    unreadCount: unreadCount.present ? unreadCount.value : this.unreadCount,
    lastMsgId: lastMsgId.present ? lastMsgId.value : this.lastMsgId,
    lastMsgAt: lastMsgAt.present ? lastMsgAt.value : this.lastMsgAt,
    pinnedMsgId: pinnedMsgId.present ? pinnedMsgId.value : this.pinnedMsgId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    isPinned: isPinned ?? this.isPinned,
    isFavorite: isFavorite ?? this.isFavorite,
    isMuted: isMuted ?? this.isMuted,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    needSync: needSync ?? this.needSync,
    disappearingAfterSec: disappearingAfterSec.present
        ? disappearingAfterSec.value
        : this.disappearingAfterSec,
  );
  Chat copyWithCompanion(ChatsCompanion data) {
    return Chat(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      createrId: data.createrId.present ? data.createrId.value : this.createrId,
      unreadCount: data.unreadCount.present
          ? data.unreadCount.value
          : this.unreadCount,
      lastMsgId: data.lastMsgId.present ? data.lastMsgId.value : this.lastMsgId,
      lastMsgAt: data.lastMsgAt.present ? data.lastMsgAt.value : this.lastMsgAt,
      pinnedMsgId: data.pinnedMsgId.present
          ? data.pinnedMsgId.value
          : this.pinnedMsgId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      isMuted: data.isMuted.present ? data.isMuted.value : this.isMuted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      needSync: data.needSync.present ? data.needSync.value : this.needSync,
      disappearingAfterSec: data.disappearingAfterSec.present
          ? data.disappearingAfterSec.value
          : this.disappearingAfterSec,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Chat(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('createrId: $createrId, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('lastMsgId: $lastMsgId, ')
          ..write('lastMsgAt: $lastMsgAt, ')
          ..write('pinnedMsgId: $pinnedMsgId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isMuted: $isMuted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('needSync: $needSync, ')
          ..write('disappearingAfterSec: $disappearingAfterSec')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    title,
    createrId,
    unreadCount,
    lastMsgId,
    lastMsgAt,
    pinnedMsgId,
    deletedAt,
    isPinned,
    isFavorite,
    isMuted,
    createdAt,
    updatedAt,
    needSync,
    disappearingAfterSec,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Chat &&
          other.id == this.id &&
          other.type == this.type &&
          other.title == this.title &&
          other.createrId == this.createrId &&
          other.unreadCount == this.unreadCount &&
          other.lastMsgId == this.lastMsgId &&
          other.lastMsgAt == this.lastMsgAt &&
          other.pinnedMsgId == this.pinnedMsgId &&
          other.deletedAt == this.deletedAt &&
          other.isPinned == this.isPinned &&
          other.isFavorite == this.isFavorite &&
          other.isMuted == this.isMuted &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.needSync == this.needSync &&
          other.disappearingAfterSec == this.disappearingAfterSec);
}

class ChatsCompanion extends UpdateCompanion<Chat> {
  final Value<String> id;
  final Value<String> type;
  final Value<String?> title;
  final Value<String?> createrId;
  final Value<int?> unreadCount;
  final Value<String?> lastMsgId;
  final Value<String?> lastMsgAt;
  final Value<String?> pinnedMsgId;
  final Value<String?> deletedAt;
  final Value<bool> isPinned;
  final Value<bool> isFavorite;
  final Value<bool> isMuted;
  final Value<String?> createdAt;
  final Value<String?> updatedAt;
  final Value<bool> needSync;
  final Value<int?> disappearingAfterSec;
  final Value<int> rowid;
  const ChatsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.createrId = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.lastMsgId = const Value.absent(),
    this.lastMsgAt = const Value.absent(),
    this.pinnedMsgId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.isMuted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.needSync = const Value.absent(),
    this.disappearingAfterSec = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatsCompanion.insert({
    required String id,
    required String type,
    this.title = const Value.absent(),
    this.createrId = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.lastMsgId = const Value.absent(),
    this.lastMsgAt = const Value.absent(),
    this.pinnedMsgId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.isMuted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.needSync = const Value.absent(),
    this.disappearingAfterSec = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type);
  static Insertable<Chat> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? createrId,
    Expression<int>? unreadCount,
    Expression<String>? lastMsgId,
    Expression<String>? lastMsgAt,
    Expression<String>? pinnedMsgId,
    Expression<String>? deletedAt,
    Expression<bool>? isPinned,
    Expression<bool>? isFavorite,
    Expression<bool>? isMuted,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<bool>? needSync,
    Expression<int>? disappearingAfterSec,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (createrId != null) 'creater_id': createrId,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (lastMsgId != null) 'last_msg_id': lastMsgId,
      if (lastMsgAt != null) 'last_msg_at': lastMsgAt,
      if (pinnedMsgId != null) 'pinned_msg_id': pinnedMsgId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (isMuted != null) 'is_muted': isMuted,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (needSync != null) 'need_sync': needSync,
      if (disappearingAfterSec != null)
        'disappearing_after_sec': disappearingAfterSec,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String?>? title,
    Value<String?>? createrId,
    Value<int?>? unreadCount,
    Value<String?>? lastMsgId,
    Value<String?>? lastMsgAt,
    Value<String?>? pinnedMsgId,
    Value<String?>? deletedAt,
    Value<bool>? isPinned,
    Value<bool>? isFavorite,
    Value<bool>? isMuted,
    Value<String?>? createdAt,
    Value<String?>? updatedAt,
    Value<bool>? needSync,
    Value<int?>? disappearingAfterSec,
    Value<int>? rowid,
  }) {
    return ChatsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      createrId: createrId ?? this.createrId,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMsgId: lastMsgId ?? this.lastMsgId,
      lastMsgAt: lastMsgAt ?? this.lastMsgAt,
      pinnedMsgId: pinnedMsgId ?? this.pinnedMsgId,
      deletedAt: deletedAt ?? this.deletedAt,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      isMuted: isMuted ?? this.isMuted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      needSync: needSync ?? this.needSync,
      disappearingAfterSec: disappearingAfterSec ?? this.disappearingAfterSec,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createrId.present) {
      map['creater_id'] = Variable<String>(createrId.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (lastMsgId.present) {
      map['last_msg_id'] = Variable<String>(lastMsgId.value);
    }
    if (lastMsgAt.present) {
      map['last_msg_at'] = Variable<String>(lastMsgAt.value);
    }
    if (pinnedMsgId.present) {
      map['pinned_msg_id'] = Variable<String>(pinnedMsgId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (isMuted.present) {
      map['is_muted'] = Variable<bool>(isMuted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (needSync.present) {
      map['need_sync'] = Variable<bool>(needSync.value);
    }
    if (disappearingAfterSec.present) {
      map['disappearing_after_sec'] = Variable<int>(disappearingAfterSec.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('createrId: $createrId, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('lastMsgId: $lastMsgId, ')
          ..write('lastMsgAt: $lastMsgAt, ')
          ..write('pinnedMsgId: $pinnedMsgId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isMuted: $isMuted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('needSync: $needSync, ')
          ..write('disappearingAfterSec: $disappearingAfterSec, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatMembersTable extends ChatMembers
    with TableInfo<$ChatMembersTable, ChatMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<String> chatId = GeneratedColumn<String>(
    'chat_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _joinedAtMeta = const VerificationMeta(
    'joinedAt',
  );
  @override
  late final GeneratedColumn<String> joinedAt = GeneratedColumn<String>(
    'joined_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _removedAtMeta = const VerificationMeta(
    'removedAt',
  );
  @override
  late final GeneratedColumn<String> removedAt = GeneratedColumn<String>(
    'removed_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastReadMsgIdMeta = const VerificationMeta(
    'lastReadMsgId',
  );
  @override
  late final GeneratedColumn<String> lastReadMsgId = GeneratedColumn<String>(
    'last_read_msg_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastDeliveredMsgIdMeta =
      const VerificationMeta('lastDeliveredMsgId');
  @override
  late final GeneratedColumn<String> lastDeliveredMsgId =
      GeneratedColumn<String>(
        'last_delivered_msg_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    chatId,
    userId,
    role,
    joinedAt,
    removedAt,
    lastReadMsgId,
    lastDeliveredMsgId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('chat_id')) {
      context.handle(
        _chatIdMeta,
        chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('joined_at')) {
      context.handle(
        _joinedAtMeta,
        joinedAt.isAcceptableOrUnknown(data['joined_at']!, _joinedAtMeta),
      );
    }
    if (data.containsKey('removed_at')) {
      context.handle(
        _removedAtMeta,
        removedAt.isAcceptableOrUnknown(data['removed_at']!, _removedAtMeta),
      );
    }
    if (data.containsKey('last_read_msg_id')) {
      context.handle(
        _lastReadMsgIdMeta,
        lastReadMsgId.isAcceptableOrUnknown(
          data['last_read_msg_id']!,
          _lastReadMsgIdMeta,
        ),
      );
    }
    if (data.containsKey('last_delivered_msg_id')) {
      context.handle(
        _lastDeliveredMsgIdMeta,
        lastDeliveredMsgId.isAcceptableOrUnknown(
          data['last_delivered_msg_id']!,
          _lastDeliveredMsgIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatMember(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      chatId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chat_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      joinedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}joined_at'],
      ),
      removedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}removed_at'],
      ),
      lastReadMsgId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_read_msg_id'],
      ),
      lastDeliveredMsgId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_delivered_msg_id'],
      ),
    );
  }

  @override
  $ChatMembersTable createAlias(String alias) {
    return $ChatMembersTable(attachedDatabase, alias);
  }
}

class ChatMember extends DataClass implements Insertable<ChatMember> {
  final String id;
  final String chatId;
  final String userId;
  final String role;
  final String? joinedAt;
  final String? removedAt;
  final String? lastReadMsgId;
  final String? lastDeliveredMsgId;
  const ChatMember({
    required this.id,
    required this.chatId,
    required this.userId,
    required this.role,
    this.joinedAt,
    this.removedAt,
    this.lastReadMsgId,
    this.lastDeliveredMsgId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['chat_id'] = Variable<String>(chatId);
    map['user_id'] = Variable<String>(userId);
    map['role'] = Variable<String>(role);
    if (!nullToAbsent || joinedAt != null) {
      map['joined_at'] = Variable<String>(joinedAt);
    }
    if (!nullToAbsent || removedAt != null) {
      map['removed_at'] = Variable<String>(removedAt);
    }
    if (!nullToAbsent || lastReadMsgId != null) {
      map['last_read_msg_id'] = Variable<String>(lastReadMsgId);
    }
    if (!nullToAbsent || lastDeliveredMsgId != null) {
      map['last_delivered_msg_id'] = Variable<String>(lastDeliveredMsgId);
    }
    return map;
  }

  ChatMembersCompanion toCompanion(bool nullToAbsent) {
    return ChatMembersCompanion(
      id: Value(id),
      chatId: Value(chatId),
      userId: Value(userId),
      role: Value(role),
      joinedAt: joinedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(joinedAt),
      removedAt: removedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(removedAt),
      lastReadMsgId: lastReadMsgId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReadMsgId),
      lastDeliveredMsgId: lastDeliveredMsgId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastDeliveredMsgId),
    );
  }

  factory ChatMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatMember(
      id: serializer.fromJson<String>(json['id']),
      chatId: serializer.fromJson<String>(json['chatId']),
      userId: serializer.fromJson<String>(json['userId']),
      role: serializer.fromJson<String>(json['role']),
      joinedAt: serializer.fromJson<String?>(json['joinedAt']),
      removedAt: serializer.fromJson<String?>(json['removedAt']),
      lastReadMsgId: serializer.fromJson<String?>(json['lastReadMsgId']),
      lastDeliveredMsgId: serializer.fromJson<String?>(
        json['lastDeliveredMsgId'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'chatId': serializer.toJson<String>(chatId),
      'userId': serializer.toJson<String>(userId),
      'role': serializer.toJson<String>(role),
      'joinedAt': serializer.toJson<String?>(joinedAt),
      'removedAt': serializer.toJson<String?>(removedAt),
      'lastReadMsgId': serializer.toJson<String?>(lastReadMsgId),
      'lastDeliveredMsgId': serializer.toJson<String?>(lastDeliveredMsgId),
    };
  }

  ChatMember copyWith({
    String? id,
    String? chatId,
    String? userId,
    String? role,
    Value<String?> joinedAt = const Value.absent(),
    Value<String?> removedAt = const Value.absent(),
    Value<String?> lastReadMsgId = const Value.absent(),
    Value<String?> lastDeliveredMsgId = const Value.absent(),
  }) => ChatMember(
    id: id ?? this.id,
    chatId: chatId ?? this.chatId,
    userId: userId ?? this.userId,
    role: role ?? this.role,
    joinedAt: joinedAt.present ? joinedAt.value : this.joinedAt,
    removedAt: removedAt.present ? removedAt.value : this.removedAt,
    lastReadMsgId: lastReadMsgId.present
        ? lastReadMsgId.value
        : this.lastReadMsgId,
    lastDeliveredMsgId: lastDeliveredMsgId.present
        ? lastDeliveredMsgId.value
        : this.lastDeliveredMsgId,
  );
  ChatMember copyWithCompanion(ChatMembersCompanion data) {
    return ChatMember(
      id: data.id.present ? data.id.value : this.id,
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      userId: data.userId.present ? data.userId.value : this.userId,
      role: data.role.present ? data.role.value : this.role,
      joinedAt: data.joinedAt.present ? data.joinedAt.value : this.joinedAt,
      removedAt: data.removedAt.present ? data.removedAt.value : this.removedAt,
      lastReadMsgId: data.lastReadMsgId.present
          ? data.lastReadMsgId.value
          : this.lastReadMsgId,
      lastDeliveredMsgId: data.lastDeliveredMsgId.present
          ? data.lastDeliveredMsgId.value
          : this.lastDeliveredMsgId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatMember(')
          ..write('id: $id, ')
          ..write('chatId: $chatId, ')
          ..write('userId: $userId, ')
          ..write('role: $role, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('removedAt: $removedAt, ')
          ..write('lastReadMsgId: $lastReadMsgId, ')
          ..write('lastDeliveredMsgId: $lastDeliveredMsgId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    chatId,
    userId,
    role,
    joinedAt,
    removedAt,
    lastReadMsgId,
    lastDeliveredMsgId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMember &&
          other.id == this.id &&
          other.chatId == this.chatId &&
          other.userId == this.userId &&
          other.role == this.role &&
          other.joinedAt == this.joinedAt &&
          other.removedAt == this.removedAt &&
          other.lastReadMsgId == this.lastReadMsgId &&
          other.lastDeliveredMsgId == this.lastDeliveredMsgId);
}

class ChatMembersCompanion extends UpdateCompanion<ChatMember> {
  final Value<String> id;
  final Value<String> chatId;
  final Value<String> userId;
  final Value<String> role;
  final Value<String?> joinedAt;
  final Value<String?> removedAt;
  final Value<String?> lastReadMsgId;
  final Value<String?> lastDeliveredMsgId;
  final Value<int> rowid;
  const ChatMembersCompanion({
    this.id = const Value.absent(),
    this.chatId = const Value.absent(),
    this.userId = const Value.absent(),
    this.role = const Value.absent(),
    this.joinedAt = const Value.absent(),
    this.removedAt = const Value.absent(),
    this.lastReadMsgId = const Value.absent(),
    this.lastDeliveredMsgId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatMembersCompanion.insert({
    required String id,
    required String chatId,
    required String userId,
    required String role,
    this.joinedAt = const Value.absent(),
    this.removedAt = const Value.absent(),
    this.lastReadMsgId = const Value.absent(),
    this.lastDeliveredMsgId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       chatId = Value(chatId),
       userId = Value(userId),
       role = Value(role);
  static Insertable<ChatMember> custom({
    Expression<String>? id,
    Expression<String>? chatId,
    Expression<String>? userId,
    Expression<String>? role,
    Expression<String>? joinedAt,
    Expression<String>? removedAt,
    Expression<String>? lastReadMsgId,
    Expression<String>? lastDeliveredMsgId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chatId != null) 'chat_id': chatId,
      if (userId != null) 'user_id': userId,
      if (role != null) 'role': role,
      if (joinedAt != null) 'joined_at': joinedAt,
      if (removedAt != null) 'removed_at': removedAt,
      if (lastReadMsgId != null) 'last_read_msg_id': lastReadMsgId,
      if (lastDeliveredMsgId != null)
        'last_delivered_msg_id': lastDeliveredMsgId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatMembersCompanion copyWith({
    Value<String>? id,
    Value<String>? chatId,
    Value<String>? userId,
    Value<String>? role,
    Value<String?>? joinedAt,
    Value<String?>? removedAt,
    Value<String?>? lastReadMsgId,
    Value<String?>? lastDeliveredMsgId,
    Value<int>? rowid,
  }) {
    return ChatMembersCompanion(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      removedAt: removedAt ?? this.removedAt,
      lastReadMsgId: lastReadMsgId ?? this.lastReadMsgId,
      lastDeliveredMsgId: lastDeliveredMsgId ?? this.lastDeliveredMsgId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (chatId.present) {
      map['chat_id'] = Variable<String>(chatId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (joinedAt.present) {
      map['joined_at'] = Variable<String>(joinedAt.value);
    }
    if (removedAt.present) {
      map['removed_at'] = Variable<String>(removedAt.value);
    }
    if (lastReadMsgId.present) {
      map['last_read_msg_id'] = Variable<String>(lastReadMsgId.value);
    }
    if (lastDeliveredMsgId.present) {
      map['last_delivered_msg_id'] = Variable<String>(lastDeliveredMsgId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatMembersCompanion(')
          ..write('id: $id, ')
          ..write('chatId: $chatId, ')
          ..write('userId: $userId, ')
          ..write('role: $role, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('removedAt: $removedAt, ')
          ..write('lastReadMsgId: $lastReadMsgId, ')
          ..write('lastDeliveredMsgId: $lastDeliveredMsgId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<String> chatId = GeneratedColumn<String>(
    'chat_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderIdMeta = const VerificationMeta(
    'senderId',
  );
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
    'sender_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repliedToMeta = const VerificationMeta(
    'repliedTo',
  );
  @override
  late final GeneratedColumn<String> repliedTo = GeneratedColumn<String>(
    'replied_to',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, dynamic>?, String>
  attachments = GeneratedColumn<String>(
    'attachments',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<Map<String, dynamic>?>($MessagesTable.$converterattachments);
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<String> sentAt = GeneratedColumn<String>(
    'sent_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<String> expiresAt = GeneratedColumn<String>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFailedMeta = const VerificationMeta(
    'isFailed',
  );
  @override
  late final GeneratedColumn<bool> isFailed = GeneratedColumn<bool>(
    'is_failed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_failed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    chatId,
    senderId,
    repliedTo,
    type,
    body,
    attachments,
    sentAt,
    deletedAt,
    expiresAt,
    isFailed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Message> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('chat_id')) {
      context.handle(
        _chatIdMeta,
        chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(
        _senderIdMeta,
        senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta),
      );
    }
    if (data.containsKey('replied_to')) {
      context.handle(
        _repliedToMeta,
        repliedTo.isAcceptableOrUnknown(data['replied_to']!, _repliedToMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('sent_at')) {
      context.handle(
        _sentAtMeta,
        sentAt.isAcceptableOrUnknown(data['sent_at']!, _sentAtMeta),
      );
    } else if (isInserting) {
      context.missing(_sentAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    if (data.containsKey('is_failed')) {
      context.handle(
        _isFailedMeta,
        isFailed.isAcceptableOrUnknown(data['is_failed']!, _isFailedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      chatId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chat_id'],
      )!,
      senderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_id'],
      ),
      repliedTo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}replied_to'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      attachments: $MessagesTable.$converterattachments.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}attachments'],
        ),
      ),
      sentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sent_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expires_at'],
      ),
      isFailed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_failed'],
      )!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }

  static TypeConverter<Map<String, dynamic>?, String?> $converterattachments =
      const JsonMapConverter();
}

class Message extends DataClass implements Insertable<Message> {
  final String id;
  final String chatId;
  final String? senderId;
  final String? repliedTo;
  final String type;
  final String? body;
  final Map<String, dynamic>? attachments;
  final String sentAt;
  final String? deletedAt;
  final String? expiresAt;
  final bool isFailed;
  const Message({
    required this.id,
    required this.chatId,
    this.senderId,
    this.repliedTo,
    required this.type,
    this.body,
    this.attachments,
    required this.sentAt,
    this.deletedAt,
    this.expiresAt,
    required this.isFailed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['chat_id'] = Variable<String>(chatId);
    if (!nullToAbsent || senderId != null) {
      map['sender_id'] = Variable<String>(senderId);
    }
    if (!nullToAbsent || repliedTo != null) {
      map['replied_to'] = Variable<String>(repliedTo);
    }
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    if (!nullToAbsent || attachments != null) {
      map['attachments'] = Variable<String>(
        $MessagesTable.$converterattachments.toSql(attachments),
      );
    }
    map['sent_at'] = Variable<String>(sentAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<String>(expiresAt);
    }
    map['is_failed'] = Variable<bool>(isFailed);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      chatId: Value(chatId),
      senderId: senderId == null && nullToAbsent
          ? const Value.absent()
          : Value(senderId),
      repliedTo: repliedTo == null && nullToAbsent
          ? const Value.absent()
          : Value(repliedTo),
      type: Value(type),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      attachments: attachments == null && nullToAbsent
          ? const Value.absent()
          : Value(attachments),
      sentAt: Value(sentAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      isFailed: Value(isFailed),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<String>(json['id']),
      chatId: serializer.fromJson<String>(json['chatId']),
      senderId: serializer.fromJson<String?>(json['senderId']),
      repliedTo: serializer.fromJson<String?>(json['repliedTo']),
      type: serializer.fromJson<String>(json['type']),
      body: serializer.fromJson<String?>(json['body']),
      attachments: serializer.fromJson<Map<String, dynamic>?>(
        json['attachments'],
      ),
      sentAt: serializer.fromJson<String>(json['sentAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      expiresAt: serializer.fromJson<String?>(json['expiresAt']),
      isFailed: serializer.fromJson<bool>(json['isFailed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'chatId': serializer.toJson<String>(chatId),
      'senderId': serializer.toJson<String?>(senderId),
      'repliedTo': serializer.toJson<String?>(repliedTo),
      'type': serializer.toJson<String>(type),
      'body': serializer.toJson<String?>(body),
      'attachments': serializer.toJson<Map<String, dynamic>?>(attachments),
      'sentAt': serializer.toJson<String>(sentAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'expiresAt': serializer.toJson<String?>(expiresAt),
      'isFailed': serializer.toJson<bool>(isFailed),
    };
  }

  Message copyWith({
    String? id,
    String? chatId,
    Value<String?> senderId = const Value.absent(),
    Value<String?> repliedTo = const Value.absent(),
    String? type,
    Value<String?> body = const Value.absent(),
    Value<Map<String, dynamic>?> attachments = const Value.absent(),
    String? sentAt,
    Value<String?> deletedAt = const Value.absent(),
    Value<String?> expiresAt = const Value.absent(),
    bool? isFailed,
  }) => Message(
    id: id ?? this.id,
    chatId: chatId ?? this.chatId,
    senderId: senderId.present ? senderId.value : this.senderId,
    repliedTo: repliedTo.present ? repliedTo.value : this.repliedTo,
    type: type ?? this.type,
    body: body.present ? body.value : this.body,
    attachments: attachments.present ? attachments.value : this.attachments,
    sentAt: sentAt ?? this.sentAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
    isFailed: isFailed ?? this.isFailed,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      repliedTo: data.repliedTo.present ? data.repliedTo.value : this.repliedTo,
      type: data.type.present ? data.type.value : this.type,
      body: data.body.present ? data.body.value : this.body,
      attachments: data.attachments.present
          ? data.attachments.value
          : this.attachments,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      isFailed: data.isFailed.present ? data.isFailed.value : this.isFailed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('chatId: $chatId, ')
          ..write('senderId: $senderId, ')
          ..write('repliedTo: $repliedTo, ')
          ..write('type: $type, ')
          ..write('body: $body, ')
          ..write('attachments: $attachments, ')
          ..write('sentAt: $sentAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('isFailed: $isFailed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    chatId,
    senderId,
    repliedTo,
    type,
    body,
    attachments,
    sentAt,
    deletedAt,
    expiresAt,
    isFailed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.chatId == this.chatId &&
          other.senderId == this.senderId &&
          other.repliedTo == this.repliedTo &&
          other.type == this.type &&
          other.body == this.body &&
          other.attachments == this.attachments &&
          other.sentAt == this.sentAt &&
          other.deletedAt == this.deletedAt &&
          other.expiresAt == this.expiresAt &&
          other.isFailed == this.isFailed);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<String> id;
  final Value<String> chatId;
  final Value<String?> senderId;
  final Value<String?> repliedTo;
  final Value<String> type;
  final Value<String?> body;
  final Value<Map<String, dynamic>?> attachments;
  final Value<String> sentAt;
  final Value<String?> deletedAt;
  final Value<String?> expiresAt;
  final Value<bool> isFailed;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.chatId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.repliedTo = const Value.absent(),
    this.type = const Value.absent(),
    this.body = const Value.absent(),
    this.attachments = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.isFailed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String chatId,
    this.senderId = const Value.absent(),
    this.repliedTo = const Value.absent(),
    required String type,
    this.body = const Value.absent(),
    this.attachments = const Value.absent(),
    required String sentAt,
    this.deletedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.isFailed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       chatId = Value(chatId),
       type = Value(type),
       sentAt = Value(sentAt);
  static Insertable<Message> custom({
    Expression<String>? id,
    Expression<String>? chatId,
    Expression<String>? senderId,
    Expression<String>? repliedTo,
    Expression<String>? type,
    Expression<String>? body,
    Expression<String>? attachments,
    Expression<String>? sentAt,
    Expression<String>? deletedAt,
    Expression<String>? expiresAt,
    Expression<bool>? isFailed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chatId != null) 'chat_id': chatId,
      if (senderId != null) 'sender_id': senderId,
      if (repliedTo != null) 'replied_to': repliedTo,
      if (type != null) 'type': type,
      if (body != null) 'body': body,
      if (attachments != null) 'attachments': attachments,
      if (sentAt != null) 'sent_at': sentAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (isFailed != null) 'is_failed': isFailed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? chatId,
    Value<String?>? senderId,
    Value<String?>? repliedTo,
    Value<String>? type,
    Value<String?>? body,
    Value<Map<String, dynamic>?>? attachments,
    Value<String>? sentAt,
    Value<String?>? deletedAt,
    Value<String?>? expiresAt,
    Value<bool>? isFailed,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      repliedTo: repliedTo ?? this.repliedTo,
      type: type ?? this.type,
      body: body ?? this.body,
      attachments: attachments ?? this.attachments,
      sentAt: sentAt ?? this.sentAt,
      deletedAt: deletedAt ?? this.deletedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isFailed: isFailed ?? this.isFailed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (chatId.present) {
      map['chat_id'] = Variable<String>(chatId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (repliedTo.present) {
      map['replied_to'] = Variable<String>(repliedTo.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (attachments.present) {
      map['attachments'] = Variable<String>(
        $MessagesTable.$converterattachments.toSql(attachments.value),
      );
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<String>(sentAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<String>(expiresAt.value);
    }
    if (isFailed.present) {
      map['is_failed'] = Variable<bool>(isFailed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('chatId: $chatId, ')
          ..write('senderId: $senderId, ')
          ..write('repliedTo: $repliedTo, ')
          ..write('type: $type, ')
          ..write('body: $body, ')
          ..write('attachments: $attachments, ')
          ..write('sentAt: $sentAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('isFailed: $isFailed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessageInfoTable extends MessageInfo
    with TableInfo<$MessageInfoTable, MessageInfoData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageInfoTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<String> chatId = GeneratedColumn<String>(
    'chat_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deliveredAtMeta = const VerificationMeta(
    'deliveredAt',
  );
  @override
  late final GeneratedColumn<String> deliveredAt = GeneratedColumn<String>(
    'delivered_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<String> readAt = GeneratedColumn<String>(
    'read_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reactionMeta = const VerificationMeta(
    'reaction',
  );
  @override
  late final GeneratedColumn<String> reaction = GeneratedColumn<String>(
    'reaction',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    chatId,
    messageId,
    userId,
    deliveredAt,
    readAt,
    reaction,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_info';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageInfoData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chat_id')) {
      context.handle(
        _chatIdMeta,
        chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('delivered_at')) {
      context.handle(
        _deliveredAtMeta,
        deliveredAt.isAcceptableOrUnknown(
          data['delivered_at']!,
          _deliveredAtMeta,
        ),
      );
    }
    if (data.containsKey('read_at')) {
      context.handle(
        _readAtMeta,
        readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta),
      );
    }
    if (data.containsKey('reaction')) {
      context.handle(
        _reactionMeta,
        reaction.isAcceptableOrUnknown(data['reaction']!, _reactionMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId, userId};
  @override
  MessageInfoData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageInfoData(
      chatId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chat_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      deliveredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}delivered_at'],
      ),
      readAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}read_at'],
      ),
      reaction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reaction'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $MessageInfoTable createAlias(String alias) {
    return $MessageInfoTable(attachedDatabase, alias);
  }
}

class MessageInfoData extends DataClass implements Insertable<MessageInfoData> {
  final String chatId;
  final String messageId;
  final String userId;
  final String? deliveredAt;
  final String? readAt;
  final String? reaction;
  final String? deletedAt;
  const MessageInfoData({
    required this.chatId,
    required this.messageId,
    required this.userId,
    this.deliveredAt,
    this.readAt,
    this.reaction,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chat_id'] = Variable<String>(chatId);
    map['message_id'] = Variable<String>(messageId);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || deliveredAt != null) {
      map['delivered_at'] = Variable<String>(deliveredAt);
    }
    if (!nullToAbsent || readAt != null) {
      map['read_at'] = Variable<String>(readAt);
    }
    if (!nullToAbsent || reaction != null) {
      map['reaction'] = Variable<String>(reaction);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  MessageInfoCompanion toCompanion(bool nullToAbsent) {
    return MessageInfoCompanion(
      chatId: Value(chatId),
      messageId: Value(messageId),
      userId: Value(userId),
      deliveredAt: deliveredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deliveredAt),
      readAt: readAt == null && nullToAbsent
          ? const Value.absent()
          : Value(readAt),
      reaction: reaction == null && nullToAbsent
          ? const Value.absent()
          : Value(reaction),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory MessageInfoData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageInfoData(
      chatId: serializer.fromJson<String>(json['chatId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      userId: serializer.fromJson<String>(json['userId']),
      deliveredAt: serializer.fromJson<String?>(json['deliveredAt']),
      readAt: serializer.fromJson<String?>(json['readAt']),
      reaction: serializer.fromJson<String?>(json['reaction']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chatId': serializer.toJson<String>(chatId),
      'messageId': serializer.toJson<String>(messageId),
      'userId': serializer.toJson<String>(userId),
      'deliveredAt': serializer.toJson<String?>(deliveredAt),
      'readAt': serializer.toJson<String?>(readAt),
      'reaction': serializer.toJson<String?>(reaction),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  MessageInfoData copyWith({
    String? chatId,
    String? messageId,
    String? userId,
    Value<String?> deliveredAt = const Value.absent(),
    Value<String?> readAt = const Value.absent(),
    Value<String?> reaction = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
  }) => MessageInfoData(
    chatId: chatId ?? this.chatId,
    messageId: messageId ?? this.messageId,
    userId: userId ?? this.userId,
    deliveredAt: deliveredAt.present ? deliveredAt.value : this.deliveredAt,
    readAt: readAt.present ? readAt.value : this.readAt,
    reaction: reaction.present ? reaction.value : this.reaction,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  MessageInfoData copyWithCompanion(MessageInfoCompanion data) {
    return MessageInfoData(
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      userId: data.userId.present ? data.userId.value : this.userId,
      deliveredAt: data.deliveredAt.present
          ? data.deliveredAt.value
          : this.deliveredAt,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
      reaction: data.reaction.present ? data.reaction.value : this.reaction,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageInfoData(')
          ..write('chatId: $chatId, ')
          ..write('messageId: $messageId, ')
          ..write('userId: $userId, ')
          ..write('deliveredAt: $deliveredAt, ')
          ..write('readAt: $readAt, ')
          ..write('reaction: $reaction, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    chatId,
    messageId,
    userId,
    deliveredAt,
    readAt,
    reaction,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageInfoData &&
          other.chatId == this.chatId &&
          other.messageId == this.messageId &&
          other.userId == this.userId &&
          other.deliveredAt == this.deliveredAt &&
          other.readAt == this.readAt &&
          other.reaction == this.reaction &&
          other.deletedAt == this.deletedAt);
}

class MessageInfoCompanion extends UpdateCompanion<MessageInfoData> {
  final Value<String> chatId;
  final Value<String> messageId;
  final Value<String> userId;
  final Value<String?> deliveredAt;
  final Value<String?> readAt;
  final Value<String?> reaction;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const MessageInfoCompanion({
    this.chatId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.userId = const Value.absent(),
    this.deliveredAt = const Value.absent(),
    this.readAt = const Value.absent(),
    this.reaction = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageInfoCompanion.insert({
    required String chatId,
    required String messageId,
    required String userId,
    this.deliveredAt = const Value.absent(),
    this.readAt = const Value.absent(),
    this.reaction = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : chatId = Value(chatId),
       messageId = Value(messageId),
       userId = Value(userId);
  static Insertable<MessageInfoData> custom({
    Expression<String>? chatId,
    Expression<String>? messageId,
    Expression<String>? userId,
    Expression<String>? deliveredAt,
    Expression<String>? readAt,
    Expression<String>? reaction,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chatId != null) 'chat_id': chatId,
      if (messageId != null) 'message_id': messageId,
      if (userId != null) 'user_id': userId,
      if (deliveredAt != null) 'delivered_at': deliveredAt,
      if (readAt != null) 'read_at': readAt,
      if (reaction != null) 'reaction': reaction,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageInfoCompanion copyWith({
    Value<String>? chatId,
    Value<String>? messageId,
    Value<String>? userId,
    Value<String?>? deliveredAt,
    Value<String?>? readAt,
    Value<String?>? reaction,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return MessageInfoCompanion(
      chatId: chatId ?? this.chatId,
      messageId: messageId ?? this.messageId,
      userId: userId ?? this.userId,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      reaction: reaction ?? this.reaction,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chatId.present) {
      map['chat_id'] = Variable<String>(chatId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (deliveredAt.present) {
      map['delivered_at'] = Variable<String>(deliveredAt.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<String>(readAt.value);
    }
    if (reaction.present) {
      map['reaction'] = Variable<String>(reaction.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageInfoCompanion(')
          ..write('chatId: $chatId, ')
          ..write('messageId: $messageId, ')
          ..write('userId: $userId, ')
          ..write('deliveredAt: $deliveredAt, ')
          ..write('readAt: $readAt, ')
          ..write('reaction: $reaction, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MissedWsMessagesTable extends MissedWsMessages
    with TableInfo<$MissedWsMessagesTable, MissedWsMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MissedWsMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, eventType, payload, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'missed_ws_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<MissedWsMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MissedWsMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MissedWsMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MissedWsMessagesTable createAlias(String alias) {
    return $MissedWsMessagesTable(attachedDatabase, alias);
  }
}

class MissedWsMessage extends DataClass implements Insertable<MissedWsMessage> {
  final String id;
  final String eventType;
  final String payload;
  final String createdAt;
  const MissedWsMessage({
    required this.id,
    required this.eventType,
    required this.payload,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['event_type'] = Variable<String>(eventType);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  MissedWsMessagesCompanion toCompanion(bool nullToAbsent) {
    return MissedWsMessagesCompanion(
      id: Value(id),
      eventType: Value(eventType),
      payload: Value(payload),
      createdAt: Value(createdAt),
    );
  }

  factory MissedWsMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MissedWsMessage(
      id: serializer.fromJson<String>(json['id']),
      eventType: serializer.fromJson<String>(json['eventType']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'eventType': serializer.toJson<String>(eventType),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  MissedWsMessage copyWith({
    String? id,
    String? eventType,
    String? payload,
    String? createdAt,
  }) => MissedWsMessage(
    id: id ?? this.id,
    eventType: eventType ?? this.eventType,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
  );
  MissedWsMessage copyWithCompanion(MissedWsMessagesCompanion data) {
    return MissedWsMessage(
      id: data.id.present ? data.id.value : this.id,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MissedWsMessage(')
          ..write('id: $id, ')
          ..write('eventType: $eventType, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, eventType, payload, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MissedWsMessage &&
          other.id == this.id &&
          other.eventType == this.eventType &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt);
}

class MissedWsMessagesCompanion extends UpdateCompanion<MissedWsMessage> {
  final Value<String> id;
  final Value<String> eventType;
  final Value<String> payload;
  final Value<String> createdAt;
  final Value<int> rowid;
  const MissedWsMessagesCompanion({
    this.id = const Value.absent(),
    this.eventType = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MissedWsMessagesCompanion.insert({
    required String id,
    required String eventType,
    required String payload,
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       eventType = Value(eventType),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<MissedWsMessage> custom({
    Expression<String>? id,
    Expression<String>? eventType,
    Expression<String>? payload,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventType != null) 'event_type': eventType,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MissedWsMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? eventType,
    Value<String>? payload,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return MissedWsMessagesCompanion(
      id: id ?? this.id,
      eventType: eventType ?? this.eventType,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MissedWsMessagesCompanion(')
          ..write('id: $id, ')
          ..write('eventType: $eventType, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UsersTable users = $UsersTable(this);
  late final $ContactsTable contacts = $ContactsTable(this);
  late final $CallsTable calls = $CallsTable(this);
  late final $ChatsTable chats = $ChatsTable(this);
  late final $ChatMembersTable chatMembers = $ChatMembersTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $MessageInfoTable messageInfo = $MessageInfoTable(this);
  late final $MissedWsMessagesTable missedWsMessages = $MissedWsMessagesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    users,
    contacts,
    calls,
    chats,
    chatMembers,
    messages,
    messageInfo,
    missedWsMessages,
  ];
}

typedef $$UsersTableCreateCompanionBuilder =
    UsersCompanion Function({
      required String id,
      required String name,
      Value<String?> username,
      required String phone,
      Value<String?> role,
      required bool isOnline,
      Value<String?> profilePic,
      Value<bool?> callAccess,
      Value<String?> lastSeen,
      Value<int> rowid,
    });
typedef $$UsersTableUpdateCompanionBuilder =
    UsersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> username,
      Value<String> phone,
      Value<String?> role,
      Value<bool> isOnline,
      Value<String?> profilePic,
      Value<bool?> callAccess,
      Value<String?> lastSeen,
      Value<int> rowid,
    });

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isOnline => $composableBuilder(
    column: $table.isOnline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profilePic => $composableBuilder(
    column: $table.profilePic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get callAccess => $composableBuilder(
    column: $table.callAccess,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isOnline => $composableBuilder(
    column: $table.isOnline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profilePic => $composableBuilder(
    column: $table.profilePic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get callAccess => $composableBuilder(
    column: $table.callAccess,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<bool> get isOnline =>
      $composableBuilder(column: $table.isOnline, builder: (column) => column);

  GeneratedColumn<String> get profilePic => $composableBuilder(
    column: $table.profilePic,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get callAccess => $composableBuilder(
    column: $table.callAccess,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);
}

class $$UsersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsersTable,
          User,
          $$UsersTableFilterComposer,
          $$UsersTableOrderingComposer,
          $$UsersTableAnnotationComposer,
          $$UsersTableCreateCompanionBuilder,
          $$UsersTableUpdateCompanionBuilder,
          (User, BaseReferences<_$AppDatabase, $UsersTable, User>),
          User,
          PrefetchHooks Function()
        > {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> username = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<bool> isOnline = const Value.absent(),
                Value<String?> profilePic = const Value.absent(),
                Value<bool?> callAccess = const Value.absent(),
                Value<String?> lastSeen = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersCompanion(
                id: id,
                name: name,
                username: username,
                phone: phone,
                role: role,
                isOnline: isOnline,
                profilePic: profilePic,
                callAccess: callAccess,
                lastSeen: lastSeen,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> username = const Value.absent(),
                required String phone,
                Value<String?> role = const Value.absent(),
                required bool isOnline,
                Value<String?> profilePic = const Value.absent(),
                Value<bool?> callAccess = const Value.absent(),
                Value<String?> lastSeen = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersCompanion.insert(
                id: id,
                name: name,
                username: username,
                phone: phone,
                role: role,
                isOnline: isOnline,
                profilePic: profilePic,
                callAccess: callAccess,
                lastSeen: lastSeen,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsersTable,
      User,
      $$UsersTableFilterComposer,
      $$UsersTableOrderingComposer,
      $$UsersTableAnnotationComposer,
      $$UsersTableCreateCompanionBuilder,
      $$UsersTableUpdateCompanionBuilder,
      (User, BaseReferences<_$AppDatabase, $UsersTable, User>),
      User,
      PrefetchHooks Function()
    >;
typedef $$ContactsTableCreateCompanionBuilder =
    ContactsCompanion Function({
      required String id,
      required String name,
      required String phone,
      Value<String?> profilePic,
      Value<int> rowid,
    });
typedef $$ContactsTableUpdateCompanionBuilder =
    ContactsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> phone,
      Value<String?> profilePic,
      Value<int> rowid,
    });

class $$ContactsTableFilterComposer
    extends Composer<_$AppDatabase, $ContactsTable> {
  $$ContactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profilePic => $composableBuilder(
    column: $table.profilePic,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContactsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContactsTable> {
  $$ContactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profilePic => $composableBuilder(
    column: $table.profilePic,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContactsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContactsTable> {
  $$ContactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get profilePic => $composableBuilder(
    column: $table.profilePic,
    builder: (column) => column,
  );
}

class $$ContactsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContactsTable,
          Contact,
          $$ContactsTableFilterComposer,
          $$ContactsTableOrderingComposer,
          $$ContactsTableAnnotationComposer,
          $$ContactsTableCreateCompanionBuilder,
          $$ContactsTableUpdateCompanionBuilder,
          (Contact, BaseReferences<_$AppDatabase, $ContactsTable, Contact>),
          Contact,
          PrefetchHooks Function()
        > {
  $$ContactsTableTableManager(_$AppDatabase db, $ContactsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String?> profilePic = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion(
                id: id,
                name: name,
                phone: phone,
                profilePic: profilePic,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String phone,
                Value<String?> profilePic = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion.insert(
                id: id,
                name: name,
                phone: phone,
                profilePic: profilePic,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContactsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContactsTable,
      Contact,
      $$ContactsTableFilterComposer,
      $$ContactsTableOrderingComposer,
      $$ContactsTableAnnotationComposer,
      $$ContactsTableCreateCompanionBuilder,
      $$ContactsTableUpdateCompanionBuilder,
      (Contact, BaseReferences<_$AppDatabase, $ContactsTable, Contact>),
      Contact,
      PrefetchHooks Function()
    >;
typedef $$CallsTableCreateCompanionBuilder =
    CallsCompanion Function({
      required String id,
      required String callerId,
      required String calleeId,
      required String startedAt,
      Value<String?> answeredAt,
      Value<String?> endedAt,
      Value<int> durationSeconds,
      required String status,
      Value<String?> reason,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$CallsTableUpdateCompanionBuilder =
    CallsCompanion Function({
      Value<String> id,
      Value<String> callerId,
      Value<String> calleeId,
      Value<String> startedAt,
      Value<String?> answeredAt,
      Value<String?> endedAt,
      Value<int> durationSeconds,
      Value<String> status,
      Value<String?> reason,
      Value<String> createdAt,
      Value<int> rowid,
    });

class $$CallsTableFilterComposer extends Composer<_$AppDatabase, $CallsTable> {
  $$CallsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get callerId => $composableBuilder(
    column: $table.callerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get calleeId => $composableBuilder(
    column: $table.calleeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CallsTableOrderingComposer
    extends Composer<_$AppDatabase, $CallsTable> {
  $$CallsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get callerId => $composableBuilder(
    column: $table.callerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get calleeId => $composableBuilder(
    column: $table.calleeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CallsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CallsTable> {
  $$CallsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get callerId =>
      $composableBuilder(column: $table.callerId, builder: (column) => column);

  GeneratedColumn<String> get calleeId =>
      $composableBuilder(column: $table.calleeId, builder: (column) => column);

  GeneratedColumn<String> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<String> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CallsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CallsTable,
          Call,
          $$CallsTableFilterComposer,
          $$CallsTableOrderingComposer,
          $$CallsTableAnnotationComposer,
          $$CallsTableCreateCompanionBuilder,
          $$CallsTableUpdateCompanionBuilder,
          (Call, BaseReferences<_$AppDatabase, $CallsTable, Call>),
          Call,
          PrefetchHooks Function()
        > {
  $$CallsTableTableManager(_$AppDatabase db, $CallsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CallsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CallsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CallsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> callerId = const Value.absent(),
                Value<String> calleeId = const Value.absent(),
                Value<String> startedAt = const Value.absent(),
                Value<String?> answeredAt = const Value.absent(),
                Value<String?> endedAt = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CallsCompanion(
                id: id,
                callerId: callerId,
                calleeId: calleeId,
                startedAt: startedAt,
                answeredAt: answeredAt,
                endedAt: endedAt,
                durationSeconds: durationSeconds,
                status: status,
                reason: reason,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String callerId,
                required String calleeId,
                required String startedAt,
                Value<String?> answeredAt = const Value.absent(),
                Value<String?> endedAt = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                required String status,
                Value<String?> reason = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => CallsCompanion.insert(
                id: id,
                callerId: callerId,
                calleeId: calleeId,
                startedAt: startedAt,
                answeredAt: answeredAt,
                endedAt: endedAt,
                durationSeconds: durationSeconds,
                status: status,
                reason: reason,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CallsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CallsTable,
      Call,
      $$CallsTableFilterComposer,
      $$CallsTableOrderingComposer,
      $$CallsTableAnnotationComposer,
      $$CallsTableCreateCompanionBuilder,
      $$CallsTableUpdateCompanionBuilder,
      (Call, BaseReferences<_$AppDatabase, $CallsTable, Call>),
      Call,
      PrefetchHooks Function()
    >;
typedef $$ChatsTableCreateCompanionBuilder =
    ChatsCompanion Function({
      required String id,
      required String type,
      Value<String?> title,
      Value<String?> createrId,
      Value<int?> unreadCount,
      Value<String?> lastMsgId,
      Value<String?> lastMsgAt,
      Value<String?> pinnedMsgId,
      Value<String?> deletedAt,
      Value<bool> isPinned,
      Value<bool> isFavorite,
      Value<bool> isMuted,
      Value<String?> createdAt,
      Value<String?> updatedAt,
      Value<bool> needSync,
      Value<int?> disappearingAfterSec,
      Value<int> rowid,
    });
typedef $$ChatsTableUpdateCompanionBuilder =
    ChatsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String?> title,
      Value<String?> createrId,
      Value<int?> unreadCount,
      Value<String?> lastMsgId,
      Value<String?> lastMsgAt,
      Value<String?> pinnedMsgId,
      Value<String?> deletedAt,
      Value<bool> isPinned,
      Value<bool> isFavorite,
      Value<bool> isMuted,
      Value<String?> createdAt,
      Value<String?> updatedAt,
      Value<bool> needSync,
      Value<int?> disappearingAfterSec,
      Value<int> rowid,
    });

class $$ChatsTableFilterComposer extends Composer<_$AppDatabase, $ChatsTable> {
  $$ChatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createrId => $composableBuilder(
    column: $table.createrId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMsgId => $composableBuilder(
    column: $table.lastMsgId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMsgAt => $composableBuilder(
    column: $table.lastMsgAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinnedMsgId => $composableBuilder(
    column: $table.pinnedMsgId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMuted => $composableBuilder(
    column: $table.isMuted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get needSync => $composableBuilder(
    column: $table.needSync,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get disappearingAfterSec => $composableBuilder(
    column: $table.disappearingAfterSec,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatsTable> {
  $$ChatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createrId => $composableBuilder(
    column: $table.createrId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMsgId => $composableBuilder(
    column: $table.lastMsgId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMsgAt => $composableBuilder(
    column: $table.lastMsgAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinnedMsgId => $composableBuilder(
    column: $table.pinnedMsgId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMuted => $composableBuilder(
    column: $table.isMuted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get needSync => $composableBuilder(
    column: $table.needSync,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get disappearingAfterSec => $composableBuilder(
    column: $table.disappearingAfterSec,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatsTable> {
  $$ChatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get createrId =>
      $composableBuilder(column: $table.createrId, builder: (column) => column);

  GeneratedColumn<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMsgId =>
      $composableBuilder(column: $table.lastMsgId, builder: (column) => column);

  GeneratedColumn<String> get lastMsgAt =>
      $composableBuilder(column: $table.lastMsgAt, builder: (column) => column);

  GeneratedColumn<String> get pinnedMsgId => $composableBuilder(
    column: $table.pinnedMsgId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isMuted =>
      $composableBuilder(column: $table.isMuted, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get needSync =>
      $composableBuilder(column: $table.needSync, builder: (column) => column);

  GeneratedColumn<int> get disappearingAfterSec => $composableBuilder(
    column: $table.disappearingAfterSec,
    builder: (column) => column,
  );
}

class $$ChatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatsTable,
          Chat,
          $$ChatsTableFilterComposer,
          $$ChatsTableOrderingComposer,
          $$ChatsTableAnnotationComposer,
          $$ChatsTableCreateCompanionBuilder,
          $$ChatsTableUpdateCompanionBuilder,
          (Chat, BaseReferences<_$AppDatabase, $ChatsTable, Chat>),
          Chat,
          PrefetchHooks Function()
        > {
  $$ChatsTableTableManager(_$AppDatabase db, $ChatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> createrId = const Value.absent(),
                Value<int?> unreadCount = const Value.absent(),
                Value<String?> lastMsgId = const Value.absent(),
                Value<String?> lastMsgAt = const Value.absent(),
                Value<String?> pinnedMsgId = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<bool> isMuted = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<bool> needSync = const Value.absent(),
                Value<int?> disappearingAfterSec = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatsCompanion(
                id: id,
                type: type,
                title: title,
                createrId: createrId,
                unreadCount: unreadCount,
                lastMsgId: lastMsgId,
                lastMsgAt: lastMsgAt,
                pinnedMsgId: pinnedMsgId,
                deletedAt: deletedAt,
                isPinned: isPinned,
                isFavorite: isFavorite,
                isMuted: isMuted,
                createdAt: createdAt,
                updatedAt: updatedAt,
                needSync: needSync,
                disappearingAfterSec: disappearingAfterSec,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                Value<String?> title = const Value.absent(),
                Value<String?> createrId = const Value.absent(),
                Value<int?> unreadCount = const Value.absent(),
                Value<String?> lastMsgId = const Value.absent(),
                Value<String?> lastMsgAt = const Value.absent(),
                Value<String?> pinnedMsgId = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<bool> isMuted = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<bool> needSync = const Value.absent(),
                Value<int?> disappearingAfterSec = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatsCompanion.insert(
                id: id,
                type: type,
                title: title,
                createrId: createrId,
                unreadCount: unreadCount,
                lastMsgId: lastMsgId,
                lastMsgAt: lastMsgAt,
                pinnedMsgId: pinnedMsgId,
                deletedAt: deletedAt,
                isPinned: isPinned,
                isFavorite: isFavorite,
                isMuted: isMuted,
                createdAt: createdAt,
                updatedAt: updatedAt,
                needSync: needSync,
                disappearingAfterSec: disappearingAfterSec,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatsTable,
      Chat,
      $$ChatsTableFilterComposer,
      $$ChatsTableOrderingComposer,
      $$ChatsTableAnnotationComposer,
      $$ChatsTableCreateCompanionBuilder,
      $$ChatsTableUpdateCompanionBuilder,
      (Chat, BaseReferences<_$AppDatabase, $ChatsTable, Chat>),
      Chat,
      PrefetchHooks Function()
    >;
typedef $$ChatMembersTableCreateCompanionBuilder =
    ChatMembersCompanion Function({
      required String id,
      required String chatId,
      required String userId,
      required String role,
      Value<String?> joinedAt,
      Value<String?> removedAt,
      Value<String?> lastReadMsgId,
      Value<String?> lastDeliveredMsgId,
      Value<int> rowid,
    });
typedef $$ChatMembersTableUpdateCompanionBuilder =
    ChatMembersCompanion Function({
      Value<String> id,
      Value<String> chatId,
      Value<String> userId,
      Value<String> role,
      Value<String?> joinedAt,
      Value<String?> removedAt,
      Value<String?> lastReadMsgId,
      Value<String?> lastDeliveredMsgId,
      Value<int> rowid,
    });

class $$ChatMembersTableFilterComposer
    extends Composer<_$AppDatabase, $ChatMembersTable> {
  $$ChatMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get removedAt => $composableBuilder(
    column: $table.removedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastReadMsgId => $composableBuilder(
    column: $table.lastReadMsgId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastDeliveredMsgId => $composableBuilder(
    column: $table.lastDeliveredMsgId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatMembersTable> {
  $$ChatMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get removedAt => $composableBuilder(
    column: $table.removedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastReadMsgId => $composableBuilder(
    column: $table.lastReadMsgId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastDeliveredMsgId => $composableBuilder(
    column: $table.lastDeliveredMsgId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatMembersTable> {
  $$ChatMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get joinedAt =>
      $composableBuilder(column: $table.joinedAt, builder: (column) => column);

  GeneratedColumn<String> get removedAt =>
      $composableBuilder(column: $table.removedAt, builder: (column) => column);

  GeneratedColumn<String> get lastReadMsgId => $composableBuilder(
    column: $table.lastReadMsgId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastDeliveredMsgId => $composableBuilder(
    column: $table.lastDeliveredMsgId,
    builder: (column) => column,
  );
}

class $$ChatMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatMembersTable,
          ChatMember,
          $$ChatMembersTableFilterComposer,
          $$ChatMembersTableOrderingComposer,
          $$ChatMembersTableAnnotationComposer,
          $$ChatMembersTableCreateCompanionBuilder,
          $$ChatMembersTableUpdateCompanionBuilder,
          (
            ChatMember,
            BaseReferences<_$AppDatabase, $ChatMembersTable, ChatMember>,
          ),
          ChatMember,
          PrefetchHooks Function()
        > {
  $$ChatMembersTableTableManager(_$AppDatabase db, $ChatMembersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatMembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> chatId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String?> joinedAt = const Value.absent(),
                Value<String?> removedAt = const Value.absent(),
                Value<String?> lastReadMsgId = const Value.absent(),
                Value<String?> lastDeliveredMsgId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatMembersCompanion(
                id: id,
                chatId: chatId,
                userId: userId,
                role: role,
                joinedAt: joinedAt,
                removedAt: removedAt,
                lastReadMsgId: lastReadMsgId,
                lastDeliveredMsgId: lastDeliveredMsgId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String chatId,
                required String userId,
                required String role,
                Value<String?> joinedAt = const Value.absent(),
                Value<String?> removedAt = const Value.absent(),
                Value<String?> lastReadMsgId = const Value.absent(),
                Value<String?> lastDeliveredMsgId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatMembersCompanion.insert(
                id: id,
                chatId: chatId,
                userId: userId,
                role: role,
                joinedAt: joinedAt,
                removedAt: removedAt,
                lastReadMsgId: lastReadMsgId,
                lastDeliveredMsgId: lastDeliveredMsgId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatMembersTable,
      ChatMember,
      $$ChatMembersTableFilterComposer,
      $$ChatMembersTableOrderingComposer,
      $$ChatMembersTableAnnotationComposer,
      $$ChatMembersTableCreateCompanionBuilder,
      $$ChatMembersTableUpdateCompanionBuilder,
      (
        ChatMember,
        BaseReferences<_$AppDatabase, $ChatMembersTable, ChatMember>,
      ),
      ChatMember,
      PrefetchHooks Function()
    >;
typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      required String id,
      required String chatId,
      Value<String?> senderId,
      Value<String?> repliedTo,
      required String type,
      Value<String?> body,
      Value<Map<String, dynamic>?> attachments,
      required String sentAt,
      Value<String?> deletedAt,
      Value<String?> expiresAt,
      Value<bool> isFailed,
      Value<int> rowid,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<String> id,
      Value<String> chatId,
      Value<String?> senderId,
      Value<String?> repliedTo,
      Value<String> type,
      Value<String?> body,
      Value<Map<String, dynamic>?> attachments,
      Value<String> sentAt,
      Value<String?> deletedAt,
      Value<String?> expiresAt,
      Value<bool> isFailed,
      Value<int> rowid,
    });

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repliedTo => $composableBuilder(
    column: $table.repliedTo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    Map<String, dynamic>?,
    Map<String, dynamic>,
    String
  >
  get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFailed => $composableBuilder(
    column: $table.isFailed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repliedTo => $composableBuilder(
    column: $table.repliedTo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFailed => $composableBuilder(
    column: $table.isFailed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get repliedTo =>
      $composableBuilder(column: $table.repliedTo, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Map<String, dynamic>?, String>
  get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<bool> get isFailed =>
      $composableBuilder(column: $table.isFailed, builder: (column) => column);
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTable,
          Message,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
          Message,
          PrefetchHooks Function()
        > {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> chatId = const Value.absent(),
                Value<String?> senderId = const Value.absent(),
                Value<String?> repliedTo = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<Map<String, dynamic>?> attachments = const Value.absent(),
                Value<String> sentAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String?> expiresAt = const Value.absent(),
                Value<bool> isFailed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                chatId: chatId,
                senderId: senderId,
                repliedTo: repliedTo,
                type: type,
                body: body,
                attachments: attachments,
                sentAt: sentAt,
                deletedAt: deletedAt,
                expiresAt: expiresAt,
                isFailed: isFailed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String chatId,
                Value<String?> senderId = const Value.absent(),
                Value<String?> repliedTo = const Value.absent(),
                required String type,
                Value<String?> body = const Value.absent(),
                Value<Map<String, dynamic>?> attachments = const Value.absent(),
                required String sentAt,
                Value<String?> deletedAt = const Value.absent(),
                Value<String?> expiresAt = const Value.absent(),
                Value<bool> isFailed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                chatId: chatId,
                senderId: senderId,
                repliedTo: repliedTo,
                type: type,
                body: body,
                attachments: attachments,
                sentAt: sentAt,
                deletedAt: deletedAt,
                expiresAt: expiresAt,
                isFailed: isFailed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTable,
      Message,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
      Message,
      PrefetchHooks Function()
    >;
typedef $$MessageInfoTableCreateCompanionBuilder =
    MessageInfoCompanion Function({
      required String chatId,
      required String messageId,
      required String userId,
      Value<String?> deliveredAt,
      Value<String?> readAt,
      Value<String?> reaction,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$MessageInfoTableUpdateCompanionBuilder =
    MessageInfoCompanion Function({
      Value<String> chatId,
      Value<String> messageId,
      Value<String> userId,
      Value<String?> deliveredAt,
      Value<String?> readAt,
      Value<String?> reaction,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$MessageInfoTableFilterComposer
    extends Composer<_$AppDatabase, $MessageInfoTable> {
  $$MessageInfoTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deliveredAt => $composableBuilder(
    column: $table.deliveredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reaction => $composableBuilder(
    column: $table.reaction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessageInfoTableOrderingComposer
    extends Composer<_$AppDatabase, $MessageInfoTable> {
  $$MessageInfoTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deliveredAt => $composableBuilder(
    column: $table.deliveredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reaction => $composableBuilder(
    column: $table.reaction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessageInfoTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessageInfoTable> {
  $$MessageInfoTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get deliveredAt => $composableBuilder(
    column: $table.deliveredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);

  GeneratedColumn<String> get reaction =>
      $composableBuilder(column: $table.reaction, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$MessageInfoTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessageInfoTable,
          MessageInfoData,
          $$MessageInfoTableFilterComposer,
          $$MessageInfoTableOrderingComposer,
          $$MessageInfoTableAnnotationComposer,
          $$MessageInfoTableCreateCompanionBuilder,
          $$MessageInfoTableUpdateCompanionBuilder,
          (
            MessageInfoData,
            BaseReferences<_$AppDatabase, $MessageInfoTable, MessageInfoData>,
          ),
          MessageInfoData,
          PrefetchHooks Function()
        > {
  $$MessageInfoTableTableManager(_$AppDatabase db, $MessageInfoTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageInfoTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageInfoTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessageInfoTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> chatId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> deliveredAt = const Value.absent(),
                Value<String?> readAt = const Value.absent(),
                Value<String?> reaction = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageInfoCompanion(
                chatId: chatId,
                messageId: messageId,
                userId: userId,
                deliveredAt: deliveredAt,
                readAt: readAt,
                reaction: reaction,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String chatId,
                required String messageId,
                required String userId,
                Value<String?> deliveredAt = const Value.absent(),
                Value<String?> readAt = const Value.absent(),
                Value<String?> reaction = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageInfoCompanion.insert(
                chatId: chatId,
                messageId: messageId,
                userId: userId,
                deliveredAt: deliveredAt,
                readAt: readAt,
                reaction: reaction,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessageInfoTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessageInfoTable,
      MessageInfoData,
      $$MessageInfoTableFilterComposer,
      $$MessageInfoTableOrderingComposer,
      $$MessageInfoTableAnnotationComposer,
      $$MessageInfoTableCreateCompanionBuilder,
      $$MessageInfoTableUpdateCompanionBuilder,
      (
        MessageInfoData,
        BaseReferences<_$AppDatabase, $MessageInfoTable, MessageInfoData>,
      ),
      MessageInfoData,
      PrefetchHooks Function()
    >;
typedef $$MissedWsMessagesTableCreateCompanionBuilder =
    MissedWsMessagesCompanion Function({
      required String id,
      required String eventType,
      required String payload,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$MissedWsMessagesTableUpdateCompanionBuilder =
    MissedWsMessagesCompanion Function({
      Value<String> id,
      Value<String> eventType,
      Value<String> payload,
      Value<String> createdAt,
      Value<int> rowid,
    });

class $$MissedWsMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MissedWsMessagesTable> {
  $$MissedWsMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MissedWsMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MissedWsMessagesTable> {
  $$MissedWsMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MissedWsMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MissedWsMessagesTable> {
  $$MissedWsMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MissedWsMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MissedWsMessagesTable,
          MissedWsMessage,
          $$MissedWsMessagesTableFilterComposer,
          $$MissedWsMessagesTableOrderingComposer,
          $$MissedWsMessagesTableAnnotationComposer,
          $$MissedWsMessagesTableCreateCompanionBuilder,
          $$MissedWsMessagesTableUpdateCompanionBuilder,
          (
            MissedWsMessage,
            BaseReferences<
              _$AppDatabase,
              $MissedWsMessagesTable,
              MissedWsMessage
            >,
          ),
          MissedWsMessage,
          PrefetchHooks Function()
        > {
  $$MissedWsMessagesTableTableManager(
    _$AppDatabase db,
    $MissedWsMessagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MissedWsMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MissedWsMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MissedWsMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MissedWsMessagesCompanion(
                id: id,
                eventType: eventType,
                payload: payload,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String eventType,
                required String payload,
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MissedWsMessagesCompanion.insert(
                id: id,
                eventType: eventType,
                payload: payload,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MissedWsMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MissedWsMessagesTable,
      MissedWsMessage,
      $$MissedWsMessagesTableFilterComposer,
      $$MissedWsMessagesTableOrderingComposer,
      $$MissedWsMessagesTableAnnotationComposer,
      $$MissedWsMessagesTableCreateCompanionBuilder,
      $$MissedWsMessagesTableUpdateCompanionBuilder,
      (
        MissedWsMessage,
        BaseReferences<_$AppDatabase, $MissedWsMessagesTable, MissedWsMessage>,
      ),
      MissedWsMessage,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db, _db.contacts);
  $$CallsTableTableManager get calls =>
      $$CallsTableTableManager(_db, _db.calls);
  $$ChatsTableTableManager get chats =>
      $$ChatsTableTableManager(_db, _db.chats);
  $$ChatMembersTableTableManager get chatMembers =>
      $$ChatMembersTableTableManager(_db, _db.chatMembers);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$MessageInfoTableTableManager get messageInfo =>
      $$MessageInfoTableTableManager(_db, _db.messageInfo);
  $$MissedWsMessagesTableTableManager get missedWsMessages =>
      $$MissedWsMessagesTableTableManager(_db, _db.missedWsMessages);
}
