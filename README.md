# PHD Kontor

Smartphone-Konto (Projekt Informatik, FRA-UAS). Backend: Spring Boot + PostgreSQL, App: Flutter.

## Starten (Entwicklung)

1. Datenbank und Mailserver: `docker compose up -d db mailpit`
   - Alle Mails (Codes) landen in Mailpit: http://localhost:8025, nicht im echten Postfach
2. Backend: `cd backend && ./gradlew bootRun`
3. App: `cd app && flutter pub get && flutter run -d chrome`

## Prototyp (nur Aufbau, ohne Funktion)

Zeigt alle geplanten Bereiche der App als Schema, ohne Server und ohne Daten:

```bash
cd app && flutter run -d chrome -t lib/prototype/main_prototype.dart
```

## Schnittstellen

| Methode | Pfad | Beschreibung |
|---|---|---|
| GET | `/api/status` | Server läuft, Anzahl Nutzer |
| POST | `/api/auth/register` | Registrieren, schickt Code per Mail (202) |
| POST | `/api/auth/verify-email` | Code bestätigen, legt Girokonto mit IBAN an |
| POST | `/api/auth/resend-code` | Bestätigungscode erneut schicken |
| POST | `/api/auth/login` | Anmelden: ohne Code → 428 + Mail, mit Code → angemeldet |
| POST | `/api/auth/password/forgot` | Code zum Zurücksetzen schicken |
| POST | `/api/auth/password/reset` | Neues Passwort mit Code setzen |
| GET | `/api/users/{id}/accounts` | Konten mit Kontostand |
