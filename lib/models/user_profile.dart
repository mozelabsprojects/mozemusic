class UserProfile {
  final String uid;
  final String name;
  final String avatarUrl;
  final String status;

  UserProfile({
    required this.uid,
    required this.name,
    required this.avatarUrl,
    required this.status,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    return UserProfile(
      uid: uid,
      name: map['name'] ?? '',
      avatarUrl: map['avatarUrl'] ?? '',
      status: map['status'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'avatarUrl': avatarUrl,
      'status': status,
    };
  }
}
