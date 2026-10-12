# Responsible operations (short)

How DaySignal handles secrets, PII, retries, and hard “never” rules for the MVP.

---

## Secrets

| Rule | Practice |
| --- | --- |
| API keys and SMTP passwords live in ENV | Root `.env` (gitignored); template in `.env.example` |
| Never commit live keys | Audit: no `WEATHER_API_KEY` / SMTP secrets in tracked files |
| Weather responses | Log status / error class only — not full forecast bodies at INFO |
| Credentials | Prefer ENV for this MVP; Rails credentials optional later |

---

## PII

| Data | Handling |
| --- | --- |
| Email | Account identifier; required for mail delivery |
| Location label / lat / lng | User-provided preference; shown in alert email |
| Seeds | Use `demo@daysignal.local` only — never real personal addresses in repo |

Auth is required for preferences. Password reset uses the same mailer stack as
the rest of the app (Letter Opener in dev).

---

## Retries and failure behavior

| Failure | Behavior |
| --- | --- |
| Weather timeout / HTTP 429 | Job retries (bounded); warn-level logging for 429 |
| Weather HTTP 401 | Fail fast (bad key) — do not hammer the provider |
| SMTP / delivery errors | Bounded retries on the job |
| Missing user | Job no-op |
| Invalid timezone at dispatch | Log + skip; other users still processed |
| Sidekiq / Redis down | Prefs UI and auth still serve; alerts queue until workers return |

Web requests **do not** call OpenWeatherMap or SMTP. Fetch + send happen only
inside jobs (or explicit rake tasks for demos).

---

## What the system never does (MVP)

1. **LLM decisions** — `AlertEvaluator` is deterministic Ruby only.
2. **Spam without a threshold match** — no email when rules say pass (silent).
3. **More than one alert stamp per local calendar day** — `last_alerted_at`
   idempotency (see `docs/scheduling.md`).
4. **Network weather calls in CI** — Faraday stubs / injectable client.
5. **Commit secrets or real-user seed emails.**

---

## Operator checklist (before a public demo)

- [ ] `.env` present locally; not staged for git
- [ ] `bin/rails test` green
- [ ] Sidekiq running if you will show live dispatch
- [ ] Letter Opener or SMTP configured intentionally
- [ ] Demo account password known; not a production secret reused elsewhere

For deploy hardening (HTTPS, real SMTP, host Postgres ports), see BUILD_PLAN
Step 5.6 when you choose to ship a VPS URL.
