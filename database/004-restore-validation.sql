-- =============================================================================
-- 004-restore-validation.sql
-- Run this AGAINST A NON-PRODUCTION TEST DATABASE after pg_restore of a backup.
-- Confirms the three tables, row counts, constraints, indexes and referential
-- integrity survived the backup/restore cycle.
-- Use with: psql -v ON_ERROR_STOP=1 -f 004-restore-validation.sql
-- =============================================================================

\set ON_ERROR_STOP on
SET client_min_messages = WARNING;

DO $$
DECLARE
    v_customers   BIGINT;
    v_orders      BIGINT;
    v_order_items BIGINT;
    v_pk_count    BIGINT;
    v_fk_count    BIGINT;
    v_ix_count    BIGINT;
    v_ri          BIGINT;
BEGIN
    -- Table existence
    IF to_regclass('eanco_demo.customers')   IS NULL THEN RAISE EXCEPTION 'RESTORE FAIL: missing customers'; END IF;
    IF to_regclass('eanco_demo.orders')      IS NULL THEN RAISE EXCEPTION 'RESTORE FAIL: missing orders'; END IF;
    IF to_regclass('eanco_demo.order_items') IS NULL THEN RAISE EXCEPTION 'RESTORE FAIL: missing order_items'; END IF;

    -- Row counts vs expected minimums
    SELECT count(*) INTO v_customers   FROM eanco_demo.customers;
    SELECT count(*) INTO v_orders      FROM eanco_demo.orders;
    SELECT count(*) INTO v_order_items FROM eanco_demo.order_items;
    IF v_customers < 3 OR v_orders < 2 OR v_order_items < 3 THEN
        RAISE EXCEPTION 'RESTORE FAIL: row counts customers=%, orders=%, order_items=%',
            v_customers, v_orders, v_order_items;
    END IF;

    -- Constraints & indexes survived
    SELECT count(*) INTO v_pk_count FROM pg_constraint
        WHERE contype='p' AND conname IN ('customers_pkey','orders_pkey','order_items_pkey');
    IF v_pk_count <> 3 THEN RAISE EXCEPTION 'RESTORE FAIL: expected 3 PKs, found %', v_pk_count; END IF;

    SELECT count(*) INTO v_fk_count FROM pg_constraint
        WHERE contype='f' AND conname IN ('fk_orders_customer','fk_order_items_order');
    IF v_fk_count <> 2 THEN RAISE EXCEPTION 'RESTORE FAIL: expected 2 FKs, found %', v_fk_count; END IF;

    SELECT count(*) INTO v_ix_count FROM pg_indexes
        WHERE schemaname='eanco_demo';
    IF v_ix_count < 6 THEN RAISE EXCEPTION 'RESTORE FAIL: expected >=6 indexes, found %', v_ix_count; END IF;

    -- Referential integrity
    SELECT count(*) INTO v_ri FROM eanco_demo.orders o
        LEFT JOIN eanco_demo.customers c ON c.customer_id=o.customer_id
        WHERE c.customer_id IS NULL;
    IF v_ri > 0 THEN RAISE EXCEPTION 'RESTORE FAIL: % orphan orders', v_ri; END IF;

    SELECT count(*) INTO v_ri FROM eanco_demo.order_items i
        LEFT JOIN eanco_demo.orders o ON o.order_id=i.order_id
        WHERE o.order_id IS NULL;
    IF v_ri > 0 THEN RAISE EXCEPTION 'RESTORE FAIL: % orphan order_items', v_ri; END IF;

    RAISE NOTICE 'RESTORE VALIDATION PASSED: customers=%, orders=%, order_items=%, PKs=%, FKs=%, indexes=%',
        v_customers, v_orders, v_order_items, v_pk_count, v_fk_count, v_ix_count;
END $$;
