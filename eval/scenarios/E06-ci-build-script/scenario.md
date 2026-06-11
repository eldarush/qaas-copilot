# E06 â€” ci-build-script (docker-image)

**Complex system simulated:** Reusable build-test-run script for mocker images.
Validates containerization, packaging, multi-stage Dockerfiles, and orchestrations of QaaS services.

- Category: docker-image
- Infra: Local Docker daemon
- Live gates: docker build exits 0, container starts and serves traffic correctly
- Traps tested: FB s13 citations
