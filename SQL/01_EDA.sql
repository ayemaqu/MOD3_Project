-- Q0: Row counts per table
SELECT 'dim_guest' AS table_name, COUNT(*) AS n FROM dim_guest
UNION ALL SELECT 'dim_ticket', COUNT(*) FROM dim_ticket
UNION ALL SELECT 'dim_attraction', COUNT(*) FROM dim_attraction
UNION ALL SELECT 'fact_visits', COUNT(*) FROM fact_visits
UNION ALL SELECT 'fact_ride_events', COUNT(*) FROM fact_ride_events
UNION ALL SELECT 'fact_purchases', COUNT(*) FROM fact_purchases;

--Q1. Date range of visit_date; number of distinct dates; visits per date(use GROUP BY + ORDER BY).
/* 
DOCUMENTATION:
    To get the range of the dates, I found the first date and 
    last date to show the "range" and the number of distinct dates we have
 
     I then did a seperate SELECT statement to show the number of visits for each date.
     I grouped it by visit_date so the query counts visits separately for each date 
     instead of all together
     
*/

SELECT MIN(visit_date) AS first_date,
       MAX(visit_date) AS last_date,
       COUNT(DISTINCT visit_date) AS distinct_dates
FROM fact_visits;

SELECT visit_date, COUNT (*) AS num_of_visits
FROM fact_visits
GROUP BY visit_date
ORDER BY visit_date;

--Q2. Visits by ticket_type_name (join to dim_ticket), ordered by most to least.

/* 
DOCUMENTATION 
    INNER JOIN → only ticket types that actually appear in fact_visits will show up 
    (which is fine since all 3 types were used, you can also use LEFT JOIN).
    GROUP BY ticket_type_name → correctly groups visits per ticket type.
    COUNT(visit_id) → counts visits.

ORDER BY num_of_visits DESC → sorts from most used ticket type to least.*/
SELECT ticket_type_name, COUNT(visit_id) AS num_of_visits
FROM dim_ticket dt
INNER JOIN fact_visits fv ON fv.ticket_type_id = dt.ticket_type_id
GROUP BY ticket_type_name
ORDER BY num_of_visits DESC;


-- Q3. Distribution of wait_minutes (include NULL count separately).

/*
 DOCUMENTATION
     I had to first figure out what the question meant by "Distribution", I thought it meant
     sum the number of minutes but that's not useful in this case. I learned that it mean, finding
     the: avg, min and max 
     
    Then, I found the count of wait_minutes cases its null and not null specifically  
 
*/
SELECT MAX(wait_minutes) AS max_wait,
       MIN(wait_minutes) AS min_wait,
       AVG(wait_minutes) AS avg_wait
  FROM fact_ride_events;


SELECT COUNT( * ) AS total_rows,
       COUNT(wait_minutes) AS non_null_rows,
       SUM(CASE WHEN wait_minutes IS NULL THEN 1 ELSE 0 END) AS null_rows
  FROM fact_ride_events;


--After doing the above two queries I thought to myself, a distribution means the spread of the data
--Which reminded me of a histogram, and I thought of putting the wait times in group bins and calculating the count for each
/*
0–15 (short wait)
16–30 (moderate wait)
31–60 (long wait)
61+ (disney lines be like)
*/
/*
If wait_minutes is between 0 and 15, label it as '0-15'
If between 16 and 30, then'16-30' ... etc
If it’s NULL label it 'NULL'
*/
SELECT
  CASE
    WHEN wait_minutes IS NULL THEN 'NULL'
    WHEN wait_minutes >= 0  AND wait_minutes <= 15 THEN '0-15'
    WHEN wait_minutes >= 16 AND wait_minutes <= 30 THEN '16-30'
    WHEN wait_minutes >= 31 AND wait_minutes <= 60 THEN '31-60'
    WHEN wait_minutes >= 61 THEN '60+'
  END AS wait_bins,
  COUNT(*) AS num_events
FROM fact_ride_events
GROUP BY wait_bins
ORDER BY wait_bins;

--Q4. Average satisfaction_rating by attraction_name and by category.

SELECT ROUND(AVG(satisfaction_rating),2) AS avg_ratings , da.attraction_name, da.category
FROM fact_ride_events fre
LEFT JOIN dim_attraction da ON da.attraction_id = fre.attraction_id
GROUP BY da.attraction_name, da.category
ORDER BY category, attraction_name, avg_ratings;


-- Q5. Duplicates check: exact duplicate fact_ride_events rows (match on all columns)with counts.
-- so find the count of dupliate rows, make sure to leave out PK, I used having to set a 
-- condition since you cannot use where with groupby

/*
DOCUMENTATION
In the result, these exact combination appears twice in fact_ride_events.
In other words, duplicate_count tells you how many times that exact combo shows up, 
hence 8 rows showed up twice 
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


--Q6. Null audit for key columns you care about (report counts).

/*
What does a Null audit even mean T_T ?
A = it means check how many missing values you have in the important columns.
DOCUMENTATION FOR QUERY:
Pick the key columns I care about(like IDs, dates) 
and write queries to count how many of those are missing...
*/

-- Null audit for guest info... only 1 missing in marketing_opt_in
SELECT
  COUNT(*) AS total_rows,
  SUM(CASE WHEN birthdate IS NULL THEN 1 ELSE 0 END) AS null_birthdate,
  SUM(CASE WHEN home_state IS NULL THEN 1 ELSE 0 END) AS null_home_state,
  SUM(CASE WHEN marketing_opt_in IS NULL THEN 1 ELSE 0 END) AS null_marketing_opt_in
FROM dim_guest;

-- Null audit for attraction info... There are no nulls 
SELECT
  COUNT(*) AS total_rows,
  SUM(CASE WHEN category IS NULL THEN 1 ELSE 0 END) AS null_category,
  SUM(CASE WHEN min_height_cm IS NULL THEN 1 ELSE 0 END) AS null_min_height,
  SUM(CASE WHEN opened_date IS NULL THEN 1 ELSE 0 END) AS null_opened_date,
  SUM(CASE WHEN attraction_name IS NULL THEN 1 ELSE 0 END) AS null_attraciton_name
FROM dim_attraction;

-- Null audit for fact_purchases
SELECT
  COUNT(*) AS total_rows,
  SUM(CASE WHEN category IS NULL THEN 1 ELSE 0 END) AS null_category,
  SUM(CASE WHEN item_name IS NULL THEN 1 ELSE 0 END) AS null_item_name,
  SUM(CASE WHEN amount_cents IS NULL THEN 1 ELSE 0 END) AS null_amount_cents,
  SUM(CASE WHEN amount_cents_clean IS NULL THEN 1 ELSE 0 END) AS null_amount_cents_clean,
  SUM(CASE WHEN payment_method IS NULL THEN 1 ELSE 0 END) AS null_payment_method
FROM fact_purchases;


--Null audit for dim_ticket... there are no nulls 
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN ticket_type_name IS NULL THEN 1 ELSE 0 END) AS null_ticket_type_name,
    SUM(CASE WHEN base_price_cents IS NULL THEN 1 ELSE 0 END) AS null_base_price_cents,
    SUM(CASE WHEN restrictions IS NULL THEN 1 ELSE 0 END) AS null_restrictions
FROM dim_ticket;

--Null audit for fat_ride_events
/*
50% of wait_minutes fieldsa are nulls 
35% of photo_purchases fields are nulls 

*/
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN ride_time IS NULL THEN 1 ELSE 0 END) AS null_ride_time,
    SUM(CASE WHEN wait_minutes IS NULL THEN 1 ELSE 0 END) AS null_wait_minutes,
    SUM(CASE WHEN satisfaction_rating IS NULL THEN 1 ELSE 0 END) AS null_satisfaction_rating,
    SUM(CASE WHEN photo_purchase IS NULL THEN 1 ELSE 0 END) AS null_photo_purchase,
    ROUND(100.0 * SUM(CASE WHEN wait_minutes IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_null_waittime,
    ROUND(100.0 * SUM(CASE WHEN photo_purchase IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_null_photo_purchase
FROM fact_ride_events;

--Null audit for fact_visits
/*
21% nulls for total_spend_cents
14% nulls for promotion_code
21% nulls for spend_cents_clean
*/
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN party_size IS NULL THEN 1 ELSE 0 END) AS null_party_size,
    SUM(CASE WHEN entry_time IS NULL THEN 1 ELSE 0 END) AS null_entry_time,
    SUM(CASE WHEN exit_time IS NULL THEN 1 ELSE 0 END) AS null_exit_time,
    SUM(CASE WHEN total_spend_cents IS NULL THEN 1 ELSE 0 END) AS null_total_spend_cents,
    SUM(CASE WHEN promotion_code IS NULL THEN 1 ELSE 0 END) AS null_promotion_code,
    SUM(CASE WHEN spend_cents_clean IS NULL THEN 1 ELSE 0 END) AS null_spend_cents_clean,
    ROUND(100.00 * SUM(CASE WHEN total_spend_cents IS NULL THEN 1 ELSE 0 END) / COUNT (*), 2) AS pct_null_totat_spend,
    ROUND(100.00 * SUM(CASE WHEN promotion_code is NULL THEN 1 ELSE 0 END) / COUNT (*), 2) AS pct_null_promotion_code,
    ROUND(100.00 * SUM(CASE WHEN spend_cents_clean is NULL THEN 1 ELSE 0 END) / COUNT (*), 2) AS pct_null_spend_cents_clean
FROM fact_visits;

--NULL audit for dim_date... there isnt any 
SELECT 
    COUNT(*) as total_rows,
    SUM(CASE WHEN day_name IS NULL THEN 1 ELSE 0 END) AS null_day_name,
    SUM(CASE WHEN is_weekend IS NULL THEN 1 ELSE 0 END) AS null_is_weekend,
    SUM(CASE WHEN season IS NULL THEN 1 ELSE 0 END) AS nullseason
FROM dim_date;

-- Q7. Average party_size by day of week (dim_date.day_name)/
/*
For this query, I wanted to display the average party size by day of the week. 
To do this, I joined fact_visits with dim_date so I could use the weekday names 
from the date dimension. I then grouped the results by day_name to calculate the 
average party size for each day. Finally, since SQLite doesn’t have a built-in 
function to order days of the week(SMH), I used an ORDER BY CASE statement to arrange 
the results from Monday through Sunday in the correct order.
*/
SELECT ROUND(AVG(fv.party_size),2) as avg_party_size, dd.day_name
FROM fact_visits fv
LEFT JOIN dim_date dd ON dd.date_id = fv.date_id
GROUP BY dd.day_name
ORDER BY CASE dd.day_name
    WHEN 'Monday' THEN 1
    WHEN 'Tuesday' THEN 2
    WHEN 'Wednesday' THEN 3
    WHEN 'Thursday' THEN 4
    WHEN 'Friday' THEN 5
    WHEN 'Saturday' THEN 6
    WHEN 'Sunday' THEN 7
END;



