class UserModel {
  final int id;
  final String name;
  final String phone;
  final String? profilePic;
  final bool callAccess;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.profilePic,
    this.callAccess = false,
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

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, phone: $phone, profilePic: $profilePic, callAccess: $callAccess)';
  }
}
