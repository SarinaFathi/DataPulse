-- ============================================================
-- ۱۰ کوئری تحلیلی روی دیتا مارت فروش
-- ============================================================

\c datapulse;

-- *****************************************
-- کوئری ۱: فروش ماهانه به تفکیک دسته‌بندی
-- *****************************************
SELECT 
    dc.category_name,
    dt.year,
    dt.month_name,
    SUM(fs.total_amount) AS total_revenue,
    SUM(fs.quantity_sold) AS total_quantity
FROM fact_sales fs
JOIN dim_category dc ON fs.category_key = dc.category_key
JOIN dim_time dt ON fs.time_key = dt.time_key
GROUP BY dc.category_name, dt.year, dt.month_name, dt.month
ORDER BY dt.year, dt.month, dc.category_name;


-- *****************************************
-- کوئری ۲: ۱۰ محصول پرفروش ماه جاری (مرداد ۱۴۰۵)
-- *****************************************
SELECT 
    dp.product_name,
    ds.store_name,
    SUM(fs.quantity_sold) AS total_sold,
    SUM(fs.total_amount) AS total_revenue
FROM fact_sales fs
JOIN dim_product dp ON fs.product_key = dp.product_key
JOIN dim_store ds ON fs.store_key = ds.store_key
JOIN dim_time dt ON fs.time_key = dt.time_key
WHERE dt.year = 2026 AND dt.month = 8  -- مرداد
GROUP BY dp.product_name, ds.store_name
ORDER BY total_sold DESC
LIMIT 10;


-- *****************************************
-- کوئری ۳: تحلیل رفتار کاربران جدید (ثبت‌نام در ماه جاری)
-- *****************************************
-- (با فرض اینکه جدول users رو نداریم، از mock_sales_transactions استفاده می‌کنیم)
SELECT 
    dt.month_name,
    COUNT(DISTINCT fs.transaction_id) AS new_user_transactions,
    SUM(fs.total_amount) AS revenue_from_new_users
FROM fact_sales fs
JOIN dim_time dt ON fs.time_key = dt.time_key
WHERE dt.year = 2026 AND dt.month = 8
GROUP BY dt.month_name;


-- *****************************************
-- کوئری ۴: مقایسه فروش فروشگاه‌ها (رشد ماهانه)
-- *****************************************
WITH monthly_sales AS (
    SELECT 
        ds.store_name,
        dt.year,
        dt.month,
        SUM(fs.total_amount) AS revenue
    FROM fact_sales fs
    JOIN dim_store ds ON fs.store_key = ds.store_key
    JOIN dim_time dt ON fs.time_key = dt.time_key
    WHERE dt.year = 2026
    GROUP BY ds.store_name, dt.year, dt.month
),
sales_with_previous AS (
    SELECT 
        store_name,
        year,
        month,
        revenue,
        LAG(revenue, 1) OVER (PARTITION BY store_name ORDER BY year, month) AS prev_month_revenue
    FROM monthly_sales
)
SELECT 
    store_name,
    year,
    month,
    revenue,
    prev_month_revenue,
    CASE 
        WHEN prev_month_revenue IS NULL THEN NULL
        WHEN prev_month_revenue = 0 THEN NULL
        ELSE ROUND(((revenue - prev_month_revenue) / prev_month_revenue * 100)::NUMERIC, 2)
    END AS growth_percent
FROM sales_with_previous
ORDER BY store_name, year, month;


-- *****************************************
-- کوئری ۵: میانگین قیمت فروش در هر دسته‌بندی
-- *****************************************
SELECT 
    dc.category_name,
    ROUND(AVG(fs.unit_price)::NUMERIC, 0) AS avg_price,
    ROUND(AVG(fs.total_amount / fs.quantity_sold)::NUMERIC, 0) AS avg_price_per_unit
FROM fact_sales fs
JOIN dim_category dc ON fs.category_key = dc.category_key
GROUP BY dc.category_name
ORDER BY avg_price DESC;


-- *****************************************
-- کوئری ۶: تعداد فروش در روزهای هفته (تحلیل رفتار خرید)
-- *****************************************
SELECT 
    dt.day_name,
    COUNT(fs.sales_key) AS number_of_sales,
    SUM(fs.total_amount) AS total_revenue,
    ROUND(AVG(fs.total_amount)::NUMERIC, 0) AS avg_order_value
FROM fact_sales fs
JOIN dim_time dt ON fs.time_key = dt.time_key
GROUP BY dt.day_name, dt.day_of_week
ORDER BY dt.day_of_week;


-- *****************************************
-- کوئری ۷: تحلیل همبستگی قیمت و تعداد فروش
-- *****************************************
SELECT 
    dp.product_name,
    dp.price AS product_price,
    SUM(fs.quantity_sold) AS total_sold,
    COUNT(fs.sales_key) AS number_of_transactions
FROM fact_sales fs
JOIN dim_product dp ON fs.product_key = dp.product_key
GROUP BY dp.product_name, dp.price
ORDER BY dp.price DESC;


-- *****************************************
-- کوئری ۸: محصولاتی که معمولاً با هم خریداری می‌شن (تحلیل سبد خرید)
-- *****************************************
-- (نسخه ساده - برای دیتای واقعی نیاز به الگوریتم‌های پیشرفته‌تر داره)
SELECT 
    p1.product_name AS product_a,
    p2.product_name AS product_b,
    COUNT(*) AS co_occurrence
FROM fact_sales fs1
JOIN fact_sales fs2 ON fs1.transaction_id = fs2.transaction_id 
    AND fs1.product_key < fs2.product_key
JOIN dim_product p1 ON fs1.product_key = p1.product_key
JOIN dim_product p2 ON fs2.product_key = p2.product_key
GROUP BY p1.product_name, p2.product_name
ORDER BY co_occurrence DESC
LIMIT 10;


-- *****************************************
-- کوئری ۹: پیش‌بینی ساده با رگرسیون (فروش ماه آینده)
-- *****************************************
WITH monthly_revenue AS (
    SELECT 
        dt.year,
        dt.month,
        SUM(fs.total_amount) AS revenue,
        ROW_NUMBER() OVER (ORDER BY dt.year, dt.month) AS month_number
    FROM fact_sales fs
    JOIN dim_time dt ON fs.time_key = dt.time_key
    WHERE dt.year = 2026
    GROUP BY dt.year, dt.month
)
SELECT 
    'پیش‌بینی فروش ماه آینده (شهریور)' AS prediction,
    ROUND(
        (SELECT 
            REGR_SLOPE(revenue, month_number) * (MAX(month_number) + 1) + 
            REGR_INTERCEPT(revenue, month_number)
         FROM monthly_revenue
        )::NUMERIC, 0
    ) AS predicted_revenue
FROM monthly_revenue;


-- *****************************************
-- کوئری ۱۰: فروش تجمعی (Cumulative) هر فروشگاه در سال
-- *****************************************
SELECT 
    ds.store_name,
    dt.month_name,
    SUM(fs.total_amount) AS monthly_revenue,
    SUM(SUM(fs.total_amount)) OVER (PARTITION BY ds.store_name ORDER BY dt.month) AS cumulative_revenue
FROM fact_sales fs
JOIN dim_store ds ON fs.store_key = ds.store_key
JOIN dim_time dt ON fs.time_key = dt.time_key
WHERE dt.year = 2026
GROUP BY ds.store_name, dt.month_name, dt.month
ORDER BY ds.store_name, dt.month;