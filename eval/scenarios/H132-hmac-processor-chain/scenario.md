# H132 -- hmac-processor-chain (hooks)

**Complex system simulated:** A signing gateway: clients send base64-encoded JSON; the gateway
decodes, mutates a configured field, recomputes an HMAC-SHA256 signature over the mutated body,
and returns `{"payload":"<base64>","signature":"<base64>"}`. A paired runner assertion re-derives
the HMAC independently and verifies authenticity end-to-end.

**Weak-model job:** author a custom `BaseTransactionProcessor<SignedMutateConfig>` (mocker side)
performing the three-phase chain (decode -> mutate -> HMAC-sign), wire it into a mocker YAML on
port 8231, then author a custom `BaseAssertion<HmacSignatureConfig>` (runner side) that
recomputes the HMAC and verifies the returned signature, complete with a hermetic count guard.

- Category: hooks (custom mocker processor + custom runner assertion)
- Infra: None (mocker runs as a local dotnet process on port 8231; no broker)
- Live gates: dotnet build exit 0 (both projects), template exit 0 (both), live e2e runner exit 0
- Traps tested: s13#1 (ProcessorConfiguration key not TransactionData), s13#7 (aspnet Dockerfile
  base for mocker), s13#9 (Mocker 2.4.1 / Common.Processors 1.5.1 / Common.Assertions 3.5.1),
  s13#5 (ALL-LOWERCASE route, no leading slash on runner Route), s04 (stateless processor,
  Configuration=null in ctor, [Required] DataAnnotations on config records),
  s13#12 (HermeticByExpectedOutputCount guard -- HttpStatus passes vacuously on zero outputs),
  NoConfiguration->object trap (use typed config record instead).
