// lib/features/auth/owner_registration_repository.dart
// Repository for owner registration. Calls the server-side registerOwner
// Edge Function — the ONLY place where role='owner' may be assigned.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_client.dart';

/// Result returned to the UI on successful owner registration.
class OwnerRegistrationResult {
  final String userId;
  final String gymId;
  final String gymName;
  final String gymSlug;

  const OwnerRegistrationResult({
    required this.userId,
    required this.gymId,
    required this.gymName,
    required this.gymSlug,
  });

  factory OwnerRegistrationResult.fromMap(Map<String, dynamic> map) =>
      OwnerRegistrationResult(
        userId:  map['user_id']  as String? ?? '',
        gymId:   map['gym_id']   as String? ?? '',
        gymName: map['gym_name'] as String? ?? '',
        gymSlug: map['gym_slug'] as String? ?? '',
      );
}

abstract class OwnerRegistrationRepository {
  /// Registers a new gym owner via the server-side Edge Function.
  ///
  /// The [setupSecret] is validated server-side against [OWNER_SETUP_SECRET].
  /// Role assignment happens entirely on the server — the Flutter client
  /// never sends a role field.
  Future<OwnerRegistrationResult> registerOwner({
    required String gymName,
    required String gymSlug,
    required String fullName,
    required String phone,
    required String username,
    required String password,
    required String setupSecret,
  });
}

class SupabaseOwnerRegistrationRepository implements OwnerRegistrationRepository {
  final SupabaseClient? _client;

  SupabaseOwnerRegistrationRepository([SupabaseClient? client]) : _client = client;

  SupabaseClient get client => _client ?? AppSupabase.client;

  @override
  Future<OwnerRegistrationResult> registerOwner({
    required String gymName,
    required String gymSlug,
    required String fullName,
    required String phone,
    required String username,
    required String password,
    required String setupSecret,
  }) async {
    // SECURITY: setup_secret is sent to the server only; it is validated
    // server-side. The client NEVER receives it back. Role assignment is
    // performed server-side using service_role — the anon key cannot bypass RLS.
    final res = await client.functions.invoke(
      'registerOwner',
      body: {
        'gym_name':     gymName.trim(),
        'gym_slug':     gymSlug.trim().toLowerCase(),
        'full_name':    fullName.trim(),
        'phone':        phone.trim(),
        'username':     username.trim().toLowerCase(),
        'password':     password, // never trim passwords
        'setup_secret': setupSecret.trim(),
      },
    );

    final data = res.data;
    if (data is Map) {
      if (data.containsKey('error')) {
        throw StateError(data['error'] as String);
      }
      return OwnerRegistrationResult.fromMap(Map<String, dynamic>.from(data));
    }
    throw StateError('Unexpected response from owner registration service.');
  }
}

final ownerRegistrationRepositoryProvider = Provider<OwnerRegistrationRepository>(
  (ref) => SupabaseOwnerRegistrationRepository(),
);
