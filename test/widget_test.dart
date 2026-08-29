// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liftflow/app.dart';

void main() {
  testWidgets('App smoke test initializes correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: App(),
      ),
    );

    // Initial pump shows loading state or app container
    expect(find.byType(App), findsOneWidget);
  });
}
