// lib/core/models/no_show_case.dart
import 'package:flutter/foundation.dart';

@immutable
class NoShowCase {
  final String id;
  final String memberId;
  final String memberName;
  final String gymId;
  final String status; // open | in_progress | resolved | dismissed
  final String reason;
  final DateTime createdAt;
  final DateTime? lastSeenAt;
  final String? resolvedOutcome;
  final DateTime? resolvedAt;

  const NoShowCase({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.gymId,
    required this.status,
    required this.reason,
    required this.createdAt,
    this.lastSeenAt,
    this.resolvedOutcome,
    this.resolvedAt,
  });
}
