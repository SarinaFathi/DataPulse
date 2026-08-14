# مستندسازی ایندکس‌های دیتابیس DataPulse (تیم دوم - نقش ETL)

**تاریخ:** ۱۴۰۵/۰۵/۲۳  
**توسعه‌دهنده:** سارینا فتحی

---

## ۱. گزارش استفاده از ایندکس‌ها (بر اساس `pg_stat_user_indexes`)

| نام جدول | نام ایندکس | تعداد استفاده (`idx_scan`) | حجم |
| :--- | :--- | :--- | :--- |
| stores | stores_pkey | 331 | 16 kB |
| categories | categories_pkey | 247 | 16 kB |
| inventory | idx_inventory_product_id | 70 | 16 kB |
| products | idx_products_category_id | 24 | 16 kB |
| products | idx_products_status | 22 | 16 kB |
| products | products_pkey | 11 | 16 kB |
| products | idx_products_store_id | 3 | 16 kB |
| products | idx_products_store_price_status | **0** | 16 kB |
| products | idx_products_category_store | **0** | 16 kB |
| inventory | idx_inventory_covering | **0** | 16 kB |
| products | products_sku_key | 0 | 16 kB |
| test | test_pkey | 0 | 16 kB |
| staging_raw_imports | staging_raw_imports_pkey | 0 | 16 kB |
| mv_store_category_inventory_report | idx_mv_store_category | 0 | 16 kB |

---

## ۲. تحلیل ایندکس‌های استفاده‌نشده (با `idx_scan = 0`)

چرا ایندکس‌های جدید (مثل `idx_products_store_price_status`) استفاده نشدند؟

**دلیل:** در حال حاضر حجم داده‌های دیتابیس بسیار کم است (حدود ۲۰ رکورد). PostgreSQL برای داده‌های کم‌حجم، **Sequential Scan** (اسکن کامل جدول) را به **Index Scan** ترجیح می‌دهد زیرا هزینه‌ی کمتری دارد. با افزایش حجم داده به بیش از چند هزار رکورد، این ایندکس‌ها به‌طور خودکار فعال می‌شوند و عملکرد را به شدت بهبود می‌بخشند.

**نتیجه‌گیری:** این ایندکس‌ها برای پروژه‌های واقعی با داده‌های انبوه طراحی شده‌اند و فعلاً نگهداری می‌شوند.

---

## ۳. ایندکس‌های قابل حذف (اختیاری)

- **`test_pkey`**: مربوط به جدول تست جلسه اول است و دیگر استفاده نمی‌شود. در صورت نیاز می‌توان آن را حذف کرد:
  ```sql
  DROP INDEX test_pkey;