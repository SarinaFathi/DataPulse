-- ==============================================
-- ساخت Materialized View برای گزارش فروش ماهانه
-- (مناسب برای نقش ETL و تیم دوم)
-- ==============================================

-- ۱. (اختیاری) یک جدول شبیه‌سازی‌شده از تراکنش‌های فروش بسازیم 
--    تا بتونیم گزارش ماهانه بدیم (چون تیم دوم جدول سفارش نداره، این کار رو به عنوان ETL انجام میدیم)
CREATE TABLE IF NOT EXISTS mock_sales_transactions (
    id SERIAL PRIMARY KEY,
    product_id INT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    sale_date DATE NOT NULL,
    quantity_sold INT NOT NULL CHECK (quantity_sold > 0),
    unit_price_at_sale DECIMAL(15, 2) NOT NULL CHECK (unit_price_at_sale >= 0)
);

-- ۲. درج ۲۰ رکورد شبیه‌سازی‌شده از فروش در ماه‌های مختلف (برای تست)
INSERT INTO mock_sales_transactions (product_id, sale_date, quantity_sold, unit_price_at_sale) VALUES
(1, '2026-01-15', 2, 68000000),
(1, '2026-01-20', 1, 68000000),
(2, '2026-01-10', 3, 55000000),
(3, '2026-02-05', 5, 1250000),
(4, '2026-02-14', 2, 2300000),
(5, '2026-02-20', 1, 45000000),
(1, '2026-03-01', 2, 68000000),
(3, '2026-03-15', 3, 1250000),
(6, '2026-03-22', 4, 28000000),
(2, '2026-04-02', 1, 55000000),
(9, '2026-04-18', 6, 22000000),
(10, '2026-04-25', 3, 8500000),
(5, '2026-05-10', 2, 45000000),
(11, '2026-05-12', 1, 3500000),
(8, '2026-05-28', 4, 1800000),
(2, '2026-06-03', 2, 55000000),
(3, '2026-06-19', 7, 1250000),
(4, '2026-07-07', 3, 2300000),
(9, '2026-07-21', 5, 22000000),
(10, '2026-08-01', 2, 8500000);

-- ۳. ساخت Materialized View برای گزارش فروش ماهانه (جمع فروش هر ماه به تفکیک فروشگاه)
CREATE MATERIALIZED VIEW mv_monthly_sales_report AS
SELECT 
    s.id AS store_id,
    s.name AS store_name,
    DATE_TRUNC('month', mst.sale_date)::DATE AS sale_month,
    COUNT(DISTINCT mst.id) AS total_transactions,
    SUM(mst.quantity_sold) AS total_items_sold,
    SUM(mst.quantity_sold * mst.unit_price_at_sale) AS total_revenue
FROM mock_sales_transactions mst
JOIN products p ON mst.product_id = p.id
JOIN stores s ON p.store_id = s.id
GROUP BY s.id, s.name, DATE_TRUNC('month', mst.sale_date)
ORDER BY s.name, sale_month;

-- ۴. برای سرعت، یک ایندکس روی View می‌زنیم
CREATE UNIQUE INDEX idx_mv_monthly_sales ON mv_monthly_sales_report (store_id, sale_month);

-- ۵. تست سرعت - این گزارش رو با کوئری معمولی مقایسه کن
-- (قبل از ساختن MV، این کوئری رو تست کن و زمانش رو ببین، بعد دوباره از خود MV بخون)
-- زمان کوئری معمولی:
EXPLAIN (ANALYZE, BUFFERS) 
SELECT 
    s.name, 
    DATE_TRUNC('month', mst.sale_date)::DATE AS month,
    SUM(mst.quantity_sold * mst.unit_price_at_sale) AS revenue
FROM mock_sales_transactions mst
JOIN products p ON mst.product_id = p.id
JOIN stores s ON p.store_id = s.id
GROUP BY s.name, DATE_TRUNC('month', mst.sale_date);

-- زمان استفاده از Materialized View (خیلی سریعتر):
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM mv_monthly_sales_report ORDER BY store_name, sale_month;

-- ۶. به‌روزرسانی View (هر وقت دیتای جدید وارد شد، این دستور رو بزن)
-- REFRESH MATERIALIZED VIEW mv_monthly_sales_report;