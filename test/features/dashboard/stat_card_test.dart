// test/features/dashboard/stat_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftflow/core/widgets/app_stat_card.dart';

void main() {
  testWidgets('StatCard displays title, value, and icon correctly', (tester) async {
    const data = StatCardData(
      title: 'Active Members',
      value: '240',
      subtitle: '+12% this month',
      icon: Icon(Icons.groups),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatCard(data: data),
        ),
      ),
    );

    expect(find.text('Active Members'), findsOneWidget);
    expect(find.text('240'), findsOneWidget);
    expect(find.text('+12% this month'), findsOneWidget);
    expect(find.byIcon(Icons.groups), findsOneWidget);
  });
}
