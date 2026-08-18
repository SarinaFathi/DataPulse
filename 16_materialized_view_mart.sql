-- ============================================================
-- Materialized View برای گزارش فروش ماهانه به تفکیک فروشگاه و دسته
-- ============================================================

\c datapulse;

-- ساخت Materialized View
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_monthly_store_category_sales AS
SELECT 
    ds.store_name,
    dc.category_name,
    dt.year,
    dt.month_name,
    SUM(fs.total_amount) AS total_revenue,
    SUM(fs.quantity_sold) AS total_items,
    COUNT(DISTINCT fs.sales_key) AS transaction_count
FROM fact_sales fs
JOIN dim_store ds ON fs.store_key = ds.store_key
JOIN dim_category dc ON fs.category_key = dc.category_key
JOIN dim_time dt ON fs.time_key = dt.time_key
WHERE dt.year = 2026
GROUP BY ds.store_name, dc.category_name, dt.year, dt.month_name, dt.month
ORDER BY ds.store_name, dc.category_name, dt.month;

-- ایندکس برای سرعت بیشتر
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_monthly_store_category 
ON mv_monthly_store_category_sales (store_name, category_name, year, month_name);

-- تست سرعت (خیلی سریع‌تر از کوئری معمولی)
EXPLAIN ANALYZE
SELECT * FROM mv_monthly_store_category_sales 
WHERE store_name = 'دیجی‌کالا'
ORDER BY year, month_name;

-- کوئری برای به‌روزرسانی (هر زمان دیتای جدید اضافه شد):
-- REFRESH MATERIALIZED VIEW mv_monthly_store_category_sales;