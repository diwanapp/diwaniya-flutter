class UserProfile {
  final String userId;
  final String firstName;
  final String lastName;
  final String phone;
  final String? avatarPresetId;
  final String? profileImagePath;

  const UserProfile({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.avatarPresetId,
    this.profileImagePath,
  });

  String get fullName {
    final value = '$firstName ${lastName.trim()}'.trim();
    return value.replaceAll(RegExp(r'\s+'), ' ');
  }

  String get initials {
    final parts = fullName.split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '؟';
    if (parts.length == 1) return parts.first.substring(0, 1);
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}';
  }

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? avatarPresetId,
    String? Function()? profileImagePath,
  }) {
    return UserProfile(
      userId: userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      avatarPresetId: avatarPresetId ?? this.avatarPresetId,
      profileImagePath: profileImagePath != null ? profileImagePath() : this.profileImagePath,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'avatarPresetId': avatarPresetId,
        if (profileImagePath != null) 'profileImagePath': profileImagePath,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        userId: json['userId'] as String,
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        avatarPresetId: json['avatarPresetId'] as String?,
        profileImagePath: json['profileImagePath'] as String?,
      );
}
