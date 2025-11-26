class UserInfo {
  final int? userId;
  final String username;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserInfo({
    this.userId,
    required this.username,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    this.createdAt,
    this.updatedAt,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      userId: json['user_id'],
      username: json['username'],
      email: json['email'],
      fullName: json['full_name'],
      phoneNumber: json['phone_number'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'full_name': fullName,
      'phone_number': phoneNumber,
    };
  }
}
