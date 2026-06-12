# E02 â€” image-with-controller (docker-image)

**Complex system simulated:** Containerized controller mocker reaching host Redis.
Validates containerization, packaging, multi-stage Dockerfiles, and orchestrations of QaaS services.

- Category: docker-image
- Infra: Local Docker daemon
- Live gates: docker build exits 0, container starts and serves traffic correctly
- Traps tested: FB s13 citations
