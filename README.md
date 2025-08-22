# Theme Park Analytics By Ayema Qureshi

## Business Problem 
- Supernova Theme Park is preparing its strategy for the upcoming quarter and needs data-driven insights to guide decision-making. Leadership is looking for a unified view across operations, marketing, and guest behavior to ensure resources are allocated efficiently while still maximizing revenue. The challenge is to balance staffing needs, guest satisfaction, and ticket/package optimization in a way that keeps visitors returning and spending more.

## Stakeholders 
**Primary Stakeholder: Park General Manager (GM)** 
- Oversees the entire theme park’s performance and relies on cross-departmental insights to set strategy for revenue growth and guest satisfaction.

**Supporting Stakeholder: Operations Director**
- Focuses on staffing levels, queue management, and daily efficiency. They need accurate demand forecasts (busy days, peak hours) to allocate staff effectively.

**Supporting Stakeholder: Marketing Director**
- Designs promotions and ticket/package mixes. They use insights on guest behavior, repeat spending, and switching patterns to refine pricing and campaigns.


## Overview of Database & Schema (short star-schema note) 
- The database is organized as a star schema, a common design in analytics where a central fact table contains quantitative measures (e.g., spend, visits, wait times) and is surrounded by dimension tables that add descriptive context (e.g., guest demographics, ticket type, attraction details). Facts and dimensions are linked by keys, creating a simple, intuitive “star” layout. This structure makes it easier to run flexible queries—such as analyzing revenue by ticket type, evaluating satisfaction by ride category, or tracking attendance over time—while keeping performance efficient.
<img width="800" height="400" alt="Screenshot 2025-08-22 at 4 58 38 PM" src="https://github.com/user-attachments/assets/e640822e-8df6-4ccf-a0f4-443b62f6f719" />

### Fact Tables
- fact_visits: Records each guest’s visit, including date, group size, and total spend.
- fact_purchases: Tracks in-park purchases like food, drinks, and merchandise.
- fact_ride_events: Captures ride experiences such as wait times and satisfaction ratings.

### Dimension Tables
- dim_guest: Guest information such as home state and demographics.
- dim_ticket: Ticket details including type, pricing, and restrictions.
- dim_date: Calendar context like day of week, weekend flag, and season.
- dim_attraction: Attraction details including ride name, category, and height limits.


## EDA (SQL)
During the EDA phase, I used SQL to validate the dataset and uncover initial patterns that would shape later analysis. Rather than diving straight into modeling, I first checked for coverage, quality, and baseline trends.

**Time Coverage & Visit Volume**
- Pulled the min/max visit dates and daily counts using `MIN(visit_date)`, `MAX(visit_date)`, and `COUNT(DISTINCT visit_date)`.
- Why: to check the range of data available and identify busy/slow periods for operations.

**Ticket & Guest Behavior**
- Counted visits by ticket type with `GROUP BY ticket_type_name` after joining `fact_visits` to `dim_ticket`.
- Why: to see which ticket products drive attendance and inform marketing strategy.

**Data Quality Checks (Nulls & Duplicates)**
- Ran a null audit `(SUM(CASE WHEN col IS NULL THEN 1 END))` and checked for duplicates in `fact_ride_events`.
- Why: to confirm which fields are reliable. For example, ~50% of `wait_minutes` are missing and ~21% of `total_spend_cents` are NULL, so they require special handling later.

Overall, the EDA confirmed broad date coverage for visits, revealed which ticket types dominate attendance, and highlighted key data quality issues (nulls and duplicates) to address before deeper analysis. These findings set the foundation for cleaning, feature engineering, and business-focused queries in the next steps.


## CTEs & Window Functions (SQL)
Below are the key CTE + window patterns I used, with tight snippets and why they matter for staffing and improvements. Four main analyses:

1. Daily performance (Ops staffing)
   - Used running totals with `SUM(...) OVER (ORDER BY date_iso`) and `daily ranks with DENSE_RANK() OVER (ORDER BY daily_visits DESC)`.
    - **Use**: Identify top-3 busiest days for staff scheduling and track momentum for the GM. For Operations, knowing the peak days means scheduling staff more effectively — ensuring enough ride operators, food staff, and guest services on high-traffic days like July 7th. For the GM, the running totals provide visibility into overall park momentum, answering questions like “Are we on track to beat last week’s numbers?” or “Which days consistently carry attendance?


2. RFM & CLV by state (guest targeting)
   - Found each guest’s last visit with `MAX(visit_date) OVER (PARTITION BY guest_id)` and ranked spend within state using `RANK() OVER (...)`.
   - **Use**: This ranking shows who the top spenders are in each state. For Marketing, rank-1 guests represent the most valuable individuals in their region — the ideal targets for loyalty programs, exclusive offers, or early access promotions. For the GM, the breakdown reveals which states send the highest-value visitors overall, guiding decisions about regional partnerships and advertising spend. Lower-rank guests can also be nurtured with targeted campaigns to encourage them to “climb the ladder.

3. Behavior change (repeat visit spending)
   - Compared visits with `LAG(spend_cents_clean) OVER (PARTITION BY guest_id)` to calculate `delta_spend`.
   - **Use**: Found that 43% of repeat visits spent more than their previous visit. This means nearly half of returning guests are open to increasing their spending — a strong signal for Marketing to target them with bundles, upsells, or loyalty perks. For Operations, this insight highlights when to staff food, retail, and guest services more heavily, since repeat visitors are more likely to purchase extras..

4. Ticket switching (pricing & packaging)
   - Captured each guest’s first ticket with` FIRST_VALUE(ticket_type_name)` and flagged switches using `CASE WHEN current_ticket <> first_ticket`.
   - **Use**: Every repeat guest switched tickets at least once. This shows the tiers are flexible and attractive, but also suggests guests may not pick the right option upfront — an opportunity to improve how tickets are packaged and explained

Together, these CTE and window function analyses connected guest behavior to concrete business actions: staffing the right days, targeting the most valuable guests, understanding spending growth on return visits, and evaluating ticket product fit. By layering queries step by step, the park can turn raw data into decisions that directly improve both guest satisfaction and revenue.



