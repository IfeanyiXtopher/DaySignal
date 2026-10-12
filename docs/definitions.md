# Definitions

## Forecast window (MVP)

When evaluating an alert we look at OpenWeatherMap **3-hour forecast slots**
whose start time falls in the next **12 hours** from fetch time.

- **POP used for the decision:** the **maximum** `pop` among those slots,
  converted to an integer percent `0–100`.
- If no slot falls in the window (rare clock skew / empty list), fall back to
  the first slot in the API `list`.

Rationale: a single “will it rain around my alert hour?” check without needing
One Call hourly data. Documented so Step 3 jobs and emails share the same rule.

## Alert trigger (deterministic)

| Condition | Result |
| --- | --- |
| `precipitation_probability >= user.rain_threshold` | Trigger email |
| Else if any window slot has rain volume (`rain.3h`) ≥ **5.0 mm** | Trigger (heavy precip) |
| Otherwise | No email (silent pass) |

No LLM participates in this decision.

## Forecast fields we keep

| Field | Meaning |
| --- | --- |
| `precipitation_probability` | Max POP % in the 12h window |
| `summary` | Weather description from the slot that supplied the max POP |
| `wind_speed` | Wind speed (m/s, metric) from that same slot |
| `raw` | Slim hash of the slots considered (debug; not mailed wholesale) |
| `fetched_at` | When we fetched |
