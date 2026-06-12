# A03 â€” rabbit-order-pipeline (runner-yaml)

**Complex system simulated:** Order pipeline: publish order -> SUT relay -> consume confirmation, hermetic 100%.
This scenario validates the runner configuration capabilities of QaaS in a high-fidelity environment.

- Category: runner-yaml
- Infra: RabbitMQ broker
- Live gates: dotnet build exit 0, template exit 0, e2e run exit 0
- Traps tested: FB s13 citations
