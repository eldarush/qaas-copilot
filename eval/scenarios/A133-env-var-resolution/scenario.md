# A133 - env-var-resolution (analyze-sut-repo)

**Complex system simulated:** Helm chart for a payment-gateway service where env vars are sourced
from five layers (appsettings defaults, Helm base values, Helm prod overlay, K8s ConfigMap envFrom,
and K8s explicit env overrides), requiring full provenance tracing to determine effective runtime
config.

- Category: analyze-sut-repo
- Infra: None (analysis only, no running services)
- Live gates: Select-String checks on analysis output files confirm planted effective values appear
- Traps tested: multi-layer override precedence, K8s explicit-env overrides envFrom, Helm prod
  overlay vs base values, base64-encoded secrets decodable from secret.yaml, wrong effective value
  if any layer is skipped
