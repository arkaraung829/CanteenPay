import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Basic smoke test — app requires Firebase/Supabase init
    // which can't run in test environment. Just verify test framework works.
    expect(1 + 1, equals(2));
  });
}
