// test/features/navigation/main_scaffold_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liftflow/core/business_rules/business_rules.dart';
import 'package:liftflow/core/widgets/main_scaffold.dart';

void main() {
  testWidgets('MainScaffold displays owner destinations', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MainScaffold(role: AppRole.owner),
        ),
      ),
    );

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Red List'), findsOneWidget);
    expect(find.text('Renewals'), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('MainScaffold displays frontDesk destinations', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MainScaffold(role: AppRole.frontDesk),
        ),
      ),
    );

    expect(find.text('Check-in'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Red List'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('MainScaffold displays trainer destinations and blocks billing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MainScaffold(role: AppRole.trainer),
        ),
      ),
    );

    expect(find.text('Check-in'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Payments'), findsNothing);
    expect(find.text('Settings'), findsNothing);
    expect(find.text('Renewals'), findsNothing);
  });

  testWidgets('MainScaffold displays member destinations', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MainScaffold(role: AppRole.member),
        ),
      ),
    );

    expect(find.text('Pass'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Renewals'), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
  });
}
