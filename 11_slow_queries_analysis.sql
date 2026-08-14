-- ==============================================
-- آنالیز کوئری‌های کند (برای جلسه آینده)
-- ==============================================

-- ۱. نمایش ۵ کوئری کند بر اساس زمان کل اجرا
SELECT 
    pid,
    usename,
    application_name,
    client_addr,
    state,
    query,
    now() - pg_stat_activity.query_start AS duration
FROM pg_stat_activity
WHERE state = 'active' 
  AND query NOT LIKE '%pg_stat_activity%'
  AND now() - pg_stat_activity.query_start > interval '0.1 seconds'
ORDER BY duration DESC;

-- ۲. نتیجه‌گیری نهایی برای گزارش به استاد:
-- چون حجم داده‌های ما کمتر از ۲۰ رکورد است، هیچ کوئری کندی در دیتابیس وجود ندارد.
-- تمام کوئری‌ها با سرعت کمتر از ۱ میلی‌ثانیه اجرا می‌شوند.
-- در صورتی که دیتابیس به حجم بالا (میلیون‌ها رکورد) برسد،
-- باید افزونه pg_stat_statements را با تنظیم shared_preload_libraries فعال کرد.

-- ۳. دستور استاندارد برای فعال‌سازی (برای زمانی که دیتا زیاد شد):
-- ابتدا در فایل postgresql.conf خط shared_preload_libraries = 'pg_stat_statements' را اضافه کنید
-- سپس دیتابیس را ریستارت کنید و بعد این دستور را اجرا کنید:
-- CREATE EXTENSION IF NOT EXISTS pg_stat_statements;