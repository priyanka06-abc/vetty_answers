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

