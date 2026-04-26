-- Brokerage Intelligence System — PostgreSQL Schema
-- PostgreSQL 14+
-- Developed by: [Sri Shreya]
-- Date: 2024-24-01

CREATE TABLE clients (
    client_id       SERIAL PRIMARY KEY,
    name            VARCHAR(120)    NOT NULL,
    age             SMALLINT        NOT NULL CHECK (age BETWEEN 18 AND 80),
    city            VARCHAR(80)     NOT NULL,
    state           VARCHAR(60)     NOT NULL,
    client_type     VARCHAR(10)     NOT NULL CHECK (client_type IN ('Retail', 'HNI')),
    risk_profile    VARCHAR(15)     NOT NULL CHECK (risk_profile IN ('Conservative', 'Moderate', 'Aggressive')),
    onboarding_date DATE            NOT NULL,
    kyc_status      VARCHAR(10)     NOT NULL CHECK (kyc_status IN ('Pending', 'Verified'))
);

CREATE INDEX idx_clients_type       ON clients (client_type);
CREATE INDEX idx_clients_onboarding ON clients (onboarding_date);
CREATE INDEX idx_clients_kyc        ON clients (kyc_status);
CREATE INDEX idx_clients_state      ON clients (state);


CREATE TABLE trading_accounts (
    account_id      SERIAL PRIMARY KEY,
    client_id       INT             NOT NULL REFERENCES clients(client_id) ON DELETE RESTRICT,
    account_type    VARCHAR(10)     NOT NULL CHECK (account_type IN ('Equity', 'F&O', 'Intraday', 'Delivery')),
    status          VARCHAR(12)     NOT NULL CHECK (status IN ('Active', 'Dormant', 'Suspended')),
    created_date    DATE            NOT NULL,
    last_trade_date DATE
);

CREATE INDEX idx_ta_client_id   ON trading_accounts (client_id);
CREATE INDEX idx_ta_status      ON trading_accounts (status);
CREATE INDEX idx_ta_last_trade  ON trading_accounts (last_trade_date);
CREATE INDEX idx_ta_type        ON trading_accounts (account_type);


CREATE TABLE trades (
    trade_id    SERIAL PRIMARY KEY,
    account_id  INT             NOT NULL REFERENCES trading_accounts(account_id) ON DELETE RESTRICT,
    trade_type  VARCHAR(4)      NOT NULL CHECK (trade_type IN ('Buy', 'Sell')),
    segment     VARCHAR(6)      NOT NULL CHECK (segment IN ('Equity', 'F&O')),
    quantity    INT             NOT NULL CHECK (quantity > 0),
    price       NUMERIC(12, 2)  NOT NULL CHECK (price > 0),
    trade_value NUMERIC(16, 2)  NOT NULL GENERATED ALWAYS AS (quantity * price) STORED,
    trade_date  DATE            NOT NULL,
    channel     VARCHAR(8)      NOT NULL CHECK (channel IN ('Mobile', 'Web', 'Dealer'))
);

CREATE INDEX idx_trades_account  ON trades (account_id);
CREATE INDEX idx_trades_date     ON trades (trade_date);
CREATE INDEX idx_trades_segment  ON trades (segment);
CREATE INDEX idx_trades_channel  ON trades (channel);
CREATE INDEX idx_trades_date_seg ON trades (trade_date, segment);


CREATE TABLE brokerage_revenue (
    revenue_id          SERIAL PRIMARY KEY,
    trade_id            INT             NOT NULL UNIQUE REFERENCES trades(trade_id) ON DELETE RESTRICT,
    brokerage_fee       NUMERIC(12, 4)  NOT NULL CHECK (brokerage_fee >= 0),
    transaction_charges NUMERIC(12, 4)  NOT NULL CHECK (transaction_charges >= 0),
    total_revenue       NUMERIC(12, 4)  NOT NULL GENERATED ALWAYS AS (brokerage_fee + transaction_charges) STORED
);

CREATE INDEX idx_br_trade_id ON brokerage_revenue (trade_id);


CREATE TABLE operational_events (
    event_id              SERIAL PRIMARY KEY,
    account_id            INT             NOT NULL REFERENCES trading_accounts(account_id) ON DELETE RESTRICT,
    event_type            VARCHAR(20)     NOT NULL CHECK (event_type IN ('Order Failure', 'App Crash', 'KYC Delay')),
    event_date            DATE            NOT NULL,
    resolution_time_hours NUMERIC(8, 2)   NOT NULL CHECK (resolution_time_hours >= 0)
);

CREATE INDEX idx_oe_account_id   ON operational_events (account_id);
CREATE INDEX idx_oe_event_date   ON operational_events (event_date);
CREATE INDEX idx_oe_event_type   ON operational_events (event_type);
CREATE INDEX idx_oe_account_date ON operational_events (account_id, event_date);


CREATE OR REPLACE VIEW vw_trade_full AS
SELECT
    t.trade_id,
    t.trade_date,
    t.trade_type,
    t.segment,
    t.quantity,
    t.price,
    t.trade_value,
    t.channel,
    br.brokerage_fee,
    br.transaction_charges,
    br.total_revenue,
    ta.account_id,
    ta.account_type,
    ta.status        AS account_status,
    ta.last_trade_date,
    c.client_id,
    c.name           AS client_name,
    c.client_type,
    c.risk_profile,
    c.city,
    c.state,
    c.onboarding_date,
    c.kyc_status
FROM trades            t
JOIN brokerage_revenue br ON br.trade_id   = t.trade_id
JOIN trading_accounts  ta ON ta.account_id = t.account_id
JOIN clients            c ON c.client_id   = ta.client_id;
