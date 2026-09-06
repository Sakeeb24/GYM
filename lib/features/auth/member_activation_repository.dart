// lib/features/auth/member_activation_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_client.dart';

class MemberActivationTokenResponse {
  final String activationToken;
  final String qrPayload;
  final DateTime expiresAt;
  final int lifetimeSeconds;
  final String gymId;
  final String gymName;
  final String? gymSlug;

  const MemberActivationTokenResponse({
    required this.activationToken,
    required this.qrPayload,
    required this.expiresAt,
    required this.lifetimeSeconds,
    required this.gymId,
    required this.gymName,
    this.gymSlug,
  });

  factory MemberActivationTokenResponse.fromMap(Map<String, dynamic> map) {
    final gymMap = map['gym'] as Map<String, dynamic>? ?? {};
    return MemberActivationTokenResponse(
      activationToken: map['activation_token'] as String? ?? '',
      qrPayload: map['qr_payload'] as String? ?? '',
      expiresAt: DateTime.tryParse(map['expires_at']?.toString() ?? '') ?? DateTime.now().add(const Duration(seconds: 60)),
      lifetimeSeconds: (map['lifetime_seconds'] as num?)?.toInt() ?? 60,
      gymId: gymMap['id'] as String? ?? '',
      gymName: gymMap['name'] as String? ?? 'Gym',
      gymSlug: gymMap['slug'] as String?,
    );
  }
}

class ValidatedGymActivation {
  final bool valid;
  final String gymId;
  final String gymName;
  final String? gymSlug;
  final DateTime expiresAt;

  const ValidatedGymActivation({
    required this.valid,
    required this.gymId,
    required this.gymName,
    this.gymSlug,
    required this.expiresAt,
  });

  factory ValidatedGymActivation.fromMap(Map<String, dynamic> map) {
    final gymMap = map['gym'] as Map<String, dynamic>? ?? {};
    return ValidatedGymActivation(
      valid: map['valid'] == true,
      gymId: gymMap['id'] as String? ?? '',
      gymName: gymMap['name'] as String? ?? 'LiftFlow Gym',
      gymSlug: gymMap['slug'] as String?,
      expiresAt: DateTime.tryParse(map['expires_at']?.toString() ?? '') ?? DateTime.now().add(const Duration(seconds: 60)),
    );
  }
}

abstract class MemberActivationRepository {
  /// Generates a new short-lived, single-use activation QR token for the owner's gym.
  Future<MemberActivationTokenResponse> createActivationToken();

  /// Validates a scanned QR token and returns verified gym details for member confirmation.
  Future<ValidatedGymActivation> validateActivationToken(String token);
}

class SupabaseMemberActivationRepository implements MemberActivationRepository {
  final SupabaseClient? _client;

  SupabaseMemberActivationRepository([SupabaseClient? client]) : _client = client;

  SupabaseClient get client => _client ?? AppSupabase.client;

  @override
  Future<MemberActivationTokenResponse> createActivationToken() async {
    final res = await client.functions.invoke(
      'createMemberActivation',
      body: {},
    );

    final data = res.data;
    if (data is Map) {
      if (data.containsKey('error')) {
        throw StateError(data['error'] as String);
      }
      return MemberActivationTokenResponse.fromMap(Map<String, dynamic>.from(data));
    }
    throw StateError('Failed to generate activation QR code');
  }

  @override
  Future<ValidatedGymActivation> validateActivationToken(String token) async {
    final res = await client.functions.invoke(
      'validateMemberActivation',
      body: {'token': token.trim()},
    );

    final data = res.data;
    if (data is Map) {
      if (data.containsKey('error')) {
        throw StateError(data['error'] as String);
      }
      return ValidatedGymActivation.fromMap(Map<String, dynamic>.from(data));
    }
    throw StateError('Failed to validate activation QR code');
  }
}

final memberActivationRepositoryProvider = Provider<MemberActivationRepository>((ref) {
  return SupabaseMemberActivationRepository();
});
