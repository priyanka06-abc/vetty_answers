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
4. Gross Transaction Value of Every Store's First Order
Goal: Find the transaction value for the very first order placed at each unique store.
----------------------------------------------------------- */


WITH StoreFirstOrder AS (
    SELECT
        t.store_id,
        t.gross_transaction_value,
        -- Rank each transaction within a store, ordered by purchase time
        ROW_NUMBER() OVER (
            PARTITION BY t.store_id
            ORDER BY t.purchase_time
        ) AS transaction_rank
    FROM
        transactions AS t
)
SELECT
    s.store_id,
    s.gross_transaction_value
FROM
    StoreFirstOrder AS s
WHERE
    s.transaction_rank = 1 -- Filter for the first order only
ORDER BY
    s.store_id;

/* -----------------------------------------------------------
5. Most Popular Item Name on Buyers' First Purchase
Goal: Determine which item name appears most frequently among the very first purchases made by each unique buyer.
----------------------------------------------------------- */


WITH BuyerFirstPurchase AS (
    SELECT
        t.store_id,
        t.item_id,
        -- Rank each transaction within a buyer, ordered by purchase time
        ROW_NUMBER() OVER (
            PARTITION BY t.buyer_id
            ORDER BY t.purchase_time
        ) AS transaction_rank
    FROM
        transactions AS t
    -- Filter out transactions where the time is the same to ensure distinct ranking for the earliest time,
    -- though ROW_NUMBER handles ties deterministically.
),
FirstPurchaseItems AS (
    SELECT
        i.item_name
    FROM
        BuyerFirstPurchase AS bfp
    INNER JOIN
        items AS i
        ON bfp.store_id = i.store_id AND bfp.item_id = i.item_id
    WHERE
        bfp.transaction_rank = 1 -- Select only the first purchase
)
SELECT
    fpi.item_name,
    COUNT(fpi.item_name) AS item_count
FROM
    FirstPurchaseItems AS fpi
GROUP BY
    fpi.item_name
ORDER BY
    item_count DESC
LIMIT 1; -- Get the item name with the highest count
/* -----------------------------------------------------------

Result: All items appear only once in the first purchases. Therefore, any of them could be returned, but the query will likely return the item that is alphabetically first (or the first one encountered during grouping) since they all have a count of 1.

Answer: chair, jewelry, lounge chair, airpods, bracelet, and tops all share the highest popularity score of 1. The query above will return one of these items.
----------------------------------------------------------- */

/* -----------------------------------------------------------
Task 6: Refund Processing Flag
Goal: Create a flag in the transactions table indicating if a refund can be processed. The condition is that the refund must happen within 72 hours (3 days) of the purchase_time.
Assuming the time difference is calculated in hours:
----------------------------------------------------------- */

SELECT
    *,
    CASE
        -- Check if refund_item is NOT NULL AND the time difference in hours is <= 72
        WHEN t.refund_item IS NOT NULL AND (
            JULIANDAY(t.refund_item) - JULIANDAY(t.purchase_time)
        ) * 24 * 60 * 60 <= 72 * 60 * 60 -- Calculation might vary based on SQL dialect (e.g., SQLite, MySQL, PostgreSQL)
        -- Using DATEDIFF/TIMESTAMPDIFF for clarity, assuming a dialect that supports it
        -- For MySQL:
        -- TIMESTAMPDIFF(HOUR, t.purchase_time, t.refund_item) <= 72
        -- For PostgreSQL:
        -- EXTRACT(EPOCH FROM (t.refund_item - t.purchase_time)) / 3600 <= 72
        THEN 'Refund Processed'
        ELSE 'Not Processed/No Refund'
    END AS refund_processable_flag
FROM
    transactions AS t;

Note on Time Calculation: The exact function for calculating the difference in hours between two timestamps (t.refund_item and t.purchase_time) varies significantly across SQL databases (e.g., TIMESTAMPDIFF(HOUR, ...) in MySQL, DATE_PART('hour', ...) in PostgreSQL). The conceptual logic remains: calculate the difference and check if it's less than or equal to 72.
/* -----------------------------------------------------------
Task 7: Second Purchase Rank
Goal: Create a rank by buyer_id and filter for only the second purchase per buyer (ignoring refunds).This task requires a Window Function, specifically ROW_NUMBER(), to assign a sequential rank within each group (PARTITION BY buyer_id), ordered by time (ORDER BY purchase_time).
----------------------------------------------------------- */

WITH RankedPurchases AS (
    SELECT
        t.*,
        -- Assign a rank to each purchase for the same buyer, ordered by purchase time
        ROW_NUMBER() OVER (
            PARTITION BY t.buyer_id
            ORDER BY t.purchase_time
        ) AS purchase_rank
    FROM
        transactions AS t
    -- IMPORTANT: Filter out refunded items as requested (refund_item IS NULL)
    WHERE
        t.refund_item IS NULL
)
SELECT
    r.buyer_id,
    r.purchase_time,
    r.store_id,
    r.item_id,
    r.gross_transaction_value
FROM
    RankedPurchases AS r
-- Filter for only the second purchase (rank = 2)
WHERE
    r.purchase_rank = 2;

/* -----------------------------------------------------------




