import 'package:flutter_test/flutter_test.dart';

import 'package:cantinho_make/app.dart';

void main() {
  testWidgets('Login screen is shown', (WidgetTester tester) async {
    await tester.pumpWidget(const CantinhoApp());
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Cantinho Make'), findsOneWidget);
    expect(find.text('Acessar'), findsOneWidget);
  });
}
