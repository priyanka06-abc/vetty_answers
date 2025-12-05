/* ===========================================================
   SQL Assignment Answers
   Dataset: transactions, items
   Assumptions:
     - purchase_time and refund_item are castable to TIMESTAMP
     - refund can be processed only if refund_time - purchase_time ≤ 72 hours
   =========================================================== */


/* -----------------------------------------------------------
1. Count of Purchases Per Month (Excluding Refunded purchases)
Goal: Count transactions grouped by the month and year of the purchase, excluding any transaction that had a refund (refund_item IS NULL).
----------------------------------------------------------- */


SELECT
    -- Extract Year and Month (e.g., '2019-09')
    STRFTIME('%Y-%m', t.purchase_time) AS purchase_month,
    COUNT(t.buyer_id) AS purchase_count
FROM
    transactions AS t
WHERE
    t.refund_item IS NULL -- Exclude refunded purchases
GROUP BY
    purchase_month
ORDER BY
    purchase_month;

/* -----------------------------------------------------------
2. Number of Stores with at Least 5 Orders in October 2020
Goal: Identify how many distinct stores recorded 5 or more transactions during the month of October 2020.
----------------------------------------------------------- */


SELECT
    COUNT(temp.store_id) AS stores_with_5_plus_orders
FROM (
    SELECT
        t.store_id,
        COUNT(t.buyer_id) AS order_count
    FROM
        transactions AS t
    WHERE
        -- Filter for all of October 2020
        t.purchase_time >= '2020-10-01 00:00:00' AND t.purchase_time < '2020-11-01 00:00:00'
    GROUP BY
        t.store_id
    HAVING
        order_count >= 5 -- Keep only stores with 5 or more orders
) AS temp;

/* -----------------------------------------------------------
Manual Verification: Looking at the provided data, only one transaction occurred in October 2020 (Buyer 1 on 2020-10-22). Since there is only 1 total transaction, no store meets the criterion of having 5 or more orders.

Answer: 0
----------------------------------------------------------- */

/* -----------------------------------------------------------
3. Shortest Interval (in min) from Purchase to Refund Time for Each Store
Goal: Calculate the shortest duration (in minutes) between the purchase_time and refund_item for each store that processed a refund.
----------------------------------------------------------- */

SELECT
    t.store_id,
    -- Find the minimum time difference (in minutes) for each store
    MIN(
        -- Calculate the difference in seconds, then convert to minutes
        (JULIANDAY(t.refund_item) - JULIANDAY(t.purchase_time)) * 24 * 60
        -- Note: The function for time difference varies by SQL dialect.
        -- Use TIMESTAMPDIFF(MINUTE, t.purchase_time, t.refund_item) for MySQL,
        -- or EXTRACT(EPOCH FROM (t.refund_item - t.purchase_time)) / 60 for PostgreSQL.
    ) AS shortest_refund_interval_minutes
FROM
    transactions AS t
WHERE
    t.refund_item IS NOT NULL -- Only consider transactions with a refund
GROUP BY
    t.store_id
ORDER BY
    t.store_id;

/* -----------------------------------------------------------
