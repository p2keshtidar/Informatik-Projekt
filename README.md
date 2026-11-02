# PHD Kontor

Smartphone-Konto (Projekt Informatik, FRA-UAS). Backend: Spring Boot + PostgreSQL, App: Flutter.

## Starten (Entwicklung)

1. Datenbank: `docker compose up -d db`
2. Backend: `cd backend && ./gradlew bootRun`
3. App: `cd app && flutter pub get && flutter run -d chrome`

## Schnittstellen

| Methode | Pfad | Beschreibung |
|---|---|---|
| GET | `/api/status` | Server läuft, Anzahl Nutzer |
| POST | `/api/auth/register` | Registrieren, legt Girokonto mit IBAN an |
| POST | `/api/auth/login` | Anmelden mit E-Mail und Passwort |
| GET | `/api/users/{id}/accounts` | Konten mit Kontostand |
