class TypingUser {
  final String userId;
  final String? userName;
  final String? userPfp;
  final String? convId;

  TypingUser({required this.userId, this.userName, this.userPfp, this.convId});

  factory TypingUser.fromJson(Map<String, dynamic> json) {
    return TypingUser(
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString(),
      userPfp: json['user_pfp']?.toString(),
      convId: json['conv_id']?.toString(),
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
    String? userId,
    String? userName,
    String? userPfp,
    String? convId,
  }) {
    return TypingUser(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPfp: userPfp ?? this.userPfp,
      convId: convId ?? this.convId,
    );
  }
}
