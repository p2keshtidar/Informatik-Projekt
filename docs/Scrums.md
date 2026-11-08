# Scrum & Team-Organisation – PHD Kontor

**Projekt:** Smartphone-Konto – Informatik-Projekt (Team 2)

**Tech Stack:** Spring Boot (Java 21), PostgreSQL, Flutter, Docker, Mailpit

## 1. Scrum-Team & Rollen (Aktuelle Beiträge)

*Hinweis: Die Verantwortlichkeiten spiegeln wider, woran die Teammitglieder bisher aktiv gearbeitet und was sie erreicht haben. 8.11.2026 *

| Teammitglied | Scrum-Rolle | Hauptbeiträge & Verantwortlichkeiten im Projekt | 
| ----- | ----- | ----- | 
| **Pouria Keshtidar** | Product Owner | Definierte und priorisierte die Projektanforderungen (`Anforderungen`) in Zusammenarbeit mit Hedi, pflegt das Product Backlog, überprüft Ergebnisse und hat an der Backend-Entwicklung mitgewirkt. | 
| **Mohamed Hedi Harbaoui** | Scrum Master / Developer | Entwickelte das Frontend, half bei der Backend-Entwicklung, arbeitete mit Pouria bei der Definition der Anforderungen zusammen und moderiert die Scrum-Prozesse als Scrum Master. | 
| **David Eslami Amirabadi** | Developer | Entwickelte das plattformübergreifende Flutter-Frontend (App), half bei der Backend-Entwicklung und arbeitete eng mit Devon am Datenbankmodell und der Buchungslogik zusammen. | 
| **Eric Devon Noah Jacob** | Developer | Entwarf die Datenbank und das ER-Diagramm, implementierte das Datenbankschema und die Buchungslogik (in Zusammenarbeit mit David) und trug maßgeblich zur Backend-Entwicklung bei. | 

## 2. Scrum-Workflow & Artefakte

### Product Backlog

Das Product Backlog wird vom Product Owner (Pouria) verwaltet und leitet sich direkt aus den Projektanforderungen (`Anforderungen.pdf`) ab. Es ist wie folgt unterteilt:

- **Benutzer & Sicherheit (Epic 1):** Registrierung (F01), 2FA-Verifizierung (F02), Passwortrichtlinien (F03), Login/Sperre (F04), Profilverwaltung (F05).

- **Konten & Überweisungen (Epic 2):** Dashboard (F10), Umsatzliste (F11), Überweisungen (F12-F13), Adressbuch (F14).

- **Karten (Epic 3):** Verwaltung der virtuellen Karte (F20), Limits & Online-Zahlungen (F21).

- **Kontoverwaltung (Epic 4):** Kontoarten (F30), Geteilte Konten (F31), Interne Umbuchungen (F32).

- **Benachrichtigungen & Übersicht (Epic 5):** Push-Benachrichtigungen (F40), Automatische Kategorisierung (F41), Monatsübersicht (F42).

- **Sparen & Kredite (Epic 6):** Sparpläne (F50-F53), Kreditrechner & -abwicklung (F60-F62).

- **Admin-/Demo-Tools (Epic 7):** Zeit vorspulen für Präsentationen (F70).

### Sprint Backlog

Ausgewählte Elemente aus dem Product Backlog werden während des Sprint Plannings in das Sprint Backlog verschoben. Die Entwickler ziehen (pull) Aufgaben aus diesem Backlog basierend auf ihren aktuellen Schwerpunkten (z.B. Frontend vs. Backend).

### Entwicklungsprozess & Git-Workflow

Wie in unseren nichtfunktionalen Anforderungen (N06) definiert:

- **Branching:** Jedes Teammitglied arbeitet in seinen eigenen Branches.

- **Integration:** Der Code wird über **Pull Requests (PRs)** integriert.

- **Review:** Der Product Owner / andere Teammitglieder überprüfen die Ergebnisse, bevor sie in den Main-Branch gemergt werden.

- **Testing:** Automatisierte Tests (N05) sind sowohl für die Flutter-App als auch für das Spring-Boot-Backend erforderlich.

## 3. Definition of Done (DoD)

Eine User Story gilt als "Done" (Erledigt), wenn:

- Das Feature im gesamten erforderlichen Stack (Backend API/Flutter UI) implementiert ist.

- Der Code lokal fehlerfrei läuft (mit `docker compose up -d db mailpit`, `./gradlew bootRun` und `flutter run -d chrome`).

- Datenbank-Regeln (z.B. doppelte Buchführung, eindeutige Schlüssel) gemäß dem Datenbankmodell eingehalten werden.

- Automatisierte Tests erfolgreich durchlaufen wurden.

- Der Pull Request überprüft und genehmigt wurde.

- Die vom Product Owner definierten Akzeptanzkriterien erfüllt sind.