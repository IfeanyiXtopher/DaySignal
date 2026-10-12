# DaySignal — 5–7 minute walkthrough script

Use for a live interview demo or a short screen recording. Times are approximate.

**Prerequisites (already running):** Docker Postgres, Redis, `bin/rails server`,
`bundle exec sidekiq -C config/sidekiq.yml`, `.env` with `WEATHER_API_KEY`.

Seed user: `demo@daysignal.local` / `password123`.

---

## 0:00–0:45 — Hook

> “DaySignal is a small Rails app that emails weather alerts at a user’s
> **local** hour. I’m using it to practice Simple-style patterns: ActiveRecord,
> Sidekiq, cron, mailers, and Hotwire — not to compete with weather apps.”

Open http://localhost:3000. Point at the logo and theme toggle if useful, then
sign in as the demo user (or sign up fresh).

---

## 0:45–2:00 — Preferences

Navigate to **Preferences**.

Say:

> “User saves location, timezone, alert time, and rain threshold. Search fills
> lat/lng and timezone; they stay editable. Validations reject bad timezones and
> out-of-range thresholds.”

Show:

1. Location search → pick a result (or keep Lagos).
2. Alert time `07:00`, threshold `50`, alerts enabled.
3. Save → flash + dashboard status: “Alerts on · next window ~ …”

Optional: flip theme Dark/Light to show Stimulus + CSS `data-theme`.

---

## 2:00–3:30 — Architecture (one diagram)

Open README Architecture (or draw the same flow):

```text
Preferences → hourly DispatchDueAlertsJob → WeatherAlertJob
  → WeatherClient → AlertEvaluator → WeatherMailer (if triggered)
```

Say:

> “Web requests never call the weather API. Cron selects by **local** hour.
> The job fetches, decides in Ruby, and mails only when rules fire. At most one
> alert stamp per user per local calendar day.”

Point at files if screen-sharing IDE:

- `app/jobs/dispatch_due_alerts_job.rb`
- `app/services/alert_evaluator.rb`
- `config/schedule.yml`

---

## 3:30–5:00 — Prove the loop

**Path A — Letter Opener (visual):**

1. Set threshold to `0` in Preferences → Save.
2. Terminal: `EMAIL=demo@daysignal.local bin/rails alerts:deliver_one`
3. Letter Opener tab opens → show subject/body (location, POP, reason).

**Path B — Evaluate only (no mail):**

```bash
EMAIL=demo@daysignal.local bin/rails weather:evaluate
```

Show `trigger?=true/false` and POP vs threshold.

**Path C — Tests (if no API key in the room):**

```bash
bin/rails test test/integration/manual_qa_test.rb
```

> “Same Manual QA checklist from the approach doc — six scenarios, stubbed network.”

---

## 5:00–6:00 — What we deliberately do not do

> “No LLM in the decision path. No SMS yet. No multi-location. Secrets only in
> `.env`. Ops notes are in `docs/responsible_ops.md`.”

---

## 6:00–7:00 — Close with skill transfer

> “This maps to Simple-style work: models and migrations, Sidekiq for async,
> cron for scheduled work, mailers for outbound messages, timezones for global
> programs, Faraday for external integrations, Hotwire for small internal UIs,
> and idempotent sends so we don’t spam.”

Offer: “Happy to open any job or the evaluator and walk line by line.”

---

## Backup one-liners

| If they ask… | Answer |
| --- | --- |
| Why not Solid Queue? | Sidekiq + Redis matches many production Rails shops / Simple-adjacent stacks |
| Why OpenWeatherMap 2.5? | Free-key friendly 3h slots; see `docs/weather_provider.md` |
| How do you avoid double email? | `last_alerted_at` vs user’s local calendar date |
| What if timezone is garbage? | Log + skip that user; batch continues |
