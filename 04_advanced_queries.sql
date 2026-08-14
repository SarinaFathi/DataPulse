-- اتصال به دیتابیس
\c datapulse;

-- ============================================
-- بخش اول: ۵ کوئری با Window Functions
-- ============================================

-- ۱. رتبه‌بندی محصولات بر اساس قیمت در هر فروشگاه (گران‌ترین ها)
-- (استفاده از RANK و DENSE_RANK)
SELECT 
    s.name AS store_name,
    p.name AS product_name,
    p.price,
    RANK() OVER (PARTITION BY p.store_id ORDER BY p.price DESC) AS price_rank,
    DENSE_RANK() OVER (PARTITION BY p.store_id ORDER BY p.price DESC) AS price_dense_rank
FROM products p
JOIN stores s ON p.store_id = s.id
WHERE p.status = 'active'
ORDER BY s.name, price_rank;

-- ۲. مقایسه قیمت هر محصول با محصول گران‌تر و ارزان‌تر در همان دسته‌بندی
-- (استفاده از LAG و LEAD)
SELECT 
    c.name AS category_name,
    p.name AS product_name,
    p.price,
    LAG(p.price, 1) OVER (PARTITION BY p.category_id ORDER BY p.price) AS cheaper_than_current,
    LEAD(p.price, 1) OVER (PARTITION BY p.category_id ORDER BY p.price) AS more_expensive_than_current
FROM products p
JOIN categories c ON p.category_id = c.id
WHERE p.status = 'active';

-- ۳. شماره ردیف محصولات به ترتیب وارد شدن به انبار (برای هر فروشگاه)
-- (استفاده از ROW_NUMBER)
SELECT 
    s.name AS store_name,
    p.name AS product_name,
    p.created_at,
    ROW_NUMBER() OVER (PARTITION BY p.store_id ORDER BY p.created_at ASC) AS entry_order
FROM products p
JOIN stores s ON p.store_id = s.id
ORDER BY s.name, entry_order;

-- ۴. محاسبه میانگین متحرک (مووینگ اورج) موجودی هر محصول در ۳ مرحله آخر
-- (استفاده از AVG با ROWS BETWEEN - مخصوص نقش ETL برای تحلیل روند موجودی)
SELECT 
    product_id,
    quantity,
    last_updated,
    AVG(quantity) OVER (PARTITION BY product_id ORDER BY last_updated ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg_3steps
FROM inventory
ORDER BY product_id, last_updated;

-- ۵. محاسبه ارزش کل موجودی انباشته (Cumulative) برای هر فروشگاه
-- (استفاده از SUM با ORDER BY)
SELECT 
    s.name AS store_name,
    p.name AS product_name,
    i.quantity,
    (p.price * i.quantity) AS inventory_value,
    SUM(p.price * i.quantity) OVER (PARTITION BY p.store_id ORDER BY p.id) AS cumulative_inventory_value
FROM products p
JOIN stores s ON p.store_id = s.id
JOIN inventory i ON p.id = i.product_id
WHERE p.status = 'active'
ORDER BY s.name, p.id;


-- ============================================
-- بخش دوم: ۳ کوئری با CTE
-- ============================================

-- ۱. CTE ساده: پیدا کردن فروشگاه‌هایی که بیش از ۳ محصول فعال دارند و سپس لیست محصولاتشان
WITH active_stores AS (
    SELECT 
        s.id AS store_id,
        s.name AS store_name,
        COUNT(p.id) AS product_count
    FROM stores s
    JOIN products p ON s.id = p.store_id
    WHERE p.status = 'active'
    GROUP BY s.id, s.name
    HAVING COUNT(p.id) > 3
)
SELECT 
    as_.store_name,
    p.name AS product_name,
    p.price
FROM active_stores as_
JOIN products p ON as_.store_id = p.store_id
ORDER BY as_.store_name, p.price DESC;

-- ۲. CTE با JOIN چندگانه: محاسبه میانگین قیمت در هر دسته‌بندی و نمایش محصولات بالاتر از میانگین
WITH category_avg_price AS (
    SELECT 
        c.id AS category_id,
        c.name AS category_name,
        AVG(p.price) AS avg_price
    FROM categories c
    JOIN products p ON c.id = p.category_id
    WHERE p.status = 'active'
    GROUP BY c.id, c.name
)
SELECT 
    p.name AS product_name,
    cap.category_name,
    p.price,
    cap.avg_price,
    ROUND((p.price - cap.avg_price) / cap.avg_price * 100, 2) AS percentage_above_avg
FROM products p
JOIN category_avg_price cap ON p.category_id = cap.category_id
WHERE p.price > cap.avg_price
ORDER BY percentage_above_avg DESC;

-- ۳. CTE ویژه نقش ETL: پردازش داده‌های خام (Staging) و تبدیل به فرمت جدول اصلی
-- (شبیه‌سازی تمیزکاری داده)
WITH raw_processing AS (
    SELECT 
        id,
        source_system,
        raw_data->>'product_name' AS raw_name,
        (raw_data->>'price')::BIGINT AS raw_price,
        (raw_data->>'stock')::INT AS raw_stock
    FROM staging_raw_imports
    WHERE status = 'pending'
)
SELECT 
    raw_name AS product_name,
    raw_price,
    raw_stock,
    CASE 
        WHEN raw_price < 0 THEN 0 
        ELSE raw_price 
    END AS cleaned_price,
    CASE 
        WHEN raw_stock < 0 THEN 0 
        ELSE raw_stock 
    END AS cleaned_stock
FROM raw_processing;


-- ============================================
-- بخش سوم: ۱ کوئری تحلیلی با GROUP BY ROLLUP
-- ============================================

-- گزارش ارزش کل موجودی به تفکیک فروشگاه و دسته‌بندی به همراه جمع‌های زیرمجموعه (Subtotals) و جمع کل (Grand Total)
SELECT 
    COALESCE(s.name, 'همه فروشگاه‌ها') AS store_name,
    COALESCE(c.name, 'همه دسته‌بندی‌ها') AS category_name,
    COUNT(DISTINCT p.id) AS product_count,
    SUM(i.quantity) AS total_stock_quantity,
    SUM(p.price * i.quantity) AS total_inventory_value
FROM products p
JOIN stores s ON p.store_id = s.id
JOIN categories c ON p.category_id = c.id
JOIN inventory i ON p.id = i.product_id
WHERE p.status = 'active'
GROUP BY ROLLUP(s.name, c.name)
ORDER BY s.name, c.name;