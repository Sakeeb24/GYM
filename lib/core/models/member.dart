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
  final DateTime? dob;
  final List<String> tags;
  final String status;
  final DateTime? createdAt;
  final bool isActive;

  const Member({
    required this.id,
    required this.gymId,
    required this.memberNumber,
    required this.fullName,
    this.phone,
    this.email,
    this.dob,
    this.tags = const [],
    this.status = 'active',
    this.createdAt,
    required this.isActive,
  });

  Member copyWith({
    String? id,
    String? gymId,
    String? memberNumber,
    String? fullName,
    String? phone,
    String? email,
    DateTime? dob,
    List<String>? tags,
    String? status,
    DateTime? createdAt,
    bool? isActive,
  }) {
    final newStatus = status ?? this.status;
    return Member(
      id: id ?? this.id,
      gymId: gymId ?? this.gymId,
      memberNumber: memberNumber ?? this.memberNumber,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      dob: dob ?? this.dob,
      tags: tags ?? this.tags,
      status: newStatus,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? (newStatus != 'inactive'),
    );
  }

  factory Member.fromMap(Map<String, dynamic> m) {
    final statusVal = (m['status'] as String?) ?? 'active';
    final tagsRaw = m['tags'];
    List<String> tagsList = const [];
    if (tagsRaw is List) {
      tagsList = tagsRaw.map((e) => e.toString()).toList();
    }

    return Member(
      id: m['id'] as String,
      gymId: m['gym_id'] as String,
      memberNumber: m['member_number'] as String? ?? m['id'] as String,
      fullName: m['full_name'] as String,
      phone: m['phone'] as String?,
      email: m['email'] as String?,
      dob: m['dob'] != null ? DateTime.tryParse(m['dob'].toString()) : null,
      tags: tagsList,
      status: statusVal,
      createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at'].toString()) : null,
      isActive: statusVal != 'inactive',
    );
  }
}

