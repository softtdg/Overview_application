import 'package:digital_wall/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Digital Wall app loads login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Username'), findsOneWidget);
  });
}
