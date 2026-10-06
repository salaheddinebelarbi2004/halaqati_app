import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halaqati/main.dart';

void main() {
  testWidgets('App launches correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: HalaqatiApp()));
    expect(find.byType(HalaqatiApp), findsOneWidget);
  });
}
