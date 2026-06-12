# A07 â€” staged-controller-failover (runner-yaml)

**Complex system simulated:** PSP failover: stage1 200, stage2 ChangeActionStub->503, stage3 assert degraded.
This scenario validates the runner configuration capabilities of QaaS in a high-fidelity environment.

- Category: runner-yaml
- Infra: Redis container
- Live gates: dotnet build exit 0, template exit 0, e2e run exit 0
- Traps tested: FB s13 citations
