import 'package:blackout_prague/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Zobrazí základní krizový přehled', (WidgetTester tester) async {
    await tester.pumpWidget(const BlackoutPragueShell());

    expect(find.text('Blackout Prague'), findsWidgets);
    expect(find.text('Offline režim připraven'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
  });
}