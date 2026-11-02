import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:girokonto_app/main.dart';
import 'package:girokonto_app/util/money.dart';

void main() {
  test('Cent werden als Euro angezeigt', () {
    expect(formatCents(0), '0,00 €');
    expect(formatCents(123456), '1.234,56 €');
    expect(formatCents(-500), '-5,00 €');
  });

  test('IBAN wird in Vierergruppen angezeigt', () {
    expect(formatIban('DE89370400440532013000'), 'DE89 3704 0044 0532 0130 00');
  });

  testWidgets('Startseite zeigt die Anmeldung', (tester) async {
    await tester.pumpWidget(const GirokontoApp());

    expect(find.text('PHD Kontor'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Anmelden'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
