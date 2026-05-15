-- Sales performance analysis
-- 2 years of data, 5 product lines
-- feeding into Power BI dashboard


-- overall sales summary by product line and year
SELECT
    product_line,
    EXTRACT(YEAR FROM order_date) AS year,
    COUNT(DISTINCT order_id) AS orders,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(SUM(revenue), 2) AS total_revenue,
    ROUND(SUM(revenue) - SUM(cogs), 2) AS gross_profit,
    ROUND(100.0 * (SUM(revenue) - SUM(cogs)) / NULLIF(SUM(revenue), 0), 1) AS margin_pct
FROM sales
GROUP BY product_line, EXTRACT(YEAR FROM order_date)
ORDER BY product_line, year;


-- monthly revenue trend with running total and MoM growth
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', order_date) AS month,
        ROUND(SUM(revenue), 2) AS monthly_revenue
    FROM sales
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT
    TO_CHAR(month, 'YYYY-MM') AS month,
    monthly_revenue,
    SUM(monthly_revenue) OVER (ORDER BY month) AS running_total,
    LAG(monthly_revenue) OVER (ORDER BY month) AS prev_month_revenue,
    ROUND(
        100.0 * (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY month))
        / NULLIF(LAG(monthly_revenue) OVER (ORDER BY month), 0),
        1
    ) AS mom_growth_pct
FROM monthly
ORDER BY month;


-- SKU performance - sell-through rate vs margin
-- this is where the underperforming SKUs showed up
WITH sku_metrics AS (
    SELECT
        s.sku_id,
        p.product_name,
        p.product_line,
        p.category,
        SUM(s.units_sold) AS units_sold,
        SUM(i.units_available) AS units_available,
        ROUND(SUM(s.revenue), 2) AS revenue,
        ROUND(SUM(s.revenue) - SUM(s.cogs), 2) AS gross_profit,
        ROUND(100.0 * (SUM(s.revenue) - SUM(s.cogs)) / NULLIF(SUM(s.revenue), 0), 1) AS margin_pct,
        ROUND(100.0 * SUM(s.units_sold) / NULLIF(SUM(i.units_available), 0), 1) AS sell_through_pct
    FROM sales s
    JOIN products p ON s.sku_id = p.sku_id
    LEFT JOIN inventory i ON s.sku_id = i.sku_id
    GROUP BY s.sku_id, p.product_name, p.product_line, p.category
)
SELECT
    *,
    -- flag underperformers: high revenue but low margin OR low sell-through
    CASE
        WHEN margin_pct < 15 AND revenue > 50000 THEN 'High Revenue / Low Margin'
        WHEN sell_through_pct < 30 THEN 'Low Sell-Through'
        WHEN margin_pct < 10 THEN 'Low Margin'
        ELSE 'OK'
    END AS performance_flag
FROM sku_metrics
ORDER BY revenue DESC;


-- regional performance breakdown
SELECT
    region,
    channel,
    COUNT(DISTINCT order_id) AS orders,
    ROUND(SUM(revenue), 2) AS revenue,
    ROUND(AVG(order_value), 2) AS avg_order_value,
    ROUND(100.0 * SUM(returns_value) / NULLIF(SUM(revenue), 0), 1) AS return_rate_pct
FROM sales s
JOIN customers c USING (customer_id)
GROUP BY region, channel
ORDER BY revenue DESC;


-- YoY comparison by product line
WITH yearly AS (
    SELECT
        product_line,
        EXTRACT(YEAR FROM order_date) AS yr,
        SUM(revenue) AS revenue
    FROM sales
    GROUP BY product_line, EXTRACT(YEAR FROM order_date)
)
SELECT
    a.product_line,
    a.yr AS current_year,
    ROUND(a.revenue, 2) AS current_revenue,
    ROUND(b.revenue, 2) AS prior_revenue,
    ROUND(100.0 * (a.revenue - b.revenue) / NULLIF(b.revenue, 0), 1) AS yoy_growth_pct
FROM yearly a
LEFT JOIN yearly b
    ON a.product_line = b.product_line
    AND a.yr = b.yr + 1
ORDER BY a.product_line, a.yr;


-- customer repeat purchase rate by channel
-- wanted to see which channels drive loyal vs one-time buyers
WITH order_counts AS (
    SELECT
        customer_id,
        channel,
        COUNT(DISTINCT order_id) AS total_orders
    FROM sales
    GROUP BY customer_id, channel
)
SELECT
    channel,
    COUNT(*) AS customers,
    SUM(CASE WHEN total_orders = 1 THEN 1 ELSE 0 END) AS one_time_buyers,
    SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) AS repeat_buyers,
    ROUND(100.0 * SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS repeat_rate_pct
FROM order_counts
GROUP BY channel
ORDER BY repeat_rate_pct DESC;
