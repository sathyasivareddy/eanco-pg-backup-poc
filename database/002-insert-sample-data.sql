-- =============================================================================
-- 002-insert-sample-data.sql
-- Idempotent sample data for the backup POC.
-- Inserts at least 3 customers, 2 orders, 3 order items.
-- Re-running does not create duplicates (ON CONFLICT DO NOTHING on natural keys).
-- =============================================================================

SET client_min_messages = WARNING;

-- ---- customers ----
INSERT INTO eanco_demo.customers (customer_code, full_name, email, country_code, credit_limit)
VALUES
    ('CUST-0001', 'Acme Industrial Ltd', 'billing@acme-industrial.example', 'US', 25000.00),
    ('CUST-0002', 'Northwind Traders',    'ap@northwind.example',            'GB',  15000.00),
    ('CUST-0003', 'Contoso Foods GmbH',   'finance@contoso-foods.example',   'DE',  40000.00)
ON CONFLICT (customer_code) DO NOTHING;

-- ---- orders ----
-- Resolve customer_id by natural key to stay idempotent and portable.
INSERT INTO eanco_demo.orders (order_number, customer_id, order_status, order_total, currency_code, ordered_at)
SELECT 'ORD-1001', c.customer_id, 'PAID', 1250.00, 'USD', TIMESTAMPTZ '2026-01-15 10:30:00+00'
FROM eanco_demo.customers c WHERE c.customer_code = 'CUST-0001'
ON CONFLICT (order_number) DO NOTHING;

INSERT INTO eanco_demo.orders (order_number, customer_id, order_status, order_total, currency_code, ordered_at)
SELECT 'ORD-1002', c.customer_id, 'PENDING', 830.50, 'GBP', TIMESTAMPTZ '2026-02-03 14:05:00+00'
FROM eanco_demo.customers c WHERE c.customer_code = 'CUST-0002'
ON CONFLICT (order_number) DO NOTHING;

-- ---- order_items ----
INSERT INTO eanco_demo.order_items (order_id, sku, description, quantity, unit_price)
SELECT o.order_id, 'SKU-A100', 'Industrial widget, grade A', 5, 150.00
FROM eanco_demo.orders o WHERE o.order_number = 'ORD-1001'
ON CONFLICT (order_id, sku) DO NOTHING;

INSERT INTO eanco_demo.order_items (order_id, sku, description, quantity, unit_price)
SELECT o.order_id, 'SKU-B200', 'Mounting bracket set', 10, 50.00
FROM eanco_demo.orders o WHERE o.order_number = 'ORD-1001'
ON CONFLICT (order_id, sku) DO NOTHING;

INSERT INTO eanco_demo.order_items (order_id, sku, description, quantity, unit_price)
SELECT o.order_id, 'SKU-C300', 'Replacement filter', 3, 276.83
FROM eanco_demo.orders o WHERE o.order_number = 'ORD-1002'
ON CONFLICT (order_id, sku) DO NOTHING;

-- Keep order_total consistent with line items (idempotent recompute).
UPDATE eanco_demo.orders o
SET order_total = sub.total,
    updated_at  = now()
FROM (
    SELECT order_id, COALESCE(SUM(line_total), 0) AS total
    FROM eanco_demo.order_items
    GROUP BY order_id
) sub
WHERE o.order_id = sub.order_id
  AND o.order_total <> sub.total;
