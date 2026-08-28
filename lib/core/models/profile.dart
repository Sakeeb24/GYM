// lib/core/models/profile.dart
import 'package:flutter/foundation.dart';
import 'package:liftflow/core/business_rules/business_rules.dart';

AppRole? parseRole(String? v) {
  return switch (v) {
    'owner' => AppRole.owner,
    'front_desk' => AppRole.frontDesk,
    'trainer' => AppRole.trainer,
    'member' => AppRole.member,
    _ => null,
  };
}

@immutable
class Profile {
  final String userId;
  final String gymId;
  final String? fullName;
  final String? email;
  final String? phone;
  final AppRole role;

  const Profile({
    required this.userId,
    required this.gymId,
    required this.role,
    this.fullName,
    this.email,
    this.phone,
  });

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        userId: m['user_id'] as String? ?? m['id'] as String,
        gymId: m['gym_id'] as String,
        role: parseRole(m['role'] as String? ?? '') ?? AppRole.member,
        fullName: m['full_name'] as String?,
        email: m['email'] as String?,
        phone: m['phone'] as String?,
      );
}
