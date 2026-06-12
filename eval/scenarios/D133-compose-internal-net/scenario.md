# D133 - compose-internal-net (docker-image)

**Complex system simulated:** Docker Compose topology where mocker and redis share an
internal-only network; mocker port 8251 bridged to host; QaaS runner runs on host after
docker healthcheck gate confirms mocker readiness.

- Category: docker-image
- Infra: Local Docker daemon (compose manages redis internally)
- Live gates: docker compose up --build, healthcheck passes, runner session exit 0, compose down
- Traps tested: FB s13#7 aspnet base not runtime, s13#12 vacuous HttpStatus, s13#19 redis no host
  port, s13#5b lowercase routes, internal-net isolates redis from host
