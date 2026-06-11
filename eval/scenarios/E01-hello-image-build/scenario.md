# E01 — hello-image-build (docker image)

**Complex system simulated:** Platform engineering wants the team's static *hello* mocker shipped
as a reusable container image so CI agents and the airgapped lab can `docker run` it without the
.NET SDK. The mocker project already works; only the packaging is missing.

**Weak-model job (single task):** author a multi-stage `Dockerfile` (sdk:10.0 build →
**aspnet:10.0** runtime — FB s13#7: the runtime image lacks the HTTP stack the mocker needs),
a `.dockerignore`, and `BUILD.md`. The verify gate actually builds the image, runs it with
`-p 8094:8080`, curls `/hello` through the mapped port, and cleans up.

- Category: docker-image
- Infra: local docker daemon (no compose services)
- Seed: working Hello/ mocker project (yaml listens on container-internal port 8080)
- Live gates: docker build exit 0; running container answers `hello` on host port 8094
