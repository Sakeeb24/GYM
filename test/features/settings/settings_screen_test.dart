// test/features/settings/settings_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liftflow/core/business_rules/business_rules.dart';
import 'package:liftflow/core/models/profile.dart';
import 'package:liftflow/features/auth/auth_notifier.dart';
import 'package:liftflow/features/auth/auth_repository.dart';
import 'package:liftflow/features/settings/presentation/settings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthRepo implements AuthRepository {
  bool signedOut = false;

  @override
  Stream<AuthState> authState() => const Stream.empty();

  @override
  Future<void> signInWithUsername(String username, String password) async {}

  @override
  Future<void> sendPhoneOtp(String phone) async {}

  @override
  Future<void> registerMember({
    required String fullName,
    required String phone,
    required String otpToken,
    required String username,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {
    signedOut = true;
  }

  @override
  Future<Profile?> currentProfile() async => null;

  @override
  Stream<Profile?> watchProfile() => const Stream.empty();

  @override
  Future<bool> isUsernameTaken(String username) async => false;

  @override
  Future<String> requestPasswordReset(String username) async => '+91******7247';

  @override
  Future<void> completePasswordReset({
    required String username,
    required String otpToken,
    required String newPassword,
  }) async {}
}

void main() {
  group('SettingsScreen & Button Action Tests', () {
    const ownerProfile = Profile(
      userId: 'user-1',
      gymId: 'gym-1',
      username: 'coach_dave',
      fullName: 'Dave Miller',
      role: AppRole.owner,
    );

    final fakeSettings = {
      'inactivity_threshold_days': 7,
      'qr_session_grace_minutes': 5,
    };

    testWidgets('Renders operations, notification toggles, and sign out button', (tester) async {
      final mockAuth = MockAuthRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(ownerProfile)),
            gymSettingsProvider('gym-1').overrideWith((ref) => Future.value(fakeSettings)),
            authRepositoryProvider.overrideWithValue(mockAuth),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Profile Section
      expect(find.text('Dave Miller'), findsOneWidget);
      expect(find.text('@coach_dave • OWNER'), findsOneWidget);

      // Verify Gym Operations Section
      expect(find.text('Gym Operations'), findsOneWidget);
      expect(find.text('Save Parameters'), findsOneWidget);

      // Verify Notification Switches
      expect(find.text('WhatsApp Expiry Reminders'), findsOneWidget);
      expect(find.text('Daily Performance Digest'), findsOneWidget);

      // Toggle switches
      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(2));
      await tester.tap(switches.at(0));
      await tester.pumpAndSettle();

      // Verify Sign Out button
      final signOutBtn = find.text('Sign Out of LiftFlow');
      expect(signOutBtn, findsOneWidget);
      await tester.ensureVisible(signOutBtn);
      await tester.tap(signOutBtn);
      await tester.pumpAndSettle();
      expect(mockAuth.signedOut, isTrue);
    });
  });
}
