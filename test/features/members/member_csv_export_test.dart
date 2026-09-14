// test/features/members/member_csv_export_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liftflow/core/business_rules/business_rules.dart';
import 'package:liftflow/core/models/member.dart';
import 'package:liftflow/core/models/profile.dart';
import 'package:liftflow/core/utils/csv_export_helper.dart';
import 'package:liftflow/features/auth/auth_notifier.dart';
import 'package:liftflow/features/members/presentation/export_roster_dialog.dart';
import 'package:liftflow/features/members/presentation/members_screen.dart';

void main() {
  group('CsvExportHelper Unit Tests', () {
    test('escapeField properly handles quotes, commas, and newlines', () {
      expect(CsvExportHelper.escapeField('Marcus Vance'), 'Marcus Vance');
      expect(CsvExportHelper.escapeField('Vance, Marcus'), '"Vance, Marcus"');
      expect(CsvExportHelper.escapeField('Marcus "The Beast" Vance'), '"Marcus ""The Beast"" Vance"');
      expect(CsvExportHelper.escapeField('Marcus\nVance'), '"Marcus\nVance"');
      expect(CsvExportHelper.escapeField(null), '');
    });

    test('membersToCsv generates valid CSV with toggled fields', () {
      final members = [
        Member(
          id: 'm-1',
          gymId: 'gym-1',
          memberNumber: '101',
          fullName: 'Marcus Vance, Jr.',
          phone: '+1555123456',
          email: 'marcus@example.com',
          isActive: true,
          tags: const ['VIP', 'Morning Crew'],
          createdAt: DateTime(2026, 1, 15),
        ),
        Member(
          id: 'm-2',
          gymId: 'gym-1',
          memberNumber: '102',
          fullName: 'Sarah Connor',
          phone: '+1555987654',
          email: 'sarah@example.com',
          isActive: false,
          tags: const ['Competitor'],
          createdAt: DateTime(2026, 2, 20),
        ),
      ];

      final csvFull = CsvExportHelper.membersToCsv(members);
      expect(csvFull, contains('Member ID,Full Name,Phone,Email,Status,Tags,Enrolled Date'));
      expect(csvFull, contains('LF-101,"Marcus Vance, Jr.",+1555123456,marcus@example.com,Active,VIP; Morning Crew,2026-01-15'));
      expect(csvFull, contains('LF-102,Sarah Connor,+1555987654,sarah@example.com,Inactive,Competitor,2026-02-20'));

      // Test without phone and email
      final csvMinimal = CsvExportHelper.membersToCsv(
        members,
        includePhone: false,
        includeEmail: false,
      );
      expect(csvMinimal, contains('Member ID,Full Name,Status,Tags,Enrolled Date'));
      expect(csvMinimal, isNot(contains('+1555123456')));
    });
  });

  group('ExportRosterDialog Widget Tests', () {
    final members = [
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

    testWidgets('ExportRosterDialog displays scopes, checkboxes, and buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportRosterDialog(
              allMembers: members,
              filteredMembers: [members.first],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('EXPORT ROSTER (CSV)'), findsOneWidget);
      expect(find.text('All Athletes (2)'), findsOneWidget);
      expect(find.text('Current Filter (1)'), findsOneWidget);
      expect(find.text('Phone Numbers'), findsOneWidget);
      expect(find.text('Email Addresses'), findsOneWidget);
      expect(find.text('Download CSV File'), findsOneWidget);
      expect(find.text('Copy CSV Data to Clipboard'), findsOneWidget);

      // Switch to All Athletes
      await tester.tap(find.text('All Athletes (2)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 athlete records selected for export.'), findsOneWidget);
    });
  });

  group('MembersScreen Sorting, Tag Filtering & Export Trigger Tests', () {
    const ownerProfile = Profile(
      userId: 'user-1',
      gymId: 'gym-1',
      username: 'coach_dave',
      fullName: 'Dave Miller',
      role: AppRole.owner,
    );

    final List<Member> fakeMemberList = [
      Member(
        id: 'm-1',
        gymId: 'gym-1',
        memberNumber: '101',
        fullName: 'Zara Larsson',
        phone: '+1555123456',
        isActive: true,
        tags: const ['VIP'],
        createdAt: DateTime(2026, 1, 1),
      ),
      Member(
        id: 'm-2',
        gymId: 'gym-1',
        memberNumber: '102',
        fullName: 'Aaron Paul',
        phone: '+1555987654',
        isActive: true,
        tags: const ['Morning Crew'],
        createdAt: DateTime(2026, 2, 1),
      ),
    ];

    testWidgets('Sorting roster A-Z and Z-A reorders items', (tester) async {
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

      // By default A-Z: Aaron Paul should be first
      expect(find.text('Aaron Paul'), findsOneWidget);
      expect(find.text('Zara Larsson'), findsOneWidget);

      // Verify Export CSV button in AppBar
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);

      // Verify Tag chips rendered
      expect(find.text('TAGS:'), findsOneWidget);
      expect(find.text('All Tags'), findsOneWidget);
      expect(find.text('VIP'), findsWidgets);
      expect(find.text('Morning Crew'), findsWidgets);

      // Tap on VIP tag filter
      await tester.tap(find.text('VIP').first);
      await tester.pumpAndSettle();

      expect(find.text('Zara Larsson'), findsOneWidget);
      expect(find.text('Aaron Paul'), findsNothing);

      // Tap All Tags to clear
      await tester.tap(find.text('All Tags'));
      await tester.pumpAndSettle();

      expect(find.text('Zara Larsson'), findsOneWidget);
      expect(find.text('Aaron Paul'), findsOneWidget);

      // Tap Export CSV icon to open dialog
      await tester.tap(find.byIcon(Icons.file_download_outlined));
      await tester.pumpAndSettle();

      expect(find.text('EXPORT ROSTER (CSV)'), findsOneWidget);
    });
  });
}
