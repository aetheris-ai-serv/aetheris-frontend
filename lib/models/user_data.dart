class UserData {
  final int? dataId;
  final int userId;
  final double speed;
  final double traffic;
  final DateTime time;
  final DateTime? createdAt;

  UserData({
    this.dataId,
    required this.userId,
    required this.speed,
    required this.traffic,
    required this.time,
    this.createdAt,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      dataId: json['data_id'],
      userId: json['user_id'],
      speed: json['speed'].toDouble(),
      traffic: json['traffic'].toDouble(),
      time: DateTime.parse(json['time']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'speed': speed,
      'traffic': traffic,
      'time': time.toIso8601String(),
    };
  }
}
