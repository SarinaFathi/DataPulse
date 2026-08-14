-- اتصال به دیتابیس
\c datapulse;

-- ==============================================
-- گزارش ایندکس‌های بلااستفاده (برای نگهداری)
-- ==============================================

SELECT 
    schemaname AS شِمای_جدول,
    relname AS نام_جدول,
    indexrelname AS نام_ایندکس,
    idx_scan AS تعداد_استفاده_شده,
    pg_size_pretty(pg_relation_size(indexrelid)) AS حجم_ایندکس
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan ASC, pg_relation_size(indexrelid) DESC;

-- اگر ایندکسی با idx_scan = 0 دیدی، یعنی هیچ‌وقت استفاده نشده و می‌تونی حذفش کنی.
-- مثلاً: DROP INDEX idx_products_category_store;

-- (نکته: تو که دیتای کمی داری، ممکنه بعضی ایندکس‌ها صفر نشون بدن. اون‌ها رو نادیده بگیر)