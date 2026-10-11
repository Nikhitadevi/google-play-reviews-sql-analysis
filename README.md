# Which Google app gets the most negative Play Store reviews, and why?

A SQL analytics project using public Google Play reviews (India, English).
Independent project; not affiliated with Google.

## Question
Which of five Google apps (Gmail, Photos, Maps, Sheets, Drive) has the highest share of negative reviews, when did the problem start, and which app version is associated with it?

## Data
- ~25,000 reviews, 5,000 per app, collected with the Python `google-play-scraper` library (`country="in"`, `lang="en"`, newest first).
- Usernames and profile images were dropped. Raw data is **not** included in this repo.
- Loaded into MySQL 8.0 (`complaints.reviews`).
- **Negative review = star rating <= 2.**

## Method (SQL)
Aggregation with `CASE WHEN`, `GROUP BY` / `HAVING`, CTEs, and the `LAG()` window function. All queries are in [`queries.sql`](queries.sql).

## Findings
1. **Naive ranking was misleading.** Each app's 5,000 reviews cover a different period (Maps: 14 days, Drive: 122 days), so raw percentages are not comparable.
2. **Fair ranking (same window, reviews on/after 2026-09-24):** Gmail 28.5%, Maps 27.9%, Drive 21.2%, Photos 17.4%, Sheets 14.6%. Gmail and Maps are effectively tied at the top.
3. **Gmail version `2026.09.07.977329765.Release`** has 921 reviews and 62.9% negative, about twice its neighbouring versions. Its first review is on 2026-09-17.
4. **Daily trend (Q5):** Gmail is normally about 25-32% negative per day with roughly 110-140 reviews. It spikes to about 65% on 2026-09-20/21 (238 reviews on 09-21), then decays: 52.9% (09-22), 45.7% (09-23), 35.8% (09-24), back to 26% by 09-25. The spike does **not** start on 09-17, when the target version first appears (31.9% that day). The Gmail "36.0%" headline is inflated by this one spike.
5. **Version vs period (Q6/Q6b/Q7):** Across 09-17 onward the target version is 62.9% negative (921 reviews) vs 30.8% for other versions (2,476). But after the spike (09-26 onward) the target's daily negative share is 0-27% on very small counts, similar to other versions. Its reviews are concentrated in the spike days, so version and date are entangled. _TODO: add the Q6b result for 09-17 to 09-25 and state whether other versions were also elevated._
6. **Review text (Q8):** Of 1,341 negative Gmail reviews since 09-17, 25 mention "crash", 93 login/sign in, 60 notifications, 9 "slow", and 417 "update" (ambiguous; people write both "after the update" and "please update"). Keyword counts show themes, not causes.

_Add 2-3 screenshots here (e.g. the fair ranking, the daily trend, the version comparison)._

## Limitations
- India / English reviews only; no global claims.
- Reviews are self-selected: unhappy users review more often.
- `first_seen` is the first **review** date, not the release date.
- Some reviews have a blank `appVersion` (see Q9 for the share).
- The review text was not analysed in depth, so **the cause is unknown**. This shows association, not causation.
- Gmail vs Maps (28.5% vs 27.9%) is within noise; do not read it as a ranking.

## Next steps (not done)
Text analysis of review content, sentiment modelling, and a before/after test of specific feature releases.

## Files
- `queries.sql`: all analysis queries, commented.
- `README.md`: this file.
