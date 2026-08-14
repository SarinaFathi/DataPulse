-- کوئری تحلیلی: ارزش کل موجودی هر فروشگاه (قیمت * تعداد) + تعداد محصولات فعال
SELECT 
    s.name AS store_name,
    COUNT(DISTINCT p.id) AS total_active_products,
    SUM(i.quantity) AS total_items_in_stock,
    SUM(p.price * i.quantity) AS total_inventory_value
FROM stores s
JOIN products p ON s.id = p.store_id
JOIN inventory i ON p.id = i.product_id
LEFT JOIN categories c ON p.category_id = c.id
WHERE p.status = 'active'
GROUP BY s.id, s.name
ORDER BY total_inventory_value DESC;

-- کوئری مخصوص نقش ETL: نمایش داده‌های خام که هنوز پردازش نشدن (وضعیت pending)
SELECT 
    id,
    source_system,
    raw_data->>'product_name' AS extracted_name,
    (raw_data->>'price')::BIGINT AS extracted_price,
    imported_at
FROM staging_raw_imports
WHERE status = 'pending';