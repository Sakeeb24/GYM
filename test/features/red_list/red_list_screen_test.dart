// test/features/red_list/red_list_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liftflow/core/business_rules/business_rules.dart';
import 'package:liftflow/core/models/no_show_case.dart';
import 'package:liftflow/core/models/profile.dart';
import 'package:liftflow/features/auth/auth_notifier.dart';
import 'package:liftflow/features/red_list/no_show_repository.dart';
import 'package:liftflow/features/red_list/presentation/red_list_screen.dart';

class FakeNoShowRepository implements NoShowRepository {
  bool resolved = false;

  @override
  Stream<List<NoShowCase>> openCases(String gymId) => const Stream.empty();

  @override
  Future<void> resolveCase(String caseId, String status, String outcome) async {
    resolved = true;
  }
}

void main() {
  group('RedListScreen & Retention Action Tests', () {
    const ownerProfile = Profile(
      userId: 'user-1',
      gymId: 'gym-1',
      username: 'coach_dave',
      fullName: 'Dave Miller',
      role: AppRole.owner,
    );

    final fakeCases = [
      NoShowCase(
        id: 'case-1',
        memberId: 'mem-1',
        memberName: 'Elena Rostova',
        gymId: 'gym-1',
        status: 'open',
        reason: '14 days inactive',
        lastSeenAt: DateTime.now().subtract(const Duration(days: 12)),
        createdAt: DateTime(2026, 8, 15),
      ),
    ];

    testWidgets('Renders retention cards and handles contact action', (tester) async {
      final fakeRepo = FakeNoShowRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(ownerProfile)),
            openCasesProvider('gym-1').overrideWith((ref) => Stream.value(fakeCases)),
            noShowRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: RedListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header & Filters
      expect(find.text('Retention & Red List'), findsOneWidget);
      expect(find.text('ALL'), findsOneWidget);
      expect(find.text('AT RISK'), findsOneWidget);

      // Verify Card details
      expect(find.text('Elena Rostova'), findsOneWidget);
      expect(find.text('Last visit: 12 days ago • Reason: 14 days inactive'), findsOneWidget);
      expect(find.text('OPEN'), findsOneWidget);

      // Verify Action Buttons
      expect(find.text('Contact'), findsOneWidget);
      expect(find.text('Resolve'), findsOneWidget);

      // Tap Contact button
      await tester.tap(find.text('Contact'));
      await tester.pumpAndSettle();
      expect(find.text('Opening outreach channel for Elena Rostova...'), findsOneWidget);
    });

    testWidgets('Handles resolve action on retention card', (tester) async {
      final fakeRepo = FakeNoShowRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(ownerProfile)),
            openCasesProvider('gym-1').overrideWith((ref) => Stream.value(fakeCases)),
            noShowRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: RedListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Resolve button
      await tester.tap(find.text('Resolve'));
      await tester.pumpAndSettle();

      expect(fakeRepo.resolved, isTrue);
      expect(find.text('Resolved retention case for Elena Rostova'), findsOneWidget);
    });

    testWidgets('Renders empty state when no cases exist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(ownerProfile)),
            openCasesProvider('gym-1').overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: RedListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No retention alerts matching this filter category.'), findsOneWidget);
    });
  });
}
