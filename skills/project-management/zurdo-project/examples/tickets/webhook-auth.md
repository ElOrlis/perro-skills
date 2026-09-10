---
type: grilling
question: Which auth scheme should the webhook use?
status: resolved
blocked-by: []
---

## Question

The tool must authenticate outbound webhook requests to prevent unauthorized access. Options include bearer token from environment variable, mTLS with client certificates, or API key headers. We need to choose a scheme that balances operational simplicity (for single-instance CLI use) with security (for production deployments).

## Findings

Bearer token authentication via `Authorization: Bearer $WEBHOOK_TOKEN` environment variable is the best fit for this use case. The scheme is widely supported, requires no certificate management overhead, and works well for CLI tooling where environment configuration is the norm. Tokens can be rotated by updating the env var without redeploying the CLI binary.
