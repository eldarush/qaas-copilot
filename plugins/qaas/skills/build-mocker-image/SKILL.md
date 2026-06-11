---
name: build-mocker-image
version: 1.0.0
description: Build and verify a Docker image for a custom QaaS mocker using the multi-stage aspnet:10.0 Dockerfile.
when_to_use: When a mocker must run in a container (CI, Docker Compose, Kubernetes).
inputs:
  - name: project_name
    example: "HelloMocker"
  - name: config_file
    example: "mocker.qaas.yaml"
  - name: port
    example: 8080
outputs:
  - path: "Mocker/Dockerfile"
  - path: "Mocker/.dockerignore"
  - path: "Mocker/NuGet.config"
fact_base_slices: [s03, s08, s13, s14]
references:
  - references/container-networking.md
contract:
  done_rubric:
    - "docker build -t <image>:lab . => exit 0"
    - "docker run -d -p <port>:<port> <image>:lab => container running"
    - "docker logs <container> contains 'HTTP Server started'"
    - "curl.exe http://127.0.0.1:<port><path> => expected status/body"
  failure_modes:
    - "runtime:10.0 base image → 'Microsoft.AspNetCore.App not found' (FB s13#7)"
    - "IsLocalhost:true in YAML → binds 127.0.0.1 only, unreachable from host (FB s03)"
    - "127.0.0.1 in container for Redis/RabbitMQ → resolves to container loopback (FB s07)"
    - "Wrong NuGet feed in restore stage → restore fails in airgap (FB s08)"
  escalation: "NEEDS_CLARIFICATION: base image registry URL | BLOCKED: private registry unavailable"
---

## When to use

Use when a mocker project must be containerized. Covers Dockerfile authoring, build/run/verify, and networking.

## Steps

### 1. Verbatim Dockerfile (FB s14#6, LAB L5)
```dockerfile
# build
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY . .
RUN dotnet restore --configfile NuGet.config
RUN dotnet publish -c Release -o /app

# runtime — MUST be aspnet (mocker hosts an HTTP server); dotnet/runtime:10.0 FAILS at start
FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /app .
ENTRYPOINT ["dotnet", "HelloMocker.dll", "mocker.qaas.yaml"]
```
**CRITICAL**: runtime stage MUST be `aspnet:10.0`. Using `runtime:10.0` fails at container start:
`Framework 'Microsoft.AspNetCore.App' ... No frameworks were found.` (FB s13#7, LAB L5).

**Dockerfile comments must be on their OWN line** (FB s13#18). Never append a trailing comment to an
instruction line — `FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build  # note` fails the build with
`dockerfile parse error ... FROM requires either one or three arguments`. Put `# ...` on a separate line.

### 2. Airgap build args (FB s08, docs deployMock.md)
For Artifactory feed, pass build args at build time:
```powershell
docker build `
  --build-arg QAAS_NUGET_SOURCE_NAME=QaaS `
  --build-arg QAAS_NUGET_SOURCE_URL=https://artifactory.example.com/nuget/v3/index.json `
  -t hellomocker:lab .
```
NuGet.config template using these args:
```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="${QAAS_NUGET_SOURCE_NAME}" value="${QAAS_NUGET_SOURCE_URL}" />
  </packageSources>
</configuration>
```
Some scaffolds use `ENTRYPOINT ["sh","-c","exec dotnet DummyAppMock.dll \"$QAAS_MOCKER_CONFIG\""]`
for runtime config override (FB s14#6).

### 3. .dockerignore
```
obj/
bin/
allure-results/
session-data/
*.user
```

### 4. Mocker YAML for container: disable IsLocalhost
```yaml
Servers:
  - Http:
      Port: 8080
      # IsLocalhost: false  ← omit or explicitly false → binds 0.0.0.0 (accessible from host)
      # IsLocalhost: true   ← WRONG in a container; binds 127.0.0.1 only (FB s03)
```

### 5. Build and run sequence
```powershell
cd Mocker                                         # must be in the Dockerfile context dir

docker build -t hellomocker:lab .
# exit 0 = success

docker run -d -p 8080:8080 --name hellomocker hellomocker:lab
# -d = detached; -p host:container port mapping

docker logs hellomocker
# Look for:
# "Building transaction stub 'X' with processor 'Y'"
# "Built 4 transaction stub(s) including default not-found and internal-error stubs"
# "HTTP Server started. Listening on http://0.0.0.0:8080"
# "controller enabled: False"  (or True if Controller configured)
```
Expected startup log lines (FB s14#6, LAB L5):
- `Building transaction stub 'HealthStub' with processor 'HealthProcessor'`
- `Built 4 transaction stub(s) including default not-found and internal-error stubs`
- `Resolved runtime graph with 0 data source(s), 4 stub(s), 1 server(s) [Http], and controller enabled: False`
- `HTTP Server started. Listening on http://0.0.0.0:8080`

### 6. Verify curl
```powershell
curl.exe -s -w "\n%{http_code}" http://127.0.0.1:8080/hello
# Expected: body + 200

curl.exe -s -o NUL -w "%{http_code}" http://127.0.0.1:8080/health
# Expected: 200
```

### 7. Controller Redis from inside container (FB s14#7, LAB L6)
If mocker uses Controller, Redis host inside the container must reach the host machine:
```yaml
Controller:
  ServerName: HelloMocker
  Redis:
    Host: "host.docker.internal:6379"   # NOT 127.0.0.1 (that is the container itself)
```
See references/container-networking.md for Docker network options.

### 8. Cleanup
```powershell
docker stop hellomocker
docker rm hellomocker
```

### 9. Docker Compose (multi-service stack)
Run the mocker — plus any dependency it talks to (Redis/RabbitMQ) — as a compose stack. Inside a
compose network, services reach each other by **service name** (e.g. Redis host `redis:6379`, NOT
`127.0.0.1`); the host reaches the mocker through the published port. **Publish ONLY the service you
curl from the host (the mocker).** Publishing a dependency like Redis to a fixed host port (`6379:6379`)
can clash with another container already bound to that port on the host — leave internal deps unpublished.
```yaml
# docker-compose.yml
services:
  redis:                     # internal dependency — NOT published to the host
    image: redis:7-alpine    # other services reach it as host "redis" on 6379
  mocker:
    build: .                 # builds the Dockerfile in this directory
    ports: ["8125:8080"]     # ONLY the mocker is published (host:container; container stays on its YAML Port)
    depends_on: [redis]
```
```powershell
docker compose -p qaas-e03 up -d --build      # build + start
curl.exe http://127.0.0.1:8125/health         # verify through the published host port
docker compose -p qaas-e03 down -v            # tear down (remove volumes)
```

### 10. CI build script
A thin, idempotent wrapper so CI can build (and optionally smoke-test) the image in one call. Keep the
exact image tag the rest of the pipeline expects, and propagate the build exit code.
```powershell
# build.ps1
docker build -t hellomocker:lab .
if ($LASTEXITCODE -ne 0) { Write-Error "image build failed"; exit 1 }
```

### 11. Env-driven config at run time
Use the `sh -c` ENTRYPOINT (FB s14#6) so the config file is chosen by an environment variable at
`docker run` time instead of being baked into the image:
```dockerfile
ENTRYPOINT ["sh", "-c", "exec dotnet Hello.dll \"$QAAS_MOCKER_CONFIG\""]
```
```powershell
docker run -d -p 8127:8080 -e QAAS_MOCKER_CONFIG=hello.mocker.yaml hellomocker:lab
```

## Traps
| # | Trap | Fix |
|---|---|---|
| s13#7 | `runtime:10.0` base → aspnet crash | Use `aspnet:10.0` in second FROM stage |
| s03 | `IsLocalhost:true` in container | Omit or set false |
| s07 | `127.0.0.1` for Redis/broker inside container | Use `host.docker.internal` |
| s08 | No NuGet.config → restore fails airgap | Include NuGet.config with `<clear/>` + Artifactory add |
| LAB L5 | ENTRYPOINT DLL name wrong | Must match `<AssemblyName>` in csproj |

## Citations
- FB s13#7 (aspnet fix), FB s14#6 (verbatim Dockerfile), FB s03 (IsLocalhost), FB s08 (airgap/NuGet)
