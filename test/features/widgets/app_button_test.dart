// test/features/widgets/app_button_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftflow/core/widgets/app_button.dart';

void main() {
  group('AppButton Widget Tests', () {
    testWidgets('Renders text and responds to taps when enabled', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              text: 'Click Me',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Click Me'), findsOneWidget);
      await tester.tap(find.text('Click Me'));
      expect(tapped, isTrue);
    });

    testWidgets('Does not trigger tap when enabled is false', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              text: 'Disabled Button',
              enabled: false,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Disabled Button'), findsOneWidget);
      await tester.tap(find.text('Disabled Button'));
      expect(tapped, isFalse);
    });

    testWidgets('Renders icon when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppButton(
              text: 'With Icon',
              icon: Icon(Icons.bolt),
            ),
          ),
        ),
      );

      expect(find.text('With Icon'), findsOneWidget);
      expect(find.byIcon(Icons.bolt), findsOneWidget);
    });

    testWidgets('Renders all variants without errors', (tester) async {
      for (final variant in AppButtonVariant.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppButton(
                text: 'Variant ${variant.name}',
                variant: variant,
                onPressed: () {},
              ),
            ),
          ),
        );
        expect(find.text('Variant ${variant.name}'), findsOneWidget);
      }
    });
  });
}
