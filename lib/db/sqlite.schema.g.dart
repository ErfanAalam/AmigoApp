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
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
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
  List<GeneratedColumn> get $columns => [id, name, phone, role, profilePic];
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
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
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
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
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
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      profilePic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_pic'],
      ),
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class User extends DataClass implements Insertable<User> {
  final int id;
  final String name;
  final String phone;
  final String role;
  final String? profilePic;
  const User({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.profilePic,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['phone'] = Variable<String>(phone);
    map['role'] = Variable<String>(role);
    if (!nullToAbsent || profilePic != null) {
      map['profile_pic'] = Variable<String>(profilePic);
    }
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      name: Value(name),
      phone: Value(phone),
      role: Value(role),
      profilePic: profilePic == null && nullToAbsent
          ? const Value.absent()
          : Value(profilePic),
    );
  }

  factory User.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String>(json['phone']),
      role: serializer.fromJson<String>(json['role']),
      profilePic: serializer.fromJson<String?>(json['profilePic']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String>(phone),
      'role': serializer.toJson<String>(role),
      'profilePic': serializer.toJson<String?>(profilePic),
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? phone,
    String? role,
    Value<String?> profilePic = const Value.absent(),
  }) => User(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    role: role ?? this.role,
    profilePic: profilePic.present ? profilePic.value : this.profilePic,
  );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      role: data.role.present ? data.role.value : this.role,
      profilePic: data.profilePic.present
          ? data.profilePic.value
          : this.profilePic,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('role: $role, ')
          ..write('profilePic: $profilePic')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, phone, role, profilePic);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == this.id &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.role == this.role &&
          other.profilePic == this.profilePic);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> phone;
  final Value<String> role;
  final Value<String?> profilePic;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.role = const Value.absent(),
    this.profilePic = const Value.absent(),
  });
  UsersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String phone,
    required String role,
    this.profilePic = const Value.absent(),
  }) : name = Value(name),
       phone = Value(phone),
       role = Value(role);
  static Insertable<User> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? role,
    Expression<String>? profilePic,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (role != null) 'role': role,
      if (profilePic != null) 'profile_pic': profilePic,
    });
  }

  UsersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? phone,
    Value<String>? role,
    Value<String?>? profilePic,
  }) {
    return UsersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profilePic: profilePic ?? this.profilePic,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (profilePic.present) {
      map['profile_pic'] = Variable<String>(profilePic.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('role: $role, ')
          ..write('profilePic: $profilePic')
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
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
        DriftSqlType.int,
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
  final int id;
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
    map['id'] = Variable<int>(id);
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
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String>(json['phone']),
      profilePic: serializer.fromJson<String?>(json['profilePic']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String>(phone),
      'profilePic': serializer.toJson<String?>(profilePic),
    };
  }

  Contact copyWith({
    int? id,
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
  final Value<int> id;
  final Value<String> name;
  final Value<String> phone;
  final Value<String?> profilePic;
  const ContactsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.profilePic = const Value.absent(),
  });
  ContactsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String phone,
    this.profilePic = const Value.absent(),
  }) : name = Value(name),
       phone = Value(phone);
  static Insertable<Contact> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? profilePic,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (profilePic != null) 'profile_pic': profilePic,
    });
  }

  ContactsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? phone,
    Value<String?>? profilePic,
  }) {
    return ContactsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      profilePic: profilePic ?? this.profilePic,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContactsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('profilePic: $profilePic')
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
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _callerIdMeta = const VerificationMeta(
    'callerId',
  );
  @override
  late final GeneratedColumn<int> callerId = GeneratedColumn<int>(
    'caller_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _calleeIdMeta = const VerificationMeta(
    'calleeId',
  );
  @override
  late final GeneratedColumn<int> calleeId = GeneratedColumn<int>(
    'callee_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _callTypeMeta = const VerificationMeta(
    'callType',
  );
  @override
  late final GeneratedColumn<String> callType = GeneratedColumn<String>(
    'call_type',
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
    endedAt,
    status,
    callType,
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
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
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
    if (data.containsKey('call_type')) {
      context.handle(
        _callTypeMeta,
        callType.isAcceptableOrUnknown(data['call_type']!, _callTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_callTypeMeta);
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
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      callerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}caller_id'],
      )!,
      calleeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}callee_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ended_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      callType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}call_type'],
      )!,
    );
  }

  @override
  $CallsTable createAlias(String alias) {
    return $CallsTable(attachedDatabase, alias);
  }
}

class Call extends DataClass implements Insertable<Call> {
  final int id;
  final int callerId;
  final int calleeId;
  final String startedAt;
  final String? endedAt;
  final String status;
  final String callType;
  const Call({
    required this.id,
    required this.callerId,
    required this.calleeId,
    required this.startedAt,
    this.endedAt,
    required this.status,
    required this.callType,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['caller_id'] = Variable<int>(callerId);
    map['callee_id'] = Variable<int>(calleeId);
    map['started_at'] = Variable<String>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<String>(endedAt);
    }
    map['status'] = Variable<String>(status);
    map['call_type'] = Variable<String>(callType);
    return map;
  }

  CallsCompanion toCompanion(bool nullToAbsent) {
    return CallsCompanion(
      id: Value(id),
      callerId: Value(callerId),
      calleeId: Value(calleeId),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      status: Value(status),
      callType: Value(callType),
    );
  }

  factory Call.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Call(
      id: serializer.fromJson<int>(json['id']),
      callerId: serializer.fromJson<int>(json['callerId']),
      calleeId: serializer.fromJson<int>(json['calleeId']),
      startedAt: serializer.fromJson<String>(json['startedAt']),
      endedAt: serializer.fromJson<String?>(json['endedAt']),
      status: serializer.fromJson<String>(json['status']),
      callType: serializer.fromJson<String>(json['callType']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'callerId': serializer.toJson<int>(callerId),
      'calleeId': serializer.toJson<int>(calleeId),
      'startedAt': serializer.toJson<String>(startedAt),
      'endedAt': serializer.toJson<String?>(endedAt),
      'status': serializer.toJson<String>(status),
      'callType': serializer.toJson<String>(callType),
    };
  }

  Call copyWith({
    int? id,
    int? callerId,
    int? calleeId,
    String? startedAt,
    Value<String?> endedAt = const Value.absent(),
    String? status,
    String? callType,
  }) => Call(
    id: id ?? this.id,
    callerId: callerId ?? this.callerId,
    calleeId: calleeId ?? this.calleeId,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    status: status ?? this.status,
    callType: callType ?? this.callType,
  );
  Call copyWithCompanion(CallsCompanion data) {
    return Call(
      id: data.id.present ? data.id.value : this.id,
      callerId: data.callerId.present ? data.callerId.value : this.callerId,
      calleeId: data.calleeId.present ? data.calleeId.value : this.calleeId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      status: data.status.present ? data.status.value : this.status,
      callType: data.callType.present ? data.callType.value : this.callType,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Call(')
          ..write('id: $id, ')
          ..write('callerId: $callerId, ')
          ..write('calleeId: $calleeId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('status: $status, ')
          ..write('callType: $callType')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, callerId, calleeId, startedAt, endedAt, status, callType);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Call &&
          other.id == this.id &&
          other.callerId == this.callerId &&
          other.calleeId == this.calleeId &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.status == this.status &&
          other.callType == this.callType);
}

class CallsCompanion extends UpdateCompanion<Call> {
  final Value<int> id;
  final Value<int> callerId;
  final Value<int> calleeId;
  final Value<String> startedAt;
  final Value<String?> endedAt;
  final Value<String> status;
  final Value<String> callType;
  const CallsCompanion({
    this.id = const Value.absent(),
    this.callerId = const Value.absent(),
    this.calleeId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.callType = const Value.absent(),
  });
  CallsCompanion.insert({
    this.id = const Value.absent(),
    required int callerId,
    required int calleeId,
    required String startedAt,
    this.endedAt = const Value.absent(),
    required String status,
    required String callType,
  }) : callerId = Value(callerId),
       calleeId = Value(calleeId),
       startedAt = Value(startedAt),
       status = Value(status),
       callType = Value(callType);
  static Insertable<Call> custom({
    Expression<int>? id,
    Expression<int>? callerId,
    Expression<int>? calleeId,
    Expression<String>? startedAt,
    Expression<String>? endedAt,
    Expression<String>? status,
    Expression<String>? callType,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (callerId != null) 'caller_id': callerId,
      if (calleeId != null) 'callee_id': calleeId,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (status != null) 'status': status,
      if (callType != null) 'call_type': callType,
    });
  }

  CallsCompanion copyWith({
    Value<int>? id,
    Value<int>? callerId,
    Value<int>? calleeId,
    Value<String>? startedAt,
    Value<String?>? endedAt,
    Value<String>? status,
    Value<String>? callType,
  }) {
    return CallsCompanion(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      calleeId: calleeId ?? this.calleeId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      status: status ?? this.status,
      callType: callType ?? this.callType,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (callerId.present) {
      map['caller_id'] = Variable<int>(callerId.value);
    }
    if (calleeId.present) {
      map['callee_id'] = Variable<int>(calleeId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<String>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<String>(endedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (callType.present) {
      map['call_type'] = Variable<String>(callType.value);
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
          ..write('endedAt: $endedAt, ')
          ..write('status: $status, ')
          ..write('callType: $callType')
          ..write(')'))
        .toString();
  }
}

class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, Conversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _dmKeyMeta = const VerificationMeta('dmKey');
  @override
  late final GeneratedColumn<String> dmKey = GeneratedColumn<String>(
    'dm_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createrIdMeta = const VerificationMeta(
    'createrId',
  );
  @override
  late final GeneratedColumn<int> createrId = GeneratedColumn<int>(
    'creater_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unreadCountMeta = const VerificationMeta(
    'unreadCount',
  );
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
    'unread_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastMessageIdMeta = const VerificationMeta(
    'lastMessageId',
  );
  @override
  late final GeneratedColumn<int> lastMessageId = GeneratedColumn<int>(
    'last_message_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _needsSyncMeta = const VerificationMeta(
    'needsSync',
  );
  @override
  late final GeneratedColumn<bool> needsSync = GeneratedColumn<bool>(
    'needs_sync',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_sync" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    createdAt,
    dmKey,
    createrId,
    title,
    userId,
    unreadCount,
    lastMessageId,
    isDeleted,
    isPinned,
    isFavorite,
    isMuted,
    needsSync,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Conversation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('dm_key')) {
      context.handle(
        _dmKeyMeta,
        dmKey.isAcceptableOrUnknown(data['dm_key']!, _dmKeyMeta),
      );
    }
    if (data.containsKey('creater_id')) {
      context.handle(
        _createrIdMeta,
        createrId.isAcceptableOrUnknown(data['creater_id']!, _createrIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
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
    if (data.containsKey('last_message_id')) {
      context.handle(
        _lastMessageIdMeta,
        lastMessageId.isAcceptableOrUnknown(
          data['last_message_id']!,
          _lastMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
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
    if (data.containsKey('needs_sync')) {
      context.handle(
        _needsSyncMeta,
        needsSync.isAcceptableOrUnknown(data['needs_sync']!, _needsSyncMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Conversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Conversation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      dmKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dm_key'],
      ),
      createrId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}creater_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      ),
      unreadCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unread_count'],
      )!,
      lastMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_message_id'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
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
      needsSync: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_sync'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class Conversation extends DataClass implements Insertable<Conversation> {
  final int id;
  final String type;
  final String? createdAt;
  final String? dmKey;
  final int? createrId;
  final String? title;
  final int? userId;
  final int unreadCount;
  final int? lastMessageId;
  final bool isDeleted;
  final bool isPinned;
  final bool isFavorite;
  final bool isMuted;
  final bool needsSync;
  final String? updatedAt;
  const Conversation({
    required this.id,
    required this.type,
    this.createdAt,
    this.dmKey,
    this.createrId,
    this.title,
    this.userId,
    required this.unreadCount,
    this.lastMessageId,
    required this.isDeleted,
    required this.isPinned,
    required this.isFavorite,
    required this.isMuted,
    required this.needsSync,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || dmKey != null) {
      map['dm_key'] = Variable<String>(dmKey);
    }
    if (!nullToAbsent || createrId != null) {
      map['creater_id'] = Variable<int>(createrId);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<int>(userId);
    }
    map['unread_count'] = Variable<int>(unreadCount);
    if (!nullToAbsent || lastMessageId != null) {
      map['last_message_id'] = Variable<int>(lastMessageId);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['is_muted'] = Variable<bool>(isMuted);
    map['needs_sync'] = Variable<bool>(needsSync);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      type: Value(type),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      dmKey: dmKey == null && nullToAbsent
          ? const Value.absent()
          : Value(dmKey),
      createrId: createrId == null && nullToAbsent
          ? const Value.absent()
          : Value(createrId),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      unreadCount: Value(unreadCount),
      lastMessageId: lastMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageId),
      isDeleted: Value(isDeleted),
      isPinned: Value(isPinned),
      isFavorite: Value(isFavorite),
      isMuted: Value(isMuted),
      needsSync: Value(needsSync),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory Conversation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Conversation(
      id: serializer.fromJson<int>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      dmKey: serializer.fromJson<String?>(json['dmKey']),
      createrId: serializer.fromJson<int?>(json['createrId']),
      title: serializer.fromJson<String?>(json['title']),
      userId: serializer.fromJson<int?>(json['userId']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      lastMessageId: serializer.fromJson<int?>(json['lastMessageId']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      isMuted: serializer.fromJson<bool>(json['isMuted']),
      needsSync: serializer.fromJson<bool>(json['needsSync']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(type),
      'createdAt': serializer.toJson<String?>(createdAt),
      'dmKey': serializer.toJson<String?>(dmKey),
      'createrId': serializer.toJson<int?>(createrId),
      'title': serializer.toJson<String?>(title),
      'userId': serializer.toJson<int?>(userId),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'lastMessageId': serializer.toJson<int?>(lastMessageId),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'isMuted': serializer.toJson<bool>(isMuted),
      'needsSync': serializer.toJson<bool>(needsSync),
      'updatedAt': serializer.toJson<String?>(updatedAt),
    };
  }

  Conversation copyWith({
    int? id,
    String? type,
    Value<String?> createdAt = const Value.absent(),
    Value<String?> dmKey = const Value.absent(),
    Value<int?> createrId = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<int?> userId = const Value.absent(),
    int? unreadCount,
    Value<int?> lastMessageId = const Value.absent(),
    bool? isDeleted,
    bool? isPinned,
    bool? isFavorite,
    bool? isMuted,
    bool? needsSync,
    Value<String?> updatedAt = const Value.absent(),
  }) => Conversation(
    id: id ?? this.id,
    type: type ?? this.type,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    dmKey: dmKey.present ? dmKey.value : this.dmKey,
    createrId: createrId.present ? createrId.value : this.createrId,
    title: title.present ? title.value : this.title,
    userId: userId.present ? userId.value : this.userId,
    unreadCount: unreadCount ?? this.unreadCount,
    lastMessageId: lastMessageId.present
        ? lastMessageId.value
        : this.lastMessageId,
    isDeleted: isDeleted ?? this.isDeleted,
    isPinned: isPinned ?? this.isPinned,
    isFavorite: isFavorite ?? this.isFavorite,
    isMuted: isMuted ?? this.isMuted,
    needsSync: needsSync ?? this.needsSync,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  Conversation copyWithCompanion(ConversationsCompanion data) {
    return Conversation(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      dmKey: data.dmKey.present ? data.dmKey.value : this.dmKey,
      createrId: data.createrId.present ? data.createrId.value : this.createrId,
      title: data.title.present ? data.title.value : this.title,
      userId: data.userId.present ? data.userId.value : this.userId,
      unreadCount: data.unreadCount.present
          ? data.unreadCount.value
          : this.unreadCount,
      lastMessageId: data.lastMessageId.present
          ? data.lastMessageId.value
          : this.lastMessageId,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      isMuted: data.isMuted.present ? data.isMuted.value : this.isMuted,
      needsSync: data.needsSync.present ? data.needsSync.value : this.needsSync,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Conversation(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('createdAt: $createdAt, ')
          ..write('dmKey: $dmKey, ')
          ..write('createrId: $createrId, ')
          ..write('title: $title, ')
          ..write('userId: $userId, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('lastMessageId: $lastMessageId, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('isPinned: $isPinned, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isMuted: $isMuted, ')
          ..write('needsSync: $needsSync, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    createdAt,
    dmKey,
    createrId,
    title,
    userId,
    unreadCount,
    lastMessageId,
    isDeleted,
    isPinned,
    isFavorite,
    isMuted,
    needsSync,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Conversation &&
          other.id == this.id &&
          other.type == this.type &&
          other.createdAt == this.createdAt &&
          other.dmKey == this.dmKey &&
          other.createrId == this.createrId &&
          other.title == this.title &&
          other.userId == this.userId &&
          other.unreadCount == this.unreadCount &&
          other.lastMessageId == this.lastMessageId &&
          other.isDeleted == this.isDeleted &&
          other.isPinned == this.isPinned &&
          other.isFavorite == this.isFavorite &&
          other.isMuted == this.isMuted &&
          other.needsSync == this.needsSync &&
          other.updatedAt == this.updatedAt);
}

class ConversationsCompanion extends UpdateCompanion<Conversation> {
  final Value<int> id;
  final Value<String> type;
  final Value<String?> createdAt;
  final Value<String?> dmKey;
  final Value<int?> createrId;
  final Value<String?> title;
  final Value<int?> userId;
  final Value<int> unreadCount;
  final Value<int?> lastMessageId;
  final Value<bool> isDeleted;
  final Value<bool> isPinned;
  final Value<bool> isFavorite;
  final Value<bool> isMuted;
  final Value<bool> needsSync;
  final Value<String?> updatedAt;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.dmKey = const Value.absent(),
    this.createrId = const Value.absent(),
    this.title = const Value.absent(),
    this.userId = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.lastMessageId = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.isMuted = const Value.absent(),
    this.needsSync = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ConversationsCompanion.insert({
    this.id = const Value.absent(),
    required String type,
    this.createdAt = const Value.absent(),
    this.dmKey = const Value.absent(),
    this.createrId = const Value.absent(),
    this.title = const Value.absent(),
    this.userId = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.lastMessageId = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.isMuted = const Value.absent(),
    this.needsSync = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : type = Value(type);
  static Insertable<Conversation> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<String>? createdAt,
    Expression<String>? dmKey,
    Expression<int>? createrId,
    Expression<String>? title,
    Expression<int>? userId,
    Expression<int>? unreadCount,
    Expression<int>? lastMessageId,
    Expression<bool>? isDeleted,
    Expression<bool>? isPinned,
    Expression<bool>? isFavorite,
    Expression<bool>? isMuted,
    Expression<bool>? needsSync,
    Expression<String>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (createdAt != null) 'created_at': createdAt,
      if (dmKey != null) 'dm_key': dmKey,
      if (createrId != null) 'creater_id': createrId,
      if (title != null) 'title': title,
      if (userId != null) 'user_id': userId,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (lastMessageId != null) 'last_message_id': lastMessageId,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (isMuted != null) 'is_muted': isMuted,
      if (needsSync != null) 'needs_sync': needsSync,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ConversationsCompanion copyWith({
    Value<int>? id,
    Value<String>? type,
    Value<String?>? createdAt,
    Value<String?>? dmKey,
    Value<int?>? createrId,
    Value<String?>? title,
    Value<int?>? userId,
    Value<int>? unreadCount,
    Value<int?>? lastMessageId,
    Value<bool>? isDeleted,
    Value<bool>? isPinned,
    Value<bool>? isFavorite,
    Value<bool>? isMuted,
    Value<bool>? needsSync,
    Value<String?>? updatedAt,
  }) {
    return ConversationsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      dmKey: dmKey ?? this.dmKey,
      createrId: createrId ?? this.createrId,
      title: title ?? this.title,
      userId: userId ?? this.userId,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      isDeleted: isDeleted ?? this.isDeleted,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      isMuted: isMuted ?? this.isMuted,
      needsSync: needsSync ?? this.needsSync,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (dmKey.present) {
      map['dm_key'] = Variable<String>(dmKey.value);
    }
    if (createrId.present) {
      map['creater_id'] = Variable<int>(createrId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (lastMessageId.present) {
      map['last_message_id'] = Variable<int>(lastMessageId.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
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
    if (needsSync.present) {
      map['needs_sync'] = Variable<bool>(needsSync.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('createdAt: $createdAt, ')
          ..write('dmKey: $dmKey, ')
          ..write('createrId: $createrId, ')
          ..write('title: $title, ')
          ..write('userId: $userId, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('lastMessageId: $lastMessageId, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('isPinned: $isPinned, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isMuted: $isMuted, ')
          ..write('needsSync: $needsSync, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ConversationMembersTable extends ConversationMembers
    with TableInfo<$ConversationMembersTable, ConversationMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<int> conversationId = GeneratedColumn<int>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _unreadCountMeta = const VerificationMeta(
    'unreadCount',
  );
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
    'unread_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastReadMessageIdMeta = const VerificationMeta(
    'lastReadMessageId',
  );
  @override
  late final GeneratedColumn<int> lastReadMessageId = GeneratedColumn<int>(
    'last_read_message_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastDeliveredMessageIdMeta =
      const VerificationMeta('lastDeliveredMessageId');
  @override
  late final GeneratedColumn<int> lastDeliveredMessageId = GeneratedColumn<int>(
    'last_delivered_message_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    userId,
    role,
    unreadCount,
    joinedAt,
    removedAt,
    deleted,
    lastReadMessageId,
    lastDeliveredMessageId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
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
    if (data.containsKey('unread_count')) {
      context.handle(
        _unreadCountMeta,
        unreadCount.isAcceptableOrUnknown(
          data['unread_count']!,
          _unreadCountMeta,
        ),
      );
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
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('last_read_message_id')) {
      context.handle(
        _lastReadMessageIdMeta,
        lastReadMessageId.isAcceptableOrUnknown(
          data['last_read_message_id']!,
          _lastReadMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('last_delivered_message_id')) {
      context.handle(
        _lastDeliveredMessageIdMeta,
        lastDeliveredMessageId.isAcceptableOrUnknown(
          data['last_delivered_message_id']!,
          _lastDeliveredMessageIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConversationMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationMember(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}conversation_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      unreadCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unread_count'],
      )!,
      joinedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}joined_at'],
      ),
      removedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}removed_at'],
      ),
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      lastReadMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_read_message_id'],
      ),
      lastDeliveredMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_delivered_message_id'],
      ),
    );
  }

  @override
  $ConversationMembersTable createAlias(String alias) {
    return $ConversationMembersTable(attachedDatabase, alias);
  }
}

class ConversationMember extends DataClass
    implements Insertable<ConversationMember> {
  final int id;
  final int conversationId;
  final int userId;
  final String role;
  final int unreadCount;
  final String? joinedAt;
  final String? removedAt;
  final bool deleted;
  final int? lastReadMessageId;
  final int? lastDeliveredMessageId;
  const ConversationMember({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.role,
    required this.unreadCount,
    this.joinedAt,
    this.removedAt,
    required this.deleted,
    this.lastReadMessageId,
    this.lastDeliveredMessageId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['conversation_id'] = Variable<int>(conversationId);
    map['user_id'] = Variable<int>(userId);
    map['role'] = Variable<String>(role);
    map['unread_count'] = Variable<int>(unreadCount);
    if (!nullToAbsent || joinedAt != null) {
      map['joined_at'] = Variable<String>(joinedAt);
    }
    if (!nullToAbsent || removedAt != null) {
      map['removed_at'] = Variable<String>(removedAt);
    }
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || lastReadMessageId != null) {
      map['last_read_message_id'] = Variable<int>(lastReadMessageId);
    }
    if (!nullToAbsent || lastDeliveredMessageId != null) {
      map['last_delivered_message_id'] = Variable<int>(lastDeliveredMessageId);
    }
    return map;
  }

  ConversationMembersCompanion toCompanion(bool nullToAbsent) {
    return ConversationMembersCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      userId: Value(userId),
      role: Value(role),
      unreadCount: Value(unreadCount),
      joinedAt: joinedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(joinedAt),
      removedAt: removedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(removedAt),
      deleted: Value(deleted),
      lastReadMessageId: lastReadMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReadMessageId),
      lastDeliveredMessageId: lastDeliveredMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastDeliveredMessageId),
    );
  }

  factory ConversationMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationMember(
      id: serializer.fromJson<int>(json['id']),
      conversationId: serializer.fromJson<int>(json['conversationId']),
      userId: serializer.fromJson<int>(json['userId']),
      role: serializer.fromJson<String>(json['role']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      joinedAt: serializer.fromJson<String?>(json['joinedAt']),
      removedAt: serializer.fromJson<String?>(json['removedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      lastReadMessageId: serializer.fromJson<int?>(json['lastReadMessageId']),
      lastDeliveredMessageId: serializer.fromJson<int?>(
        json['lastDeliveredMessageId'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'conversationId': serializer.toJson<int>(conversationId),
      'userId': serializer.toJson<int>(userId),
      'role': serializer.toJson<String>(role),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'joinedAt': serializer.toJson<String?>(joinedAt),
      'removedAt': serializer.toJson<String?>(removedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'lastReadMessageId': serializer.toJson<int?>(lastReadMessageId),
      'lastDeliveredMessageId': serializer.toJson<int?>(lastDeliveredMessageId),
    };
  }

  ConversationMember copyWith({
    int? id,
    int? conversationId,
    int? userId,
    String? role,
    int? unreadCount,
    Value<String?> joinedAt = const Value.absent(),
    Value<String?> removedAt = const Value.absent(),
    bool? deleted,
    Value<int?> lastReadMessageId = const Value.absent(),
    Value<int?> lastDeliveredMessageId = const Value.absent(),
  }) => ConversationMember(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    userId: userId ?? this.userId,
    role: role ?? this.role,
    unreadCount: unreadCount ?? this.unreadCount,
    joinedAt: joinedAt.present ? joinedAt.value : this.joinedAt,
    removedAt: removedAt.present ? removedAt.value : this.removedAt,
    deleted: deleted ?? this.deleted,
    lastReadMessageId: lastReadMessageId.present
        ? lastReadMessageId.value
        : this.lastReadMessageId,
    lastDeliveredMessageId: lastDeliveredMessageId.present
        ? lastDeliveredMessageId.value
        : this.lastDeliveredMessageId,
  );
  ConversationMember copyWithCompanion(ConversationMembersCompanion data) {
    return ConversationMember(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      userId: data.userId.present ? data.userId.value : this.userId,
      role: data.role.present ? data.role.value : this.role,
      unreadCount: data.unreadCount.present
          ? data.unreadCount.value
          : this.unreadCount,
      joinedAt: data.joinedAt.present ? data.joinedAt.value : this.joinedAt,
      removedAt: data.removedAt.present ? data.removedAt.value : this.removedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      lastReadMessageId: data.lastReadMessageId.present
          ? data.lastReadMessageId.value
          : this.lastReadMessageId,
      lastDeliveredMessageId: data.lastDeliveredMessageId.present
          ? data.lastDeliveredMessageId.value
          : this.lastDeliveredMessageId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationMember(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('userId: $userId, ')
          ..write('role: $role, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('removedAt: $removedAt, ')
          ..write('deleted: $deleted, ')
          ..write('lastReadMessageId: $lastReadMessageId, ')
          ..write('lastDeliveredMessageId: $lastDeliveredMessageId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    userId,
    role,
    unreadCount,
    joinedAt,
    removedAt,
    deleted,
    lastReadMessageId,
    lastDeliveredMessageId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationMember &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.userId == this.userId &&
          other.role == this.role &&
          other.unreadCount == this.unreadCount &&
          other.joinedAt == this.joinedAt &&
          other.removedAt == this.removedAt &&
          other.deleted == this.deleted &&
          other.lastReadMessageId == this.lastReadMessageId &&
          other.lastDeliveredMessageId == this.lastDeliveredMessageId);
}

class ConversationMembersCompanion extends UpdateCompanion<ConversationMember> {
  final Value<int> id;
  final Value<int> conversationId;
  final Value<int> userId;
  final Value<String> role;
  final Value<int> unreadCount;
  final Value<String?> joinedAt;
  final Value<String?> removedAt;
  final Value<bool> deleted;
  final Value<int?> lastReadMessageId;
  final Value<int?> lastDeliveredMessageId;
  const ConversationMembersCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.userId = const Value.absent(),
    this.role = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.joinedAt = const Value.absent(),
    this.removedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.lastReadMessageId = const Value.absent(),
    this.lastDeliveredMessageId = const Value.absent(),
  });
  ConversationMembersCompanion.insert({
    this.id = const Value.absent(),
    required int conversationId,
    required int userId,
    required String role,
    this.unreadCount = const Value.absent(),
    this.joinedAt = const Value.absent(),
    this.removedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.lastReadMessageId = const Value.absent(),
    this.lastDeliveredMessageId = const Value.absent(),
  }) : conversationId = Value(conversationId),
       userId = Value(userId),
       role = Value(role);
  static Insertable<ConversationMember> custom({
    Expression<int>? id,
    Expression<int>? conversationId,
    Expression<int>? userId,
    Expression<String>? role,
    Expression<int>? unreadCount,
    Expression<String>? joinedAt,
    Expression<String>? removedAt,
    Expression<bool>? deleted,
    Expression<int>? lastReadMessageId,
    Expression<int>? lastDeliveredMessageId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (userId != null) 'user_id': userId,
      if (role != null) 'role': role,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (joinedAt != null) 'joined_at': joinedAt,
      if (removedAt != null) 'removed_at': removedAt,
      if (deleted != null) 'deleted': deleted,
      if (lastReadMessageId != null) 'last_read_message_id': lastReadMessageId,
      if (lastDeliveredMessageId != null)
        'last_delivered_message_id': lastDeliveredMessageId,
    });
  }

  ConversationMembersCompanion copyWith({
    Value<int>? id,
    Value<int>? conversationId,
    Value<int>? userId,
    Value<String>? role,
    Value<int>? unreadCount,
    Value<String?>? joinedAt,
    Value<String?>? removedAt,
    Value<bool>? deleted,
    Value<int?>? lastReadMessageId,
    Value<int?>? lastDeliveredMessageId,
  }) {
    return ConversationMembersCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      unreadCount: unreadCount ?? this.unreadCount,
      joinedAt: joinedAt ?? this.joinedAt,
      removedAt: removedAt ?? this.removedAt,
      deleted: deleted ?? this.deleted,
      lastReadMessageId: lastReadMessageId ?? this.lastReadMessageId,
      lastDeliveredMessageId:
          lastDeliveredMessageId ?? this.lastDeliveredMessageId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<int>(conversationId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (joinedAt.present) {
      map['joined_at'] = Variable<String>(joinedAt.value);
    }
    if (removedAt.present) {
      map['removed_at'] = Variable<String>(removedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (lastReadMessageId.present) {
      map['last_read_message_id'] = Variable<int>(lastReadMessageId.value);
    }
    if (lastDeliveredMessageId.present) {
      map['last_delivered_message_id'] = Variable<int>(
        lastDeliveredMessageId.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationMembersCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('userId: $userId, ')
          ..write('role: $role, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('removedAt: $removedAt, ')
          ..write('deleted: $deleted, ')
          ..write('lastReadMessageId: $lastReadMessageId, ')
          ..write('lastDeliveredMessageId: $lastDeliveredMessageId')
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
  late final GeneratedColumn<BigInt> id = GeneratedColumn<BigInt>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<int> conversationId = GeneratedColumn<int>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderIdMeta = const VerificationMeta(
    'senderId',
  );
  @override
  late final GeneratedColumn<int> senderId = GeneratedColumn<int>(
    'sender_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, dynamic>?, String>
  attachments = GeneratedColumn<String>(
    'attachments',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<Map<String, dynamic>?>($MessagesTable.$converterattachments);
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, dynamic>?, String>
  metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<Map<String, dynamic>?>($MessagesTable.$convertermetadata);
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
  static const VerificationMeta _isStarredMeta = const VerificationMeta(
    'isStarred',
  );
  @override
  late final GeneratedColumn<bool> isStarred = GeneratedColumn<bool>(
    'is_starred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_starred" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isRepliedMeta = const VerificationMeta(
    'isReplied',
  );
  @override
  late final GeneratedColumn<bool> isReplied = GeneratedColumn<bool>(
    'is_replied',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_replied" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isForwardedMeta = const VerificationMeta(
    'isForwarded',
  );
  @override
  late final GeneratedColumn<bool> isForwarded = GeneratedColumn<bool>(
    'is_forwarded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_forwarded" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<String> sentAt = GeneratedColumn<String>(
    'sent_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    senderId,
    type,
    body,
    status,
    attachments,
    metadata,
    isPinned,
    isStarred,
    isReplied,
    isForwarded,
    sentAt,
    isDeleted,
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
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(
        _senderIdMeta,
        senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_senderIdMeta);
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
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('is_starred')) {
      context.handle(
        _isStarredMeta,
        isStarred.isAcceptableOrUnknown(data['is_starred']!, _isStarredMeta),
      );
    }
    if (data.containsKey('is_replied')) {
      context.handle(
        _isRepliedMeta,
        isReplied.isAcceptableOrUnknown(data['is_replied']!, _isRepliedMeta),
      );
    }
    if (data.containsKey('is_forwarded')) {
      context.handle(
        _isForwardedMeta,
        isForwarded.isAcceptableOrUnknown(
          data['is_forwarded']!,
          _isForwardedMeta,
        ),
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
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
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
        DriftSqlType.bigInt,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}conversation_id'],
      )!,
      senderId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sender_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attachments: $MessagesTable.$converterattachments.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}attachments'],
        ),
      ),
      metadata: $MessagesTable.$convertermetadata.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}metadata'],
        ),
      ),
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      isStarred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_starred'],
      )!,
      isReplied: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_replied'],
      )!,
      isForwarded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_forwarded'],
      )!,
      sentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sent_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }

  static TypeConverter<Map<String, dynamic>?, String?> $converterattachments =
      const JsonMapConverter();
  static TypeConverter<Map<String, dynamic>?, String?> $convertermetadata =
      const JsonMapConverter();
}

class Message extends DataClass implements Insertable<Message> {
  final BigInt id;
  final int conversationId;
  final int senderId;
  final String type;
  final String? body;
  final String status;
  final Map<String, dynamic>? attachments;
  final Map<String, dynamic>? metadata;
  final bool isPinned;
  final bool isStarred;
  final bool isReplied;
  final bool isForwarded;
  final String sentAt;
  final bool isDeleted;
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    this.body,
    required this.status,
    this.attachments,
    this.metadata,
    required this.isPinned,
    required this.isStarred,
    required this.isReplied,
    required this.isForwarded,
    required this.sentAt,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<BigInt>(id);
    map['conversation_id'] = Variable<int>(conversationId);
    map['sender_id'] = Variable<int>(senderId);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || attachments != null) {
      map['attachments'] = Variable<String>(
        $MessagesTable.$converterattachments.toSql(attachments),
      );
    }
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(
        $MessagesTable.$convertermetadata.toSql(metadata),
      );
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_starred'] = Variable<bool>(isStarred);
    map['is_replied'] = Variable<bool>(isReplied);
    map['is_forwarded'] = Variable<bool>(isForwarded);
    map['sent_at'] = Variable<String>(sentAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      senderId: Value(senderId),
      type: Value(type),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      status: Value(status),
      attachments: attachments == null && nullToAbsent
          ? const Value.absent()
          : Value(attachments),
      metadata: metadata == null && nullToAbsent
          ? const Value.absent()
          : Value(metadata),
      isPinned: Value(isPinned),
      isStarred: Value(isStarred),
      isReplied: Value(isReplied),
      isForwarded: Value(isForwarded),
      sentAt: Value(sentAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<BigInt>(json['id']),
      conversationId: serializer.fromJson<int>(json['conversationId']),
      senderId: serializer.fromJson<int>(json['senderId']),
      type: serializer.fromJson<String>(json['type']),
      body: serializer.fromJson<String?>(json['body']),
      status: serializer.fromJson<String>(json['status']),
      attachments: serializer.fromJson<Map<String, dynamic>?>(
        json['attachments'],
      ),
      metadata: serializer.fromJson<Map<String, dynamic>?>(json['metadata']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isStarred: serializer.fromJson<bool>(json['isStarred']),
      isReplied: serializer.fromJson<bool>(json['isReplied']),
      isForwarded: serializer.fromJson<bool>(json['isForwarded']),
      sentAt: serializer.fromJson<String>(json['sentAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<BigInt>(id),
      'conversationId': serializer.toJson<int>(conversationId),
      'senderId': serializer.toJson<int>(senderId),
      'type': serializer.toJson<String>(type),
      'body': serializer.toJson<String?>(body),
      'status': serializer.toJson<String>(status),
      'attachments': serializer.toJson<Map<String, dynamic>?>(attachments),
      'metadata': serializer.toJson<Map<String, dynamic>?>(metadata),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isStarred': serializer.toJson<bool>(isStarred),
      'isReplied': serializer.toJson<bool>(isReplied),
      'isForwarded': serializer.toJson<bool>(isForwarded),
      'sentAt': serializer.toJson<String>(sentAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  Message copyWith({
    BigInt? id,
    int? conversationId,
    int? senderId,
    String? type,
    Value<String?> body = const Value.absent(),
    String? status,
    Value<Map<String, dynamic>?> attachments = const Value.absent(),
    Value<Map<String, dynamic>?> metadata = const Value.absent(),
    bool? isPinned,
    bool? isStarred,
    bool? isReplied,
    bool? isForwarded,
    String? sentAt,
    bool? isDeleted,
  }) => Message(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    senderId: senderId ?? this.senderId,
    type: type ?? this.type,
    body: body.present ? body.value : this.body,
    status: status ?? this.status,
    attachments: attachments.present ? attachments.value : this.attachments,
    metadata: metadata.present ? metadata.value : this.metadata,
    isPinned: isPinned ?? this.isPinned,
    isStarred: isStarred ?? this.isStarred,
    isReplied: isReplied ?? this.isReplied,
    isForwarded: isForwarded ?? this.isForwarded,
    sentAt: sentAt ?? this.sentAt,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      type: data.type.present ? data.type.value : this.type,
      body: data.body.present ? data.body.value : this.body,
      status: data.status.present ? data.status.value : this.status,
      attachments: data.attachments.present
          ? data.attachments.value
          : this.attachments,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isStarred: data.isStarred.present ? data.isStarred.value : this.isStarred,
      isReplied: data.isReplied.present ? data.isReplied.value : this.isReplied,
      isForwarded: data.isForwarded.present
          ? data.isForwarded.value
          : this.isForwarded,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('type: $type, ')
          ..write('body: $body, ')
          ..write('status: $status, ')
          ..write('attachments: $attachments, ')
          ..write('metadata: $metadata, ')
          ..write('isPinned: $isPinned, ')
          ..write('isStarred: $isStarred, ')
          ..write('isReplied: $isReplied, ')
          ..write('isForwarded: $isForwarded, ')
          ..write('sentAt: $sentAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    senderId,
    type,
    body,
    status,
    attachments,
    metadata,
    isPinned,
    isStarred,
    isReplied,
    isForwarded,
    sentAt,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.senderId == this.senderId &&
          other.type == this.type &&
          other.body == this.body &&
          other.status == this.status &&
          other.attachments == this.attachments &&
          other.metadata == this.metadata &&
          other.isPinned == this.isPinned &&
          other.isStarred == this.isStarred &&
          other.isReplied == this.isReplied &&
          other.isForwarded == this.isForwarded &&
          other.sentAt == this.sentAt &&
          other.isDeleted == this.isDeleted);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<BigInt> id;
  final Value<int> conversationId;
  final Value<int> senderId;
  final Value<String> type;
  final Value<String?> body;
  final Value<String> status;
  final Value<Map<String, dynamic>?> attachments;
  final Value<Map<String, dynamic>?> metadata;
  final Value<bool> isPinned;
  final Value<bool> isStarred;
  final Value<bool> isReplied;
  final Value<bool> isForwarded;
  final Value<String> sentAt;
  final Value<bool> isDeleted;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.type = const Value.absent(),
    this.body = const Value.absent(),
    this.status = const Value.absent(),
    this.attachments = const Value.absent(),
    this.metadata = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isStarred = const Value.absent(),
    this.isReplied = const Value.absent(),
    this.isForwarded = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  });
  MessagesCompanion.insert({
    this.id = const Value.absent(),
    required int conversationId,
    required int senderId,
    required String type,
    this.body = const Value.absent(),
    required String status,
    this.attachments = const Value.absent(),
    this.metadata = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isStarred = const Value.absent(),
    this.isReplied = const Value.absent(),
    this.isForwarded = const Value.absent(),
    required String sentAt,
    this.isDeleted = const Value.absent(),
  }) : conversationId = Value(conversationId),
       senderId = Value(senderId),
       type = Value(type),
       status = Value(status),
       sentAt = Value(sentAt);
  static Insertable<Message> custom({
    Expression<BigInt>? id,
    Expression<int>? conversationId,
    Expression<int>? senderId,
    Expression<String>? type,
    Expression<String>? body,
    Expression<String>? status,
    Expression<String>? attachments,
    Expression<String>? metadata,
    Expression<bool>? isPinned,
    Expression<bool>? isStarred,
    Expression<bool>? isReplied,
    Expression<bool>? isForwarded,
    Expression<String>? sentAt,
    Expression<bool>? isDeleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (senderId != null) 'sender_id': senderId,
      if (type != null) 'type': type,
      if (body != null) 'body': body,
      if (status != null) 'status': status,
      if (attachments != null) 'attachments': attachments,
      if (metadata != null) 'metadata': metadata,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isStarred != null) 'is_starred': isStarred,
      if (isReplied != null) 'is_replied': isReplied,
      if (isForwarded != null) 'is_forwarded': isForwarded,
      if (sentAt != null) 'sent_at': sentAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
    });
  }

  MessagesCompanion copyWith({
    Value<BigInt>? id,
    Value<int>? conversationId,
    Value<int>? senderId,
    Value<String>? type,
    Value<String?>? body,
    Value<String>? status,
    Value<Map<String, dynamic>?>? attachments,
    Value<Map<String, dynamic>?>? metadata,
    Value<bool>? isPinned,
    Value<bool>? isStarred,
    Value<bool>? isReplied,
    Value<bool>? isForwarded,
    Value<String>? sentAt,
    Value<bool>? isDeleted,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      type: type ?? this.type,
      body: body ?? this.body,
      status: status ?? this.status,
      attachments: attachments ?? this.attachments,
      metadata: metadata ?? this.metadata,
      isPinned: isPinned ?? this.isPinned,
      isStarred: isStarred ?? this.isStarred,
      isReplied: isReplied ?? this.isReplied,
      isForwarded: isForwarded ?? this.isForwarded,
      sentAt: sentAt ?? this.sentAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<BigInt>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<int>(conversationId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<int>(senderId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attachments.present) {
      map['attachments'] = Variable<String>(
        $MessagesTable.$converterattachments.toSql(attachments.value),
      );
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(
        $MessagesTable.$convertermetadata.toSql(metadata.value),
      );
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isStarred.present) {
      map['is_starred'] = Variable<bool>(isStarred.value);
    }
    if (isReplied.present) {
      map['is_replied'] = Variable<bool>(isReplied.value);
    }
    if (isForwarded.present) {
      map['is_forwarded'] = Variable<bool>(isForwarded.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<String>(sentAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('type: $type, ')
          ..write('body: $body, ')
          ..write('status: $status, ')
          ..write('attachments: $attachments, ')
          ..write('metadata: $metadata, ')
          ..write('isPinned: $isPinned, ')
          ..write('isStarred: $isStarred, ')
          ..write('isReplied: $isReplied, ')
          ..write('isForwarded: $isForwarded, ')
          ..write('sentAt: $sentAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }
}

class $MessageStatusModelTable extends MessageStatusModel
    with TableInfo<$MessageStatusModelTable, MessageStatusModelData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageStatusModelTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<BigInt> id = GeneratedColumn<BigInt>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<int> messageId = GeneratedColumn<int>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    messageId,
    userId,
    deliveredAt,
    readAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_status_model';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageStatusModelData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageStatusModelData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageStatusModelData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
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
    );
  }

  @override
  $MessageStatusModelTable createAlias(String alias) {
    return $MessageStatusModelTable(attachedDatabase, alias);
  }
}

class MessageStatusModelData extends DataClass
    implements Insertable<MessageStatusModelData> {
  final BigInt id;
  final int messageId;
  final int userId;
  final String? deliveredAt;
  final String? readAt;
  const MessageStatusModelData({
    required this.id,
    required this.messageId,
    required this.userId,
    this.deliveredAt,
    this.readAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<BigInt>(id);
    map['message_id'] = Variable<int>(messageId);
    map['user_id'] = Variable<int>(userId);
    if (!nullToAbsent || deliveredAt != null) {
      map['delivered_at'] = Variable<String>(deliveredAt);
    }
    if (!nullToAbsent || readAt != null) {
      map['read_at'] = Variable<String>(readAt);
    }
    return map;
  }

  MessageStatusModelCompanion toCompanion(bool nullToAbsent) {
    return MessageStatusModelCompanion(
      id: Value(id),
      messageId: Value(messageId),
      userId: Value(userId),
      deliveredAt: deliveredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deliveredAt),
      readAt: readAt == null && nullToAbsent
          ? const Value.absent()
          : Value(readAt),
    );
  }

  factory MessageStatusModelData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageStatusModelData(
      id: serializer.fromJson<BigInt>(json['id']),
      messageId: serializer.fromJson<int>(json['messageId']),
      userId: serializer.fromJson<int>(json['userId']),
      deliveredAt: serializer.fromJson<String?>(json['deliveredAt']),
      readAt: serializer.fromJson<String?>(json['readAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<BigInt>(id),
      'messageId': serializer.toJson<int>(messageId),
      'userId': serializer.toJson<int>(userId),
      'deliveredAt': serializer.toJson<String?>(deliveredAt),
      'readAt': serializer.toJson<String?>(readAt),
    };
  }

  MessageStatusModelData copyWith({
    BigInt? id,
    int? messageId,
    int? userId,
    Value<String?> deliveredAt = const Value.absent(),
    Value<String?> readAt = const Value.absent(),
  }) => MessageStatusModelData(
    id: id ?? this.id,
    messageId: messageId ?? this.messageId,
    userId: userId ?? this.userId,
    deliveredAt: deliveredAt.present ? deliveredAt.value : this.deliveredAt,
    readAt: readAt.present ? readAt.value : this.readAt,
  );
  MessageStatusModelData copyWithCompanion(MessageStatusModelCompanion data) {
    return MessageStatusModelData(
      id: data.id.present ? data.id.value : this.id,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      userId: data.userId.present ? data.userId.value : this.userId,
      deliveredAt: data.deliveredAt.present
          ? data.deliveredAt.value
          : this.deliveredAt,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageStatusModelData(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('userId: $userId, ')
          ..write('deliveredAt: $deliveredAt, ')
          ..write('readAt: $readAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, messageId, userId, deliveredAt, readAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageStatusModelData &&
          other.id == this.id &&
          other.messageId == this.messageId &&
          other.userId == this.userId &&
          other.deliveredAt == this.deliveredAt &&
          other.readAt == this.readAt);
}

class MessageStatusModelCompanion
    extends UpdateCompanion<MessageStatusModelData> {
  final Value<BigInt> id;
  final Value<int> messageId;
  final Value<int> userId;
  final Value<String?> deliveredAt;
  final Value<String?> readAt;
  const MessageStatusModelCompanion({
    this.id = const Value.absent(),
    this.messageId = const Value.absent(),
    this.userId = const Value.absent(),
    this.deliveredAt = const Value.absent(),
    this.readAt = const Value.absent(),
  });
  MessageStatusModelCompanion.insert({
    this.id = const Value.absent(),
    required int messageId,
    required int userId,
    this.deliveredAt = const Value.absent(),
    this.readAt = const Value.absent(),
  }) : messageId = Value(messageId),
       userId = Value(userId);
  static Insertable<MessageStatusModelData> custom({
    Expression<BigInt>? id,
    Expression<int>? messageId,
    Expression<int>? userId,
    Expression<String>? deliveredAt,
    Expression<String>? readAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (messageId != null) 'message_id': messageId,
      if (userId != null) 'user_id': userId,
      if (deliveredAt != null) 'delivered_at': deliveredAt,
      if (readAt != null) 'read_at': readAt,
    });
  }

  MessageStatusModelCompanion copyWith({
    Value<BigInt>? id,
    Value<int>? messageId,
    Value<int>? userId,
    Value<String?>? deliveredAt,
    Value<String?>? readAt,
  }) {
    return MessageStatusModelCompanion(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      userId: userId ?? this.userId,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<BigInt>(id.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<int>(messageId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (deliveredAt.present) {
      map['delivered_at'] = Variable<String>(deliveredAt.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<String>(readAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageStatusModelCompanion(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('userId: $userId, ')
          ..write('deliveredAt: $deliveredAt, ')
          ..write('readAt: $readAt')
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
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $ConversationMembersTable conversationMembers =
      $ConversationMembersTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $MessageStatusModelTable messageStatusModel =
      $MessageStatusModelTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    users,
    contacts,
    calls,
    conversations,
    conversationMembers,
    messages,
    messageStatusModel,
  ];
}

typedef $$UsersTableCreateCompanionBuilder =
    UsersCompanion Function({
      Value<int> id,
      required String name,
      required String phone,
      required String role,
      Value<String?> profilePic,
    });
typedef $$UsersTableUpdateCompanionBuilder =
    UsersCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> phone,
      Value<String> role,
      Value<String?> profilePic,
    });

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
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

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profilePic => $composableBuilder(
    column: $table.profilePic,
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
  ColumnOrderings<int> get id => $composableBuilder(
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

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profilePic => $composableBuilder(
    column: $table.profilePic,
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
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get profilePic => $composableBuilder(
    column: $table.profilePic,
    builder: (column) => column,
  );
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
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String?> profilePic = const Value.absent(),
              }) => UsersCompanion(
                id: id,
                name: name,
                phone: phone,
                role: role,
                profilePic: profilePic,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String phone,
                required String role,
                Value<String?> profilePic = const Value.absent(),
              }) => UsersCompanion.insert(
                id: id,
                name: name,
                phone: phone,
                role: role,
                profilePic: profilePic,
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
      Value<int> id,
      required String name,
      required String phone,
      Value<String?> profilePic,
    });
typedef $$ContactsTableUpdateCompanionBuilder =
    ContactsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> phone,
      Value<String?> profilePic,
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
  ColumnFilters<int> get id => $composableBuilder(
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
  ColumnOrderings<int> get id => $composableBuilder(
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
  GeneratedColumn<int> get id =>
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
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String?> profilePic = const Value.absent(),
              }) => ContactsCompanion(
                id: id,
                name: name,
                phone: phone,
                profilePic: profilePic,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String phone,
                Value<String?> profilePic = const Value.absent(),
              }) => ContactsCompanion.insert(
                id: id,
                name: name,
                phone: phone,
                profilePic: profilePic,
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
      Value<int> id,
      required int callerId,
      required int calleeId,
      required String startedAt,
      Value<String?> endedAt,
      required String status,
      required String callType,
    });
typedef $$CallsTableUpdateCompanionBuilder =
    CallsCompanion Function({
      Value<int> id,
      Value<int> callerId,
      Value<int> calleeId,
      Value<String> startedAt,
      Value<String?> endedAt,
      Value<String> status,
      Value<String> callType,
    });

class $$CallsTableFilterComposer extends Composer<_$AppDatabase, $CallsTable> {
  $$CallsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get callerId => $composableBuilder(
    column: $table.callerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calleeId => $composableBuilder(
    column: $table.calleeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get callType => $composableBuilder(
    column: $table.callType,
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
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get callerId => $composableBuilder(
    column: $table.callerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calleeId => $composableBuilder(
    column: $table.calleeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get callType => $composableBuilder(
    column: $table.callType,
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
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get callerId =>
      $composableBuilder(column: $table.callerId, builder: (column) => column);

  GeneratedColumn<int> get calleeId =>
      $composableBuilder(column: $table.calleeId, builder: (column) => column);

  GeneratedColumn<String> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<String> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get callType =>
      $composableBuilder(column: $table.callType, builder: (column) => column);
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
                Value<int> id = const Value.absent(),
                Value<int> callerId = const Value.absent(),
                Value<int> calleeId = const Value.absent(),
                Value<String> startedAt = const Value.absent(),
                Value<String?> endedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> callType = const Value.absent(),
              }) => CallsCompanion(
                id: id,
                callerId: callerId,
                calleeId: calleeId,
                startedAt: startedAt,
                endedAt: endedAt,
                status: status,
                callType: callType,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int callerId,
                required int calleeId,
                required String startedAt,
                Value<String?> endedAt = const Value.absent(),
                required String status,
                required String callType,
              }) => CallsCompanion.insert(
                id: id,
                callerId: callerId,
                calleeId: calleeId,
                startedAt: startedAt,
                endedAt: endedAt,
                status: status,
                callType: callType,
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
typedef $$ConversationsTableCreateCompanionBuilder =
    ConversationsCompanion Function({
      Value<int> id,
      required String type,
      Value<String?> createdAt,
      Value<String?> dmKey,
      Value<int?> createrId,
      Value<String?> title,
      Value<int?> userId,
      Value<int> unreadCount,
      Value<int?> lastMessageId,
      Value<bool> isDeleted,
      Value<bool> isPinned,
      Value<bool> isFavorite,
      Value<bool> isMuted,
      Value<bool> needsSync,
      Value<String?> updatedAt,
    });
typedef $$ConversationsTableUpdateCompanionBuilder =
    ConversationsCompanion Function({
      Value<int> id,
      Value<String> type,
      Value<String?> createdAt,
      Value<String?> dmKey,
      Value<int?> createrId,
      Value<String?> title,
      Value<int?> userId,
      Value<int> unreadCount,
      Value<int?> lastMessageId,
      Value<bool> isDeleted,
      Value<bool> isPinned,
      Value<bool> isFavorite,
      Value<bool> isMuted,
      Value<bool> needsSync,
      Value<String?> updatedAt,
    });

class $$ConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dmKey => $composableBuilder(
    column: $table.dmKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createrId => $composableBuilder(
    column: $table.createrId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastMessageId => $composableBuilder(
    column: $table.lastMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
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

  ColumnFilters<bool> get needsSync => $composableBuilder(
    column: $table.needsSync,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dmKey => $composableBuilder(
    column: $table.dmKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createrId => $composableBuilder(
    column: $table.createrId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastMessageId => $composableBuilder(
    column: $table.lastMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
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

  ColumnOrderings<bool> get needsSync => $composableBuilder(
    column: $table.needsSync,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get dmKey =>
      $composableBuilder(column: $table.dmKey, builder: (column) => column);

  GeneratedColumn<int> get createrId =>
      $composableBuilder(column: $table.createrId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastMessageId => $composableBuilder(
    column: $table.lastMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isMuted =>
      $composableBuilder(column: $table.isMuted, builder: (column) => column);

  GeneratedColumn<bool> get needsSync =>
      $composableBuilder(column: $table.needsSync, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ConversationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationsTable,
          Conversation,
          $$ConversationsTableFilterComposer,
          $$ConversationsTableOrderingComposer,
          $$ConversationsTableAnnotationComposer,
          $$ConversationsTableCreateCompanionBuilder,
          $$ConversationsTableUpdateCompanionBuilder,
          (
            Conversation,
            BaseReferences<_$AppDatabase, $ConversationsTable, Conversation>,
          ),
          Conversation,
          PrefetchHooks Function()
        > {
  $$ConversationsTableTableManager(_$AppDatabase db, $ConversationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> dmKey = const Value.absent(),
                Value<int?> createrId = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<int?> userId = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<int?> lastMessageId = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<bool> isMuted = const Value.absent(),
                Value<bool> needsSync = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
              }) => ConversationsCompanion(
                id: id,
                type: type,
                createdAt: createdAt,
                dmKey: dmKey,
                createrId: createrId,
                title: title,
                userId: userId,
                unreadCount: unreadCount,
                lastMessageId: lastMessageId,
                isDeleted: isDeleted,
                isPinned: isPinned,
                isFavorite: isFavorite,
                isMuted: isMuted,
                needsSync: needsSync,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String type,
                Value<String?> createdAt = const Value.absent(),
                Value<String?> dmKey = const Value.absent(),
                Value<int?> createrId = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<int?> userId = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<int?> lastMessageId = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<bool> isMuted = const Value.absent(),
                Value<bool> needsSync = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
              }) => ConversationsCompanion.insert(
                id: id,
                type: type,
                createdAt: createdAt,
                dmKey: dmKey,
                createrId: createrId,
                title: title,
                userId: userId,
                unreadCount: unreadCount,
                lastMessageId: lastMessageId,
                isDeleted: isDeleted,
                isPinned: isPinned,
                isFavorite: isFavorite,
                isMuted: isMuted,
                needsSync: needsSync,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationsTable,
      Conversation,
      $$ConversationsTableFilterComposer,
      $$ConversationsTableOrderingComposer,
      $$ConversationsTableAnnotationComposer,
      $$ConversationsTableCreateCompanionBuilder,
      $$ConversationsTableUpdateCompanionBuilder,
      (
        Conversation,
        BaseReferences<_$AppDatabase, $ConversationsTable, Conversation>,
      ),
      Conversation,
      PrefetchHooks Function()
    >;
typedef $$ConversationMembersTableCreateCompanionBuilder =
    ConversationMembersCompanion Function({
      Value<int> id,
      required int conversationId,
      required int userId,
      required String role,
      Value<int> unreadCount,
      Value<String?> joinedAt,
      Value<String?> removedAt,
      Value<bool> deleted,
      Value<int?> lastReadMessageId,
      Value<int?> lastDeliveredMessageId,
    });
typedef $$ConversationMembersTableUpdateCompanionBuilder =
    ConversationMembersCompanion Function({
      Value<int> id,
      Value<int> conversationId,
      Value<int> userId,
      Value<String> role,
      Value<int> unreadCount,
      Value<String?> joinedAt,
      Value<String?> removedAt,
      Value<bool> deleted,
      Value<int?> lastReadMessageId,
      Value<int?> lastDeliveredMessageId,
    });

class $$ConversationMembersTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationMembersTable> {
  $$ConversationMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
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

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastReadMessageId => $composableBuilder(
    column: $table.lastReadMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastDeliveredMessageId => $composableBuilder(
    column: $table.lastDeliveredMessageId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConversationMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationMembersTable> {
  $$ConversationMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
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

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReadMessageId => $composableBuilder(
    column: $table.lastReadMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastDeliveredMessageId => $composableBuilder(
    column: $table.lastDeliveredMessageId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationMembersTable> {
  $$ConversationMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get joinedAt =>
      $composableBuilder(column: $table.joinedAt, builder: (column) => column);

  GeneratedColumn<String> get removedAt =>
      $composableBuilder(column: $table.removedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get lastReadMessageId => $composableBuilder(
    column: $table.lastReadMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastDeliveredMessageId => $composableBuilder(
    column: $table.lastDeliveredMessageId,
    builder: (column) => column,
  );
}

class $$ConversationMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationMembersTable,
          ConversationMember,
          $$ConversationMembersTableFilterComposer,
          $$ConversationMembersTableOrderingComposer,
          $$ConversationMembersTableAnnotationComposer,
          $$ConversationMembersTableCreateCompanionBuilder,
          $$ConversationMembersTableUpdateCompanionBuilder,
          (
            ConversationMember,
            BaseReferences<
              _$AppDatabase,
              $ConversationMembersTable,
              ConversationMember
            >,
          ),
          ConversationMember,
          PrefetchHooks Function()
        > {
  $$ConversationMembersTableTableManager(
    _$AppDatabase db,
    $ConversationMembersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationMembersTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ConversationMembersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> conversationId = const Value.absent(),
                Value<int> userId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<String?> joinedAt = const Value.absent(),
                Value<String?> removedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int?> lastReadMessageId = const Value.absent(),
                Value<int?> lastDeliveredMessageId = const Value.absent(),
              }) => ConversationMembersCompanion(
                id: id,
                conversationId: conversationId,
                userId: userId,
                role: role,
                unreadCount: unreadCount,
                joinedAt: joinedAt,
                removedAt: removedAt,
                deleted: deleted,
                lastReadMessageId: lastReadMessageId,
                lastDeliveredMessageId: lastDeliveredMessageId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int conversationId,
                required int userId,
                required String role,
                Value<int> unreadCount = const Value.absent(),
                Value<String?> joinedAt = const Value.absent(),
                Value<String?> removedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int?> lastReadMessageId = const Value.absent(),
                Value<int?> lastDeliveredMessageId = const Value.absent(),
              }) => ConversationMembersCompanion.insert(
                id: id,
                conversationId: conversationId,
                userId: userId,
                role: role,
                unreadCount: unreadCount,
                joinedAt: joinedAt,
                removedAt: removedAt,
                deleted: deleted,
                lastReadMessageId: lastReadMessageId,
                lastDeliveredMessageId: lastDeliveredMessageId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConversationMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationMembersTable,
      ConversationMember,
      $$ConversationMembersTableFilterComposer,
      $$ConversationMembersTableOrderingComposer,
      $$ConversationMembersTableAnnotationComposer,
      $$ConversationMembersTableCreateCompanionBuilder,
      $$ConversationMembersTableUpdateCompanionBuilder,
      (
        ConversationMember,
        BaseReferences<
          _$AppDatabase,
          $ConversationMembersTable,
          ConversationMember
        >,
      ),
      ConversationMember,
      PrefetchHooks Function()
    >;
typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      Value<BigInt> id,
      required int conversationId,
      required int senderId,
      required String type,
      Value<String?> body,
      required String status,
      Value<Map<String, dynamic>?> attachments,
      Value<Map<String, dynamic>?> metadata,
      Value<bool> isPinned,
      Value<bool> isStarred,
      Value<bool> isReplied,
      Value<bool> isForwarded,
      required String sentAt,
      Value<bool> isDeleted,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<BigInt> id,
      Value<int> conversationId,
      Value<int> senderId,
      Value<String> type,
      Value<String?> body,
      Value<String> status,
      Value<Map<String, dynamic>?> attachments,
      Value<Map<String, dynamic>?> metadata,
      Value<bool> isPinned,
      Value<bool> isStarred,
      Value<bool> isReplied,
      Value<bool> isForwarded,
      Value<String> sentAt,
      Value<bool> isDeleted,
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
  ColumnFilters<BigInt> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get senderId => $composableBuilder(
    column: $table.senderId,
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

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
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

  ColumnWithTypeConverterFilters<
    Map<String, dynamic>?,
    Map<String, dynamic>,
    String
  >
  get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isStarred => $composableBuilder(
    column: $table.isStarred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isReplied => $composableBuilder(
    column: $table.isReplied,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isForwarded => $composableBuilder(
    column: $table.isForwarded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
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
  ColumnOrderings<BigInt> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get senderId => $composableBuilder(
    column: $table.senderId,
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

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isStarred => $composableBuilder(
    column: $table.isStarred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isReplied => $composableBuilder(
    column: $table.isReplied,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isForwarded => $composableBuilder(
    column: $table.isForwarded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
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
  GeneratedColumn<BigInt> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Map<String, dynamic>?, String>
  get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Map<String, dynamic>?, String>
  get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isStarred =>
      $composableBuilder(column: $table.isStarred, builder: (column) => column);

  GeneratedColumn<bool> get isReplied =>
      $composableBuilder(column: $table.isReplied, builder: (column) => column);

  GeneratedColumn<bool> get isForwarded => $composableBuilder(
    column: $table.isForwarded,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);
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
                Value<BigInt> id = const Value.absent(),
                Value<int> conversationId = const Value.absent(),
                Value<int> senderId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<Map<String, dynamic>?> attachments = const Value.absent(),
                Value<Map<String, dynamic>?> metadata = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isStarred = const Value.absent(),
                Value<bool> isReplied = const Value.absent(),
                Value<bool> isForwarded = const Value.absent(),
                Value<String> sentAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                conversationId: conversationId,
                senderId: senderId,
                type: type,
                body: body,
                status: status,
                attachments: attachments,
                metadata: metadata,
                isPinned: isPinned,
                isStarred: isStarred,
                isReplied: isReplied,
                isForwarded: isForwarded,
                sentAt: sentAt,
                isDeleted: isDeleted,
              ),
          createCompanionCallback:
              ({
                Value<BigInt> id = const Value.absent(),
                required int conversationId,
                required int senderId,
                required String type,
                Value<String?> body = const Value.absent(),
                required String status,
                Value<Map<String, dynamic>?> attachments = const Value.absent(),
                Value<Map<String, dynamic>?> metadata = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isStarred = const Value.absent(),
                Value<bool> isReplied = const Value.absent(),
                Value<bool> isForwarded = const Value.absent(),
                required String sentAt,
                Value<bool> isDeleted = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                conversationId: conversationId,
                senderId: senderId,
                type: type,
                body: body,
                status: status,
                attachments: attachments,
                metadata: metadata,
                isPinned: isPinned,
                isStarred: isStarred,
                isReplied: isReplied,
                isForwarded: isForwarded,
                sentAt: sentAt,
                isDeleted: isDeleted,
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
typedef $$MessageStatusModelTableCreateCompanionBuilder =
    MessageStatusModelCompanion Function({
      Value<BigInt> id,
      required int messageId,
      required int userId,
      Value<String?> deliveredAt,
      Value<String?> readAt,
    });
typedef $$MessageStatusModelTableUpdateCompanionBuilder =
    MessageStatusModelCompanion Function({
      Value<BigInt> id,
      Value<int> messageId,
      Value<int> userId,
      Value<String?> deliveredAt,
      Value<String?> readAt,
    });

class $$MessageStatusModelTableFilterComposer
    extends Composer<_$AppDatabase, $MessageStatusModelTable> {
  $$MessageStatusModelTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<BigInt> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userId => $composableBuilder(
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
}

class $$MessageStatusModelTableOrderingComposer
    extends Composer<_$AppDatabase, $MessageStatusModelTable> {
  $$MessageStatusModelTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<BigInt> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userId => $composableBuilder(
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
}

class $$MessageStatusModelTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessageStatusModelTable> {
  $$MessageStatusModelTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<BigInt> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get deliveredAt => $composableBuilder(
    column: $table.deliveredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);
}

class $$MessageStatusModelTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessageStatusModelTable,
          MessageStatusModelData,
          $$MessageStatusModelTableFilterComposer,
          $$MessageStatusModelTableOrderingComposer,
          $$MessageStatusModelTableAnnotationComposer,
          $$MessageStatusModelTableCreateCompanionBuilder,
          $$MessageStatusModelTableUpdateCompanionBuilder,
          (
            MessageStatusModelData,
            BaseReferences<
              _$AppDatabase,
              $MessageStatusModelTable,
              MessageStatusModelData
            >,
          ),
          MessageStatusModelData,
          PrefetchHooks Function()
        > {
  $$MessageStatusModelTableTableManager(
    _$AppDatabase db,
    $MessageStatusModelTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageStatusModelTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageStatusModelTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessageStatusModelTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<BigInt> id = const Value.absent(),
                Value<int> messageId = const Value.absent(),
                Value<int> userId = const Value.absent(),
                Value<String?> deliveredAt = const Value.absent(),
                Value<String?> readAt = const Value.absent(),
              }) => MessageStatusModelCompanion(
                id: id,
                messageId: messageId,
                userId: userId,
                deliveredAt: deliveredAt,
                readAt: readAt,
              ),
          createCompanionCallback:
              ({
                Value<BigInt> id = const Value.absent(),
                required int messageId,
                required int userId,
                Value<String?> deliveredAt = const Value.absent(),
                Value<String?> readAt = const Value.absent(),
              }) => MessageStatusModelCompanion.insert(
                id: id,
                messageId: messageId,
                userId: userId,
                deliveredAt: deliveredAt,
                readAt: readAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessageStatusModelTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessageStatusModelTable,
      MessageStatusModelData,
      $$MessageStatusModelTableFilterComposer,
      $$MessageStatusModelTableOrderingComposer,
      $$MessageStatusModelTableAnnotationComposer,
      $$MessageStatusModelTableCreateCompanionBuilder,
      $$MessageStatusModelTableUpdateCompanionBuilder,
      (
        MessageStatusModelData,
        BaseReferences<
          _$AppDatabase,
          $MessageStatusModelTable,
          MessageStatusModelData
        >,
      ),
      MessageStatusModelData,
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
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$ConversationMembersTableTableManager get conversationMembers =>
      $$ConversationMembersTableTableManager(_db, _db.conversationMembers);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$MessageStatusModelTableTableManager get messageStatusModel =>
      $$MessageStatusModelTableTableManager(_db, _db.messageStatusModel);
}
