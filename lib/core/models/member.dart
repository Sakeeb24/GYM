// lib/core/models/member.dart
import 'package:flutter/foundation.dart';

@immutable
class Member {
  final String id;
  final String gymId;
  final String memberNumber;
  final String fullName;
  final String? phone;
  final String? email;
  final bool isActive;

  const Member({
    required this.id,
    required this.gymId,
    required this.memberNumber,
    required this.fullName,
    this.phone,
    this.email,
    required this.isActive,
  });

  factory Member.fromMap(Map<String, dynamic> m) => Member(
        id: m['id'] as String,
        gymId: m['gym_id'] as String,
        memberNumber: m['member_number'] as String? ?? m['id'] as String,
        fullName: m['full_name'] as String,
        phone: m['phone'] as String?,
        email: m['email'] as String?,
        isActive: (m['status'] as String?) != 'inactive',
      );
}
