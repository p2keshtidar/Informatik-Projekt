import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:girokonto_app/main.dart';
import 'package:girokonto_app/util/money.dart';
import 'package:girokonto_app/util/password_rules.dart';

void main() {
  test('Cent werden als Euro angezeigt', () {
    expect(formatCents(0), '0,00 €');
    expect(formatCents(123456), '1.234,56 €');
    expect(formatCents(-500), '-5,00 €');
  });

  test('IBAN wird in Vierergruppen angezeigt', () {
    expect(formatIban('DE89370400440532013000'), 'DE89 3704 0044 0532 0130 00');
  });

  group('Passwortregeln (gleich wie im Backend)', () {
    final personal = personalParts('anna.muster@test.de', 'Anna', 'Muster');

    test('sicheres Passwort', () {
      expect(isPasswordOk('Kontor!Blau7Wald', personal), isTrue);
    });

    test('zu schwach', () {
      expect(isPasswordOk('kurz', personal), isFalse);
      expect(isPasswordOk('Muster!Konto77x', personal), isFalse);
      expect(isPasswordOk('Konto!1234Blau', personal), isFalse);
      expect(isPasswordOk('Willkommen99!', personal), isFalse);
    });
  });

  testWidgets('Startseite zeigt die Anmeldung', (tester) async {
    await tester.pumpWidget(const GirokontoApp());

    expect(find.text('PHD Kontor'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Anmelden'), findsOneWidget);
    expect(find.text('Passwort vergessen?'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
