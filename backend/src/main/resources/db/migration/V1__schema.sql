-- PHD Kontor – Datenbankschema
-- Alle Beträge in Cent (BIGINT), alle Zeitpunkte als TIMESTAMPTZ.


-- =========================================================
-- Benutzer und Anmeldung
-- =========================================================

CREATE TABLE app_user (
    id                       BIGSERIAL    PRIMARY KEY,
    email                    VARCHAR(255) NOT NULL UNIQUE,
    password_hash            VARCHAR(100) NOT NULL,
    first_name               VARCHAR(100) NOT NULL,
    last_name                VARCHAR(100) NOT NULL,
    phone                    VARCHAR(30)  NOT NULL UNIQUE,
    birth_date               DATE         NOT NULL,
    role                     VARCHAR(20)  NOT NULL DEFAULT 'USER',
    language                 VARCHAR(2),                          -- 'de' / 'en', NULL = Gerätesprache
    token_version            INT          NOT NULL DEFAULT 0,     -- +1 beim Abmelden -> alte Tokens ungültig
    failed_logins            INT          NOT NULL DEFAULT 0,
    locked_until             TIMESTAMPTZ,
    email_verified_at        TIMESTAMPTZ,                         -- Anmeldung erst nach Bestätigung
    health_score_consent_at  TIMESTAMPTZ,                         -- Einwilligung Finanz-Check
    created_at               TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT app_user_language_check CHECK (language IS NULL OR language IN ('de', 'en'))
);

CREATE TABLE refresh_token (
    id          BIGSERIAL   PRIMARY KEY,
    user_id     BIGINT      NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
    token_hash  VARCHAR(64) NOT NULL UNIQUE,   -- nur SHA-256, nie das Token selbst
    expires_at  TIMESTAMPTZ NOT NULL,
    revoked     BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_refresh_token_user ON refresh_token (user_id);

-- Codes per Mail: Registrierung, 2FA beim Login, Passwort ändern/vergessen
CREATE TABLE mail_code (
    id          BIGSERIAL   PRIMARY KEY,
    user_id     BIGINT      NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
    purpose     VARCHAR(20) NOT NULL,          -- VERIFY_EMAIL, LOGIN, PASSWORD_CHANGE, PASSWORD_RESET
    code_hash   VARCHAR(64) NOT NULL,          -- HMAC-SHA-256 des Codes
    expires_at  TIMESTAMPTZ NOT NULL,
    attempts    INT         NOT NULL DEFAULT 0,
    used_at     TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_mail_code_user ON mail_code (user_id, purpose, created_at DESC);

CREATE TABLE audit_log (
    id          BIGSERIAL    PRIMARY KEY,
    user_id     BIGINT,
    action      VARCHAR(60)  NOT NULL,
    target      VARCHAR(100),
    details     VARCHAR(300),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_audit_log_user ON audit_log (user_id, created_at);


-- =========================================================
-- Konten und Buchungen (doppelte Buchführung)
-- =========================================================

CREATE SEQUENCE account_number_seq START WITH 1000000001;   -- 10-stellige Kontonummer für die IBAN

CREATE TABLE account (
    id               BIGSERIAL    PRIMARY KEY,
    owner_id         BIGINT       REFERENCES app_user (id),   -- NULL = System-Konto
    type             VARCHAR(20)  NOT NULL,                   -- MAIN, SUB (geteilt), CALL, SAVINGS, LOAN, SYSTEM
    name             VARCHAR(100) NOT NULL,
    icon             VARCHAR(50),
    iban             VARCHAR(34)  UNIQUE,
    status           VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',
    purpose          VARCHAR(20),
    target_cents     BIGINT,
    target_date      DATE,
    goal_reached_at  TIMESTAMPTZ,
    interest_rate    NUMERIC(6, 3),                           -- nur Tagesgeld
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_account_target CHECK (target_cents IS NULL OR target_cents > 0)
);
CREATE INDEX idx_account_owner ON account (owner_id);

-- Mitglieder geteilter Konten
CREATE TABLE account_member (
    account_id  BIGINT      NOT NULL REFERENCES account (id),
    user_id     BIGINT      NOT NULL REFERENCES app_user (id),
    role        VARCHAR(10) NOT NULL DEFAULT 'FULL',   -- FULL, DEPOSIT (nur einzahlen), VIEW
    added_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, user_id),
    CONSTRAINT ck_account_member_role CHECK (role IN ('FULL', 'DEPOSIT', 'VIEW'))
);
CREATE INDEX idx_account_member_user ON account_member (user_id);

CREATE TABLE booking (
    id               BIGSERIAL    PRIMARY KEY,
    type             VARCHAR(30)  NOT NULL,
    description      VARCHAR(140) NOT NULL,
    booked_at        TIMESTAMPTZ  NOT NULL,
    idempotency_key  VARCHAR(100) UNIQUE,
    created_by       BIGINT       REFERENCES app_user (id)
);
CREATE INDEX idx_booking_booked_at ON booking (booked_at);
CREATE INDEX idx_booking_type ON booking (type);

-- Summe aller Zeilen einer Buchung = 0
CREATE TABLE booking_line (
    id            BIGSERIAL   PRIMARY KEY,
    booking_id    BIGINT      NOT NULL REFERENCES booking (id),
    account_id    BIGINT      NOT NULL REFERENCES account (id),
    amount_cents  BIGINT      NOT NULL CHECK (amount_cents <> 0),
    category      VARCHAR(30)
);
CREATE INDEX idx_booking_line_account ON booking_line (account_id);
CREATE INDEX idx_booking_line_booking ON booking_line (booking_id);

CREATE TABLE booking_note (
    booking_id  BIGINT       NOT NULL REFERENCES booking (id),
    account_id  BIGINT       NOT NULL REFERENCES account (id),
    user_id     BIGINT       NOT NULL REFERENCES app_user (id),
    note        VARCHAR(500) NOT NULL,
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    PRIMARY KEY (booking_id, account_id, user_id)
);

CREATE TABLE duplicate_dismissal (
    user_id     BIGINT       NOT NULL REFERENCES app_user (id),
    pair_key    VARCHAR(120) NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, pair_key)
);

CREATE TABLE contact (
    id               BIGSERIAL    PRIMARY KEY,
    owner_id         BIGINT       NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
    contact_user_id  BIGINT       NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
    nickname         VARCHAR(100),
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_contact UNIQUE (owner_id, contact_user_id)
);

CREATE TABLE standing_order (
    id                   BIGSERIAL    PRIMARY KEY,
    user_id              BIGINT       NOT NULL REFERENCES app_user (id),
    recipient_iban       VARCHAR(34)  NOT NULL,
    recipient_name       VARCHAR(120) NOT NULL,
    amount_cents         BIGINT       NOT NULL CHECK (amount_cents > 0),
    reference            VARCHAR(140) NOT NULL,
    execution_day        INT          NOT NULL CHECK (execution_day BETWEEN 1 AND 28),
    interval_months      INT          NOT NULL CHECK (interval_months IN (1, 3, 6, 12)),
    start_date           DATE         NOT NULL,
    end_date             DATE,
    status               VARCHAR(10)  NOT NULL DEFAULT 'ACTIVE',   -- ACTIVE, PAUSED, ENDED
    last_executed_month  VARCHAR(7),
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_standing_order_user ON standing_order (user_id);
CREATE INDEX idx_standing_order_day ON standing_order (status, execution_day);

-- Eigene Einnahmen/Ausgaben, einmalig (0) oder regelmäßig
CREATE TABLE entry (
    id               BIGSERIAL    PRIMARY KEY,
    user_id          BIGINT       NOT NULL REFERENCES app_user (id),
    kind             VARCHAR(10)  NOT NULL CHECK (kind IN ('INCOME', 'EXPENSE')),
    title            VARCHAR(60)  NOT NULL,
    category         VARCHAR(30)  NOT NULL,
    amount_cents     BIGINT       NOT NULL CHECK (amount_cents > 0),
    interval_months  INT          NOT NULL CHECK (interval_months IN (0, 1, 3, 6, 12)),
    start_date       DATE         NOT NULL,
    end_date         DATE,
    status           VARCHAR(10)  NOT NULL DEFAULT 'ACTIVE',   -- ACTIVE, PAUSED, DONE, DELETED
    last_booked_date DATE,
    booked_count     INT          NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_entry_user ON entry (user_id);
CREATE INDEX idx_entry_status ON entry (status);


-- =========================================================
-- Karten und Benachrichtigungen
-- =========================================================

CREATE TABLE card (
    id                 BIGSERIAL    PRIMARY KEY,
    user_id            BIGINT       NOT NULL UNIQUE REFERENCES app_user (id),
    account_id         BIGINT       NOT NULL REFERENCES account (id),
    pan_encrypted      VARCHAR(200) NOT NULL,   -- AES-GCM
    pan_last4          VARCHAR(4)   NOT NULL,
    cvc_encrypted      VARCHAR(200) NOT NULL,
    expiry_month       INT          NOT NULL,
    expiry_year        INT          NOT NULL,
    status             VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',   -- ACTIVE, LOCKED
    daily_limit_cents  BIGINT       NOT NULL DEFAULT 100000,
    online_enabled     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Karten für geteilte Konten (nur letzte 4 Ziffern)
CREATE TABLE subaccount_card (
    id                 BIGSERIAL   PRIMARY KEY,
    account_id         BIGINT      NOT NULL UNIQUE REFERENCES account (id) ON DELETE CASCADE,
    created_by         BIGINT      NOT NULL REFERENCES app_user (id),
    last4              VARCHAR(4)  NOT NULL,
    status             VARCHAR(10) NOT NULL CHECK (status IN ('ACTIVE', 'LOCKED')),
    daily_limit_cents  BIGINT      NOT NULL CHECK (daily_limit_cents BETWEEN 100 AND 200000),
    created_at         TIMESTAMPTZ NOT NULL
);

CREATE TABLE credit_card (
    id                   BIGSERIAL     PRIMARY KEY,
    user_id              BIGINT        NOT NULL REFERENCES app_user (id),
    masked_number        VARCHAR(19)   NOT NULL,
    limit_cents          BIGINT        NOT NULL CHECK (limit_cents > 0),
    foreign_fee_percent  NUMERIC(4, 2) NOT NULL,
    status               VARCHAR(10)   NOT NULL DEFAULT 'ACTIVE',   -- ACTIVE, BLOCKED, CLOSED
    created_at           TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_credit_card_open ON credit_card (user_id) WHERE status <> 'CLOSED';

CREATE TABLE credit_card_statement (
    id           BIGSERIAL   PRIMARY KEY,
    card_id      BIGINT      NOT NULL REFERENCES credit_card (id),
    period       VARCHAR(7)  NOT NULL,          -- JJJJ-MM
    total_cents  BIGINT      NOT NULL,
    fee_cents    BIGINT      NOT NULL,
    status       VARCHAR(10) NOT NULL,          -- OPEN, PAID
    booking_id   BIGINT      REFERENCES booking (id),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    paid_at      TIMESTAMPTZ,
    CONSTRAINT uq_credit_card_statement UNIQUE (card_id, period)
);
CREATE INDEX idx_credit_card_statement_open ON credit_card_statement (card_id) WHERE status = 'OPEN';

CREATE TABLE credit_card_tx (
    id                BIGSERIAL    PRIMARY KEY,
    card_id           BIGINT       NOT NULL REFERENCES credit_card (id),
    booked_at         TIMESTAMPTZ  NOT NULL,
    merchant          VARCHAR(100) NOT NULL,
    amount_cents      BIGINT       NOT NULL CHECK (amount_cents > 0),
    fee_cents         BIGINT       NOT NULL DEFAULT 0,
    foreign_currency  BOOLEAN      NOT NULL DEFAULT FALSE,
    statement_id      BIGINT       REFERENCES credit_card_statement (id)
);
CREATE INDEX idx_credit_card_tx_card ON credit_card_tx (card_id, statement_id);

CREATE TABLE notification (
    id          BIGSERIAL    PRIMARY KEY,
    user_id     BIGINT       NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
    type        VARCHAR(30)  NOT NULL,
    title       VARCHAR(100) NOT NULL,
    body        VARCHAR(300) NOT NULL,
    booking_id  BIGINT       REFERENCES booking (id),
    is_read     BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_notification_user ON notification (user_id, created_at DESC);
CREATE INDEX idx_notification_unread ON notification (user_id) WHERE NOT is_read;


-- =========================================================
-- Sparen, Investieren, Budgets
-- =========================================================

CREATE TABLE savings_plan (
    id                   BIGSERIAL    PRIMARY KEY,
    user_id              BIGINT       NOT NULL REFERENCES app_user (id),
    account_id           BIGINT       REFERENCES account (id),
    type                 VARCHAR(10)  NOT NULL,                  -- GOAL, INVEST
    name                 VARCHAR(60)  NOT NULL,
    icon                 VARCHAR(30),
    target_cents         BIGINT,
    target_date          DATE,
    monthly_rate_cents   BIGINT       NOT NULL,
    execution_day        INT          NOT NULL,
    risk_level           VARCHAR(12)  NOT NULL,
    status               VARCHAR(12)  NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, PAUSED, COMPLETED, CLOSED
    deposited_cents      BIGINT       NOT NULL DEFAULT 0,
    last_executed_month  VARCHAR(7),
    reminder_days        INT          NOT NULL DEFAULT 3,        -- 0 = keine Erinnerung
    last_reminded_month  VARCHAR(7),
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_savings_plan_user ON savings_plan (user_id);

CREATE TABLE depot_position (
    id              BIGSERIAL     PRIMARY KEY,
    plan_id         BIGINT        NOT NULL REFERENCES savings_plan (id),
    fund_code       VARCHAR(20)   NOT NULL,
    units           NUMERIC(18,6) NOT NULL DEFAULT 0,
    invested_cents  BIGINT        NOT NULL DEFAULT 0,
    CONSTRAINT uq_depot_position UNIQUE (plan_id, fund_code)
);

CREATE TABLE plan_snapshot (
    id               BIGSERIAL PRIMARY KEY,
    plan_id          BIGINT    NOT NULL REFERENCES savings_plan (id),
    snapshot_date    DATE      NOT NULL,
    value_cents      BIGINT    NOT NULL,
    deposited_cents  BIGINT    NOT NULL
);
CREATE INDEX idx_plan_snapshot_plan ON plan_snapshot (plan_id, snapshot_date);

CREATE TABLE budget (
    id             BIGSERIAL   PRIMARY KEY,
    user_id        BIGINT      NOT NULL REFERENCES app_user (id),
    category       VARCHAR(30) NOT NULL,
    monthly_cents  BIGINT      NOT NULL CHECK (monthly_cents > 0),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_budget UNIQUE (user_id, category)
);

CREATE TABLE budget_alert (
    user_id     BIGINT      NOT NULL REFERENCES app_user (id),
    category    VARCHAR(30) NOT NULL,
    month       VARCHAR(7)  NOT NULL,
    level       INT         NOT NULL,          -- 80 oder 100 (%)
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, category, month, level)
);


-- =========================================================
-- Kredite
-- =========================================================

CREATE TABLE loan (
    id                  BIGSERIAL    PRIMARY KEY,
    user_id             BIGINT       NOT NULL REFERENCES app_user (id),
    account_id          BIGINT       NOT NULL REFERENCES account (id),   -- Kreditkonto
    application_id      BIGINT,                                          -- FK unten (zyklisch)
    bank_code           VARCHAR(20)  NOT NULL,
    bank_name           VARCHAR(60)  NOT NULL,
    purpose             VARCHAR(20)  NOT NULL,
    principal_cents     BIGINT       NOT NULL,
    equity_cents        BIGINT       NOT NULL DEFAULT 0,
    interest_rate       NUMERIC(6,4) NOT NULL,                           -- % p. a.
    effective_rate      NUMERIC(6,4),
    term_months         INT          NOT NULL,
    monthly_rate_cents  BIGINT       NOT NULL,
    start_date          DATE         NOT NULL,
    next_due_date       DATE,                                            -- erst ab Auszahlung
    paid_installments   INT          NOT NULL DEFAULT 0,
    status              VARCHAR(12)  NOT NULL DEFAULT 'ACTIVE',          -- CONTRACTED, ACTIVE, PAID_OFF
    contracted_at       TIMESTAMPTZ,
    paid_out_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_loan_user ON loan (user_id);

CREATE TABLE loan_application (
    id                  BIGSERIAL    PRIMARY KEY,
    user_id             BIGINT       NOT NULL REFERENCES app_user (id),
    provider            VARCHAR(20)  NOT NULL,
    bank_code           VARCHAR(20)  NOT NULL,
    bank_name           VARCHAR(60)  NOT NULL,
    purpose             VARCHAR(20)  NOT NULL,
    principal_cents     BIGINT       NOT NULL CHECK (principal_cents > 0),
    equity_cents        BIGINT       NOT NULL DEFAULT 0,
    term_months         INT          NOT NULL CHECK (term_months > 0),
    credit_class        VARCHAR(10)  NOT NULL,
    interest_rate       NUMERIC(6,4),
    effective_rate      NUMERIC(6,4),
    monthly_rate_cents  BIGINT,
    total_cents         BIGINT,
    status              VARCHAR(12)  NOT NULL,
    decision_reason     VARCHAR(300),
    valid_until         DATE,
    loan_id             BIGINT       REFERENCES loan (id),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    decided_at          TIMESTAMPTZ,
    accepted_at         TIMESTAMPTZ,
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_loan_application_status
        CHECK (status IN ('APPROVED', 'DECLINED', 'ACCEPTED', 'WITHDRAWN', 'EXPIRED')),
    CONSTRAINT ck_loan_application_class CHECK (credit_class IN ('SEHR_GUT', 'GUT', 'MITTEL', 'SCHWACH'))
);
CREATE INDEX idx_loan_application_user ON loan_application (user_id);
CREATE INDEX idx_loan_application_status ON loan_application (status, valid_until);

ALTER TABLE loan
    ADD CONSTRAINT loan_application_id_fkey FOREIGN KEY (application_id) REFERENCES loan_application (id);

CREATE TABLE loan_extra_payment (
    id                 BIGSERIAL   PRIMARY KEY,
    loan_id            BIGINT      NOT NULL REFERENCES loan (id),
    booking_id         BIGINT      NOT NULL REFERENCES booking (id),
    amount_cents       BIGINT      NOT NULL CHECK (amount_cents > 0),
    after_installment  INT         NOT NULL,   -- 0 = vor der ersten Rate
    paid_on            DATE        NOT NULL,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_loan_extra_payment_loan ON loan_extra_payment (loan_id);

-- Referenzzinsen (Bundesbank)
CREATE TABLE market_rate (
    series_key    VARCHAR(40)  PRIMARY KEY,
    period        VARCHAR(7)   NOT NULL,
    rate_percent  NUMERIC(6,3) NOT NULL,
    fetched_at    TIMESTAMPTZ  NOT NULL
);


-- =========================================================
-- Externe Banken (Open Banking) und CSV-Import
-- =========================================================

CREATE TABLE bank_connection (
    id                  BIGSERIAL    PRIMARY KEY,
    user_id             BIGINT       NOT NULL REFERENCES app_user (id),
    provider            VARCHAR(30)  NOT NULL,
    institution_id      VARCHAR(100) NOT NULL,
    institution_name    VARCHAR(150) NOT NULL,
    status              VARCHAR(20)  NOT NULL,
    consent_ref_enc     TEXT,                         -- verschlüsselt, nach Widerruf NULL
    consent_expires_at  TIMESTAMPTZ,
    expiry_notified     BOOLEAN      NOT NULL DEFAULT FALSE,
    last_sync_at        TIMESTAMPTZ,
    last_sync_status    VARCHAR(20),
    last_error          VARCHAR(200),
    failed_syncs        INT          NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    revoked_at          TIMESTAMPTZ,
    CONSTRAINT ck_bank_connection_status
        CHECK (status IN ('PENDING', 'ACTIVE', 'EXPIRED', 'REVOKED', 'REJECTED', 'ERROR'))
);
CREATE INDEX idx_bank_connection_user ON bank_connection (user_id);
CREATE INDEX idx_bank_connection_status ON bank_connection (status);

CREATE TABLE external_account (
    id             BIGSERIAL    PRIMARY KEY,
    connection_id  BIGINT       NOT NULL REFERENCES bank_connection (id) ON DELETE CASCADE,
    user_id        BIGINT       NOT NULL REFERENCES app_user (id),
    external_id    VARCHAR(100) NOT NULL,
    iban_masked    VARCHAR(34),
    iban_hash      VARCHAR(64),
    name           VARCHAR(150) NOT NULL,
    currency       VARCHAR(3)   NOT NULL DEFAULT 'EUR',
    balance_cents  BIGINT,
    balance_type   VARCHAR(40),
    balance_at     TIMESTAMPTZ,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_external_account UNIQUE (connection_id, external_id)
);
CREATE INDEX idx_external_account_user ON external_account (user_id);

CREATE TABLE external_transaction (
    id                   BIGSERIAL    PRIMARY KEY,
    external_account_id  BIGINT       NOT NULL REFERENCES external_account (id) ON DELETE CASCADE,
    user_id              BIGINT       NOT NULL REFERENCES app_user (id),
    external_id          VARCHAR(160) NOT NULL,
    status               VARCHAR(20)  NOT NULL,
    booking_date         DATE         NOT NULL,
    value_date           DATE,
    amount_cents         BIGINT       NOT NULL,
    currency             VARCHAR(3)   NOT NULL,
    counterparty         VARCHAR(200),
    remittance           VARCHAR(500),
    bank_code            VARCHAR(60),
    is_reversal          BOOLEAN      NOT NULL DEFAULT FALSE,
    related_id           BIGINT       REFERENCES external_transaction (id) ON DELETE SET NULL,
    auto_category        VARCHAR(30)  NOT NULL,
    raw_enc              TEXT         NOT NULL,
    first_seen_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_external_transaction UNIQUE (external_account_id, external_id),
    CONSTRAINT ck_external_transaction_status
        CHECK (status IN ('PENDING', 'BOOKED', 'CANCELLED', 'SUPERSEDED', 'REVERSED'))
);
CREATE INDEX idx_external_transaction_user_date ON external_transaction (user_id, booking_date);
CREATE INDEX idx_external_transaction_account_status ON external_transaction (external_account_id, status);

-- Änderungen des Nutzers, getrennt von den Originaldaten der Bank
CREATE TABLE external_transaction_edit (
    transaction_id  BIGINT       PRIMARY KEY REFERENCES external_transaction (id) ON DELETE CASCADE,
    user_id         BIGINT       NOT NULL REFERENCES app_user (id),
    category        VARCHAR(30),
    note            VARCHAR(500),
    tags            VARCHAR(300),
    excluded        BOOLEAN      NOT NULL DEFAULT FALSE,
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE csv_import (
    id             BIGSERIAL    PRIMARY KEY,
    user_id        BIGINT       NOT NULL REFERENCES app_user (id),
    file_name      VARCHAR(200) NOT NULL,
    format         VARCHAR(60)  NOT NULL,
    rows_imported  INT          NOT NULL,
    rows_skipped   INT          NOT NULL,
    first_date     DATE,
    last_date      DATE,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_csv_import_user ON csv_import (user_id);

CREATE TABLE imported_transaction (
    id            BIGSERIAL    PRIMARY KEY,
    import_id     BIGINT       NOT NULL REFERENCES csv_import (id) ON DELETE CASCADE,
    user_id       BIGINT       NOT NULL REFERENCES app_user (id),
    booked_on     DATE         NOT NULL,
    amount_cents  BIGINT       NOT NULL,
    counterparty  VARCHAR(200),
    description   VARCHAR(400),
    category      VARCHAR(30)  NOT NULL,
    dedup_key     VARCHAR(64)  NOT NULL,
    CONSTRAINT uq_imported_transaction UNIQUE (user_id, dedup_key)
);
CREATE INDEX idx_imported_transaction_user_date ON imported_transaction (user_id, booked_on);


-- =========================================================
-- Sparregeln (automatische Zuweisungen)
-- =========================================================

CREATE TABLE allocation_rule (
    id                  BIGSERIAL    PRIMARY KEY,
    user_id             BIGINT       NOT NULL REFERENCES app_user (id),
    target_account_id   BIGINT       NOT NULL REFERENCES account (id),
    source_type         VARCHAR(12)  NOT NULL,
    source_account_id   BIGINT       REFERENCES account (id),
    source_external_id  BIGINT       REFERENCES external_account (id) ON DELETE SET NULL,
    amount_cents        BIGINT       NOT NULL CHECK (amount_cents > 0),
    interval_unit       VARCHAR(10)  NOT NULL,
    start_date          DATE         NOT NULL,
    end_date            DATE,
    next_date           DATE,
    status              VARCHAR(10)  NOT NULL DEFAULT 'ACTIVE',
    status_reason       VARCHAR(200),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_alloc_rule_source CHECK (source_type IN ('PROJEKTBANK', 'EXTERNAL')),
    CONSTRAINT ck_alloc_rule_interval CHECK (interval_unit IN ('WEEKLY', 'BIWEEKLY', 'MONTHLY', 'QUARTERLY')),
    CONSTRAINT ck_alloc_rule_status CHECK (status IN ('ACTIVE', 'PAUSED', 'ENDED')),
    CONSTRAINT ck_alloc_rule_end CHECK (end_date IS NULL OR end_date >= start_date)
);
CREATE INDEX idx_alloc_rule_user ON allocation_rule (user_id);
CREATE INDEX idx_alloc_rule_target ON allocation_rule (target_account_id);
CREATE INDEX idx_alloc_rule_due ON allocation_rule (status, next_date);

CREATE TABLE allocation_run (
    id                  BIGSERIAL    PRIMARY KEY,
    rule_id             BIGINT       REFERENCES allocation_rule (id),   -- NULL = manuell
    user_id             BIGINT       NOT NULL REFERENCES app_user (id),
    target_account_id   BIGINT       NOT NULL REFERENCES account (id),
    source_type         VARCHAR(12)  NOT NULL,
    source_external_id  BIGINT       REFERENCES external_account (id) ON DELETE SET NULL,
    kind                VARCHAR(10)  NOT NULL,
    due_date            DATE         NOT NULL,
    amount_cents        BIGINT       NOT NULL CHECK (amount_cents > 0),
    status              VARCHAR(10)  NOT NULL,
    attempts            INT          NOT NULL DEFAULT 0,
    next_attempt        DATE,
    reason              VARCHAR(200),
    booking_id          BIGINT       REFERENCES booking (id),
    manual              BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_alloc_run UNIQUE (rule_id, due_date),
    CONSTRAINT ck_alloc_run_kind CHECK (kind IN ('TRANSFER', 'EARMARK', 'RELEASE')),
    CONSTRAINT ck_alloc_run_status CHECK (status IN ('PENDING', 'COMPLETED', 'RETRYING', 'FAILED', 'CANCELLED'))
);
CREATE INDEX idx_alloc_run_target ON allocation_run (target_account_id);
CREATE INDEX idx_alloc_run_user ON allocation_run (user_id);
CREATE INDEX idx_alloc_run_retry ON allocation_run (status, next_attempt);
CREATE INDEX idx_alloc_run_source ON allocation_run (source_external_id);


-- =========================================================
-- Marktplatz
-- =========================================================

CREATE TABLE market_favorite (
    user_id     BIGINT      NOT NULL REFERENCES app_user (id),
    product_id  VARCHAR(60) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, product_id)
);

CREATE TABLE market_application (
    id             BIGSERIAL    PRIMARY KEY,
    user_id        BIGINT       NOT NULL REFERENCES app_user (id),
    product_id     VARCHAR(60)  NOT NULL,
    product_name   VARCHAR(120) NOT NULL,
    provider_name  VARCHAR(120) NOT NULL,
    category       VARCHAR(20)  NOT NULL,
    status         VARCHAR(20)  NOT NULL,
    status_reason  VARCHAR(300),
    note           VARCHAR(500),
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    decided_at     TIMESTAMPTZ,
    CONSTRAINT ck_market_application_status
        CHECK (status IN ('DOCUMENTS_MISSING', 'SUBMITTED', 'APPROVED', 'DECLINED', 'WITHDRAWN'))
);
CREATE INDEX idx_market_application_user ON market_application (user_id);

CREATE TABLE market_application_document (
    application_id  BIGINT       NOT NULL REFERENCES market_application (id) ON DELETE CASCADE,
    doc_key         VARCHAR(40)  NOT NULL,
    label           VARCHAR(120) NOT NULL,
    provided_at     TIMESTAMPTZ,
    PRIMARY KEY (application_id, doc_key)
);


-- =========================================================
-- Gemeinsame Ausgaben (Gruppen)
-- =========================================================

CREATE TABLE expense_group (
    id          BIGSERIAL   PRIMARY KEY,
    owner_id    BIGINT      NOT NULL REFERENCES app_user (id),
    name        VARCHAR(60) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL
);

CREATE TABLE expense_group_member (
    group_id   BIGINT      NOT NULL REFERENCES expense_group (id) ON DELETE CASCADE,
    user_id    BIGINT      NOT NULL REFERENCES app_user (id),
    joined_at  TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (group_id, user_id)
);
CREATE INDEX idx_expense_group_member_user ON expense_group_member (user_id);

CREATE TABLE group_expense (
    id            BIGSERIAL    PRIMARY KEY,
    group_id      BIGINT       NOT NULL REFERENCES expense_group (id) ON DELETE CASCADE,
    payer_id      BIGINT       NOT NULL REFERENCES app_user (id),
    amount_cents  BIGINT       NOT NULL CHECK (amount_cents > 0),
    description   VARCHAR(100) NOT NULL,
    expense_date  DATE         NOT NULL,
    created_by    BIGINT       NOT NULL REFERENCES app_user (id),
    created_at    TIMESTAMPTZ  NOT NULL
);
CREATE INDEX idx_group_expense_group ON group_expense (group_id, expense_date DESC);

CREATE TABLE group_expense_share (
    expense_id   BIGINT NOT NULL REFERENCES group_expense (id) ON DELETE CASCADE,
    user_id      BIGINT NOT NULL REFERENCES app_user (id),
    share_cents  BIGINT NOT NULL CHECK (share_cents >= 0),
    PRIMARY KEY (expense_id, user_id)
);

CREATE TABLE group_settlement (
    id            BIGSERIAL   PRIMARY KEY,
    group_id      BIGINT      NOT NULL REFERENCES expense_group (id) ON DELETE CASCADE,
    from_user     BIGINT      NOT NULL REFERENCES app_user (id),
    to_user       BIGINT      NOT NULL REFERENCES app_user (id),
    amount_cents  BIGINT      NOT NULL CHECK (amount_cents > 0),
    method        VARCHAR(10) NOT NULL CHECK (method IN ('TRANSFER', 'CASH')),
    booking_id    BIGINT      REFERENCES booking (id),
    created_by    BIGINT      NOT NULL REFERENCES app_user (id),
    created_at    TIMESTAMPTZ NOT NULL
);
CREATE INDEX idx_group_settlement_group ON group_settlement (group_id);


-- =========================================================
-- Verträge und Dokumente
-- =========================================================

CREATE TABLE contract (
    id               BIGSERIAL   PRIMARY KEY,
    user_id          BIGINT      NOT NULL REFERENCES app_user (id),
    name             VARCHAR(80) NOT NULL,
    provider         VARCHAR(80),
    kind             VARCHAR(20) NOT NULL,
    cost_cents       BIGINT      NOT NULL CHECK (cost_cents >= 0),
    billing          VARCHAR(10) NOT NULL CHECK (billing IN ('MONTHLY', 'QUARTERLY', 'YEARLY')),
    start_date       DATE        NOT NULL,
    min_term_months  INT         NOT NULL CHECK (min_term_months BETWEEN 0 AND 120),
    renewal_months   INT         NOT NULL CHECK (renewal_months BETWEEN 1 AND 60),
    notice_value     INT         NOT NULL CHECK (notice_value BETWEEN 0 AND 24),
    notice_unit      VARCHAR(6)  NOT NULL CHECK (notice_unit IN ('DAYS', 'WEEKS', 'MONTHS')),
    reminder_days    INT         NOT NULL CHECK (reminder_days BETWEEN 0 AND 90),
    status           VARCHAR(10) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'CANCELLED')),
    ends_on          DATE,
    note             VARCHAR(300),
    reminded_for     DATE,
    created_at       TIMESTAMPTZ NOT NULL
);
CREATE INDEX idx_contract_user ON contract (user_id);
CREATE INDEX idx_contract_reminder ON contract (status) WHERE status = 'ACTIVE' AND reminder_days > 0;

-- Inhalt verschlüsselt (AES-256-GCM), Metadaten im Klartext
CREATE TABLE document (
    id            BIGSERIAL    PRIMARY KEY,
    user_id       BIGINT       NOT NULL REFERENCES app_user (id),
    contract_id   BIGINT       REFERENCES contract (id) ON DELETE SET NULL,
    title         VARCHAR(100) NOT NULL,
    file_name     VARCHAR(120) NOT NULL,
    content_type  VARCHAR(40)  NOT NULL,
    size_bytes    INT          NOT NULL,
    sha256        VARCHAR(64)  NOT NULL,
    content       BYTEA        NOT NULL,
    created_at    TIMESTAMPTZ  NOT NULL
);
CREATE INDEX idx_document_user ON document (user_id, created_at DESC);
CREATE INDEX idx_document_contract ON document (contract_id) WHERE contract_id IS NOT NULL;


-- =========================================================
-- Simulation / Hintergrundjobs
-- =========================================================

CREATE TABLE sim_clock (
    id           INT PRIMARY KEY,
    offset_days  INT NOT NULL DEFAULT 0
);

CREATE TABLE job_run (
    run_date     DATE        PRIMARY KEY,
    finished_at  TIMESTAMPTZ NOT NULL
);

CREATE TABLE demo_profile (
    user_id     BIGINT      PRIMARY KEY REFERENCES app_user (id) ON DELETE CASCADE,
    profile     VARCHAR(20) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- =========================================================
-- Startdaten
-- =========================================================

INSERT INTO sim_clock (id, offset_days) VALUES (1, 0);

-- System-Konten (Gegenkonten für Buchungen)
INSERT INTO account (owner_id, type, name) VALUES
    (NULL, 'SYSTEM', 'BANK'),          -- Startguthaben
    (NULL, 'SYSTEM', 'HAENDLER'),      -- Kartenzahlungen
    (NULL, 'SYSTEM', 'DEPOT'),
    (NULL, 'SYSTEM', 'ZINSEN'),
    (NULL, 'SYSTEM', 'ARBEITGEBER'),
    (NULL, 'SYSTEM', 'LASTSCHRIFT'),
    (NULL, 'SYSTEM', 'EXTERN');        -- Geld von/nach außerhalb der Bank
