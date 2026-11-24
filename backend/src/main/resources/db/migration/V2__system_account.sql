-- PHD Kontor – Startguthaben
-- Jeder Nutzer bekommt nach der E-Mail-Bestätigung 10.000,00 € auf das Girokonto.
-- Die Gegenbuchung läuft auf dieses System-Konto, damit die Summe jeder Buchung 0 bleibt.
-- Der Saldo des System-Kontos wird dadurch negativ (= ausgegebenes Spielgeld).

-- owner_id NULL ist bei type = 'SYSTEM' Pflicht (ck_account_owner), iban bleibt NULL,
-- status und created_at haben einen Default.
INSERT INTO account (owner_id, type, name) VALUES (NULL, 'SYSTEM', 'PHD Kontor Startguthaben');

-- Neuer Buchungstyp OPENING für das Startguthaben
ALTER TABLE booking DROP CONSTRAINT ck_booking_type;
ALTER TABLE booking ADD CONSTRAINT ck_booking_type CHECK (type IN ('TRANSFER', 'INTERNAL', 'CARD', 'SAVINGS_RATE',
                                                                  'SAVINGS_PAYOUT', 'LOAN_PAYOUT', 'LOAN_RATE',
                                                                  'OPENING'));
