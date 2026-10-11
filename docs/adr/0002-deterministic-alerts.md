# ADR-0002: Deterministic alert decisions (no LLM)

## Status

Accepted — 2026-10-11

## Context

The product decides whether to email a user about weather risk. LLMs are
tempting for “should we alert?” language, but they are non-deterministic,
harder to test, and unrelated to the Rails skills this project practices.

## Decision

- Threshold evaluation lives in pure Ruby (`AlertEvaluator` from Step 2).
- Inputs: normalized forecast + user `rain_threshold` (and optional fixed rules).
- Outputs: `trigger?` plus a machine-readable reason string for the email body.
- No LLM in the fetch → decide → notify path. Ever, for MVP.

## Consequences

- Easy unit tests: below threshold → no mail; at/above → mail.
- Failures are boring and debuggable (API errors, SMTP errors), not model drift.
- Copy stays factual (“Rain likely for Lagos: 62% chance…”) rather than toy UX.
