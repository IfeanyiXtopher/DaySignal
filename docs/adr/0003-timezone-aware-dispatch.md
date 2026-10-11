# ADR-0003: Timezone-aware hourly dispatch

## Status

Accepted — 2026-10-11

## Context

Users choose a **local** alert time (e.g. 07:00 in `Africa/Lagos`). The server
may run in UTC on a VPS. Comparing only the server clock would email people at
the wrong local hour.

## Decision

- A Sidekiq-Cron job runs every hour (`DispatchDueAlertsJob` in Step 4).
- For each alerts-enabled user, convert `Time.current` with
  `ActiveSupport::TimeZone[user.timezone]` and enqueue work only when
  `local.hour == user.alert_time.hour`.
- Idempotency: at most one alert email per user per local calendar day.
- Invalid timezones are skipped with a log line; the batch must not crash.

## Consequences

- Scheduling tests freeze time and assert Lagos vs other zones.
- MVP compares **hour** only (minute precision can come later).
- Product rule: “local timezone, not server wall-clock alone.”
