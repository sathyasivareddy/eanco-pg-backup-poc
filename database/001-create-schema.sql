-- =============================================================================
-- 001-create-schema.sql
-- Creates the eanco_demo schema and three related tables for the backup POC.
-- Idempotent: safe to run multiple times.
-- Target: Azure Database for PostgreSQL Flexible Server (v16).
-- =============================================================================

SET client_min_messages = WARNING;

-- Dedicated schema for the demo objects.
CREATE SCHEMA IF NOT EXISTS eanco_demo;

-- ---------------------------------------------------------------------------
-- customers
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS eanco_demo.customers (
    customer_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_code   VARCHAR(20)  NOT NULL,
    full_name       VARCHAR(200) NOT NULL,
    email           VARCHAR(320) NOT NULL,
    country_code    CHAR(2)      NOT NULL DEFAULT 'US',
    credit_limit    NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_customers_customer_code UNIQUE (customer_code),
    CONSTRAINT uq_customers_email         UNIQUE (email),
    CONSTRAINT ck_customers_credit_limit  CHECK (credit_limit >= 0),
    CONSTRAINT ck_customers_country_code  CHECK (country_code ~ '^[A-Z]{2}$')
);

CREATE INDEX IF NOT EXISTS ix_customers_country_code ON eanco_demo.customers (country_code);
CREATE INDEX IF NOT EXISTS ix_customers_is_active    ON eanco_demo.customers (is_active);

-- ---------------------------------------------------------------------------
-- orders
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS eanco_demo.orders (
    order_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_number    VARCHAR(30)  NOT NULL,
    customer_id     BIGINT       NOT NULL,
    order_status    VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    order_total     NUMERIC(14,2) NOT NULL DEFAULT 0.00,
    currency_code   CHAR(3)      NOT NULL DEFAULT 'USD',
    ordered_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_orders_order_number UNIQUE (order_number),
    CONSTRAINT ck_orders_status CHECK (order_status IN ('PENDING','PAID','SHIPPED','CANCELLED','REFUNDED')),
    CONSTRAINT ck_orders_total  CHECK (order_total >= 0),
    CONSTRAINT ck_orders_currency CHECK (currency_code ~ '^[A-Z]{3}$'),
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id)
        REFERENCES eanco_demo.customers (customer_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS ix_orders_customer_id ON eanco_demo.orders (customer_id);
CREATE INDEX IF NOT EXISTS ix_orders_status      ON eanco_demo.orders (order_status);
CREATE INDEX IF NOT EXISTS ix_orders_ordered_at  ON eanco_demo.orders (ordered_at);

-- ---------------------------------------------------------------------------
-- order_items
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS eanco_demo.order_items (
    order_item_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id        BIGINT       NOT NULL,
    sku             VARCHAR(40)  NOT NULL,
    description     VARCHAR(200) NOT NULL,
    quantity        INTEGER      NOT NULL DEFAULT 1,
    unit_price      NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    line_total      NUMERIC(14,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_order_items_order_sku UNIQUE (order_id, sku),
    CONSTRAINT ck_order_items_quantity   CHECK (quantity > 0),
    CONSTRAINT ck_order_items_unit_price CHECK (unit_price >= 0),
    CONSTRAINT fk_order_items_order FOREIGN KEY (order_id)
        REFERENCES eanco_demo.orders (order_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_order_items_order_id ON eanco_demo.order_items (order_id);
CREATE INDEX IF NOT EXISTS ix_order_items_sku      ON eanco_demo.order_items (sku);
