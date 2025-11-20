class UserModel {
  final int id;
  final String name;
  final String phone;
  final String? role;
  final String? profilePic;
  final bool isOnline;
  final bool? callAccess;
  final String? createdAt;
  final int? updatedAt; // ms since epoch

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.role,
    this.profilePic,
    required this.isOnline,
    this.callAccess,
    this.updatedAt,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle different types for id field
    int parsedId = 0;
    if (json['id'] != null) {
      if (json['id'] is int) {
        parsedId = json['id'];
      } else if (json['id'] is String) {
        parsedId = int.tryParse(json['id']) ?? 0;
      } else {
        parsedId = int.tryParse(json['id'].toString()) ?? 0;
      }
    }

    return UserModel(
      id: parsedId,
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      profilePic: json['profile_pic']?.toString(),
      isOnline: json['is_online'] ?? false,
      callAccess: json['call_access'] ?? false,
      updatedAt: json['updated_at'] is int
          ? json['updated_at']
          : (json['updated_at'] is String
                ? int.tryParse(json['updated_at'])
                : null),
      createdAt: json['created_at']?.toString(),
    );
  }

  // factory UserModel.fromDb(Map<String, dynamic> map) {
  //   return UserModel(
  //     id: map['id'] as int,
  //     name: map['name']?.toString() ?? '',
  //     role: map['role']?.toString() ?? '',
  //     phone: map['phone']?.toString() ?? '',
  //     profilePic: map['profile_pic'] as String?,
  //     isOnline: map['is_online'] == 1,
  //     callAccess: map['call_access'] == 1,
  //     updatedAt: map['updated_at'] as int?,
  //     createdAt: map['created_at']?.toString(),
  //   );
  // }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'phone': phone,
      'profile_pic': profilePic,
      'is_online': isOnline,
      'call_access': callAccess,
      'created_at': createdAt,
    };
  }

  // // map to save into DB
  // Map<String, dynamic> toDbMap({bool markNeedsSync = false}) {
  //   return {
  //     'id': id,
  //     'name': name,
  //     'role': role,
  //     'phone': phone,
  //     'profile_pic': profilePic,
  //     'call_access': callAccess ? 1 : 0,
  //     'updated_at': DateTime.now().millisecondsSinceEpoch,
  //     'created_at': createdAt,
  //   };
  // }

  UserModel copyWith({
    String? name,
    String? role,
    String? phone,
    String? profilePic,
    bool? isOnline,
    bool? callAccess,
    int? updatedAt,
    String? createdAt,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      profilePic: profilePic ?? this.profilePic,
      isOnline: isOnline ?? this.isOnline,
      callAccess: callAccess ?? this.callAccess,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, role: $role, phone: $phone, profilePic: $profilePic, isOnline: $isOnline, callAccess: $callAccess)';
  }
}
