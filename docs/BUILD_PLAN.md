# WeatherCheck — Build Plan and Progress Tracker

Timezone-aware weather alert delivery service. Users save a location, local
alert time, timezone, and rain threshold. An hourly scheduler selects only
users due in the current local hour, fetches a forecast, applies deterministic
threshold rules, and sends email asynchronously.

Built to practice production Ruby on Rails patterns used by systems like
[Simple](https://docs.simple.org/) (Resolve to Save Lives): ActiveRecord,
Sidekiq jobs, cron, Action Mailer, Hotwire UI. Open learning project — not a
meteorology product. Threshold evaluation is **code**, never an LLM.

This file is the single source of truth for **where the build is**. It is
updated at every milestone. Read the *Current position* line first, then the
step it points at.

Companion: [`APPROACH.md`](../APPROACH.md) (product rules, architecture, data
model). Prefer this tracker for day-to-day execution; keep APPROACH for deeper
rationale.

## How to read this file

Status marks:

- `[ ]` not started
- `[~]` in progress
- `[x]` done and verified
- `[!]` blocked (reason given inline)

Every step lists: **Goal**, numbered **Tasks**, the **Artifact** it produces,
and a **Verify** command or check that proves it is done. Nothing is marked
`[x]` unless *Verify* passes.

## Current position

> **Step 0 — Scope and repository foundation: `[x]` done.** Next: Step 1 — Auth and alert preferences.

## Prerequisites on the developer machine

Audited **2026-10-11**, completed same day. Status marks below mean the tool
is ready for Step 0, not that Step 0 itself is done.

| Tool | Needed from | Installed |
| --- | --- | --- |
| Ruby **3.3.12** via rbenv (project `.ruby-version`) | Step 0 | **yes** — `ruby -v` → 3.3.12 (not macOS system 2.6) |
| Bundler | Step 0 | **yes** — Bundler 4.0.22 |
| Rails (gem) | Step 0 | **yes** — Rails 8.1.4 |
| PostgreSQL 16 (Docker Compose service `db`) | Step 0 | **yes** — container `weathercheck-db`, host port **5433** |
| Redis | Step 0 | **yes** — `redis-cli ping` → `PONG` (v8.4.0 Homebrew) |
| Node 20+ | Step 0 | **yes** — v24.15.0 |
| Git | Step 0 | **yes** — 2.52.0 |
| Docker Desktop | Step 0 | **yes** — 29.4.2 (must be running for `db`) |
| OpenWeatherMap API key | Step 2 live | **yes** — `WEATHER_API_KEY` in root `.env` |
| SMTP / Letter Opener | Step 3 | Letter Opener in Step 0 Gemfile; real SMTP on VPS later |
| OpenAI API key | — | **not used** by WeatherCheck MVP |
| Small VPS | Step 5 optional | planned later; reuse `docker-compose.yml` for Postgres |

### How this machine is wired (learning note)

```
Mac (dev)
├── rbenv → Ruby 3.3.12 → rails / bundle   (app code runs here)
├── Redis (Homebrew) on :6379              (Sidekiq broker)
└── Docker Desktop
    └── postgres:16-alpine
        container port 5432  →  host port 5433
        DB name WeatherCheck, user postgres
```

Why port **5433**? This Mac already has native PostgreSQL 18 on **5432**
(`/Library/PostgreSQL/18`). We did not touch that. On the VPS (no host
Postgres), map `"5432:5432"` instead.

### Secrets layout

- Real keys: gitignored **root** `.env` (normalized from `docs/.env`).
- Template only: `.env.example` (safe to commit).
- Names: `DATABASE_URL`, `POSTGRES_*`, `REDIS_URL`, `WEATHER_API_KEY`,
  `WEATHER_PROVIDER=openweathermap`, `MAILER_FROM`, `APP_HOST`.

### Daily commands before coding

```bash
# 1) Docker Desktop running, then:
docker compose up -d          # Postgres
redis-cli ping                # expect PONG

# 2) New terminal (rbenv is in ~/.zshrc):
cd /Users/wyreenergy/WeatherCheck
ruby -v                       # expect 3.3.12
```

Folder names: Rails root is the repo root (`WeatherCheck/`). Business logic
lives in `app/services/` and `app/jobs/`, not fat controllers.

Database: Docker Postgres via `DATABASE_URL` in `.env`. Redis for Sidekiq.

---

## Step 0 — Scope and repository foundation `[x]`

**Goal.** Decide what is being built, for whom, and the rules that every later
step obeys. Produce a bootable Rails skeleton so each step has a home.

1. `[x]` 0.1 Initialize git repository, `.gitignore` (secrets, `.env`,
   `tmp/`, `log/`, credentials keys), MIT `LICENSE`.
2. `[x]` 0.2 Generate Rails app: `rails new . -d postgresql --skip-solid`
   (Hotwire on; Sidekiq instead of Solid Queue).
3. `[x]` 0.3 Add gems: Sidekiq, Redis, sidekiq-cron, Faraday, dotenv-rails,
   letter_opener (dev), `connection_pool ~> 2.4` (Sidekiq 7 compat). Bundle.
4. `[x]` 0.4 Configure `config/sidekiq.yml`, `config/schedule.yml`, Redis URL,
   Active Job adapter `:sidekiq`. Document ENV in `.env.example`.
5. `[x]` 0.5 Tracker `docs/BUILD_PLAN.md`; product bible `APPROACH.md`.
6. `[x]` 0.6 ADR-0001: stack (Rails, Postgres, Sidekiq, Redis, Sidekiq-Cron,
   Faraday, Action Mailer, Hotwire).
7. `[x]` 0.7 ADR-0002: alert decisions are deterministic code (`AlertEvaluator`);
   no LLM in the trigger path.
8. `[x]` 0.8 ADR-0003: timezone-aware hourly dispatch; compare local hour, not
   server wall-clock alone.
9. `[x]` 0.9 `README.md` with product description and local boot commands.

**Artifact.** Bootable Rails 8.1 app, `docs/BUILD_PLAN.md`,
`docs/adr/000{1,2,3}-*.md`, `README.md`, `.env.example`, Sidekiq wired,
Docker Postgres on :5433.

**Verify.** `bin/rails db:prepare` → `weather_check_development`;
`bin/rails s` → `/` and `/up` HTTP 200; `bundle exec sidekiq` stays up against
Redis; Step 0 commit on `main`.

**Measured on 2026-10-11.** Ruby 3.3.12, Rails 8.1.4, Sidekiq 7.3.9,
Postgres 16 (Docker), Redis PONG.

---

## Step 1 — Auth and alert preferences `[ ]`

**Goal.** A user can register, sign in, and persist a single location plus
alert preferences. No weather API yet.

1. `[ ]` 1.1 Auth: Rails 8 authentication generator **or** Devise — pick one
   and stick. Sessions for sign-in / sign-out / sign-up.
2. `[ ]` 1.2 Migration on `users` (or split only if needed later):
   `location_label`, `latitude`, `longitude`, `timezone`, `alert_time`,
   `rain_threshold` (integer, default 40–50), `alerts_enabled` (boolean,
   default true), `last_alerted_at` (datetime, nullable).
3. `[ ]` 1.3 Validations: email uniqueness; timezone in
   `ActiveSupport::TimeZone`; `rain_threshold` 0–100; location label present;
   lat/long present and in range (or city-only deferred — document choice).
4. `[ ]` 1.4 `PreferencesController` + Hotwire/ERB form: location, timezone
   select, alert time, threshold, enabled toggle. Strong params. Flash on save.
5. `[ ]` 1.5 Root / dashboard shows simple status: “Alerts on · next window ~
   {local time}” (optional but preferred).
6. `[ ]` 1.6 Tests: invalid timezone rejected; invalid threshold rejected;
   happy-path preferences persist.
7. `[ ]` 1.7 Seed: one demo user with Lagos preferences (fake email only).

**Artifact.** Auth + preferences UI; schema for alert fields; preference
tests; `db/seeds.rb` demo user.

**Verify.** Sign up → save preferences → reload shows same values;
`bin/rails test` (or `bundle exec rspec`) green for preference/auth cases;
no weather network calls in this step.

---

## Step 2 — Weather client and rule engine `[ ]`

**Goal.** Given lat/long + threshold, fetch (or stub) a forecast and decide
trigger in pure Ruby — no mail yet.

1. `[ ]` 2.1 Lock provider: OpenWeatherMap **or** WeatherAPI. Document in
   ADR or `docs/weather_provider.md`. ENV: `WEATHER_API_KEY`,
   `WEATHER_PROVIDER`.
2. `[ ]` 2.2 `app/services/forecast.rb` value object:
   `precipitation_probability`, `summary`, `wind_speed`, `raw`, `fetched_at`.
3. `[ ]` 2.3 `app/services/weather_client.rb` (Faraday): GET forecast by
   lat/long; normalize into `Forecast`; typed errors for timeout / 401 / 429.
4. `[ ]` 2.4 `app/services/alert_evaluator.rb`: POP ≥ `rain_threshold` →
   trigger; optional heavy-precip constant; otherwise no email. Return
   structured decision with `trigger?` and `reason` string
   (e.g. `precipitation_probability=62 >= threshold=50`).
5. `[ ]` 2.5 Unit tests with Faraday stub / WebMock — **no network in CI**.
   Below threshold → no trigger; at/above → trigger; client normalizes stub
   JSON.
6. `[ ]` 2.6 Optional: `bin/rails runner` or rake task to print decision for
   one seeded user (manual live key once, not CI).
7. `[ ]` 2.7 Document forecast window choice (next N hours vs daily) in
   `docs/definitions.md`.

**Artifact.** `WeatherClient`, `Forecast`, `AlertEvaluator`, provider docs,
evaluator + client tests.

**Verify.** `bin/rails test test/services/` (or equivalent) green; manual
live fetch once with real key succeeds locally; CI never calls the provider.

---

## Step 3 — Mailer and per-user alert job `[ ]`

**Goal.** Background job fetches forecast, evaluates rules, and emails only
when triggered. Web requests never call the weather API or SMTP.

1. `[ ]` 3.1 `WeatherMailer`: HTML + text templates. Subject includes location
   + local date. Body contract: location, forecast facts, why it fired, short
   factual recommendation (no toy “umbrella” product framing).
2. `[ ]` 3.2 `WeatherAlertJob#perform(user_id)`: load user; bail if alerts
   disabled; fetch → evaluate → `deliver_now` inside job if triggered; set
   `last_alerted_at`. Prefer `deliver_now` inside the job (avoid nested
   deliver_later surprises).
3. `[ ]` 3.3 Dev delivery: Letter Opener or log delivery. `MAILER_FROM` from
   ENV.
4. `[ ]` 3.4 Failure handling: missing user → drop; timeout → retry with
   backoff (e.g. 3x); 401 → fail loudly, limited retries; SMTP → retry then
   dead set.
5. `[ ]` 3.5 Tests: trigger path invokes mailer; non-trigger does not; mailer
   renders location + reason (assert body).
6. `[ ]` 3.6 Manual console: `WeatherAlertJob.perform_later(user.id)` for
   demo user; open Letter Opener.

**Artifact.** `WeatherMailer`, `WeatherAlertJob`, job/mailer tests, working
dev email path.

**Verify.** Trigger path shows mail in Letter Opener; non-trigger sends
nothing; Sidekiq retries documented failure without crashing the web process;
tests green with stubbed client.

---

## Step 4 — Hourly dispatch and timezone selection `[ ]`

**Goal.** Cron selects only users whose **local** alert hour matches the
current hour in their timezone; at most one alert email per user per local
day.

1. `[ ]` 4.1 `DispatchDueAlertsJob`: for each `alerts_enabled` user, convert
   `Time.current` with `ActiveSupport::TimeZone[user.timezone]`; enqueue
   `WeatherAlertJob` only when `local.hour == user.alert_time.hour`.
2. `[ ]` 4.2 Sidekiq-Cron schedule `config/schedule.yml` (or equivalent):
   `0 * * * *` → `DispatchDueAlertsJob`.
3. `[ ]` 4.3 Idempotency: skip if already alerted today in the user’s
   timezone (`last_alerted_at`) **or** unique `alert_deliveries`
   `(user_id, local_date)` — pick one and document.
4. `[ ]` 4.4 Invalid timezone: skip user + error log; do not crash the batch.
5. `[ ]` 4.5 Tests with frozen time: `Africa/Lagos` user due at 07:00 local
   is selected at the matching UTC hour; wrong hour not selected; disabled
   user not selected; same local day not double-enqueued after send.
6. `[ ]` 4.6 Optional: SQL/Ruby batch notes in `docs/scheduling.md` (find_each,
   concurrency limits).

**Artifact.** `DispatchDueAlertsJob`, cron schedule, idempotency, timezone
tests.

**Verify.** Timezone selection tests green; running dispatch with frozen time
enqueues only due users; second run same local day does not spam; invalid
timezone skipped safely.

---

## Step 5 — Hardening, demo polish, and definition of done `[ ]`

**Goal.** Safe to show on a CV / interview. Fresh machine path works.
Optional small deploy only after the loop is solid.

1. `[ ]` 5.1 Polish rescues: 429 backoff, concurrency limits on Sidekiq,
   no full raw API dumps at INFO in production.
2. `[ ]` 5.2 Forecast cache by rounded lat/long (30–60 min) — optional MVP+;
   skip if not needed yet.
3. `[ ]` 5.3 README: screenshots or terminal demo, “try this in 15 minutes”
   path, architecture one-liner, honest learning-project framing.
4. `[ ]` 5.4 Seeds + Manual QA script from APPROACH §13 executed and checked
   off below.
5. `[ ]` 5.5 Secrets audit: no API keys, real emails, or credentials in git.
6. `[ ]` 5.6 Optional deploy (Fly.io / Render / VPS): Sidekiq + Redis +
   Postgres + SMTP; smoke-test one real alert.
7. `[ ]` 5.7 Résumé / portfolio links **only after** this step’s Verify
   passes.

**Artifact.** Polished README, QA evidence, optional live URL, no secrets in
repo.

**Verify.** Fresh clone: README alone gets app running; Manual QA script
(below) all pass; `git secrets` / eyeball: no committed keys.

### Manual QA script (must pass before Step 5 `[x]`)

1. `[ ]` User A: timezone `Africa/Lagos`, alert hour = current Lagos hour,
   threshold `0` (or mocked high POP) → dispatch → mail appears.
2. `[ ]` Threshold `100` with mocked low POP → no mail.
3. `[ ]` Timezone so local hour ≠ now → user not selected.
4. `[ ]` `alerts_enabled = false` → not selected.
5. `[ ]` Broken API key → job fails/retries; preferences UI still serves.
6. `[ ]` Restart Redis/Sidekiq → preferences page still works.

---

## Step 6 — Documentation and pitch package `[ ]`

**Goal.** A third party (or interviewer) can understand the product, run the
demo, and map skills to Simple-style Rails work.

1. `[ ]` 6.1 README table of contents; demo flow diagram
   (`docs/demo-flow.svg` or mermaid in README).
2. `[ ]` 6.2 `docs/pitch.md`: one section per learning use case (accounts →
   prefs → cron → fetch → decide → notify) with screen, metric/test, file
   path; Simple skill mapping (from APPROACH §14).
3. `[ ]` 6.3 5–7 minute walkthrough **script** (`docs/walkthrough.md`) for
   recording or live demo.
4. `[ ]` 6.4 `docs/responsible_ops.md` (short): secrets, PII (email), retries,
   what the system never does (LLM decisions, spam without threshold).
5. `[ ]` 6.5 Definition of done checklist mirrored in README.

**Artifact.** README demo path, `docs/pitch.md`, `docs/walkthrough.md`,
ops/privacy note, demo diagram.

**Verify.** A reader can run the demo from README alone in under 15 minutes;
walkthrough script matches actual screens; pitch maps each feature to a file
path.

---

## Out of scope (do not pull into MVP steps)

| Deferred | Earliest after |
| --- | --- |
| SMS / WhatsApp / push | Step 5 email path solid |
| Multi-location per user | Step 1 single location proven |
| Admin dashboard / send metrics | Step 4 jobs logged |
| Docker Compose one-shot | Local path proven |
| In-app geocoding city → lat/long | Manual lat/long works |
| Kubernetes / GraphQL / separate React SPA | Never for this MVP |

---

## Progress log

| Date | Step | Note |
| --- | --- | --- |
| 2026-10-11 | — | Tracker written from `APPROACH.md`. No Rails app generated yet. |
| 2026-10-11 | prereq | rbenv + Ruby 3.3.12; Bundler; Docker Postgres 16 on host :5433 (`weathercheck-db`); root `.env` + `.gitignore`; Redis already local. Ready for Step 0. |
| 2026-10-11 | 0 | Rails 8.1 app generated (`--skip-solid`); Sidekiq + Redis + Faraday + dotenv + letter_opener; ADRs 0001–0003; README; DB prepared; web + Sidekiq verified. |

---

## Implementation order cheat sheet

| Order | Work | Entry |
| ---: | --- | --- |
| 0 | Rails app, Postgres, Redis, Sidekiq, ADRs, README | `rails new` |
| 1 | Auth + preferences UI | `PreferencesController` |
| 2 | Weather client + evaluator + tests | `app/services/*` |
| 3 | Mailer + `WeatherAlertJob` | `app/jobs`, `app/mailers` |
| 4 | Hourly dispatch + timezone selection | `DispatchDueAlertsJob` |
| 5 | Hardening, QA, optional deploy | Manual QA + README |
| 6 | Pitch package + walkthrough | `docs/pitch.md` |

**Next concrete action:** Step 0 only — generate the Rails app, wire Postgres
+ Redis + Sidekiq, write `README.md` and ADRs, mark tasks `[x]` only when
Verify passes.
