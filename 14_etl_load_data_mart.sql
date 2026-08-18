-- ================================================================
-- راه‌اندازی کامل دیتا مارت فروش - (تیم دوم - ETL)
-- این فایل، همه جداول را ریست می‌کند و داده‌ها را از اول وارد می‌کند
-- ================================================================

\c datapulse;

-- ***************************************************************
-- بخش ۱: حذف جدول‌های قدیمی (اگر وجود داشته باشند)
-- ***************************************************************
DROP TABLE IF EXISTS fact_sales CASCADE;
DROP TABLE IF EXISTS dim_product CASCADE;
DROP TABLE IF EXISTS dim_store CASCADE;
DROP TABLE IF EXISTS dim_category CASCADE;
DROP TABLE IF EXISTS dim_time CASCADE;

-- ***************************************************************
-- بخش ۲: ساخت جدول‌های بُعد (Dimension Tables) با ساختار درست
-- ***************************************************************

-- ۱. بُعد زمان
CREATE TABLE dim_time (
    time_key SERIAL PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    year INT,
    quarter INT,
    month INT,
    month_name VARCHAR(20),
    day INT,
    day_of_week INT,
    day_name VARCHAR(20),
    is_weekend BOOLEAN DEFAULT FALSE
);

-- ۲. بُعد فروشگاه
CREATE TABLE dim_store (
    store_key SERIAL PRIMARY KEY,
    store_id INT UNIQUE,        -- کلید یکتا برای ON CONFLICT (اختیاری)
    store_name VARCHAR(255) NOT NULL,
    address TEXT,
    phone VARCHAR(20),
    created_at TIMESTAMP
);

-- ۳. بُعد دسته‌بندی
CREATE TABLE dim_category (
    category_key SERIAL PRIMARY KEY,
    category_id INT UNIQUE,     -- کلید یکتا
    category_name VARCHAR(100) NOT NULL,
    parent_category_name VARCHAR(100),
    level INT
);

-- ۴. بُعد محصول (با اضافه کردن store_id و category_id تا مشکل قبلی حل شود)
CREATE TABLE dim_product (
    product_key SERIAL PRIMARY KEY,
    product_id INT UNIQUE,      -- کلید یکتا
    product_name VARCHAR(255) NOT NULL,
    category_name VARCHAR(100),
    store_name VARCHAR(255),
    store_id INT,               -- این ستون را اضافه کردم تا خطای قبلی را ندهد
    category_id INT,            -- این ستون را هم اضافه کردم برای امنیت بیشتر
    price DECIMAL(15, 2),
    status VARCHAR(20),
    created_at TIMESTAMP
);

-- ***************************************************************
-- بخش ۳: ساخت جدول حقیقت (Fact Table)
-- ***************************************************************

CREATE TABLE fact_sales (
    sales_key SERIAL PRIMARY KEY,
    product_key INT REFERENCES dim_product(product_key),
    store_key INT REFERENCES dim_store(store_key),
    time_key INT REFERENCES dim_time(time_key),
    category_key INT REFERENCES dim_category(category_key),
    quantity_sold INT NOT NULL CHECK (quantity_sold > 0),
    unit_price DECIMAL(15, 2) NOT NULL,
    total_amount DECIMAL(15, 2) NOT NULL,
    discount_amount DECIMAL(15, 2) DEFAULT 0,
    transaction_id INT UNIQUE,   -- کلید یکتا برای جلوگیری از درج تکراری
    sale_date DATE NOT NULL
);

-- ***************************************************************
-- بخش ۴: پر کردن جدول‌های بُعد (ETL - Extract, Transform, Load)
-- ***************************************************************

-- ۱. پر کردن بُعد زمان (همه روزهای سال ۲۰۲۶)
INSERT INTO dim_time (full_date, year, quarter, month, month_name, day, day_of_week, day_name, is_weekend)
SELECT 
    d::DATE AS full_date,
    EXTRACT(YEAR FROM d)::INT AS year,
    EXTRACT(QUARTER FROM d)::INT AS quarter,
    EXTRACT(MONTH FROM d)::INT AS month,
    TO_CHAR(d, 'Month') AS month_name,
    EXTRACT(DAY FROM d)::INT AS day,
    EXTRACT(DOW FROM d)::INT AS day_of_week,
    TO_CHAR(d, 'Day') AS day_name,
    EXTRACT(DOW FROM d) IN (0, 6) AS is_weekend
FROM generate_series('2026-01-01'::DATE, '2026-12-31'::DATE, '1 day'::INTERVAL) AS d
ON CONFLICT (full_date) DO NOTHING;

-- ۲. پر کردن بُعد فروشگاه
INSERT INTO dim_store (store_id, store_name, address, phone, created_at)
SELECT id, name, address, phone, created_at FROM stores
ON CONFLICT (store_id) DO UPDATE SET
    store_name = EXCLUDED.store_name,
    address = EXCLUDED.address,
    phone = EXCLUDED.phone;

-- ۳. پر کردن بُعد دسته‌بندی
INSERT INTO dim_category (category_id, category_name, parent_category_name, level)
SELECT 
    c.id,
    c.name,
    parent.name AS parent_category_name,
    c.level
FROM categories c
LEFT JOIN categories parent ON c.parent_id = parent.id
ON CONFLICT (category_id) DO UPDATE SET
    category_name = EXCLUDED.category_name,
    parent_category_name = EXCLUDED.parent_category_name;

-- ۴. پر کردن بُعد محصول (این بار store_id و category_id را هم پر می‌کنیم)
INSERT INTO dim_product (product_id, product_name, category_name, store_name, store_id, category_id, price, status, created_at)
SELECT 
    p.id,
    p.name,
    c.name AS category_name,
    s.name AS store_name,
    s.id AS store_id,        -- اینجا store_id را پر می‌کنیم
    c.id AS category_id,     -- اینجا category_id را پر می‌کنیم
    p.price,
    p.status,
    p.created_at
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
LEFT JOIN stores s ON p.store_id = s.id
ON CONFLICT (product_id) DO UPDATE SET
    product_name = EXCLUDED.product_name,
    category_name = EXCLUDED.category_name,
    store_name = EXCLUDED.store_name,
    store_id = EXCLUDED.store_id,
    category_id = EXCLUDED.category_id,
    price = EXCLUDED.price,
    status = EXCLUDED.status;

-- ***************************************************************
-- بخش ۵: پر کردن جدول حقیقت (Fact_Sales) با JOINهای درست
-- ***************************************************************

-- اول اگر داده هست پاک می‌کنیم تا دوباره پر شود
TRUNCATE fact_sales RESTART IDENTITY;

INSERT INTO fact_sales (
    product_key,
    store_key,
    time_key,
    category_key,
    quantity_sold,
    unit_price,
    total_amount,
    discount_amount,
    transaction_id,
    sale_date
)
SELECT 
    dp.product_key,                    -- کلید محصول از دیتا مارت
    ds.store_key,                      -- کلید فروشگاه از دیتا مارت (این بار از ds استفاده می‌کنیم نه dp)
    dt.time_key,                       -- کلید زمان
    dc.category_key,                   -- کلید دسته‌بندی
    mst.quantity_sold,
    mst.unit_price_at_sale,
    (mst.quantity_sold * mst.unit_price_at_sale) AS total_amount,
    0 AS discount_amount,
    mst.id AS transaction_id,
    mst.sale_date
FROM mock_sales_transactions mst
-- اتصال به جدول اصلی products برای پیدا کردن store_id و category_id
JOIN products p ON mst.product_id = p.id
-- اتصال به بُعد محصول (برای گرفتن product_key)
JOIN dim_product dp ON p.id = dp.product_id
-- اتصال به بُعد فروشگاه (از طریق store_id که از products گرفتیم)
JOIN dim_store ds ON p.store_id = ds.store_id
-- اتصال به بُعد زمان (از طریق تاریخ فروش)
JOIN dim_time dt ON mst.sale_date = dt.full_date
-- اتصال به بُعد دسته‌بندی (از طریق category_id که از products گرفتیم)
JOIN dim_category dc ON p.category_id = dc.category_id
ON CONFLICT (transaction_id) DO NOTHING;   -- اگر تراکنش تکراری بود، نادیده بگیر

-- ***************************************************************
-- بخش ۶: بررسی نهایی (چند کوئری برای اطمینان)
-- ***************************************************************

-- شمارش رکوردهای هر جدول
SELECT 'dim_product' AS "نام جدول", COUNT(*) AS "تعداد رکورد" FROM dim_product
UNION ALL
SELECT 'dim_store', COUNT(*) FROM dim_store
UNION ALL
SELECT 'dim_time', COUNT(*) FROM dim_time
UNION ALL
SELECT 'dim_category', COUNT(*) FROM dim_category
UNION ALL
SELECT 'fact_sales', COUNT(*) FROM fact_sales;

-- نمایش ۵ رکورد اول از Fact_Sales (برای اینکه ببینید درست پر شده)
SELECT 
    fs.sales_key,
    dp.product_name,
    ds.store_name,
    dt.full_date AS sale_date,
    fs.quantity_sold,
    fs.total_amount
FROM fact_sales fs
JOIN dim_product dp ON fs.product_key = dp.product_key
JOIN dim_store ds ON fs.store_key = ds.store_key
JOIN dim_time dt ON fs.time_key = dt.time_key
LIMIT 5;