-- If you haven't added these yet, run them ONCE (comment out if they already exist)
--ALTER TABLE fact_visits    ADD COLUMN spend_cents_clean   INTEGER;
--ALTER TABLE fact_purchases ADD COLUMN amount_cents_clean  INTEGER;



-- Visits: compute cleaned once, join by rowid, update when cleaned is non-empty.. I RAN IT ONCE 
WITH c AS (
    SELECT rowid AS rid,
           REPLACE(REPLACE(REPLACE(REPLACE(UPPER(COALESCE(total_spend_cents, '') ), 'USD', ''), '$', ''), ',', ''), ' ', '') AS cleaned
      FROM fact_visits
)
UPDATE fact_visits
   SET spend_cents_clean = CAST ( (
           SELECT cleaned
             FROM c
            WHERE c.rid = fact_visits.rowid
       )
       AS INTEGER) 
 WHERE LENGTH( (
                   SELECT cleaned
                     FROM c
                    WHERE c.rid = fact_visits.rowid
               )
       ) > 0;

-- Purchases: same pattern (WRITE THE SAME CODE ABOVE for the fact_purchases table)  
-- Remember facts_visits and facts_purchases has the `amount` column in units of cents so you may need to do another SELECT statement to convert these columns to dollars
-- Purchases: clean the RAW text column, write to *_clean
WITH c AS (
  SELECT
    rowid AS rid,
    REPLACE(
      REPLACE(
        REPLACE(
          REPLACE(UPPER(COALESCE(amount_cents, '')), 'USD',''),
        '$',''),
      ',',''),
    ' ','') AS cleaned
  FROM fact_purchases
)
UPDATE fact_purchases
SET amount_cents_clean = CAST(
      (SELECT cleaned FROM c WHERE c.rid = fact_purchases.rowid) AS INTEGER
    )
WHERE LENGTH((SELECT cleaned FROM c WHERE c.rid = fact_purchases.rowid)) > 0;


--convert to dollars
SELECT 
    purchase_id,
    amount_cents_clean,
    ROUND(amount_cents_clean / 100.0, 2) AS amount_dollars
FROM fact_purchases
LIMIT 15;



-- Visits for checking purposes
SELECT COUNT(*) AS filled_rows 
FROM fact_visits 
WHERE spend_cents_clean IS NOT NULL;


-- Purchases for checking purposes 
SELECT COUNT(*) AS filled_rows 
FROM fact_purchases 
WHERE amount_cents_clean IS NOT NULL;



-- B) Exact duplicates
/*
Exact duplicates: every column in a row matches across rows. 
Detect with GROUP BY all_columns HAVING COUNT(*)>1.
Hint:  Start with a query that just counts up how many duplicates 
are in the fact_ride_events table (comment how many duplicates you found in your code)
Think:  If there are duplicates how can you decide which one to keep?  
Is there a way you could code this in SQL? Add your thoughts as a comment in your .sql file 
*/ 


/*
There are 8 rows that are duplicates, I can decide to keep 1 because they are
the same exact rows, so for each i'll just keep one 
*/

SELECT visit_id,
       attraction_id,
       ride_time,
       wait_minutes,
       satisfaction_rating,
       photo_purchase,
       COUNT( * ) AS duplicate_count
  FROM fact_ride_events
 GROUP BY visit_id,
          attraction_id,
          ride_time,
          wait_minutes,
          satisfaction_rating,
          photo_purchase
HAVING COUNT( * ) > 1;

-- The total number of duplicates(returns a single value)
/* DOCUMENTATION  
Query explained: I use a CTE to group all the columns in fact_ride_events and count 
how many times each row repeats. If a row shows up more than once, 
it’s a duplicate. In the second query, I subtract 1 from each count 
(because the first copy is the “real” one) to find only the extra copies. 
Finally, I sum those up to get the total number of duplicate rows in the table.
*/

WITH d AS (
  SELECT
    visit_id, attraction_id, ride_time, wait_minutes, satisfaction_rating, photo_purchase,
    COUNT(*) AS c
  FROM fact_ride_events
  GROUP BY visit_id, attraction_id, ride_time, wait_minutes, satisfaction_rating, photo_purchase
  HAVING COUNT(*) > 1
)
SELECT SUM(c - 1) AS total_duplicate_rows
FROM d;

-- I'm going to start with the view approach (non-destructive, I don't want to accidentally delete data)
CREATE VIEW fact_ride_events_dupe AS
WITH ranked AS (
  SELECT *,
         ROW_NUMBER() OVER (
           PARTITION BY visit_id, attraction_id, ride_time, wait_minutes, satisfaction_rating, photo_purchase
           ORDER BY ride_event_id
         ) AS rn
  FROM fact_ride_events
)
SELECT *
FROM ranked
WHERE rn = 1;

SELECT *
FROM fact_ride_events_dupe
LIMIT 10;


--Confirmed no duplicates remain, now rows printed
SELECT visit_id,
       attraction_id,
       ride_time,
       wait_minutes,
       satisfaction_rating,
       photo_purchase,
       COUNT( * ) 
  FROM fact_ride_events_dupe
 GROUP BY visit_id,
          attraction_id,
          ride_time,
          wait_minutes,
          satisfaction_rating,
          photo_purchase
HAVING COUNT( * ) > 1;

/* DOCUMENTATION SUMMARY FOR DUPLICATES:
Instead of permanently deleting rows, I created a view to handle 
duplicates in a non-destructive way. This means the original data stays intact,
but I can still query a “cleaned” version without the duplicate rows.
*/




--5c: Validate keys 
/*
I approached this step by following the example 
given and applied it to my schema map. For each primary key–foreign key relationship in my schema, 
I wrote queries to check for orphans (child rows without a matching parent). I validated the five main cases:
*/

--Case 1: visits without a matching guest
SELECT COUNT(*) AS orphan_visit_ticket_types
FROM fact_visits fv
LEFT JOIN dim_guest dg ON dg.guest_id = fv.guest_id
WHERE dg.guest_id IS NULL;


--CASE 2: visits with a ticket_type_id that has no match in dim_ticket
SELECT COUNT(*) AS orphan_visit_ticket_types
FROM fact_visits fv
LEFT JOIN dim_ticket dt ON dt.ticket_type_id = fv.ticket_type_id
WHERE dt.ticket_type_id IS NULL;

--CASE 3: purchases with a visit_id that has no match in fact_visits
SELECT COUNT(*) AS orphan_purchases
FROM fact_purchases fp
LEFT JOIN fact_visits fv ON fv.visit_id = fp.visit_id
WHERE fv.visit_id IS NULL;


--CASE 4: ride events with a visit_id that has no match in fact_visits
SELECT COUNT(*) AS orphan_ride_events
FROM fact_ride_events fre
LEFT JOIN fact_visits fv ON fv.visit_id = fre.visit_id
WHERE fv.visit_id IS NULL;


--CASE 5: ride events with an attraction_id that has no match in dim_attraction
SELECT COUNT(*) AS orphan_ride_attractions
FROM fact_ride_events fre
LEFT JOIN dim_attraction da ON da.attraction_id = fre.attraction_id
WHERE da.attraction_id IS NULL;



-- D) Handling missing 
/*
DOCUMENTATION: 
I checked for empty string placeholders in text fields like promotion_code and replaced them with NULL. 
No updates were needed because missing values were already stored as NULL. 
For analysis, I will exclude rows with NULL in essential fields (like spend, wait_minutes, satisfaction_rating). 
Non-essential text fields (promotion_code, home_state) will be left as NULL without imputation.
*/

UPDATE fact_visits
SET promotion_code = NULL
WHERE TRIM(promotion_code) = '';




--standarization 
/*
DOCUMENTATION
I standardized categorical/text fields by applying TRIM to remove extra spaces and UPPER to 
enforce consistent casing. This was applied to home_state, promotion_code, payment_method, category, 
and item_name. NULL values were left unchanged. This ensures consistency without altering the underlying 
meaning of the data
*/

UPDATE dim_guest
SET home_state = UPPER(TRIM(home_state))
WHERE home_state IS NOT NULL;

UPDATE fact_visits
SET promotion_code = REPLACE(UPPER(TRIM(promotion_code)), '-', '')
WHERE promotion_code IS NOT NULL;

SELECT promotion_code
FROM fact_visits;


UPDATE fact_purchases
SET payment_method = UPPER(TRIM(payment_method))
WHERE payment_method IS NOT NULL;

UPDATE fact_purchases
SET category = (TRIM(category))
WHERE category IS NOT NULL;

UPDATE fact_purchases
SET item_name = (TRIM(item_name))
WHERE item_name IS NOT NULL;

