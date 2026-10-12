# ADR-0001: Application stack

## Status

Accepted — 2026-10-11

## Context

DaySignal is a learning MVP that practices production Rails patterns used by
systems like Simple (Resolve to Save Lives): models, background jobs, cron,
mailers, and a small Hotwire UI. It will run locally and later on a small VPS.

## Decision

| Layer | Choice |
| --- | --- |
| Language | Ruby 3.3 (rbenv) |
| Framework | Rails 8.x |
| Database | PostgreSQL 16 (Docker Compose locally and on VPS) |
| Background jobs | Sidekiq + Redis |
| Scheduling | Sidekiq-Cron (hourly dispatch in Step 4) |
| HTTP client | Faraday (weather API) |
| Email | Action Mailer + Letter Opener (dev) / SMTP (VPS) |
| Frontend | Hotwire (Turbo + Stimulus) + ERB — no separate SPA |
| Secrets | Root `.env` (dotenv-rails) + Rails credentials for `master.key` |

We skip Rails 8 Solid Queue/Cache/Cable defaults in favour of Sidekiq + Redis,
which matches the job of “async work beside the web process” more closely to
Simple-style Sidekiq usage.

## Consequences

- Local and VPS both need Redis and Postgres (Compose provides Postgres).
- Two processes to run in development: `bin/rails s` and `bundle exec sidekiq`.
- Weather and mail work must live in jobs/services, not controllers.
