   # PHD Kontor

**Smartphone-Konto** – Informatik-Projekt an der Frankfurt University of Applied Sciences (FRA-UAS).

### Tech Stack
* **Backend:** Spring Boot (Java 21) + PostgreSQL
* **App (Frontend):** Flutter
* **Infrastruktur:** Docker, Mailpit

---

## Starten (Entwicklung)

### 1. Datenbank und Mailserver
Starte die Container für die Datenbank und den Mailserver:
```bash
docker compose up -d db mailpit
```
> **Hinweis:** Alle E-Mails (z. B. Bestätigungscodes) landen in Mailpit und nicht in deinem echten Postfach. 
> Mailpit öffnen: [http://localhost:8025](http://localhost:8025)

### 2. Backend
Starte das Spring Boot Backend:
```bash
cd backend
./gradlew bootRun
```

### 3. App
Lade die Abhängigkeiten und starte die Flutter-App im Browser:
```bash
cd app
flutter pub get
flutter run -d chrome
```

---

## Prototyp (nur Aufbau, ohne Funktion)

Der Prototyp zeigt alle geplanten Bereiche der App als visuelles Schema. Er benötigt weder einen aktiven Server noch echte Daten:

```bash
cd app
flutter run -d chrome -t lib/prototype/main_prototype.dart
```

---

## Schnittstellen (API)

| Methode | Pfad | Beschreibung |
|:---|:---|:---|
| **GET** | `/api/status` | Serverstatus und Anzahl der Nutzer |
| **POST** | `/api/auth/register` | Registrierung, versendet Code per Mail (202) |
| **POST** | `/api/auth/verify-email` | Code bestätigen, legt Girokonto mit IBAN an |
| **POST** | `/api/auth/resend-code` | Bestätigungscode erneut versenden |
| **POST** | `/api/auth/login` | Anmeldung: ohne Code → 428 + Mail, mit Code → angemeldet |
| **POST** | `/api/auth/password/forgot` | Code zum Zurücksetzen des Passworts versenden |
| **POST** | `/api/auth/password/reset` | Neues Passwort mit Bestätigungscode festlegen |
| **GET** | `/api/users/{id}/accounts` | Konten und aktuelle Kontostände abrufen |

---

## Dokumentation

Weitere Informationen zum Projekt und zur Architektur findest du hier:

- 📄 [Anforderungen](docs/anforderungen.md)
- 🗄️ [Datenbankmodell](docs/datenbankmodell.md) (inkl. ER-Diagramm)
- 🧮 [Buchungslogik](docs/buchungslogik.md)