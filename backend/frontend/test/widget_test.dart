import 'package:flutter_test/flutter_test.dart';

import 'package:vocablock_ui/app.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const VocabLockApp());
    await tester.pump();
    expect(find.byType(VocabLockApp), findsOneWidget);
  });
}
