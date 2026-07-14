import 'package:flutter_test/flutter_test.dart';

import 'package:my_animes/main.dart';

void main() {
  testWidgets('MyAnimes app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MyAnimesApp());
    // Verify the loading page or main app renders
    expect(find.text('My Animes'), findsAny);
  });
}
