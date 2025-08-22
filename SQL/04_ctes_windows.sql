/*
Q1:
Daily performance: Build a daily CTE (join fact_visits→dim_date) 
with daily_visits and daily_spend. Add a running total window. 
Identify top 3 peak days. (Interpret for Ops staffing.)
*/

WITH daily AS (
  SELECT
    dd.date_iso,
    dd.day_name,
    COUNT(DISTINCT fv.visit_id)            AS daily_visits,
    SUM(COALESCE(fv.spend_cents_clean,0))  AS daily_spend_cents
  FROM fact_visits fv
  LEFT JOIN dim_date dd
    ON dd.date_id = fv.date_id
  GROUP BY dd.date_iso, dd.day_name
),
daily_with_running AS (
  SELECT
    date_iso,
    day_name,
    daily_visits,
    daily_spend_cents,
    SUM(daily_visits)       OVER (ORDER BY date_iso) AS run_visits, --line up the rows by date
    SUM(daily_spend_cents)  OVER (ORDER BY date_iso) AS run_spend_cents 
  FROM daily
),
ranked AS (
  SELECT
    *,
    DENSE_RANK() OVER (ORDER BY daily_spend_cents DESC) AS r_spend,
    DENSE_RANK() OVER (ORDER BY daily_visits DESC)      AS r_visits
  FROM daily_with_running
)
SELECT date_iso             AS visit_date,            -- clearer name
       day_name             AS weekday,               -- clearer name
       daily_visits         AS visits_today,          -- visits on that day
       daily_spend_cents    AS spend_on_that_day,     -- spend on that day
       run_visits           AS visits_cumulative,     -- total visits so far
       run_spend_cents      AS spend_cumulative,      -- total spend so far
       r_spend              AS rank_by_spend,         -- 1 = top spend day
       r_visits             AS rank_by_visits         -- 1 = busiest day
  FROM ranked
 WHERE r_spend <= 3
 ORDER BY date_iso;-- make sure rows line up in time order



--====================================================================
--DOCUMENTATION FOR Q1:
--I first wrote a plain SELECT that joined fact_visits to dim_date, grouped by date, 
--and calculated daily_visits and daily_spend_cents. Once that worked, 
--I wrapped it into a CTE called daily so you could reuse it. Then I repeated 
--the same process for the running totals: first added the window functions SUM(...) OVER (ORDER BY date_iso) 
--in a plain query, tested it, and then wrapped that into another CTE (daily_with_running). 
--Finally, I  built a third CTE (ranked) to layer on the ranks with DENSE_RANK().
-- So my method was: start plain → test it → wrap in a CTE → build on top step by step.
--====================================================================

--====================================================================
--TL;DR (brief interpertation)
--Busiest day by visits: Monday (10 visits, rank_by_visits = 1).
--Highest‑revenue day: Sunday (₵112,843, rank_by_spend = 1).
--Saturday is solid but behind both on revenue and visits.
--Ops takeaway:
--    Mon = staff for throughput (ride ops, guest services, queues).
--    Sun = staff for spend (food/merch cashiers, mobile‑order runners, photo/upsell).
--    Sat = balanced coverage.
--====================================================================




/*
Q2:
RFM & CLV(Customer Lifetime Value): Define CLV_revenue_proxy = SUM(spend_cents_clean) per guest. 
Compute RFM and rank guests by CLV within home_state using a window function. 
(Interpret which segments to target.)
*/

--I realized my data was getting skewed so I standarized the data again 
UPDATE dim_guest
SET home_state = CASE
  WHEN UPPER(TRIM(home_state)) IN ('CALIFORNIA','CA') THEN 'CA'
  WHEN UPPER(TRIM(home_state)) IN ('NEW YORK','NY')   THEN 'NY'
  WHEN UPPER(TRIM(home_state)) IN ('FLORIDA','FL')    THEN 'FL'
  ELSE UPPER(TRIM(home_state))
END
WHERE home_state IS NOT NULL;


WITH rfm AS (
  SELECT dg.guest_id,
         SUM(fv.spend_cents_clean) as clv_revenue_proxy
  FROM dim_guest dg
  LEFT JOIN fact_visits fv 
    ON fv.guest_id = dg.guest_id
  GROUP BY dg.guest_id
),
--Add Frequency
--How many visits did this guest make?...That means look at the visits grain (one row per visit) to count them
frequency AS (
  SELECT
    guest_id,
    COUNT(*) AS freq   -- or COUNT(DISTINCT visit_id)
  FROM fact_visits
  GROUP BY guest_id
),
--RECENCY: Days since a guest’s most recent visit, measured against the latest date in the dataset
/*
I need
- Their last visit date
- The dataset’s max visit date (same for everyone) because "since" when? Ill need an anchor point.
Recency tells you how fresh a guest’s engagement is.
-A guest with recency = 0 → they came most recently possible → they’re active and probably easier to bring back.
-A guest with recency = 1 → still pretty fresh, came just before the most recent date.
-If you had someone with recency = 60 → they haven’t come in two months → they might be “at risk” of churning
*/

recency AS(
  SELECT DISTINCT
    guest_id,
    MAX(visit_date) OVER (PARTITION BY guest_id) AS last_visit,     -- each guest's most recent visit
    MAX(visit_date) OVER ()                      AS anchor_date,    -- everyones latest date in dataset
    CAST(
      JULIANDAY(MAX(visit_date) OVER ()) 
      - JULIANDAY(MAX(visit_date) OVER (PARTITION BY guest_id))
      AS INTEGER
    ) AS recency_days
  FROM fact_visits
),
--Compute RFM and rank guests by CLV within home_state using a window function. 
combined_rfm_clv AS(
SELECT
  dg.home_state,
  dg.guest_id,
  r.clv_revenue_proxy       AS monetary_cents,
  f.freq                    AS frequency,
  rc.recency_days           AS recency_days
FROM rfm r
LEFT JOIN frequency f  USING (guest_id) --shortcut instead of writint LEFT JOIN frequency f ON r.guest_id = f.guest_id
LEFT JOIN recency rc USING (guest_id)
LEFT JOIN dim_guest dg USING (guest_id)
)
SELECT
  home_state,
  guest_id,
  monetary_cents,
  frequency,
  recency_days,
  RANK() OVER ( PARTITION BY home_state ORDER BY monetary_cents DESC) AS clv_rank_in_state
FROM combined_rfm_clv
ORDER BY home_state, clv_rank_in_state, monetary_cents DESC;


--====================================================================
--DOCUMENTATION FOR Q2
--For the RFM & CLV analysis, I started by calculating Monetary as the total spend per guest 
--(SUM(spend_cents_clean)), which I called clv_revenue_proxy. Next, I built Frequency by counting 
--the number of visits each guest made. For Recency, I used window functions: one MAX(visit_date) 
--per guest to get their last visit, and another global MAX(visit_date) as the anchor to measure how 
--many days ago that was. After testing each piece as a plain query, I wrapped them into separate 
--CTEs and then joined them together with guest info from dim_guest. Finally, I ranked guests by their 
--CLV within each home_state using a RANK() OVER (PARTITION BY home_state ORDER BY monetary_cents DESC). 
--This gave me one table with Recency, Frequency, Monetary, and state-level CLV ranks to identify which 
--guest segments are most valuable to target.
--====================================================================


--====================================================================
--TL;DR (brief interpertation)
--This analysis shows each guest’s Recency, Frequency, and Monetary (RFM) scores, 
--and ranks them by spending within their home state. Guests with rank 1 are top 
--spenders in their state, especially those with recent visits and high frequency, 
--making them prime targets for loyalty perks or premium offers.
--====================================================================



/*
Q3:Behavior change: Using LAG(spend_cents_clean) per guest (ordered by visit date), 
compute delta vs. prior visit. What share increased? (Interpret what factors correlate with increases—ticket type, 
day, party size.)
*/

WITH lagged AS (
  SELECT
    fv.guest_id,
    fv.visit_date,
    fv.spend_cents_clean AS curr_spend, --amount spend on this visit
    LAG(fv.spend_cents_clean) OVER (
      PARTITION BY fv.guest_id ORDER BY fv.visit_date
    ) AS prev_spend,
    (fv.spend_cents_clean
       - LAG(fv.spend_cents_clean) OVER (
           PARTITION BY fv.guest_id ORDER BY fv.visit_date
         )
    ) AS delta_spend,
    dd.day_name,
    fv.party_size,
    dt.ticket_type_name
  FROM fact_visits fv
  LEFT JOIN dim_ticket dt USING (ticket_type_id)
  LEFT JOIN dim_date   dd USING (date_id)
)

-- Overall share: among visits that HAVE a prior visit, what % spent more?
SELECT
  -- count of visits that have a prior visit to compare
  SUM(CASE WHEN prev_spend IS NOT NULL THEN 1 ELSE 0 END) AS previous_visit_spends,
  -- count of those where spending increased vs prior visit
  SUM(CASE WHEN prev_spend IS NOT NULL AND delta_spend > 0 THEN 1 ELSE 0 END) AS delta_visits_spend,
ROUND(
  100.0 * SUM(CASE WHEN prev_spend IS NOT NULL AND delta_spend > 0 THEN 1 ELSE 0 END)
       / NULLIF(SUM(CASE WHEN prev_spend IS NOT NULL THEN 1 ELSE 0 END), 0),
  1
) AS share_repeat_visit_pct
FROM lagged;


--====================================================================
--DOCUMENTATION FOR Q3
--In this query, I wanted to understand how guests’ spending changes when 
--they return to the park. First, I used a CTE (lagged) to line up each 
--guest’s visits in order and bring in the amount they spent on the current 
--visit (curr_spend). With the LAG() window function, I pulled in the previous 
--visit’s spend (prev_spend) for the same guest. From there, I calculated delta_spend 
--as the difference between current and previous spend, which tells me if a 
--guest spent more, less, or the same compared to their last trip. In the final 
--SELECT, I counted how many visits had a prior visit to compare against 
--(previous_visit_spends), and of those, how many showed an increase in spending
--(delta_visits_spend). Finally, I divided the two to calculate the percentage of 
--return visits where spending went up (share_repeat_visit_pct). This gives me a 
--simple way to measure behavior change: in other words, what share of repeat visits 
--are actually spending more money than before.
--====================================================================

--====================================================================
--TL;DR (brief interpertation)
--Out of 30 repeatable visits, 13 guests spent more on their next visit 
--compared to their prior one. That means 43.3% of guests increased their spending 
--when they returned.
--====================================================================








/*
Q4:
Ticket switching: Using FIRST_VALUE(ticket_type_name) 
per guest, flag if they later switched. 
(Interpret implications for pricing/packaging.)
*/

--STEP 1 
WITH foundation AS(   
SELECT fv.guest_id,
       fv.visit_id,
       fv.visit_date,     -- add date so we can order visits correctly
       dt.ticket_type_name AS current_ticket
FROM fact_visits fv
LEFT JOIN dim_ticket dt ON dt.ticket_type_id = fv.ticket_type_id
),

first_ticket AS(
SELECT guest_id,
       current_ticket,
       visit_id,
       visit_date,
       FIRST_VALUE(current_ticket) OVER (
         PARTITION BY guest_id 
         ORDER BY visit_date         -- use visit_date for chronological "first"
       ) AS first_ticket
FROM foundation
),

--Lastly flag it
flag AS (
    SELECT 
      *,
      LAG(current_ticket) OVER (
        PARTITION BY guest_id ORDER BY visit_date
      ) AS prev_ticket,
      CASE WHEN current_ticket IS NOT first_ticket  THEN 1 ELSE 0 END AS switched_flag
    FROM first_ticket
),

count_guess AS (
SELECT guest_id,
       COUNT( * ) AS num_visits --count the number of rows per guest_id 
       FROM fact_visits
       GROUP BY guest_id
),
--count which # of guests switched 
switched_guest AS (
SELECT guest_id,
       MAX(switched_flag) AS case_switched --1 means swithced in flag CTE, so MAX counts the 1 
    FROM FLAG
    GROUP BY guest_id
)
-- final rollup
SELECT
  -- number of repeat guests who could have switched tickets (must have 2+ visits)
  SUM(CASE WHEN cg.num_visits >= 2 THEN 1 ELSE 0 END) AS potential_switchers,

  -- among eligible guests, how many actually switched at least once
  SUM(CASE WHEN cg.num_visits >= 2 AND sg.case_switched = 1 THEN 1 ELSE 0 END) AS guest_switched,

  -- percentage of eligible guests who switched (rounded, as %)
  ROUND(
    100.0 * SUM(CASE WHEN cg.num_visits >= 2 AND sg.case_switched = 1 THEN 1 ELSE 0 END)
      / NULLIF(SUM(CASE WHEN cg.num_visits >= 2 THEN 1 ELSE 0 END), 0)
  , 1) AS share_switched_pct
FROM count_guess cg
JOIN switched_guest sg USING (guest_id);


--====================================================================
--DOCUMENTATION FOR Q4
--I started by joining fact_visits with dim_ticket so that each visit row 
--showed the guest’s current ticket type. Then, in another CTE, I used the FIRST_VALUE 
--window function partitioned by guest_id and ordered by visit date to capture 
--each guest’s very first ticket type. With that baseline, 
--I created a flag column using CASE WHEN current_ticket 
--<> first_ticket THEN 1 ELSE 0 END to mark visits where the guest used 
--a different ticket than their original one. 
--That already answers the prompt, since it shows whether a guest 
--switched or stayed consistent. To strengthen the analysis, I also considered 
--rolling this up to the guest level: count how many guests had at least 2 
--visits (eligible to switch), check how many of them ever switched 
--using MAX(switched_flag), and then calculate the percentage. Finally, 
--this percentage can be broken down by first ticket type and even by previous 
--ticket (using LAG) to see direction—who upgraded vs. downgraded—which helps 
--interpret the implications for pricing and packaging.
--====================================================================


--====================================================================
--TL;DR (brief interpertation)
--Every eligible repeat guest switched ticket type at least once 
--(10/10 → 100% switched). That’s a strong signal that guests don’t stick with 
--their initial product; pricing/packaging is likely nudging them to change 
--(promos, value gaps, or availability).
--====================================================================
