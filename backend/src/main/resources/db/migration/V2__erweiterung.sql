-- PHD Kontor – Erweiterung des Schemas für die freigegebenen Anforderungen
-- Startguthaben und Gehalt, Online-Shop mit Abos, Kategorien, Musterdepot-Kurse,
-- geteilte Konten mit Zustimmungen, physische Karte, Kreditprüfung,
-- Kontoauszüge und Löschen von Accounts.


-- =========================================================
-- Benutzer: Gehalt und Löschung
-- =========================================================

ALTER TABLE app_user
    ADD COLUMN monthly_salary_cents BIGINT NOT NULL DEFAULT 0 CHECK (monthly_salary_cents >= 0),
    ADD COLUMN deleted_at           TIMESTAMPTZ;                 -- NULL = aktiv, sonst anonymisiert

-- Beim Löschen wird das Geburtsdatum entfernt, solange der Nutzer aktiv ist, ist es Pflicht.
ALTER TABLE app_user ALTER COLUMN birth_date DROP NOT NULL;
ALTER TABLE app_user ADD CONSTRAINT ck_app_user_birth_date
    CHECK (deleted_at IS NOT NULL OR birth_date IS NOT NULL);


-- =========================================================
-- Neue Buchungsarten
-- =========================================================

ALTER TABLE booking DROP CONSTRAINT ck_booking_type;
ALTER TABLE booking ADD CONSTRAINT ck_booking_type CHECK (type IN (
    'TRANSFER', 'INTERNAL', 'CARD', 'SAVINGS_RATE', 'SAVINGS_PAYOUT', 'LOAN_PAYOUT', 'LOAN_RATE',
    'START_CREDIT',     -- 10.000 € bei Kontoeröffnung
    'SALARY',           -- monatliches Gehalt
    'SUBSCRIPTION',     -- monatliche Abo-Abbuchung
    'FEE'               -- Gebühren, z. B. Bestellung der physischen Karte
));


-- =========================================================
-- Kategorien
-- owner_id NULL = Standardkategorie für alle, sonst eigene Kategorie eines Nutzers
-- =========================================================

CREATE TABLE category (
    id          BIGSERIAL     PRIMARY KEY,
    owner_id    BIGINT        REFERENCES app_user (id) ON DELETE CASCADE,
    name        VARCHAR(40)   NOT NULL,
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_category_standard ON category (name) WHERE owner_id IS NULL;
CREATE UNIQUE INDEX uq_category_own      ON category (owner_id, name) WHERE owner_id IS NOT NULL;

-- Die Kategorie hängt jetzt an einer Kategorie-Zeile statt an freiem Text
ALTER TABLE booking_line DROP COLUMN category;
ALTER TABLE booking_line ADD COLUMN category_id BIGINT REFERENCES category (id);


-- =========================================================
-- Online-Shop: Händler, Produkte, Abos
-- =========================================================

CREATE TABLE merchant (
    id           BIGSERIAL     PRIMARY KEY,
    name         VARCHAR(60)   NOT NULL UNIQUE,
    category_id  BIGINT        NOT NULL REFERENCES category (id)   -- genau eine Kategorie je Händler
);

CREATE TABLE product (
    id               BIGSERIAL     PRIMARY KEY,
    merchant_id      BIGINT        NOT NULL REFERENCES merchant (id),
    name             VARCHAR(80)   NOT NULL,
    price_cents      BIGINT        NOT NULL CHECK (price_cents > 0),
    is_subscription  BOOLEAN       NOT NULL DEFAULT FALSE,           -- TRUE = monatliches Abo
    CONSTRAINT uq_product UNIQUE (merchant_id, name)
);

CREATE TABLE subscription (
    id                  BIGSERIAL     PRIMARY KEY,
    user_id             BIGINT        NOT NULL REFERENCES app_user (id),
    product_id          BIGINT        NOT NULL REFERENCES product (id),
    monthly_cents       BIGINT        NOT NULL CHECK (monthly_cents > 0),
    status              VARCHAR(10)   NOT NULL DEFAULT 'ACTIVE',
    started_at          TIMESTAMPTZ   NOT NULL,                       -- Simulationszeit
    cancelled_at        TIMESTAMPTZ,
    CONSTRAINT ck_subscription_status CHECK (status IN ('ACTIVE', 'CANCELLED')),
    CONSTRAINT ck_subscription_cancel CHECK ((status = 'CANCELLED') = (cancelled_at IS NOT NULL))
);
-- Ein Nutzer hat dasselbe Abo höchstens einmal aktiv
CREATE UNIQUE INDEX uq_subscription_active ON subscription (user_id, product_id) WHERE status = 'ACTIVE';

-- Eine Zeile je Abo und Monat: keine doppelte Abbuchung beim Vorspulen
CREATE TABLE subscription_execution (
    subscription_id  BIGINT       NOT NULL REFERENCES subscription (id),
    period           CHAR(7)      NOT NULL,                          -- JJJJ-MM
    status           VARCHAR(10)  NOT NULL,                          -- EXECUTED oder SKIPPED
    booking_id       BIGINT       UNIQUE REFERENCES booking (id),
    executed_at      TIMESTAMPTZ  NOT NULL,
    PRIMARY KEY (subscription_id, period),
    CONSTRAINT ck_subscription_execution CHECK ((status = 'EXECUTED') = (booking_id IS NOT NULL))
);


-- =========================================================
-- Musterdepot: Fonds und monatliche Kurse
-- =========================================================

CREATE TABLE fund (
    code  VARCHAR(20)  PRIMARY KEY,
    name  VARCHAR(60)  NOT NULL
);

-- Ein Kurs je Fonds und Simulationsmonat. Startkurs 100,00 €, nie unter 0,01 €.
CREATE TABLE fund_price (
    fund_code    VARCHAR(20)  NOT NULL REFERENCES fund (code),
    period       CHAR(7)      NOT NULL,                              -- JJJJ-MM
    price_cents  BIGINT       NOT NULL CHECK (price_cents >= 1),
    PRIMARY KEY (fund_code, period)
);

ALTER TABLE depot_position
    ADD CONSTRAINT fk_depot_position_fund FOREIGN KEY (fund_code) REFERENCES fund (code);


-- =========================================================
-- Geteilte Konten: Modell A / B, Einladungen, Zustimmungen
-- =========================================================

ALTER TABLE account ADD COLUMN share_model CHAR(1);
ALTER TABLE account ADD CONSTRAINT ck_account_share_model
    CHECK ((type = 'SUB') = (share_model IS NOT NULL) AND (share_model IS NULL OR share_model IN ('A', 'B')));

-- Rollen neu: Modell A = CO_OWNER, Modell B = ADMIN oder RESTRICTED
ALTER TABLE account_member DROP CONSTRAINT ck_account_member_role;
ALTER TABLE account_member
    ADD COLUMN status             VARCHAR(10) NOT NULL DEFAULT 'INVITED',
    ADD COLUMN daily_limit_cents  BIGINT CHECK (daily_limit_cents >= 0),     -- nur RESTRICTED
    ADD COLUMN joined_at          TIMESTAMPTZ;
ALTER TABLE account_member
    ADD CONSTRAINT ck_account_member_role   CHECK (role IN ('CO_OWNER', 'ADMIN', 'RESTRICTED')),
    ADD CONSTRAINT ck_account_member_status CHECK (status IN ('INVITED', 'ACTIVE')),
    ADD CONSTRAINT ck_account_member_limit  CHECK ((role = 'RESTRICTED') = (daily_limit_cents IS NOT NULL));

-- Zustimmungspflichtige Änderungen (Modell A). Gültig 7 Tage.
CREATE TABLE approval_request (
    id              BIGSERIAL     PRIMARY KEY,
    account_id      BIGINT        NOT NULL REFERENCES account (id),
    requested_by    BIGINT        NOT NULL REFERENCES app_user (id),
    action          VARCHAR(20)   NOT NULL,
    target_user_id  BIGINT        REFERENCES app_user (id),    -- bei ADD_MEMBER, REMOVE_MEMBER, LEAVE
    new_model       CHAR(1),                                   -- bei CHANGE_MODEL
    status          VARCHAR(10)   NOT NULL DEFAULT 'PENDING',
    created_at      TIMESTAMPTZ   NOT NULL,
    expires_at      TIMESTAMPTZ   NOT NULL,
    decided_at      TIMESTAMPTZ,
    CONSTRAINT ck_approval_action CHECK (action IN ('CHANGE_MODEL', 'ADD_MEMBER', 'REMOVE_MEMBER', 'LEAVE', 'CLOSE')),
    CONSTRAINT ck_approval_status CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'EXPIRED', 'CANCELLED')),
    CONSTRAINT ck_approval_expiry CHECK (expires_at = created_at + INTERVAL '7 days'),
    CONSTRAINT ck_approval_model  CHECK ((action = 'CHANGE_MODEL') = (new_model IS NOT NULL)),
    CONSTRAINT ck_approval_target CHECK ((action IN ('ADD_MEMBER', 'REMOVE_MEMBER', 'LEAVE')) = (target_user_id IS NOT NULL)),
    CONSTRAINT ck_approval_decided CHECK ((status = 'PENDING') = (decided_at IS NULL))
);
-- Je Konto höchstens eine offene Anfrage
CREATE UNIQUE INDEX uq_approval_open ON approval_request (account_id) WHERE status = 'PENDING';

-- Antwort je Mitinhaber. Der Antragsteller stimmt mit dem Absenden zu.
CREATE TABLE approval_vote (
    request_id  BIGINT       NOT NULL REFERENCES approval_request (id),
    user_id     BIGINT       NOT NULL REFERENCES app_user (id),
    decision    VARCHAR(10)  NOT NULL,
    voted_at    TIMESTAMPTZ  NOT NULL,
    PRIMARY KEY (request_id, user_id),
    CONSTRAINT ck_approval_vote CHECK (decision IN ('APPROVE', 'REJECT'))
);

ALTER TABLE notification ADD COLUMN approval_request_id BIGINT REFERENCES approval_request (id);


-- =========================================================
-- Karte: simulierte Bestellung der physischen Karte
-- =========================================================

ALTER TABLE card
    ADD COLUMN physical_ordered_at  TIMESTAMPTZ,                          -- NULL = nicht bestellt
    ADD COLUMN physical_booking_id  BIGINT UNIQUE REFERENCES booking (id); -- 10 € Gebühr
ALTER TABLE card ADD CONSTRAINT ck_card_physical
    CHECK ((physical_ordered_at IS NULL) = (physical_booking_id IS NULL));


-- =========================================================
-- Kredit: Selbstauskunft für die Tragfähigkeitsprüfung
-- frei verfügbar = Gehalt − (Fixausgaben + Sparraten + Kreditraten + sonstige)
-- Die Werte zum Zeitpunkt des Abschlusses werden festgehalten.
-- =========================================================

ALTER TABLE loan
    ADD COLUMN income_cents             BIGINT NOT NULL DEFAULT 0 CHECK (income_cents >= 0),
    ADD COLUMN fixed_expenses_cents     BIGINT NOT NULL DEFAULT 0 CHECK (fixed_expenses_cents >= 0),
    ADD COLUMN savings_rates_cents      BIGINT NOT NULL DEFAULT 0 CHECK (savings_rates_cents >= 0),
    ADD COLUMN loan_rates_cents         BIGINT NOT NULL DEFAULT 0 CHECK (loan_rates_cents >= 0),
    ADD COLUMN other_obligations_cents  BIGINT NOT NULL DEFAULT 0 CHECK (other_obligations_cents >= 0);


-- =========================================================
-- Monatliche Kontoauszüge (das PDF wird bei Bedarf erzeugt)
-- =========================================================

CREATE TABLE statement (
    id             BIGSERIAL    PRIMARY KEY,
    account_id     BIGINT       NOT NULL REFERENCES account (id),
    period         CHAR(7)      NOT NULL,                     -- JJJJ-MM
    opening_cents  BIGINT       NOT NULL,
    closing_cents  BIGINT       NOT NULL,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_statement UNIQUE (account_id, period)
);


-- =========================================================
-- Startdaten
-- =========================================================

-- Gegenkonten für Spielgeld (Startguthaben, Gehalt) und Gebühren
INSERT INTO account (owner_id, type, name) VALUES
    (NULL, 'SYSTEM', 'SPIELGELD'),
    (NULL, 'SYSTEM', 'GEBUEHREN');

INSERT INTO category (owner_id, name) VALUES
    (NULL, 'Lebensmittel'), (NULL, 'Shopping'), (NULL, 'Abonnements'), (NULL, 'Wohnen'),
    (NULL, 'Mobilität'), (NULL, 'Freizeit'), (NULL, 'Sparen'), (NULL, 'Kredit'),
    (NULL, 'Einnahmen'), (NULL, 'Sonstiges');

INSERT INTO merchant (name, category_id) VALUES
    ('REWE',    (SELECT id FROM category WHERE owner_id IS NULL AND name = 'Lebensmittel')),
    ('Amazon',  (SELECT id FROM category WHERE owner_id IS NULL AND name = 'Shopping')),
    ('Netflix', (SELECT id FROM category WHERE owner_id IS NULL AND name = 'Abonnements'));

INSERT INTO product (merchant_id, name, price_cents, is_subscription) VALUES
    ((SELECT id FROM merchant WHERE name = 'REWE'),    'Wocheneinkauf',      4500, FALSE),
    ((SELECT id FROM merchant WHERE name = 'REWE'),    'Getränke',           1200, FALSE),
    ((SELECT id FROM merchant WHERE name = 'Amazon'),  'Kopfhörer',          5999, FALSE),
    ((SELECT id FROM merchant WHERE name = 'Amazon'),  'Fachbuch Informatik', 3990, FALSE),
    ((SELECT id FROM merchant WHERE name = 'Netflix'), 'Standard-Abo',       1000, TRUE);

INSERT INTO fund (code, name) VALUES
    ('WELT',   'PHD Welt-Aktien'),
    ('EUROPA', 'PHD Europa-Mix');

-- Startkurs 100,00 € im Startmonat der Simulation
INSERT INTO fund_price (fund_code, period, price_cents)
SELECT code, to_char(now(), 'YYYY-MM'), 10000 FROM fund;
