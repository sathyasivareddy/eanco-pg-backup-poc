-- =============================================================================
-- 003-validate-data.sql
-- Validation checks for the sample database.
-- Exits with a non-zero psql status if any assertion fails (use with -v ON_ERROR_STOP=1).
-- Checks: table existence, row counts, PK/FK presence, indexes, join query, RI.
-- =============================================================================

\set ON_ERROR_STOP on
SET client_min_messages = WARNING;

DO $$
DECLARE
    v_customers   BIGINT;
    v_orders      BIGINT;
    v_order_items BIGINT;
    v_missing     BIGINT;
BEGIN
    -- Table existence
    IF to_regclass('eanco_demo.customers')   IS NULL THEN RAISE EXCEPTION 'Missing table: customers'; END IF;
    IF to_regclass('eanco_demo.orders')      IS NULL THEN RAISE EXCEPTION 'Missing table: orders'; END IF;
    IF to_regclass('eanco_demo.order_items') IS NULL THEN RAISE EXCEPTION 'Missing table: order_items'; END IF;

    -- Row counts (expected minimums)
    SELECT count(*) INTO v_customers   FROM eanco_demo.customers;
    SELECT count(*) INTO v_orders      FROM eanco_demo.orders;
    SELECT count(*) INTO v_order_items FROM eanco_demo.order_items;

    IF v_customers < 3 THEN RAISE EXCEPTION 'customers row count % < 3', v_customers; END IF;
    IF v_orders < 2 THEN RAISE EXCEPTION 'orders row count % < 2', v_orders; END IF;
    IF v_order_items < 3 THEN RAISE EXCEPTION 'order_items row count % < 3', v_order_items; END IF;

    -- Primary keys present
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'customers_pkey')   THEN RAISE EXCEPTION 'Missing PK on customers'; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'orders_pkey')      THEN RAISE EXCEPTION 'Missing PK on orders'; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'order_items_pkey') THEN RAISE EXCEPTION 'Missing PK on order_items'; END IF;

    -- Foreign keys present
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_orders_customer')  THEN RAISE EXCEPTION 'Missing FK fk_orders_customer'; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_order_items_order') THEN RAISE EXCEPTION 'Missing FK fk_order_items_order'; END IF;

    -- Indexes present
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='eanco_demo' AND indexname='ix_orders_customer_id')  THEN RAISE EXCEPTION 'Missing index ix_orders_customer_id'; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='eanco_demo' AND indexname='ix_order_items_order_id') THEN RAISE EXCEPTION 'Missing index ix_order_items_order_id'; END IF;

    -- Referential integrity: no orphan orders / order_items
    SELECT count(*) INTO v_missing
    FROM eanco_demo.orders o
    LEFT JOIN eanco_demo.customers c ON c.customer_id = o.customer_id
    WHERE c.customer_id IS NULL;
    IF v_missing > 0 THEN RAISE EXCEPTION 'Found % orphan orders', v_missing; END IF;

    SELECT count(*) INTO v_missing
    FROM eanco_demo.order_items i
    LEFT JOIN eanco_demo.orders o ON o.order_id = i.order_id
    WHERE o.order_id IS NULL;
    IF v_missing > 0 THEN RAISE EXCEPTION 'Found % orphan order_items', v_missing; END IF;

    RAISE NOTICE 'VALIDATION PASSED: customers=%, orders=%, order_items=%', v_customers, v_orders, v_order_items;
END $$;

-- Sample join query (human-readable output)
SELECT c.customer_code,
       o.order_number,
       o.order_status,
       o.order_total,
       count(i.order_item_id) AS item_count,
       COALESCE(SUM(i.line_total), 0) AS computed_total
FROM eanco_demo.customers c
JOIN eanco_demo.orders o        ON o.customer_id = c.customer_id
LEFT JOIN eanco_demo.order_items i ON i.order_id = o.order_id
GROUP BY c.customer_code, o.order_number, o.order_status, o.order_total
ORDER BY o.order_number;
