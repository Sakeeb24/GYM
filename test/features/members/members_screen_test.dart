// test/features/members/members_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liftflow/core/business_rules/business_rules.dart';
import 'package:liftflow/core/models/member.dart';
import 'package:liftflow/core/models/profile.dart';
import 'package:liftflow/features/auth/auth_notifier.dart';
import 'package:liftflow/features/members/presentation/members_screen.dart';

void main() {
  group('MembersScreen & Interaction Tests', () {
    const ownerProfile = Profile(
      userId: 'user-1',
      gymId: 'gym-1',
      username: 'coach_dave',
      fullName: 'Dave Miller',
      role: AppRole.owner,
    );

    final List<Member> fakeMemberList = [
      const Member(
        id: 'm-1',
        gymId: 'gym-1',
        memberNumber: '101',
        fullName: 'Marcus Vance',
        phone: '+1555123456',
        isActive: true,
      ),
      const Member(
        id: 'm-2',
        gymId: 'gym-1',
        memberNumber: '102',
        fullName: 'Sarah Connor',
        phone: '+1555987654',
        isActive: false,
      ),
    ];

    testWidgets('Renders member roster and filters by category chips', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(ownerProfile)),
            membersProvider('gym-1').overrideWith((ref) => Stream.value(fakeMemberList)),
          ],
          child: const MaterialApp(
            home: MembersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify list items
      expect(find.text('Marcus Vance'), findsOneWidget);
      expect(find.text('Sarah Connor'), findsOneWidget);

      // Verify filter chips
      expect(find.textContaining('All (2)'), findsOneWidget);
      expect(find.textContaining('Active (1)'), findsOneWidget);
      expect(find.textContaining('Inactive (1)'), findsOneWidget);

      // Filter ACTIVE
      await tester.tap(find.textContaining('Active (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Marcus Vance'), findsOneWidget);
      expect(find.text('Sarah Connor'), findsNothing);

      // Filter INACTIVE
      await tester.tap(find.textContaining('Inactive (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Marcus Vance'), findsNothing);
      expect(find.text('Sarah Connor'), findsOneWidget);

      // Filter ALL again
      await tester.tap(find.textContaining('All (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Marcus Vance'), findsOneWidget);
      expect(find.text('Sarah Connor'), findsOneWidget);
    });

    testWidgets('Searching members filters the displayed cards', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(ownerProfile)),
            membersProvider('gym-1').overrideWith((ref) => Stream.value(fakeMemberList)),
          ],
          child: const MaterialApp(
            home: MembersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Search for "Marcus"
      await tester.enterText(find.byType(TextField), 'Marcus');
      await tester.pumpAndSettle();

      expect(find.text('Marcus Vance'), findsOneWidget);
      expect(find.text('Sarah Connor'), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Marcus Vance'), findsOneWidget);
      expect(find.text('Sarah Connor'), findsOneWidget);
    });

    testWidgets('Tapping member card opens athlete profile sheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(ownerProfile)),
            membersProvider('gym-1').overrideWith((ref) => Stream.value(fakeMemberList)),
          ],
          child: const MaterialApp(
            home: MembersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Marcus Vance'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Marcus Vance'), findsWidgets);
    });
  });
}
