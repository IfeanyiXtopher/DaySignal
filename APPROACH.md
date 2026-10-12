# DaySignal — MVP Step-by-Step Approach

**Project name:** DaySignal  
**Repository / folder name:** `DaySignal`

**Product (MVP):** A timezone-aware weather alert delivery service. Users save a location, a local alert time, a timezone, and a rain threshold. An hourly scheduler selects only users due in the current local hour, fetches a forecast for their location, applies threshold rules, and sends an email asynchronously.

**Out of scope for the Rails MVP loop:** SMS/WhatsApp, push notifications, multi-tenant orgs, paid plans, native mobile apps, ML forecasting, or a separate SPA. Prove **accounts → preferences → cron → fetch → decide → notify** first.

**Why this project exists:** Practice production Ruby on Rails patterns used by systems like Simple — ActiveRecord, Sidekiq jobs, cron, Action Mailer, Hotwire UI — while shipping a small real product.

This document is the build bible. Follow the phases in order. Do not skip a phase’s acceptance checks.

---

## 1. What we are building

### 1.1 User journey

1. Open the app.
2. Sign up / sign in.
3. Save location (city name and/or lat/long).
4. Choose local alert time, timezone, and rain threshold (% probability of precipitation).
5. Optionally enable/disable alerts.
6. At the chosen local hour, the system evaluates their forecast and emails them if thresholds are met.
7. User can edit preferences or turn alerts off.

### 1.2 Non-negotiable product rules

- Alerts fire in the user’s **local timezone**, not the server’s clock alone.
- The hourly job only processes users whose **local alert hour matches the current hour** in their timezone.
- Weather API calls and email sending happen in **background jobs**, not in the web request.
- Threshold evaluation is **code** (deterministic rules), not an LLM.
- Failed weather fetches or mail sends are logged and retried sensibly; they must not crash the scheduler.
- Secrets (API keys, SMTP) live in credentials / ENV — never committed.
- No “umbrella vs raincoat” product language in the UI or emails for the portfolio pitch — frame as **weather alert delivery** with clear forecast facts and a threshold-based trigger.

### 1.3 Alert content contract

Every email should include:

1. **Location** the alert is for.
2. **Forecast facts** used in the decision (e.g. POP %, precip summary, wind if used).
3. **Why it fired** (which threshold matched).
4. A short, plain recommendation string derived from rules (keep factual; avoid toy phrasing in the product copy).

If thresholds are not met: **no email** (silent pass).

### 1.4 Core architecture flow

```
User saves preferences (Rails + Postgres)
        ↓
Sidekiq-Cron runs every hour
        ↓
Query users due this local hour
        ↓
Enqueue WeatherAlertJob per user (or small batch)
        ↓
Faraday → weather API → forecast DTO
        ↓
Rule engine (threshold / POP / wind / precip intensity)
        ↓
If triggered → Action Mailer deliver_later
        ↓
Sidekiq + Redis send email (SendGrid / Postmark / Mailgun / SMTP)
```

---

## 2. Locked tech stack

| Layer | Choice | Why |
|-------|--------|-----|
| Language | Ruby | Target skill for Simple / Rails work |
| Framework | Ruby on Rails (latest stable 7.x/8.x) | Full-stack: models, jobs, mailers, Hotwire |
| DB | PostgreSQL | Production default; matches Simple |
| Background jobs | Sidekiq + Redis | Async mail + weather fetch |
| Scheduling | Sidekiq-Cron (or `solid_queue` + recurring if you standardize later) | Hourly tick |
| HTTP client | Faraday | Weather API calls |
| Weather data | OpenWeatherMap **or** WeatherAPI | One provider for MVP |
| Email | Action Mailer + SMTP adapter (Mailgun / Postmark / SendGrid / Letter Opener in dev) | Real delivery path |
| Frontend | Hotwire (Turbo + Stimulus) + ERB | No separate SPA |
| Auth | Rails authentication (built-in generator / Devise — pick one and stick) | Accounts + sessions |
| Timezones | `tzinfo` / Active Support time zones | Local alert windows |
| Tests | Minitest or RSpec (pick one) | Models, jobs, rules |
| Config | Rails credentials + ENV | API keys |

### 2.1 Explicitly not in MVP

| Deferred | When |
|----------|------|
| SMS / WhatsApp | After email path is solid |
| Multi-location per user | After single location works |
| Admin dashboard | After core loop works |
| Docker Compose for prod | When you want one-command deploy |
| Kubernetes | Never for this learning MVP |
| GraphQL | Not needed |
| Separate React app | Hotwire is enough |

### 2.2 Environment variables / credentials

```
DATABASE_URL=
REDIS_URL=redis://localhost:6379/0
WEATHER_API_KEY=
WEATHER_PROVIDER=openweathermap   # or weatherapi
SMTP_ADDRESS=
SMTP_PORT=
SMTP_USERNAME=
SMTP_PASSWORD=
MAILER_FROM=alerts@example.com
APP_HOST=localhost:3000
```

---

## 3. Repository layout (target)

```
DaySignal/
├── APPROACH.md                 # this document
├── README.md
├── Gemfile
├── config/
│   ├── routes.rb
│   ├── sidekiq.yml
│   ├── schedule.yml            # Sidekiq-Cron hourly entry
│   └── environments/
├── app/
│   ├── models/
│   │   └── user.rb             # or User + AlertPreference
│   ├── controllers/
│   │   ├── sessions_controller.rb / registrations...
│   │   └── preferences_controller.rb
│   ├── views/
│   ├── jobs/
│   │   ├── dispatch_due_alerts_job.rb   # hourly cron entry
│   │   └── weather_alert_job.rb         # per-user evaluate + mail
│   ├── mailers/
│   │   └── weather_mailer.rb
│   ├── services/
│   │   ├── weather_client.rb            # Faraday fetch
│   │   ├── forecast.rb                  # value object / DTO
│   │   └── alert_evaluator.rb           # threshold rules
│   └── javascript/                      # Stimulus if needed
├── db/migrate/
├── test/ or spec/
└── .env / credentials
```

Rails `rails new` will create more files. Keep **business logic** in `app/services` and `app/jobs`, not fat controllers.

---

## 4. Data model

### 4.1 Preferred MVP: `users` + alert fields on user

Keep it simple unless preferences clearly need a second table.

| Field | Type | Purpose |
|-------|------|---------|
| `email` | string | Login + alert destination |
| `password_digest` | string | Auth |
| `location_label` | string | e.g. "Lagos, Nigeria" |
| `latitude` | decimal/float | Preferred for API accuracy |
| `longitude` | decimal/float | |
| `timezone` | string | e.g. `Africa/Lagos` |
| `alert_time` | time | Local time-of-day user wants evaluation |
| `rain_threshold` | integer | POP % that must be exceeded (default 40–50) |
| `alerts_enabled` | boolean | Soft off switch |
| `last_alerted_at` | datetime | Optional: prevent duplicate same-day spam |
| `created_at` / `updated_at` | datetime | |

**Indexes**

- `(alerts_enabled)` partial where true, if supported.
- Query pattern is “all enabled users” then filter by local hour in Ruby/SQL carefully — see section 7.

### 4.2 Optional later: `alert_preferences`

Only split if a user needs multiple locations. Not MVP.

---

## 5. Rule engine (deterministic)

Implement in `AlertEvaluator` (pure Ruby, easy to unit test).

### 5.1 Inputs

- Forecast for the user’s location (daily or next-hours window — pick one and document it).
- `rain_threshold` (integer percent).
- Optional secondary signals: precip intensity, wind speed.

### 5.2 MVP decision table

| Condition | Result |
|-----------|--------|
| POP (or precip probability) ≥ `rain_threshold` | **Trigger** email |
| Heavy precip flag / intensity above a fixed constant (optional) | **Trigger** |
| Otherwise | **No email** |

Store the matched reason string for the mail body, e.g. `precipitation_probability=62 >= threshold=50`.

### 5.3 What not to do

- Do not call an LLM to decide whether to email.
- Do not hardcode toy consumer copy (“bring an umbrella”) as the product identity. Prefer: “Rain likely for {location}: {POP}% chance…”

---

## 6. Weather client

### 6.1 Responsibilities (`WeatherClient`)

1. Accept lat/long (or city query if geocoding is separate).
2. GET forecast from the chosen provider.
3. Normalize into a small `Forecast` object:

| Field | Type |
|-------|------|
| `precipitation_probability` | Integer 0–100 or nil |
| `summary` | String |
| `wind_speed` | Float or nil |
| `raw` | Hash (for debugging; do not dump into email) |
| `fetched_at` | Time |

4. Raise typed errors on timeout / 401 / 429; jobs rescue and retry.

### 6.2 Caching (optional MVP+)

Cache forecast by rounded lat/long for 30–60 minutes to avoid N identical API calls for co-located users. Not required for Phase 1.

### 6.3 Rate limits

- Process users in Sidekiq with concurrency limits.
- On 429: retry with backoff; do not busy-loop in cron.

---

## 7. Scheduling and timezones

### 7.1 Hourly cron

`DispatchDueAlertsJob` runs every hour (Sidekiq-Cron).

Pseudologic:

```
now_utc = Time.current
User.alerts_enabled.find_each do |user|
  local = now_utc.in_time_zone(user.timezone)
  next unless local.hour == user.alert_time.hour
  # optional: next if already alerted today in user.timezone
  WeatherAlertJob.perform_later(user.id)
end
```

### 7.2 Rules

- Always convert with `ActiveSupport::TimeZone[user.timezone]`.
- Invalid timezone → disable alerts or skip with error log; do not crash the batch.
- `alert_time` stores time-of-day; comparison is on **hour** for MVP (minute precision later).

### 7.3 Idempotency

- Prefer at-most-one alert email per user per local calendar day.
- Use `last_alerted_at` checked in the user’s timezone, or a unique `alert_deliveries` row `(user_id, local_date)`.

---

## 8. Jobs and mailers

### 8.1 `WeatherAlertJob`

```
perform(user_id)
  user = User.find(user_id)
  return unless user.alerts_enabled?

  forecast = WeatherClient.fetch(user.latitude, user.longitude)
  decision = AlertEvaluator.call(forecast, user.rain_threshold)

  return unless decision.trigger?

  WeatherMailer.alert_email(user, forecast, decision).deliver_now
  # or deliver_later if you nest jobs carefully — prefer deliver_now inside job
  user.update!(last_alerted_at: Time.current)
```

### 8.2 `WeatherMailer`

- Subject: include location + date (local).
- Body: facts + reason + short action line.
- From: `MAILER_FROM`.
- Dev: `letter_opener` or log delivery.

### 8.3 Failure handling

| Failure | Behavior |
|---------|----------|
| User missing | Drop job |
| Weather API timeout | Retry 3x with backoff |
| Weather API 401 | Fail loudly in logs; do not infinite retry |
| SMTP error | Retry; then Dead Job set |

---

## 9. UI requirements (Hotwire)

### 9.1 Pages

1. **Sign up / sign in**
2. **Preferences** — location, timezone select, alert time, rain threshold, enabled toggle
3. **Simple status** — “Alerts on · next window ~ {local time}” (optional)

### 9.2 UX rules

- Validate timezone against known Rails time zones.
- Validate threshold 0–100.
- Show flash on save.
- Do not block HTTP on weather fetch.

---

## 10. Testing (do not skip)

| Test | Assert |
|------|--------|
| `AlertEvaluator` | Below threshold → no trigger; at/above → trigger |
| Timezone selection | User in `Africa/Lagos` at 07:00 local is selected when cron runs that UTC hour |
| `WeatherClient` | Faraday stub returns normalized `Forecast` |
| Job | Trigger path calls mailer; non-trigger does not |
| Mailer | Renders location + reason |
| Prefs | Invalid timezone rejected |

Stub the weather API in tests. Do not hit the network in CI.

---

## 11. Phase-by-phase build

### Phase 0 — Rails app skeleton

**Goal:** App boots; Postgres + Redis configured; README exists.

Steps:

1. `rails new DaySignal -d postgresql` (or equivalent).
2. Add Sidekiq, Redis, Sidekiq-Cron, Faraday, dotenv/credentials.
3. Write `README.md`: setup, `bin/dev`, Sidekiq, Redis.
4. Commit `APPROACH.md` (this file).
5. `.gitignore` secrets; document ENV.

**Acceptance**

- [ ] `rails db:setup` works
- [ ] `rails s` boots
- [ ] Sidekiq boots against Redis
- [ ] README is enough to run locally

---

### Phase 1 — Auth + preferences (no weather yet)

**Goal:** User can register and save alert preferences.

Steps:

1. Auth (Rails 8 generator or Devise — pick one).
2. Migration for alert fields.
3. Preferences form + strong params + validations.
4. Timezone dropdown (`ActiveSupport::TimeZone`).

**Acceptance**

- [ ] Sign up / sign in works
- [ ] Preferences persist in Postgres
- [ ] Invalid threshold / blank location rejected

---

### Phase 2 — Weather client + evaluator (no mail yet)

**Goal:** Given lat/long + threshold, decide trigger in code/tests.

Steps:

1. Implement `WeatherClient` + `Forecast`.
2. Implement `AlertEvaluator` with unit tests.
3. Optional: rails runner / rake task to print decision for one user.

**Acceptance**

- [ ] Stubbed API → normalized forecast
- [ ] Evaluator tests pass
- [ ] Real API key works manually once (not in CI)

---

### Phase 3 — Jobs + mailer

**Goal:** Per-user job fetches, decides, emails.

Steps:

1. `WeatherMailer` + HTML/text templates.
2. `WeatherAlertJob`.
3. Manual `perform_later` from console for yourself.
4. Dev mail preview / letter_opener.

**Acceptance**

- [ ] Trigger path sends email in development
- [ ] Non-trigger path sends nothing
- [ ] Failures retry without killing Sidekiq

---

### Phase 4 — Hourly dispatch + timezones

**Goal:** Cron selects the right users.

Steps:

1. `DispatchDueAlertsJob` + Sidekiq-Cron schedule (`0 * * * *`).
2. Idempotency (`last_alerted_at` or deliveries table).
3. Tests for timezone hour matching with frozen time.

**Acceptance**

- [ ] Only due users enqueued
- [ ] Same user not double-emailed same local day
- [ ] Invalid timezone skipped safely

---

### Phase 5 — Hardening + demo polish

**Goal:** Safe to show on a CV / interview.

Steps:

1. Rate-limit / rescue paths polished.
2. README with screenshots + “try this” steps.
3. Seed user + sample preferences.
4. Deploy somewhere small (Fly.io / Render / your VPS) **optional**.
5. Add GitHub link + live URL to résumé **only after this works**.

**Acceptance**

- [ ] Fresh machine / clean README path works
- [ ] Manual QA script in section 13 passes
- [ ] No secrets in git

---

## 12. Definition of done (MVP)

A user can:

1. Create an account.
2. Save location, timezone, alert time, rain threshold.
3. Receive an email when the hourly job runs and their threshold is met.
4. Receive nothing when the threshold is not met.
5. Turn alerts off and stop receiving mail.

Plus:

6. Jobs run via Sidekiq + Redis.
7. Timezone logic is tested.
8. Weather API is stubbed in automated tests.
9. README is enough for a third party to run locally.

---

## 13. Manual QA script

1. Create user A: timezone `Africa/Lagos`, alert hour = current Lagos hour, threshold `0` (always fire if POP present) or mock forecast.
2. Run `DispatchDueAlertsJob` (or wait for cron in staging).
3. Expect Sidekiq processes `WeatherAlertJob` and mail appears.
4. Set threshold to `100`; mock low POP → no mail.
5. Change timezone so local hour ≠ now → user not selected.
6. Disable `alerts_enabled` → not selected.
7. Break API key → job fails/retries without crashing web UI.
8. Restart Redis/Sidekiq → app still serves preferences page.

---

## 14. Mapping to Simple / RTSL learning goals

| DaySignal piece | Skill transfer |
|-----------------|----------------|
| ActiveRecord models + migrations | Simple server models |
| Sidekiq jobs | Async work, sync-adjacent patterns |
| Sidekiq-Cron | Scheduled overdue / reminder style work |
| Action Mailer | Outbound patient/staff messaging patterns |
| Timezones | Global health programs across regions |
| Faraday + external API | Integrations (weather ↔ DHIS2/EHR style adapters) |
| Hotwire CRUD | Small internal tools without a SPA |
| Idempotent daily send | “Don’t spam” operational hygiene |

Keep the README honest: this is a **learning production Rails app**, not a meteorology product.

---

## 15. Security and privacy

- Store weather API keys in credentials/ENV.
- Do not log full API responses at INFO in production.
- Auth required for preferences.
- Rate-limit sign-ups later if public.
- User email is PII — do not commit seeds with real addresses.

---

## 16. What you will scale later (not MVP)

| Later | Depends on |
|-------|------------|
| Multiple locations per user | Preferences model split |
| SMS channel | Mail path stable |
| Forecast cache by geohash | API cost pain |
| Admin metrics (sends/day, failures) | Job logging |
| Docker Compose one-shot demo | Local path proven |
| Geocoding city → lat/long in-app | Manual lat/long works |

---

## 17. Implementation order cheat sheet

| Order | Work | Entry |
|------:|------|-------|
| 0 | Rails app, Postgres, Redis, Sidekiq, README | `rails new` |
| 1 | Auth + preferences UI | `PreferencesController` |
| 2 | Weather client + evaluator + tests | `app/services/*` |
| 3 | Mailer + `WeatherAlertJob` | `app/jobs`, `app/mailers` |
| 4 | Hourly dispatch + timezone selection | `DispatchDueAlertsJob` |
| 5 | Hardening, README, optional deploy | section 12–13 |

**Next concrete action:** Phase 0 only — generate the Rails app, wire Postgres + Redis + Sidekiq, write `README.md`, keep this `APPROACH.md` as the source of truth.

---

## 18. Decisions already made

1. Product name is **DaySignal** (weather alert delivery, not umbrella gimmicks).
2. Stack: **Rails + PostgreSQL + Sidekiq + Redis + Sidekiq-Cron + Action Mailer + Faraday + Hotwire**.
3. Decisions are **code rules**, not LLM.
4. Scheduling is **timezone-aware hourly** dispatch.
5. Email is the only notification channel in MVP.
6. One location per user in MVP.
7. Résumé links go live only after Phase 5 acceptance.
8. Primary learning goal: Rails patterns transferable to **Simple**-style backend work.
