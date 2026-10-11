-- ============================================================
-- Google Play review analysis: which app has the most negative
-- reviews, when did it start, and which version drives it?
-- MySQL 8.0 | database: complaints | table: reviews
-- Negative review = score <= 2
-- Independent project using public data. Not affiliated with Google.
-- ============================================================
USE complaints;

-- ------------------------------------------------------------
-- Q1. Data coverage: what date range does each app's sample cover?
-- Why: 5,000 newest reviews per app span different windows,
-- so a raw comparison is unfair.
-- ------------------------------------------------------------
SELECT app,
       COUNT(*)                          AS total_reviews,
       MIN(`at`)                         AS first_review,
       MAX(`at`)                         AS last_review,
       DATEDIFF(MAX(`at`), MIN(`at`))    AS days_covered
FROM reviews
GROUP BY app;

-- ------------------------------------------------------------
-- Q2. Naive ranking (all available reviews). Biased by window.
-- ------------------------------------------------------------
SELECT app,
       COUNT(*) AS total_reviews,
       SUM(CASE WHEN score <= 2 THEN 1 ELSE 0 END) AS negative,
       ROUND(100.0 * SUM(CASE WHEN score <= 2 THEN 1 ELSE 0 END) / COUNT(*), 1) AS negative_pct
FROM reviews
GROUP BY app
ORDER BY negative_pct DESC;

-- ------------------------------------------------------------
-- Q3. Fair ranking: same window for every app.
-- 2026-09-24 = first full day after the latest start date among the
-- five apps (Maps' first review is 2026-09-23, from Q1).
-- Note: this window starts in the tail of a Gmail spike (see Q5).
-- ------------------------------------------------------------
SELECT app,
       COUNT(*) AS total_reviews,
       SUM(CASE WHEN score <= 2 THEN 1 ELSE 0 END) AS negative,
       ROUND(100.0 * SUM(CASE WHEN score <= 2 THEN 1 ELSE 0 END) / COUNT(*), 1) AS negative_pct
FROM reviews
WHERE `at` >= '2026-09-24'
GROUP BY app
ORDER BY negative_pct DESC;

-- ------------------------------------------------------------
-- Q4. Gmail by app version (versions with >= 30 reviews).
-- first_seen = first REVIEW date, not the release date.
-- Blank appVersion rows are excluded here (see Q9).
-- ------------------------------------------------------------
SELECT appVersion,
       COUNT(*) AS reviews,
       ROUND(100.0 * SUM(CASE WHEN score <= 2 THEN 1 ELSE 0 END) / COUNT(*), 1) AS negative_pct,
       MIN(`at`) AS first_seen
FROM reviews
WHERE app = 'gmail'
  AND appVersion IS NOT NULL AND appVersion <> ''
GROUP BY appVersion
HAVING COUNT(*) >= 30
ORDER BY first_seen;

-- ------------------------------------------------------------
-- Q5. Gmail daily negative % trend, with day-over-day change.
-- CTE builds one row per day; LAG() looks at the previous day.
-- Look at `reviews` too: a big jump on a tiny day is noise.
-- ------------------------------------------------------------
WITH daily AS (
    SELECT DATE(`at`) AS day,
           COUNT(*)   AS reviews,
           ROUND(100.0 * SUM(CASE WHEN score <= 2 THEN 1 ELSE 0 END) / COUNT(*), 1) AS neg_pct
    FROM reviews
    WHERE app = 'gmail'
    GROUP BY DATE(`at`)
)
SELECT day,
       reviews,
       neg_pct,
       LAG(neg_pct) OVER (ORDER BY day)                AS prev_neg_pct,
       neg_pct - LAG(neg_pct) OVER (ORDER BY day)      AS change_pts
FROM daily
ORDER BY day;

-- ------------------------------------------------------------
-- Q6. Version or date? Same days, target version vs all others.
-- If "other" versions are ALSO high on these days, the problem is
-- the period (or the app overall), not just this version.
-- ------------------------------------------------------------
WITH tagged AS (
    SELECT DATE(`at`) AS day,
           CASE WHEN appVersion = '2026.09.07.977329765.Release'
                THEN 'target' ELSE 'other' END AS grp,
           score
    FROM reviews
    WHERE app = 'gmail'
      AND `at` >= '2026-09-17'
)
SELECT day,
       grp,
       COUNT(*) AS reviews,
       ROUND(100.0 * SUM(CASE WHEN score <= 2 THEN 1 ELSE 0 END) / COUNT(*), 1) AS neg_pct
FROM tagged
GROUP BY day, grp
ORDER BY day, grp;

-- ------------------------------------------------------------
-- Q6b. Same as Q6 but one row per day, target and other side by side.
-- Check the spike days (about 09-17 to 09-25): are "other" versions
-- also elevated? That decides version vs. period.
-- ------------------------------------------------------------
SELECT DATE(`at`) AS day,
       SUM(appVersion = '2026.09.07.977329765.Release') AS target_reviews,
       ROUND(100.0 * SUM(appVersion = '2026.09.07.977329765.Release' AND score <= 2)
             / NULLIF(SUM(appVersion = '2026.09.07.977329765.Release'), 0), 1) AS target_neg_pct,
       SUM(appVersion <> '2026.09.07.977329765.Release' OR appVersion IS NULL) AS other_reviews,
       ROUND(100.0 * SUM((appVersion <> '2026.09.07.977329765.Release' OR appVersion IS NULL) AND score <= 2)
             / NULLIF(SUM(appVersion <> '2026.09.07.977329765.Release' OR appVersion IS NULL), 0), 1) AS other_neg_pct
FROM reviews
WHERE app = 'gmail'
  AND `at` >= '2026-09-15'
GROUP BY DATE(`at`)
ORDER BY day;

-- ------------------------------------------------------------
-- Q7. Same comparison, overall for the shared window (one row each).
-- ------------------------------------------------------------
WITH tagged AS (
    SELECT CASE WHEN appVersion = '2026.09.07.977329765.Release'
                THEN 'target' ELSE 'other' END AS grp,
           score
    FROM reviews
    WHERE app = 'gmail'
      AND `at` >= '2026-09-17'
)
SELECT grp,
       COUNT(*) AS reviews,
       ROUND(100.0 * SUM(CASE WHEN score <= 2 THEN 1 ELSE 0 END) / COUNT(*), 1) AS neg_pct
FROM tagged
GROUP BY grp;

-- ------------------------------------------------------------
-- Q8. (Optional) What do negative Gmail reviews mention?
-- Crude keyword counts. This shows themes, NOT causes.
-- ------------------------------------------------------------
SELECT COUNT(*) AS negative_reviews,
       SUM(CASE WHEN content LIKE '%crash%'   THEN 1 ELSE 0 END) AS mentions_crash,
       SUM(CASE WHEN content LIKE '%update%'  THEN 1 ELSE 0 END) AS mentions_update,
       SUM(CASE WHEN content LIKE '%notif%'   THEN 1 ELSE 0 END) AS mentions_notification,
       SUM(CASE WHEN content LIKE '%login%'
                 OR content LIKE '%sign in%'  THEN 1 ELSE 0 END) AS mentions_login,
       SUM(CASE WHEN content LIKE '%slow%'    THEN 1 ELSE 0 END) AS mentions_slow
FROM reviews
WHERE app = 'gmail'
  AND score <= 2
  AND `at` >= '2026-09-17';

-- ------------------------------------------------------------
-- Q9. Data quality: how many reviews have no app version?
-- ------------------------------------------------------------
SELECT app,
       COUNT(*) AS total,
       SUM(CASE WHEN appVersion IS NULL OR appVersion = '' THEN 1 ELSE 0 END) AS blank_version,
       ROUND(100.0 * SUM(CASE WHEN appVersion IS NULL OR appVersion = '' THEN 1 ELSE 0 END) / COUNT(*), 1) AS blank_pct
FROM reviews
GROUP BY app;
