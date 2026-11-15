
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('ChangeGuard AI dashboard loads', (WidgetTester tester) async {
    await tester.pumpWidget(const ChangeGuardApp());

    expect(find.text('ChangeGuard AI'), findsWidgets);
    expect(find.text('AI-POWERED CODE REVIEW'), findsOneWidget);
  });
}
