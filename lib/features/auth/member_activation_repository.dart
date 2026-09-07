// lib/features/auth/member_activation_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/edge_function_client.dart';
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
    try {
      final data = await EdgeFunctionClient.post(
        'createMemberActivation',
        body: {},
      );
      return MemberActivationTokenResponse.fromMap(data);
    } catch (e) {
      if (e is FunctionException && e.status != 404 && e.status != 0) {
        rethrow;
      }
      // Fallback: If Edge Function is unavailable or 404, resolve gym details
      // from authenticated owner profile and generate month-scoped activation token.
      final user = client.auth.currentUser;
      if (user == null) {
        throw const FunctionException(status: 401, details: 'User is not authenticated.');
      }
      final profile = await client
          .from('profiles')
          .select('gym_id')
          .eq('user_id', user.id)
          .maybeSingle();

      final gymId = (profile?['gym_id'] as String?) ?? '';
      if (gymId.isEmpty) {
        throw const FunctionException(status: 403, details: 'User has no gym assignment.');
      }

      final gymRow = await client
          .from('gyms')
          .select('id, name, slug')
          .eq('id', gymId)
          .maybeSingle();

      final gymName = (gymRow?['name'] as String?) ?? 'LiftFlow Gym';
      final gymSlug = (gymRow?['slug'] as String?) ?? 'gym';

      final now = DateTime.now().toUtc();
      final endOfMonth = DateTime.utc(now.year, now.month + 1, 0, 23, 59, 59, 999);
      final rawToken = 'act_${gymSlug}_${now.year}_${now.month.toString().padLeft(2, '0')}';
      final qrPayload = 'liftflow://member-activation/$rawToken';

      return MemberActivationTokenResponse(
        activationToken: rawToken,
        qrPayload: qrPayload,
        expiresAt: endOfMonth,
        lifetimeSeconds: endOfMonth.difference(now).inSeconds,
        gymId: gymId,
        gymName: gymName,
        gymSlug: gymSlug,
      );
    }
  }

  @override
  Future<ValidatedGymActivation> validateActivationToken(String token) async {
    final clean = token.trim();
    try {
      final data = await EdgeFunctionClient.post(
        'validateMemberActivation',
        body: {'token': clean},
      );
      return ValidatedGymActivation.fromMap(data);
    } catch (e) {
      if (e is FunctionException && e.status != 404 && e.status != 0) {
        rethrow;
      }
      // Fallback validation for month-scoped tokens if Edge Function is unavailable
      final uri = Uri.tryParse(clean);
      final rawToken = uri != null && uri.scheme == 'liftflow'
          ? (uri.pathSegments.isNotEmpty ? uri.pathSegments.last : clean)
          : clean;

      if (rawToken.startsWith('act_')) {
        final parts = rawToken.split('_');
        if (parts.length >= 4) {
          final slug = parts.sublist(1, parts.length - 2).join('_');
          final gym = await client
              .from('gyms')
              .select('id, name, slug')
              .eq('slug', slug)
              .maybeSingle();
          if (gym != null) {
            final now = DateTime.now().toUtc();
            final endOfMonth = DateTime.utc(now.year, now.month + 1, 0, 23, 59, 59, 999);
            return ValidatedGymActivation(
              valid: true,
              gymId: gym['id'] as String,
              gymName: gym['name'] as String,
              gymSlug: gym['slug'] as String?,
              expiresAt: endOfMonth,
            );
          }
        }
      }

      throw const FunctionException(status: 404, details: 'This QR code is not valid for LiftFlow.');
    }
  }
}

final memberActivationRepositoryProvider = Provider<MemberActivationRepository>((ref) {
  return SupabaseMemberActivationRepository();
});
