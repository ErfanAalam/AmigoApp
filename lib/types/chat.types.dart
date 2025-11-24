class TypingUser {
  final int userId;
  final String? userName;
  final String? userPfp;
  final int? convId;

  TypingUser({required this.userId, this.userName, this.userPfp, this.convId});

  factory TypingUser.fromJson(Map<String, dynamic> json) {
    return TypingUser(
      userId: json['user_id'] is int
          ? json['user_id']
          : (json['user_id'] is String ? int.tryParse(json['user_id']) : null),
      userName: json['user_name']?.toString(),
      userPfp: json['user_pfp']?.toString(),
      convId: json['conv_id'] is int
          ? json['conv_id']
          : (json['conv_id'] is String ? int.tryParse(json['conv_id']) : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'user_pfp': userPfp,
      'conv_id': convId,
    };
  }

  TypingUser copyWith({
    int? userId,
    String? userName,
    String? userPfp,
    int? convId,
  }) {
    return TypingUser(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPfp: userPfp ?? this.userPfp,
      convId: convId ?? this.convId,
    );
  }
}
