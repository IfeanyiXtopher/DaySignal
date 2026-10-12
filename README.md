# WeatherCheck

Timezone-aware **weather alert delivery**. Users save a location, a local alert
time, a timezone, and a rain threshold. An hourly job selects people due in
their local hour, fetches a forecast, applies deterministic rules, and emails
them asynchronously via Sidekiq.

Learning project: practice Rails patterns used by systems like
[Simple](https://docs.simple.org/) (ActiveRecord, Sidekiq, cron, Action Mailer,
Hotwire). Not a meteorology product. Decisions are **code**, not an LLM.

## Docs

| Doc | Purpose |
| --- | --- |
| [`APPROACH.md`](APPROACH.md) | Product rules and architecture bible |
| [`docs/BUILD_PLAN.md`](docs/BUILD_PLAN.md) | Step tracker — read *Current position* first |
| [`docs/adr/`](docs/adr/) | Architecture decision records |

## Stack (locked)

Rails 8 · PostgreSQL (Docker) · Redis · Sidekiq · Sidekiq-Cron · Faraday ·
Action Mailer · Hotwire

## Prerequisites (once per machine)

- Ruby **3.3.12** via rbenv (see `.ruby-version`)
- Docker Desktop (Postgres)
- Redis (`redis-cli ping` → `PONG`)
- Copy `.env.example` → `.env` and fill secrets

## Local boot (about 5 minutes)

```bash
# 0) Toolchain
cd /path/to/WeatherCheck
ruby -v                    # expect 3.3.12

# 1) Data services
#    Docker Desktop must be running
docker compose up -d       # Postgres on localhost:5433
redis-cli ping             # PONG

# 2) App
bundle install
bin/rails db:prepare

# 3) Processes (two terminals)
bin/rails server           # http://localhost:3000
bundle exec sidekiq -C config/sidekiq.yml
```

Health check: [http://localhost:3000/up](http://localhost:3000/up)

### Demo user (after `bin/rails db:seed`)

| Field | Value |
| --- | --- |
| Email | `demo@weathercheck.local` |
| Password | `password123` |
| Location | Lagos, Nigeria (`Africa/Lagos`, 07:00, threshold 50%) |

Sign up at `/registration/new`, then save preferences at `/preferences/edit`.

### Manual weather decision (Step 2, live API — not CI)

```bash
EMAIL=demo@weathercheck.local bin/rails weather:evaluate
```

Uses `WEATHER_API_KEY` from `.env`. Automated tests stub Faraday and never
call the network. Rules/docs: [`docs/definitions.md`](docs/definitions.md),
[`docs/weather_provider.md`](docs/weather_provider.md).

### Manual alert email (Step 3)

```bash
# Default: opens mail in the browser (Letter Opener)
EMAIL=demo@weathercheck.local bin/rails alerts:deliver_one

# Real Gmail SMTP (uses SMTP_* from `.env`):
#   MAILER_DELIVERY_METHOD=smtp EMAIL=you@example.com bin/rails alerts:deliver_one
```

Sidekiq path (async): `WeatherAlertJob.perform_later(user.id)` with
`bundle exec sidekiq -C config/sidekiq.yml` running.

## Layout (where logic will live)

```
app/
  models/          # User + alert preference fields (Step 1)
  services/        # WeatherClient, Forecast, AlertEvaluator (Step 2)
  jobs/            # WeatherAlertJob, DispatchDueAlertsJob (Steps 3–4)
  mailers/         # WeatherMailer (Step 3)
  controllers/     # Auth + preferences (Step 1)
config/
  sidekiq.yml
  schedule.yml     # Sidekiq-Cron (Step 4)
docker-compose.yml # Postgres 16
docs/BUILD_PLAN.md
```

## Environment variables

See `.env.example`. Important locally:

- `POSTGRES_*` / host port **5433** (Compose; host Postgres 18 may own 5432)
- `REDIS_URL`
- `WEATHER_API_KEY` (live fetch from Step 2; tests stub the network)

## Current build step

See **Current position** in [`docs/BUILD_PLAN.md`](docs/BUILD_PLAN.md).
