# DaySignal — Pitch package

One page for interviews: what it is, the learning loop, where the code lives,
and how it maps to Simple-style Rails work.

**Honest framing:** learning production Rails app with a real end-to-end loop —
not a meteorology product. Threshold decisions are **Ruby code**, never an LLM.

---

## One-sentence product

Users save a location and rain threshold; every hour we select people due in
**their** local timezone, fetch a forecast, apply deterministic rules, and
email asynchronously via Sidekiq.

---

## Learning use cases (accounts → prefs → cron → fetch → decide → notify)

### 1. Accounts

| | |
| --- | --- |
| **Screen** | Sign up / Sign in (`/sign_up`, `/session/new`) |
| **What you learn** | Rails 8 generator auth (sessions, password reset) + custom registration |
| **Metric / test** | Registration + session coverage in `test/controllers/` |
| **Files** | `app/controllers/registrations_controller.rb`, `sessions_controller.rb`, `app/controllers/concerns/authentication.rb`, `app/models/user.rb`, `session.rb` |

### 2. Preferences

| | |
| --- | --- |
| **Screen** | Preferences (`/preferences/edit`) — location search, lat/lng, timezone, alert time, threshold, enable toggle |
| **What you learn** | Strong params, contextual validations, Hotwire/Stimulus UX, optional geocode + timezone APIs |
| **Metric / test** | Invalid TZ/threshold rejected; happy-path persist; geocode endpoint stubbed |
| **Files** | `app/controllers/preferences_controller.rb`, `app/views/preferences/edit.html.erb`, `app/javascript/controllers/location_picker_controller.js`, `app/services/geocoding_client.rb`, `app/services/timezone_lookup.rb`, `app/controllers/geocodings_controller.rb` |

### 3. Cron / dispatch

| | |
| --- | --- |
| **Screen** | No UI — Sidekiq-Cron + `alerts:dispatch` rake |
| **What you learn** | Hourly selection by **local** hour; skip disabled / wrong hour / bad TZ; enqueue only due users |
| **Metric / test** | Frozen-time cases: Lagos due, wrong hour, Nairobi vs Lagos, invalid TZ (`test/jobs/dispatch_due_alerts_job_test.rb`) |
| **Files** | `app/jobs/dispatch_due_alerts_job.rb`, `config/schedule.yml`, `docs/scheduling.md`, `User#dispatch_status` in `app/models/user.rb` |

### 4. Fetch

| | |
| --- | --- |
| **Screen** | Optional CLI: `bin/rails weather:evaluate EMAIL=...` |
| **What you learn** | Faraday client, typed errors (timeout / 401 / 429), injectable connection for tests |
| **Metric / test** | `test/services/weather_client_test.rb` — **no network in CI** |
| **Files** | `app/services/weather_client.rb`, `app/services/forecast.rb`, `docs/weather_provider.md` |

### 5. Decide

| | |
| --- | --- |
| **Screen** | Decision appears in email body / evaluate task output |
| **What you learn** | Pure Ruby rule engine; POP ≥ threshold or heavy precip ≥ 5 mm / 3h |
| **Metric / test** | `test/services/alert_evaluator_test.rb`; rules in `docs/definitions.md` |
| **Files** | `app/services/alert_evaluator.rb` |

### 6. Notify

| | |
| --- | --- |
| **Screen** | Letter Opener tab (dev) or SMTP inbox |
| **What you learn** | Active Job → mailer; idempotency via `last_alerted_at` (one stamp per local day) |
| **Metric / test** | Job + mailer tests; Manual QA `test/integration/manual_qa_test.rb` |
| **Files** | `app/jobs/weather_alert_job.rb`, `app/mailers/weather_mailer.rb`, `app/views/weather_mailer/` |

---

## Simple / RTSL skill mapping (APPROACH §14)

| DaySignal piece | Transferable skill |
| --- | --- |
| ActiveRecord models + migrations | Simple server models |
| Sidekiq jobs | Async work, sync-adjacent patterns |
| Sidekiq-Cron | Scheduled overdue / reminder style work |
| Action Mailer | Outbound patient/staff messaging patterns |
| Timezones | Global health programs across regions |
| Faraday + external API | Integrations (weather ↔ DHIS2/EHR-style adapters) |
| Hotwire CRUD + Stimulus | Small internal tools without a SPA |
| Idempotent daily send | “Don’t spam” operational hygiene |
| Deterministic evaluator | Business rules in code, not opaque models |

---

## Demo proof points (say these out loud)

1. **Timezone correctness** — Lagos 07:00 selected; wrong hour skipped (tests prove it).
2. **No LLM in the trigger path** — `AlertEvaluator` is plain Ruby (`docs/adr/0002-deterministic-alerts.md`).
3. **CI never hits weather** — Faraday test adapter stubs.
4. **Prefs UI survives worker failure** — Manual QA #5–#6.
5. **Secrets stay out of git** — `.env` gitignored; `.env.example` only.

---

## Related docs

- Live walkthrough script: [`walkthrough.md`](walkthrough.md)
- Ops / privacy: [`responsible_ops.md`](responsible_ops.md)
- Tracker: [`BUILD_PLAN.md`](BUILD_PLAN.md)
