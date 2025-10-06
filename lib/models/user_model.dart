class UserModel {
  final int id;
  final String name;
  final String phone;
  final String? profilePic;
  final bool callAccess;
  final bool needsSync; // local-only flag
  final int? updatedAt; // ms since epoch

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.profilePic,
    this.callAccess = false,
    this.needsSync = false,
    this.updatedAt,
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
      phone: json['phone']?.toString() ?? '',
      profilePic: json['profile_pic']?.toString(),
      callAccess: json['call_access'] == true,
      needsSync: (json['needs_sync'] == true || json['needs_sync'] == 1),
      updatedAt: json['updated_at'] is int
          ? json['updated_at']
          : (json['updated_at'] is String
                ? int.tryParse(json['updated_at'])
                : null),
    );
  }

  factory UserModel.fromDb(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int,
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      profilePic: map['profile_pic'] as String?,
      callAccess: map['call_access'] == 1,
      needsSync: (map['needs_sync'] == 1),
      updatedAt: map['updated_at'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'profile_pic': profilePic,
      'call_access': callAccess,
    };
  }

  // map to save into DB
  Map<String, dynamic> toDbMap({bool markNeedsSync = false}) {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'profile_pic': profilePic,
      'call_access': callAccess ? 1 : 0,
      'needs_sync': markNeedsSync ? 1 : 0,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  UserModel copyWith({
    String? name,
    String? phone,
    String? profilePic,
    bool? callAccess,
    bool? needsSync,
    int? updatedAt,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      profilePic: profilePic ?? this.profilePic,
      callAccess: callAccess ?? this.callAccess,
      needsSync: needsSync ?? this.needsSync,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, phone: $phone, profilePic: $profilePic, callAccess: $callAccess, needsSync: $needsSync)';
  }
}
