/* 4 CASES OFFEATURE ENGINEERING*/

--FIRST CASE
--Use COUNT(visit_id) grouped by guest_id, then make a binary flag (is_repeat_guest).
-- figure out how many visits each guest has
SELECT guest_id, COUNT(visit_id) AS visit_count
FROM fact_visits
GROUP BY guest_id;

-- use a CASE WHEN to count when count of visit_id is repeated
SELECT guest_id,
       COUNT(visit_id) AS visit_count,
       CASE WHEN COUNT(visit_id) > 1 THEN 1 ELSE 0 END AS is_repeat_guest
FROM fact_visits
GROUP BY guest_id;


--SECOND CASE 
-- Logic: exit_time - entry_time = how long the guest stayed in the park. 
--Convert to minutes with JULIANDAY(exit_time) - JULIANDAY(entry_time) × 1440.
SELECT visit_id, guest_id, entry_time, exit_time,
CAST((JULIANDAY(exit_time) - JULIANDAY(entry_time)) * 24 * 60 AS INT) AS stay_minutes
FROM fact_visits;



--THIRD CASE
--Guest Value Category (High/Low/Medium)
--Logic: Total up spend per guest, then bucket into value tiers.
--SQL: SUM spend across visits -> CASE statement to assign HIGH, MEDIUM, LOW
SELECT amount_cents_clean
FROM fact_purchases;

SELECT 
    SUM(amount_cents_clean) AS total_spend,
    CASE
        WHEN SUM(amount_cents_clean) >= 5000 THEN 'HIGH'  -- $50+
        WHEN SUM(amount_cents_clean) BETWEEN 2000 AND 4999 THEN 'MEDIUM'  -- $20-$49.99
        ELSE 'LOW'  -- <$20
    END AS value_segment
FROM fact_purchases
WHERE amount_cents_clean IS NOT NULL
GROUP BY visit_id;


--FOURTH CASE
-- 4. Attraction Popularity
--Logic: Count ride events per attraction.
--SQL: COUNT(ride_event_id) grouped by attraction_id.

SELECT da.attraction_name, da.category, COUNT(ride_event_id) AS count_attraction
FROM fact_ride_events fre
LEFT JOIN dim_attraction da ON da.attraction_id = fre.attraction_id
GROUP BY da.attraction_id, da.attraction_name, da.category
ORDER BY count_attraction DESC;


/* 
Thinking prompts (answered in more detail in README) 

Why would the GM or Ops care about stay_minutes?
    Stay minutes show how long customers actually stick around. 
    Ops can use this to plan staffing and resources better — like knowing when peak hours 
    hit and making sure staff are ready so service doesn’t slip.

Why is spend_per_person useful to Marketing vs. raw spend?
    Spend per person gives Marketing a clearer picture than raw spend, 
    because it shows how much each guest is actually spending. This helps them see what 
    guests are most drawn to (like food, rides, or merch) so they can market those things more and get other people to try them too.

How might wait_bucket guide scheduling or staffing?
    Wait buckets tell you when lines are short vs. when they’re long.
    Ops can use that to schedule staff so they’re available during the busiest times, 
    cutting down wait times and making the customer experience smoother.

Why normalize promotion_code before analysis?
    Promotion codes were written in different ways (like VIPDAY vs. vip-day). 
    If you don’t clean that up, the same promo gets counted as two different ones, 
    which totally messes up the results. Normalizing makes sure you see the real performance of each code, 
    and that your analysis isn’t misleading.
*/ 