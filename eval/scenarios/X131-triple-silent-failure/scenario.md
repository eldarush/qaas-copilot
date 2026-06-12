# X131 - triple-silent-failure (diagnose)

**Complex system simulated:** Three stacked silent assertion failures produce an exit-0 suite that tests nothing.
Validates root-cause analysis across vacuous-pass and silently-ignored-key traps.

- Category: diagnose
- Infra: None
- Live gates: DIAGNOSIS.md names all three broken keys; fixed YAML exits 0 with genuine assertions
- Traps tested: s13#12 (silently ignored config key), s13#13 (vacuous HttpStatus + vacuous hermetic guard)
