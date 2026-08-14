-- ساخت Materialized View برای گزارش پرمصرف (مخصوص داشبورد مدیریت)
CREATE MATERIALIZED VIEW mv_store_category_inventory_report AS
SELECT 
    s.id AS store_id,
    s.name AS store_name,
    c.id AS category_id,
    c.name AS category_name,
    COUNT(DISTINCT p.id) AS total_products,
    SUM(i.quantity) AS total_stock,
    SUM(p.price * i.quantity) AS total_value
FROM stores s
JOIN products p ON s.id = p.store_id
JOIN categories c ON p.category_id = c.id
JOIN inventory i ON p.id = i.product_id
WHERE p.status = 'active'
GROUP BY s.id, s.name, c.id, c.name;

-- برای اینکه از سرعتش مطمئن بشی، یک ایندکس روی خود View بزن:
CREATE UNIQUE INDEX idx_mv_store_category ON mv_store_category_inventory_report (store_id, category_id);

-- کوئری تست برای مقایسه سرعت (خیلی سریع‌تر از کوئری معمولی اجرا میشه):
SELECT * FROM mv_store_category_inventory_report ORDER BY total_value DESC;

-- (توجه: هر وقت داده‌ها تغییر کرد، برای به‌روزرسانی این View باید دستور زیر رو بزنی)
-- REFRESH MATERIALIZED VIEW mv_store_category_inventory_report;