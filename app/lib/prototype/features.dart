import 'package:flutter/material.dart';

import 'schema.dart';

// Inhalt des Prototyps: welche Bereiche die App bekommt und was darauf zu sehen ist

const kontoTab = Feature(
  title: 'Konto',
  icon: Icons.account_balance_wallet_outlined,
  purpose: 'Startseite: alle Konten auf einen Blick. Bankkonten und digitale Konten sind klar getrennt. '
      'Schon umgesetzt: Girokonto mit IBAN und Kontostand.',
  sections: [
    Section('Übersicht', [Part(Kind.area, 'Gesamtvermögen (Summe aller Konten minus Kredite)')]),
    Section('Bankkonten', [
      Part(Kind.list, 'Konten der Projektbank und verbundene Banken', [
        'Girokonto mit IBAN',
        'Verbundenes Konto einer anderen Bank (nur lesen)',
      ]),
    ]),
    Section('Sparkonten und geteilte Konten', [
      Part(Kind.list, 'Tagesgeld, Sparpläne, gemeinsame Kassen', [
        'Sparkonto (Tagesgeld)',
        'Geteiltes Konto, z. B. WG-Kasse',
      ]),
    ]),
    Section('Umsätze', [
      Part(Kind.chips, '', ['Suche', 'Zeitraum', 'Eingang / Ausgang', 'Kategorie']),
      Part(Kind.list, 'Letzte Buchungen, nach Tagen gruppiert', ['Buchung', 'Buchung', 'Buchung']),
      Part(Kind.button, 'Alle Umsätze'),
    ]),
  ],
);

const ueberweisenTab = Feature(
  title: 'Überweisen',
  icon: Icons.swap_horiz,
  purpose: 'Geld senden per IBAN, E-Mail oder Telefonnummer, in drei Schritten.',
  sections: [
    Section('Ablauf', [Part(Kind.steps, '', ['Eingabe', 'Prüfen', 'Senden'])]),
    Section('Eingabe', [
      Part(Kind.field, 'Empfänger: IBAN, E-Mail oder Telefon'),
      Part(Kind.field, 'Betrag'),
      Part(Kind.field, 'Verwendungszweck'),
      Part(Kind.button, 'Weiter zur Zusammenfassung'),
    ]),
    Section('Adressbuch', [
      Part(Kind.list, 'Gespeicherte Kontakte', ['Kontakt', 'Kontakt']),
    ]),
    Section('Daueraufträge', [
      Part(Kind.list, 'Regelmäßige Überweisungen (monatlich bis jährlich)', ['Dauerauftrag']),
      Part(Kind.button, 'Dauerauftrag anlegen'),
    ]),
  ],
);

const sparenTab = Feature(
  title: 'Sparen',
  icon: Icons.savings_outlined,
  purpose: 'Finanzassistent: sparen, investieren, Kredite planen.',
  sections: [
    Section('Sparziel', [
      Part(Kind.field, 'Ziel, z. B. Urlaub'),
      Part(Kind.field, 'Zielbetrag und Datum'),
      Part(Kind.area, 'Vorschlag Monatsrate und Ampel: machbar?'),
      Part(Kind.toggle, 'Erinnerung vor der Abbuchung'),
    ]),
    Section('Investplan', [
      Part(Kind.chips, '', ['Risiko niedrig', 'mittel', 'hoch']),
      Part(Kind.chart, 'Musterdepot: Verlauf und Prognose'),
    ]),
    Section('Automatisch sparen', [
      Part(Kind.list, 'Sparregeln für Sparkonten und geteilte Konten', ['Regel (wöchentlich bis vierteljährlich)']),
    ]),
    Section('Kredit', [
      Part(Kind.chips, '', ['Auto', 'Immobilie', 'Sonstiges']),
      Part(Kind.list, 'Angebote fiktiver Banken im Vergleich', ['Bank', 'Bank', 'Bank']),
      Part(Kind.steps, '', ['Anfrage', 'Vertrag', 'Auszahlung']),
      Part(Kind.chart, 'Tilgungsplan mit Sondertilgung'),
    ]),
  ],
);

const karteTab = Feature(
  title: 'Karte',
  icon: Icons.credit_card,
  purpose: 'Virtuelle Debitkarte zum Girokonto und Kreditkarte (Simulation).',
  sections: [
    Section('Debitkarte', [
      Part(Kind.area, 'Kartenbild (Kartendaten nur nach Passwort)'),
      Part(Kind.toggle, 'Karte sperren'),
      Part(Kind.toggle, 'Online-Zahlungen erlauben'),
      Part(Kind.area, 'Tageslimit einstellen'),
    ]),
    Section('Kreditkarte', [
      Part(Kind.area, 'Verfügungsrahmen und offene Abrechnung'),
      Part(Kind.list, 'Monatsabrechnungen', ['Abrechnung']),
    ]),
  ],
);

const mehrFeatures = <Feature>[
  Feature(
    title: 'Anmeldung und Sicherheit',
    icon: Icons.lock_outline,
    implemented: true,
    purpose: 'Registrierung mit sicherem Passwort, E-Mail-Bestätigung und Anmeldung mit Code (2FA).',
    sections: [
      Section('Registrierung', [
        Part(Kind.steps, '', ['Daten', 'Code per Mail', 'Girokonto']),
        Part(Kind.area, 'Passwort-Checkliste: 12 Zeichen, Groß/klein, Ziffer, Sonderzeichen …'),
      ]),
      Section('Anmeldung', [
        Part(Kind.steps, '', ['E-Mail + Passwort', 'Code aus der Mail']),
        Part(Kind.area, 'Sperre nach 5 Fehlversuchen für 5 Minuten'),
        Part(Kind.button, 'Passwort vergessen'),
      ]),
    ],
  ),
  Feature(
    title: 'Finanzüberblick',
    icon: Icons.dashboard_outlined,
    purpose: 'Dashboard: Vermögen, Einnahmen und Ausgaben, Schulden, Sparziele.',
    sections: [
      Section('Vermögen', [Part(Kind.chart, 'Vermögensverlauf (12 Monate)')]),
      Section('Monat', [
        Part(Kind.chart, 'Einnahmen und Ausgaben pro Monat'),
        Part(Kind.area, 'Ausgaben nach Kategorien'),
        Part(Kind.list, 'Größte Ausgaben', ['Ausgabe', 'Ausgabe']),
      ]),
    ],
  ),
  Feature(
    title: 'Budgets und Prognose',
    icon: Icons.insights_outlined,
    purpose: 'Budgets je Kategorie mit Warnung bei 80 % und 100 %, Prognose des Kontostands.',
    sections: [
      Section('Budgets', [Part(Kind.list, 'Budget je Kategorie mit Fortschritt', ['Kategorie', 'Kategorie'])]),
      Section('Prognose', [
        Part(Kind.chart, 'Kontostand bis Monatsende: erwartet, günstig, ungünstig'),
        Part(Kind.list, 'Ungewöhnliche Ausgaben', ['Hinweis']),
      ]),
    ],
  ),
  Feature(
    title: 'Finanzassistent',
    icon: Icons.chat_outlined,
    purpose: 'Fragen zu den eigenen Finanzen, regelbasiert und nur mit den Zahlen der App.',
    sections: [
      Section('Fragen', [
        Part(Kind.chips, '', ['Wofür gebe ich am meisten aus?', 'Wo kann ich sparen?', 'Was wäre, wenn …']),
        Part(Kind.area, 'Antwort des Assistenten'),
      ]),
      Section('Monatsbericht', [Part(Kind.area, 'Zusammenfassung des letzten Monats')]),
    ],
  ),
  Feature(
    title: 'Gemeinsame Ausgaben',
    icon: Icons.groups_outlined,
    purpose: 'Kosten in WG, Reise oder Paar aufteilen und ausgleichen.',
    sections: [
      Section('Gruppe', [
        Part(Kind.list, 'Mitglieder und Salden', ['Mitglied', 'Mitglied', 'Mitglied']),
        Part(Kind.list, 'Ausgaben', ['Ausgabe, aufgeteilt']),
        Part(Kind.button, 'Ausgleich vorschlagen'),
      ]),
    ],
  ),
  Feature(
    title: 'Verträge und Dokumente',
    icon: Icons.description_outlined,
    purpose: 'Verträge mit Laufzeit und Kündigungsfrist, Erinnerung vor Fristende, Dokumente verschlüsselt.',
    sections: [
      Section('Verträge', [Part(Kind.list, 'Vertrag mit Kosten und Frist', ['Vertrag', 'Vertrag'])]),
      Section('Dokumente', [Part(Kind.button, 'PDF oder Bild hochladen')]),
    ],
  ),
  Feature(
    title: 'Marktplatz',
    icon: Icons.storefront_outlined,
    purpose: 'Finanzprodukte fiktiver Anbieter vergleichen und simuliert beantragen.',
    sections: [
      Section('Vergleich', [
        Part(Kind.chips, '', ['Girokonto', 'Kreditkarte', 'Tagesgeld', 'Festgeld', 'Depot']),
        Part(Kind.list, 'Produkte mit Vor- und Nachteilen', ['Produkt', 'Produkt']),
      ]),
    ],
  ),
  Feature(
    title: 'Banken verbinden',
    icon: Icons.link,
    purpose: 'Konten anderer Banken per Open Banking (PSD2) einbinden, nur Lesezugriff.',
    sections: [
      Section('Verbindung', [
        Part(Kind.steps, '', ['Bank wählen', 'Freigabe bei der Bank', 'Umsätze abrufen']),
        Part(Kind.button, 'CSV-Datei einer Bank importieren'),
      ]),
    ],
  ),
  Feature(
    title: 'Benachrichtigungen',
    icon: Icons.notifications_none,
    purpose: 'Live-Meldung bei jeder Buchung, Erinnerungen und Warnungen.',
    sections: [Section('Meldungen', [Part(Kind.list, 'Neueste zuerst', ['Meldung', 'Meldung'])])],
  ),
  Feature(
    title: 'Profil',
    icon: Icons.person_outline,
    purpose: 'Persönliche Daten, Passwort ändern, Sprache Deutsch/Englisch, Abmelden.',
    sections: [
      Section('Einstellungen', [
        Part(Kind.list, '', ['Persönliche Daten', 'Passwort ändern', 'Sprache']),
        Part(Kind.button, 'Abmelden'),
      ]),
    ],
  ),
];
