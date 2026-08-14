-- ۱. ایندکس ترکیبی برای سرعت بخشیدن به رتبه‌بندی قیمت در هر فروشگاه
-- (مخصوص Window Function با PARTITION BY store_id و ORDER BY price)
CREATE INDEX idx_products_store_price_status ON products(store_id, price DESC, status);

-- ۲. ایندکس ترکیبی برای کوئری‌های GROUP BY روی دسته‌بندی و فروشگاه
-- (مخصوص کوئری ROLLUP و CTEهای تحلیلی)
CREATE INDEX idx_products_category_store ON products(category_id, store_id);

-- ۳. ایندکس Covering برای جدول موجودی (تا دیگه نیازی به مراجعه به جدول اصلی نباشه)
-- (شامل product_id و quantity برای محاسبات سریع ارزش موجودی)
CREATE INDEX idx_inventory_covering ON inventory(product_id) INCLUDE (quantity, last_updated);