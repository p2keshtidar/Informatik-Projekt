# API: Buchungen und Überweisung

Abgestimmt zwischen David (Buchungen abrufen) und Devon (Überweisung).
Alle Endpunkte brauchen `Authorization: Bearer <accessToken>`. Ohne Token → `401`.
Beträge immer in **Cent** (`long`), Zeitpunkte als ISO-8601 in UTC (`2026-12-03T22:30:00Z`).

Fehler kommen immer im gleichen Format:

```json
{
  "timestamp": "2026-12-03T22:30:00Z",
  "status": 403,
  "error": "Forbidden",
  "message": "Das ist nicht dein Konto",
  "path": "/api/accounts/7/bookings"
}
```

---

## 1. Umsätze eines Kontos

`GET /api/accounts/{accountId}/bookings`

| Parameter  | Pflicht | Beispiel     | Bedeutung                                                         |
|------------|---------|--------------|-------------------------------------------------------------------|
| `from`     | nein    | `2026-12-01` | ab diesem Tag (einschließlich, deutsche Zeit)                     |
| `to`       | nein    | `2026-12-31` | bis zu diesem Tag (einschließlich)                                |
| `minCents` | nein    | `1000`       | Betrag ohne Vorzeichen ≥ 10,00 €                                  |
| `maxCents` | nein    | `50000`      | Betrag ohne Vorzeichen ≤ 500,00 €                                 |
| `q`        | nein    | `miete`      | Text in Verwendungszweck **oder** Name der Gegenseite (egal ob groß/klein) |
| `page`     | nein    | `0`          | Seite, beginnt bei 0                                              |
| `size`     | nein    | `20`         | Einträge pro Seite (1–100, Standard 20)                           |

Sortierung: neueste zuerst.

Antwort `200`:

```json
{
  "items": [
    {
      "id": 42,
      "bookedAt": "2026-12-03T22:30:00Z",
      "type": "TRANSFER",
      "description": "Miete Dezember",
      "amountCents": -2500,
      "counterpartyName": "Ben Birnbaum",
      "category": "SONSTIGES"
    },
    {
      "id": 7,
      "bookedAt": "2026-11-24T17:05:12Z",
      "type": "OPENING",
      "description": "Startguthaben",
      "amountCents": 1000000,
      "counterpartyName": "PHD Kontor Startguthaben",
      "category": null
    }
  ],
  "page": 0,
  "size": 20,
  "totalItems": 2,
  "hasMore": false
}
```

- `amountCents` aus Sicht **dieses** Kontos: `+` = Eingang (grün), `−` = Ausgang (rot).
- `counterpartyName`: Vor- und Nachname der Gegenseite, bei System-Konten der Kontoname.
- `category` kann `null` sein.
- `hasMore: true` → die App lädt beim Scrollen `page + 1` nach.

Fehler: `400` ungültiger Filter (z. B. `from` nach `to`, `minCents` > `maxCents`, `size` > 100, Datum nicht lesbar) ·
`403` fremdes Konto · `404` Konto gibt es nicht.

---

## 2. Buchungsdetail

`GET /api/bookings/{bookingId}`

Antwort `200`:

```json
{
  "id": 42,
  "bookedAt": "2026-12-03T22:30:00Z",
  "type": "TRANSFER",
  "description": "Miete Dezember",
  "lines": [
    { "name": "Anna Apfelbaum", "iban": "DE12500105170000000001", "amountCents": -2500, "category": "SONSTIGES", "own": true },
    { "name": "Ben Birnbaum",   "iban": "DE45 **** 0002",         "amountCents": 2500,  "category": "SONSTIGES", "own": false }
  ]
}
```

- `own: true` = Zeile auf einem eigenen Konto. Fremde IBANs kommen nur maskiert.
- Erlaubt, wenn mindestens eine Zeile ein eigenes Konto betrifft (Sender **und** Empfänger dürfen die Buchung sehen).

Fehler: `403` Buchung betrifft keine eigenen Konten · `404` Buchung gibt es nicht.

---

## 3. Überweisung (Devon, Vorschlag – bei Änderungen hier anpassen)

### Empfänger prüfen

`POST /api/transfers/check`

```json
{ "recipient": "ben@example.de" }
```

`recipient` = IBAN, E-Mail oder Telefonnummer. Antwort `200`:

```json
{ "name": "Ben Birnbaum", "maskedIban": "DE45 **** 0002" }
```

Fehler: `404` „Empfänger ist kein PHD-Kontor-Nutzer“ · `400` an sich selbst.

### Überweisen

`POST /api/transfers`

```json
{
  "recipient": "DE45500105170000000002",
  "amountCents": 2500,
  "purpose": "Miete Dezember",
  "idempotencyKey": "6f1c2a9e-3b7d-4c1e-9a55-0d2f8e7b1c44"
}
```

- `purpose` höchstens 140 Zeichen.
- `idempotencyKey` erzeugt die App einmal pro Überweisung (UUID). Wird dieselbe Anfrage noch einmal geschickt
  (z. B. Doppelklick, Netzfehler), entsteht keine zweite Buchung.

Antwort `200`:

```json
{ "bookingId": 42, "newBalanceCents": 997500 }
```

Fehler (`message` direkt in der App anzeigen): `400` Betrag ≤ 0 · `400` an sich selbst · `400` nicht genug Guthaben ·
`400` Tageslimit überschritten · `404` Empfänger unbekannt.

Danach erscheint die Buchung bei beiden in `GET /api/accounts/{id}/bookings` (Sender mit `−`, Empfänger mit `+`).
