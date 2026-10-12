# Scheduling and timezones

## What runs

| Piece | Role |
| --- | --- |
| Sidekiq-Cron (`config/schedule.yml`) | Fires `DispatchDueAlertsJob` at `0 * * * *` (top of every hour) |
| `DispatchDueAlertsJob` | Selects users due **in their local hour** and enqueues work |
| `WeatherAlertJob` | Fetch → evaluate → email one user |

## Selection rules (MVP)

For each `alerts_enabled` user with complete preferences:

1. Resolve `ActiveSupport::TimeZone[user.timezone]`.
2. If invalid → **log and skip** (do not crash the batch).
3. Compare `now.in_time_zone(zone).hour` to `user.alert_time.hour`
   (minute precision is out of scope for MVP).
4. Idempotency via `last_alerted_at`: if that timestamp falls on the same
   **local calendar date** as “now” in the user’s zone → skip (no double email
   the same local day, even if cron re-fires).

## Batch style

- Use `User.alerts_enabled.find_each` (batches of 1000) so we never load all
  users into memory.
- Hour matching is done in Ruby after timezone conversion — clearer and safer
  than trying to express every TZ offset in SQL for MVP.
- Sidekiq concurrency is capped in `config/sidekiq.yml` so weather API calls
  do not stampede (each due user becomes its own `WeatherAlertJob`).

## Manual run

```bash
bin/rails alerts:dispatch
# or
bin/rails runner 'DispatchDueAlertsJob.perform_now'
```

Frozen-time tests live in `test/jobs/dispatch_due_alerts_job_test.rb`.
