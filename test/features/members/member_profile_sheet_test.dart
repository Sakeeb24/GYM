// test/features/members/member_profile_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liftflow/core/business_rules/business_rules.dart';
import 'package:liftflow/core/models/member.dart';
import 'package:liftflow/core/models/profile.dart';
import 'package:liftflow/features/auth/auth_notifier.dart';
import 'package:liftflow/features/members/presentation/edit_member_dialog.dart';
import 'package:liftflow/features/members/presentation/member_contact_launcher.dart';
import 'package:liftflow/features/members/presentation/members_screen.dart';
import 'package:liftflow/features/members/presentation/renew_membership_dialog.dart';

void main() {
  group('Member Model & copyWith Tests', () {
    test('Member fromMap and copyWith with tags and status', () {
      final m = Member.fromMap({
        'id': 'm-123',
        'gym_id': 'gym-1',
        'member_number': '101',
        'full_name': 'Alex Mercer',
        'phone': '+91 98765 43210',
        'email': 'alex@example.com',
        'status': 'active',
        'tags': ['VIP', 'Morning Crew'],
      });

      expect(m.id, 'm-123');
      expect(m.fullName, 'Alex Mercer');
      expect(m.isActive, isTrue);
      expect(m.tags, contains('VIP'));
      expect(m.tags, contains('Morning Crew'));

      final updated = m.copyWith(
        fullName: 'Alex M. Mercer',
        status: 'inactive',
        tags: ['VIP', 'Competitor'],
      );

      expect(updated.fullName, 'Alex M. Mercer');
      expect(updated.isActive, isFalse);
      expect(updated.status, 'inactive');
      expect(updated.tags, contains('Competitor'));
    });
  });

  group('MemberQuickContactDialog & MemberContactHelper Tests', () {
    test('MemberContactHelper sanitizes phone numbers', () {
      expect(MemberContactHelper.cleanPhoneNumber('+91 (987) 65-43210'), '+919876543210');
      expect(MemberContactHelper.cleanPhoneNumber('9876543210'), '9876543210');
    });

    testWidgets('MemberQuickContactDialog renders and switches templates', (tester) async {
      const member = Member(
        id: 'm-1',
        gymId: 'gym-1',
        memberNumber: '101',
        fullName: 'Marcus Vance',
        phone: '+1555123456',
        isActive: true,
        tags: ['VIP'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemberQuickContactDialog(
              member: member,
              gymName: 'Apex Strength',
              membershipExpiresAt: DateTime(2026, 12, 31),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('QUICK CONTACT'), findsOneWidget);
      expect(find.textContaining('To: Marcus Vance'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('SMS'), findsOneWidget);
      expect(find.text('Call Phone'), findsOneWidget);
      expect(find.text('Copy Text'), findsOneWidget);

      // Default template is Renewal Reminder
      expect(find.textContaining('Your gym membership expires on 2026-12-31'), findsOneWidget);

      // Switch to Missed Workout template
      await tester.tap(find.text('Missed Workout'));
      await tester.pumpAndSettle();
      expect(find.textContaining('We missed you at Apex Strength this week!'), findsOneWidget);

      // Switch to Welcome template
      await tester.tap(find.text('Welcome'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Welcome to Apex Strength, Marcus Vance!'), findsOneWidget);
    });
  });

  group('EditMemberDialog Widget Tests', () {
    testWidgets('EditMemberDialog renders member fields and manages tags', (tester) async {
      const member = Member(
        id: 'm-1',
        gymId: 'gym-1',
        memberNumber: '101',
        fullName: 'Marcus Vance',
        phone: '+1555123456',
        email: 'marcus@example.com',
        isActive: true,
        tags: ['VIP'],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EditMemberDialog(member: member),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('EDIT ATHLETE'), findsOneWidget);
      expect(find.text('Marcus Vance'), findsOneWidget);
      expect(find.text('+1555123456'), findsOneWidget);
      expect(find.text('marcus@example.com'), findsOneWidget);
      expect(find.text('Account Status'), findsOneWidget);
      expect(find.text('VIP'), findsOneWidget);

      // Add a custom tag
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.last, 'Student');
      await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Student'), findsWidgets);
    });
  });

  group('RenewMembershipDialog Widget Tests', () {
    const ownerProfile = Profile(
      userId: 'user-1',
      gymId: 'gym-1',
      username: 'coach_dave',
      fullName: 'Dave Miller',
      role: AppRole.owner,
    );

    testWidgets('RenewMembershipDialog displays plans and calculates extension', (tester) async {
      const member = Member(
        id: 'm-1',
        gymId: 'gym-1',
        memberNumber: '101',
        fullName: 'Marcus Vance',
        phone: '+1555123456',
        isActive: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(ownerProfile)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RenewMembershipDialog(
                member: member,
                currentPlanName: 'Monthly Pass',
                currentExpiresAt: DateTime(2026, 9, 30),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RENEW MEMBERSHIP'), findsOneWidget);
      expect(find.textContaining('Marcus Vance'), findsWidgets);
      expect(find.text('Monthly Pass'), findsOneWidget);
      expect(find.text('2026-09-30'), findsOneWidget);
      expect(find.text('Confirm & Activate Renewal'), findsOneWidget);
    });
  });

  group('MembersScreen Enhanced Profile Sheet Tests', () {
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
        tags: ['VIP', 'Morning Crew'],
      ),
    ];

    testWidgets('Opening profile sheet renders Quick Action buttons', (tester) async {
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

      // Tap on member card
      await tester.tap(find.text('Marcus Vance'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check Quick Action Bar buttons
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Renew'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Check In'), findsOneWidget);
      expect(find.text('MEMBERSHIP TIER'), findsOneWidget);
    });
  });
}
