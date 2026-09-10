# Scope: Example Initiative

## Destination

Build a CLI tool that exports observability data from the monitoring system to CSV, then posts the report to a configured webhook endpoint. Users trigger exports via command-line arguments and receive confirmation of delivery.

## Notes

- **Domain:** CLI tooling, webhook integrations, observability data export.
- **Skills to consult:** `webhook-best-practices` for delivery guarantees; CLI argument parsing conventions in your framework.
- **Standing preferences:** Favor explicit CLI flags over config files for single-run operations; webhook payloads should be deterministic and idempotent for safe retries; all exported files must include a manifest describing the export time and schema version.

## Decisions so far

- [Which webhook auth scheme](tickets/webhook-auth.md) — bearer token from env var `WEBHOOK_TOKEN`, refreshed per invocation.

## Phases

| Phase | Title | PRD | Status |
|-------|-------|-----|--------|
| phase-01 | CSV export | docs/example/prds/prd-01-csv-export.md | running |
| phase-02 | Webhook delivery | | researching |

## Not yet specified

- How to handle CSV schemas that change over time (version in filename, or separate manifest?).
- Whether to batch multiple exports into one webhook call or send them separately.

## Out of scope

- Streaming large exports (files > 1GB) — CSV export is optimized for < 100MB monthly snapshots, uploads happen in-process rather than chunked.
