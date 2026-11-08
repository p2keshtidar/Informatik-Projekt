-- PHD Kontor – Datenbankschema
-- Beträge immer in Cent (BIGINT), Zeitpunkte als TIMESTAMPTZ.
-- Kontostände werden nicht gespeichert, sondern aus booking_line berechnet.


-- =========================================================
-- Benutzer und Anmeldung
-- =========================================================

CREATE TABLE app_user (
    id                 BIGSERIAL    PRIMARY KEY,
    email              VARCHAR(255) NOT NULL UNIQUE,
    password_hash      VARCHAR(255) NOT NULL,                  -- BCrypt
    first_name         VARCHAR(100) NOT NULL,
    last_name          VARCHAR(100) NOT NULL,
    phone              VARCHAR(30)  NOT NULL UNIQUE,
    birth_date         DATE         NOT NULL,
    role               VARCHAR(10)  NOT NULL DEFAULT 'USER',
    token_version      INT          NOT NULL DEFAULT 0,        -- +1 macht alle Tokens ungültig
    failed_logins      INT          NOT NULL DEFAULT 0,
    locked_until       TIMESTAMPTZ,
    email_verified_at  TIMESTAMPTZ,                            -- NULL = noch nicht bestätigt
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_app_user_role CHECK (role IN ('USER', 'ADMIN'))
);

CREATE TABLE mail_code (
    id          BIGSERIAL    PRIMARY KEY,
    user_id     BIGINT       NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
    purpose     VARCHAR(20)  NOT NULL,
    code_hash   VARCHAR(64)  NOT NULL,                         -- HMAC-SHA-256, nie der Code selbst
    expires_at  TIMESTAMPTZ  NOT NULL,
    attempts    INT          NOT NULL DEFAULT 0,
    used_at     TIMESTAMPTZ,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_mail_code_purpose CHECK (purpose IN ('VERIFY_EMAIL', 'LOGIN', 'PASSWORD_RESET', 'PASSWORD_CHANGE'))
);
CREATE INDEX idx_mail_code_open ON mail_code (user_id, purpose) WHERE used_at IS NULL;

CREATE TABLE refresh_token (
    id          BIGSERIAL    PRIMARY KEY,
    user_id     BIGINT       NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
    token_hash  VARCHAR(64)  NOT NULL UNIQUE,                  -- SHA-256
    expires_at  TIMESTAMPTZ  NOT NULL,
    revoked     BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_refresh_token_user ON refresh_token (user_id);


-- =========================================================
-- Konten, Kontakte, Karte
-- =========================================================

CREATE SEQUENCE account_number_seq START WITH 1000000001;   -- 10-stellige Kontonummer für die IBAN

CREATE TABLE account (
    id             BIGSERIAL     PRIMARY KEY,
    owner_id       BIGINT        REFERENCES app_user (id),   -- NULL nur bei System-Konten
    type           VARCHAR(10)   NOT NULL,
    name           VARCHAR(100)  NOT NULL,
    iban           VARCHAR(34)   UNIQUE,                      -- nur Girokonto
    interest_rate  NUMERIC(6, 3),                             -- nur Tagesgeld (CALL)
    status         VARCHAR(10)   NOT NULL DEFAULT 'ACTIVE',
    created_at     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ck_account_type   CHECK (type IN ('MAIN', 'CALL', 'SAVINGS', 'SUB', 'LOAN', 'SYSTEM')),
    CONSTRAINT ck_account_status CHECK (status IN ('ACTIVE', 'CLOSED')),
    CONSTRAINT ck_account_owner  CHECK ((type = 'SYSTEM') = (owner_id IS NULL))
);
CREATE INDEX idx_account_owner ON account (owner_id);
CREATE UNIQUE INDEX uq_account_one_main ON account (owner_id) WHERE type = 'MAIN';   -- ein Girokonto je Nutzer

-- Mitglieder geteilter Konten (type = 'SUB')
CREATE TABLE account_member (
    account_id  BIGINT       NOT NULL REFERENCES account (id),
    user_id     BIGINT       NOT NULL REFERENCES app_user (id),
    role        VARCHAR(10)  NOT NULL,
    added_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, user_id),
    CONSTRAINT ck_account_member_role CHECK (role IN ('FULL', 'DEPOSIT', 'VIEW'))
);
CREATE INDEX idx_account_member_user ON account_member (user_id);

CREATE TABLE contact (
    id               BIGSERIAL     PRIMARY KEY,
    owner_id         BIGINT        NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
    contact_user_id  BIGINT        NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
    nickname         VARCHAR(100),
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT uq_contact UNIQUE (owner_id, contact_user_id),
    CONSTRAINT ck_contact_self CHECK (owner_id <> contact_user_id)
);

CREATE TABLE card (
    id                 BIGSERIAL     PRIMARY KEY,
    user_id            BIGINT        NOT NULL UNIQUE REFERENCES app_user (id),
    account_id         BIGINT        NOT NULL REFERENCES account (id),   -- Girokonto
    pan_encrypted      VARCHAR(200)  NOT NULL,                           -- AES-256-GCM
    pan_last4          CHAR(4)       NOT NULL,
    cvc_encrypted      VARCHAR(200)  NOT NULL,
    expiry_month       INT           NOT NULL CHECK (expiry_month BETWEEN 1 AND 12),
    expiry_year        INT           NOT NULL,
    status             VARCHAR(10)   NOT NULL DEFAULT 'ACTIVE',
    daily_limit_cents  BIGINT        NOT NULL DEFAULT 100000,
    online_enabled     BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at         TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ck_card_status CHECK (status IN ('ACTIVE', 'LOCKED')),
    CONSTRAINT ck_card_limit  CHECK (daily_limit_cents BETWEEN 0 AND 200000)
);


-- =========================================================
-- Buchungen (doppelte Buchführung)
-- Jede Geldbewegung – Überweisung, Kartenzahlung, Sparrate, Kreditrate,
-- Kreditauszahlung, Umbuchung – ist genau eine booking mit mindestens zwei
-- booking_line. Die Summe der Zeilen einer Buchung ist immer 0.
-- =========================================================

CREATE TABLE booking (
    id               BIGSERIAL     PRIMARY KEY,
    type             VARCHAR(20)   NOT NULL,
    description      VARCHAR(140)  NOT NULL,
    booked_at        TIMESTAMPTZ   NOT NULL,                  -- Simulationszeit
    idempotency_key  VARCHAR(100)  NOT NULL UNIQUE,           -- gleiche Anfrage = gleiche Buchung
    created_by       BIGINT        REFERENCES app_user (id),  -- NULL bei automatischen Buchungen
    CONSTRAINT ck_booking_type CHECK (type IN ('TRANSFER', 'INTERNAL', 'CARD', 'SAVINGS_RATE',
                                               'SAVINGS_PAYOUT', 'LOAN_PAYOUT', 'LOAN_RATE'))
);
CREATE INDEX idx_booking_booked_at ON booking (booked_at);

CREATE TABLE booking_line (
    id            BIGSERIAL    PRIMARY KEY,
    booking_id    BIGINT       NOT NULL REFERENCES booking (id),
    account_id    BIGINT       NOT NULL REFERENCES account (id),
    amount_cents  BIGINT       NOT NULL CHECK (amount_cents <> 0),   -- + Eingang, − Ausgang
    category      VARCHAR(30)
);
CREATE INDEX idx_booking_line_account ON booking_line (account_id);
CREATE INDEX idx_booking_line_booking ON booking_line (booking_id);

-- Prüft am Ende jeder Transaktion: jede Buchung hat mind. 2 Zeilen und Summe 0.
-- Damit kann es keine halbe Überweisung geben, auch nicht bei einem Fehler im Code.
CREATE FUNCTION check_booking_balanced() RETURNS trigger AS $$
DECLARE
    b_id  BIGINT := COALESCE(NEW.booking_id, OLD.booking_id);
    total BIGINT;
    lines INT;
BEGIN
    SELECT COALESCE(SUM(amount_cents), 0), COUNT(*) INTO total, lines
    FROM booking_line WHERE booking_id = b_id;
    IF lines > 0 AND (lines < 2 OR total <> 0) THEN
        RAISE EXCEPTION 'Buchung % ist nicht ausgeglichen (Zeilen %, Summe %)', b_id, lines, total;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER trg_booking_balanced
    AFTER INSERT OR UPDATE OR DELETE ON booking_line
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION check_booking_balanced();


-- =========================================================
-- Sparpläne und Musterdepot
-- =========================================================

CREATE TABLE savings_plan (
    id                  BIGSERIAL     PRIMARY KEY,
    user_id             BIGINT        NOT NULL REFERENCES app_user (id),
    account_id          BIGINT        NOT NULL UNIQUE REFERENCES account (id),   -- eigenes Sparkonto (SAVINGS)
    name                VARCHAR(60)   NOT NULL,
    target_cents        BIGINT        NOT NULL CHECK (target_cents BETWEEN 5000 AND 10000000),
    target_date         DATE          NOT NULL,
    monthly_rate_cents  BIGINT        NOT NULL CHECK (monthly_rate_cents > 0),
    execution_day       INT           NOT NULL CHECK (execution_day BETWEEN 1 AND 28),
    risk_level          VARCHAR(10)   NOT NULL,
    status              VARCHAR(10)   NOT NULL DEFAULT 'ACTIVE',
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ck_savings_plan_risk   CHECK (risk_level IN ('CAUTIOUS', 'BALANCED', 'BOLD')),
    CONSTRAINT ck_savings_plan_status CHECK (status IN ('ACTIVE', 'PAUSED', 'COMPLETED', 'CLOSED'))
);
CREATE INDEX idx_savings_plan_user ON savings_plan (user_id);

-- Eine Zeile je Plan und Monat: verhindert doppelte Sparraten,
-- auch wenn der Tageslauf beim Vorspulen mehrfach läuft.
CREATE TABLE savings_execution (
    plan_id      BIGINT       NOT NULL REFERENCES savings_plan (id),
    period       CHAR(7)      NOT NULL,                       -- JJJJ-MM
    status       VARCHAR(10)  NOT NULL,                       -- EXECUTED oder SKIPPED (keine Deckung)
    booking_id   BIGINT       UNIQUE REFERENCES booking (id),
    executed_at  TIMESTAMPTZ  NOT NULL,
    PRIMARY KEY (plan_id, period),
    CONSTRAINT ck_savings_execution CHECK ((status = 'EXECUTED') = (booking_id IS NOT NULL))
);

CREATE TABLE depot_position (
    plan_id         BIGINT         NOT NULL REFERENCES savings_plan (id),
    fund_code       VARCHAR(20)    NOT NULL,                  -- zwei fiktive Fonds
    units           NUMERIC(18,6)  NOT NULL DEFAULT 0 CHECK (units >= 0),
    invested_cents  BIGINT         NOT NULL DEFAULT 0,
    PRIMARY KEY (plan_id, fund_code)
);


-- =========================================================
-- Kredite
-- =========================================================

CREATE TABLE loan (
    id                  BIGSERIAL     PRIMARY KEY,
    user_id             BIGINT        NOT NULL REFERENCES app_user (id),
    account_id          BIGINT        NOT NULL UNIQUE REFERENCES account (id),   -- Kreditkonto (LOAN)
    bank_code           VARCHAR(20)   NOT NULL,                                  -- eine von vier fiktiven Banken
    purpose             VARCHAR(10)   NOT NULL,
    principal_cents     BIGINT        NOT NULL CHECK (principal_cents > 0),
    equity_cents        BIGINT        NOT NULL DEFAULT 0 CHECK (equity_cents >= 0),
    interest_rate       NUMERIC(6,4)  NOT NULL,                                  -- % p. a.
    term_months         INT           NOT NULL CHECK (term_months BETWEEN 6 AND 360),
    monthly_rate_cents  BIGINT        NOT NULL CHECK (monthly_rate_cents > 0),
    due_day             INT           NOT NULL CHECK (due_day BETWEEN 1 AND 28),
    status              VARCHAR(10)   NOT NULL DEFAULT 'CONTRACTED',
    payout_booking_id   BIGINT        UNIQUE REFERENCES booking (id),            -- Auszahlung genau einmal
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ck_loan_purpose CHECK (purpose IN ('CAR', 'HOME', 'OTHER')),
    CONSTRAINT ck_loan_status  CHECK (status IN ('CONTRACTED', 'ACTIVE', 'PAID_OFF'))
);
CREATE INDEX idx_loan_user ON loan (user_id);

-- Tilgungsplan: eine Zeile je Rate. booking_id wird gesetzt, sobald die Rate gebucht ist.
-- PRIMARY KEY (loan_id, number) + UNIQUE booking_id: jede Rate höchstens einmal.
CREATE TABLE loan_installment (
    loan_id          BIGINT       NOT NULL REFERENCES loan (id),
    number           INT          NOT NULL CHECK (number >= 1),
    due_date         DATE         NOT NULL,
    principal_cents  BIGINT       NOT NULL CHECK (principal_cents >= 0),
    interest_cents   BIGINT       NOT NULL CHECK (interest_cents >= 0),
    booking_id       BIGINT       UNIQUE REFERENCES booking (id),   -- NULL = noch offen
    paid_at          TIMESTAMPTZ,
    PRIMARY KEY (loan_id, number),
    CONSTRAINT ck_loan_installment_paid CHECK ((booking_id IS NULL) = (paid_at IS NULL))
);
CREATE INDEX idx_loan_installment_open ON loan_installment (due_date) WHERE booking_id IS NULL;


-- =========================================================
-- Benachrichtigungen
-- =========================================================

CREATE TABLE notification (
    id          BIGSERIAL     PRIMARY KEY,
    user_id     BIGINT        NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
    type        VARCHAR(30)   NOT NULL,
    title       VARCHAR(100)  NOT NULL,
    body        VARCHAR(300)  NOT NULL,
    booking_id  BIGINT        REFERENCES booking (id),
    is_read     BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX idx_notification_user ON notification (user_id, created_at DESC);


-- =========================================================
-- Simulationszeit und Tageslauf
-- =========================================================

CREATE TABLE sim_clock (
    id           INT  PRIMARY KEY CHECK (id = 1),             -- genau eine Zeile
    offset_days  INT  NOT NULL DEFAULT 0 CHECK (offset_days >= 0)
);

-- Jeder Job läuft je Simulationstag höchstens einmal (z. B. SAVINGS_RATES, LOAN_RATES).
-- Bricht ein Tag ab, laufen beim nächsten Mal nur die fehlenden Jobs.
CREATE TABLE job_run (
    run_date     DATE         NOT NULL,
    job          VARCHAR(30)  NOT NULL,
    finished_at  TIMESTAMPTZ  NOT NULL,
    PRIMARY KEY (run_date, job)
);


-- =========================================================
-- Startdaten
-- =========================================================

INSERT INTO sim_clock (id, offset_days) VALUES (1, 0);

-- Gegenkonten der Bank
INSERT INTO account (owner_id, type, name) VALUES
    (NULL, 'SYSTEM', 'ZINSEN'),      -- Zinsanteil der Kreditraten, Habenzinsen
    (NULL, 'SYSTEM', 'HAENDLER'),    -- Kartenzahlungen
    (NULL, 'SYSTEM', 'DEPOT');       -- Fondskäufe der Sparpläne
