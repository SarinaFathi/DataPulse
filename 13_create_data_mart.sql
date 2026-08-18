-- ============================================================
-- ساخت دیتا مارت فروش - DataPulse (تیم دوم - نقش ETL)
-- نام: سارینا فتحی‪
-- تاریخ: ۱۴۰۵/۰۵/۲۵
-- ============================================================

\c datapulse;

-- *****************************************
-- بخش ۱: جدول‌های بُعد (Dimension Tables)
-- *****************************************

-- ۱. بُعد محصول (Dim_Product)
CREATE TABLE IF NOT EXISTS dim_product (
    product_key SERIAL PRIMARY KEY,        -- کلید سوروگیت (Surrogate Key) برای دیتا مارت
    product_id INT,                        -- کلید اصلی از دیتابیس تراکنشی (Natural Key)
    product_name VARCHAR(255) NOT NULL,
    category_name VARCHAR(100),
    store_name VARCHAR(255),
    price DECIMAL(15, 2),
    status VARCHAR(20),
    created_at TIMESTAMP,
    -- متادیتا برای ETL
    etl_created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    etl_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ۲. بُعد فروشگاه (Dim_Store)
CREATE TABLE IF NOT EXISTS dim_store (
    store_key SERIAL PRIMARY KEY,
    store_id INT,                          -- Natural Key
    store_name VARCHAR(255) NOT NULL,
    address TEXT,
    phone VARCHAR(20),
    created_at TIMESTAMP,
    etl_created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    etl_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ۳. بُعد زمان (Dim_Time) - برای تحلیل‌های زمانی
CREATE TABLE IF NOT EXISTS dim_time (
    time_key SERIAL PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    year INT,
    quarter INT,
    month INT,
    month_name VARCHAR(20),
    day INT,
    day_of_week INT,                       -- 1 = Monday, 7 = Sunday
    day_name VARCHAR(20),
    is_weekend BOOLEAN,
    is_holiday BOOLEAN DEFAULT FALSE
);

-- ۴. بُعد دسته‌بندی (Dim_Category) - برای تحلیل دسته‌ای
CREATE TABLE IF NOT EXISTS dim_category (
    category_key SERIAL PRIMARY KEY,
    category_id INT,                       -- Natural Key
    category_name VARCHAR(100) NOT NULL,
    parent_category_name VARCHAR(100),
    level INT,
    etl_created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- *****************************************
-- بخش ۲: جدول حقیقت (Fact Table)
-- *****************************************

-- ۵. جدول حقیقت فروش (Fact_Sales)
CREATE TABLE IF NOT EXISTS fact_sales (
    sales_key SERIAL PRIMARY KEY,
    -- کلیدهای خارجی به ابعاد (Surrogate Keys)
    product_key INT REFERENCES dim_product(product_key),
    store_key INT REFERENCES dim_store(store_key),
    time_key INT REFERENCES dim_time(time_key),
    category_key INT REFERENCES dim_category(category_key),
    
    -- مقادیر قابل اندازه‌گیری (Measures)
    quantity_sold INT NOT NULL CHECK (quantity_sold > 0),
    unit_price DECIMAL(15, 2) NOT NULL CHECK (unit_price >= 0),
    total_amount DECIMAL(15, 2) NOT NULL CHECK (total_amount >= 0),
    discount_amount DECIMAL(15, 2) DEFAULT 0,
    
    -- متادیتا
    transaction_id INT,                    -- ارجاع به دیتابیس تراکنشی
    sale_date DATE NOT NULL,
    etl_created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- *****************************************
-- بخش ۳: ایندکس‌های دیتا مارت (برای سرعت)
-- *****************************************

-- ایندکس روی کلیدهای خارجی (برای JOINهای سریع)
CREATE INDEX IF NOT EXISTS idx_fact_sales_product ON fact_sales(product_key);
CREATE INDEX IF NOT EXISTS idx_fact_sales_store ON fact_sales(store_key);
CREATE INDEX IF NOT EXISTS idx_fact_sales_time ON fact_sales(time_key);
CREATE INDEX IF NOT EXISTS idx_fact_sales_category ON fact_sales(category_key);

-- ایندکس ترکیبی برای کوئری‌های فروش ماهانه
CREATE INDEX IF NOT EXISTS idx_fact_sales_date_amount ON fact_sales(sale_date, total_amount);

-- ایندکس روی ابعاد برای فیلترهای سریع
CREATE INDEX IF NOT EXISTS idx_dim_product_name ON dim_product(product_name);
CREATE INDEX IF NOT EXISTS idx_dim_store_name ON dim_store(store_name);
CREATE INDEX IF NOT EXISTS idx_dim_time_date ON dim_time(full_date);