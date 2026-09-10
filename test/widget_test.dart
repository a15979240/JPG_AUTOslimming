import 'package:flutter_test/flutter_test.dart';

import 'package:jpg_slimming/main.dart';

void main() {
  testWidgets('App builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const JpgSlimmingApp());
    expect(find.text('JPG 瘦身工具'), findsOneWidget);
  });
}
