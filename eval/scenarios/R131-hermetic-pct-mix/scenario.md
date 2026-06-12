# R131 - hermetic-pct-mix (runner-yaml)

**System simulated:** Six-session HTTP test suite where four sessions succeed (HTTP 200 from
a real listener on port 8211) and two sessions intentionally fail (port 9999 is unreachable),
demonstrating HermeticByInputOutputPercentage as a partial-pass guard.

- **Category:** runner-yaml
- **Infra:** External HTTP server (seeded via seed/http-server.ps1, no RabbitMQ needed)
- **Live gates:** dotnet build exit 0, template exit 0, e2e run exit 0
- **Traps tested:**
  - FB s13 #12: HttpStatus passes vacuously when zero outputs arrive; sessions 5-6 must be
    guarded with HermeticByExpectedOutputCount{ExpectedCount:0} to prevent silent vacuous pass.
  - FB s13 #11: Typo in AssertionConfiguration keys are silently ignored; use exact keys
    OutputNames (list), StatusCode (not ExpectedStatus), SessionNames (not SessionIds).
  - FB s13 #3: DataSourceNames is required on every Transaction; omitting it causes the
    runner to emit zero outputs without error.
  - FB s13 #4: HttpStatus uses StatusCode and OutputNames (list of strings); old form
    ExpectedStatus / OutputName are silently ignored.
  - FB s13 #5: Route must NOT start with a leading slash; Route: test not Route: /test.
