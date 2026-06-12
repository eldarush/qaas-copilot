# Batch D — Advanced Docker / Offline / CI Scenarios
# IDs: D-101..D-150 | Tiers: T3×10 (D-101–110), T4×20 (D-111–130), T5×20 (D-131–150)
# Theme: multi-stage mocker images, compose topologies, airgap NuGet, CI pipelines
# FB primary: s13 (drift), s08 (offline), s03 (networking), s14 (docker)
# No duplicates with A-D series (D01-D06), E01-E06, F01-F06, G01-G06, H01-H07

---

### D-101: aspnet vs runtime base in mocker Dockerfile
Tier: T3
Goal: Prove that using `mcr.microsoft.com/dotnet/runtime:10.0` instead of `aspnet:10.0` causes mocker container start failure.
SUT: Minimal mocker project with one HTTP stub; Dockerfile uses wrong `runtime:10.0` runtime stage.
MOCK_REQUIRED: yes — scenario is about mocker container image base selection
FB slices: s13#7, s14
Trap mines: s13#7 (runtime → aspnet), s13#18 (no trailing Dockerfile comments)
Hard because:
- Build succeeds (SDK stage is fine); failure only surfaces at container run time
- Error message "Framework 'Microsoft.AspNetCore.App' was not found" may be unfamiliar
- Easy to confuse with port or config errors
Verify (mechanical):
- `docker run` logs contain "Microsoft.AspNetCore.App … was not found" with runtime base
- Fix to `aspnet:10.0`; container reaches "HTTP Server started"
- `curl http://127.0.0.1:<port>/health` returns 200
Rubric (graded):
- 1: Identifies correct base image but places it in wrong stage (sdk stage)
- 5: Produces correct Dockerfile, container starts, health probe passes
- 10: Full fix + explains why aspnet image is required (hosts Kestrel/ASP.NET pipeline)
Solution sketch: Replace `FROM mcr.microsoft.com/dotnet/runtime:10.0` in the runtime stage with `FROM mcr.microsoft.com/dotnet/aspnet:10.0`; rebuild and verify "HTTP Server started" in logs.

---

### D-102: Dockerfile trailing inline comment breaks FROM
Tier: T3
Goal: Diagnose and fix a Dockerfile where an inline `# comment` appended to a FROM instruction causes a build-time parse error.
SUT: Mocker Dockerfile with `FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build  # build stage` on one line.
MOCK_REQUIRED: yes — dockerfile authoring for mocker image
FB slices: s13#18, s14
Trap mines: s13#18 (trailing comments on instruction lines → parse error)
Hard because:
- Error reads "FROM requires either one or three arguments" — looks like a registry error
- Common habit from shell scripting to add inline comments
- The fix is purely syntactic, not logical
Verify (mechanical):
- `docker build .` fails with "dockerfile parse error … FROM requires" before fix
- After moving comment to its own `#` line, `docker build` exits 0
- Container starts and logs "HTTP Server started"
Rubric (graded):
- 1: Removes comment entirely rather than moving it to its own line
- 5: Moves comment to own line; build passes; container starts
- 10: Fix applied to ALL instruction lines; cites s13#18 explicitly
Solution sketch: Move all inline `# …` remarks to their own preceding line; never append comments after `FROM`, `COPY`, `RUN`, or `ENTRYPOINT`.

---

### D-103: Compose internal-service port collision with host
Tier: T3
Goal: Show that publishing an internal dependency (Redis) port in docker-compose causes bind failure when the port is already in use on the host.
SUT: compose.yml with `redis: ports: ["6379:6379"]`; host already runs Redis on 6379.
MOCK_REQUIRED: yes — mocker is in the compose topology
FB slices: s13#19, s03
Trap mines: s13#19 (publish only the mocker port; internal deps use service-name routing, no host port needed)
Hard because:
- Error "Bind for 0.0.0.0:6379 failed: port is already allocated" happens before mocker starts
- Removing the Redis port mapping feels wrong to developers used to accessing Redis directly
- Services must still reach Redis internally via service name
Verify (mechanical):
- `docker compose up` exits non-zero with "port is already allocated" before fix
- After removing Redis `ports:` mapping, compose up succeeds
- Mocker container connects to `redis:6379` by service name; logs show "Connected"
Rubric (graded):
- 1: Changes Redis to a different host port — still unnecessary external exposure
- 5: Removes `ports:` from redis service; compose up succeeds; mocker healthy
- 10: Also explains internal service-name routing; only mocker port is published
Solution sketch: Delete `ports:` block from the `redis:` service; keep mocker's `ports: ["8080:8080"]`; mocker config references `redis:6379` by compose service name.

---

### D-104: NuGet.config missing `<clear/>` leaks nuget.org in airgap
Tier: T3
Goal: Identify that omitting `<clear/>` from NuGet.config causes restore to fall back to nuget.org, which fails in an airgapped build.
SUT: Runner `.csproj` with explicit Artifactory source but no `<clear/>` directive; build runs inside CI with no internet.
MOCK_REQUIRED: no — packaging/restore scenario, no mocker image needed
FB slices: s08, s13
Trap mines: s08 (clear-first mandatory), s13#9 (version pinning)
Hard because:
- Restore succeeds on developer laptops (nuget.org reachable) but fails in CI
- Missing `<clear/>` is invisible in normal operation; only surfaces in airgap
- NU1301 error message doesn't name the offending source clearly
Verify (mechanical):
- Simulate airgap with `--disallow-fallback-credentials`; `dotnet restore` exits non-zero without `<clear/>`
- Add `<clear/>` as first child of `<packageSources>`; restore exits 0 against local feed only
- No `nuget.org` or `api.nuget.org` in any network request during restore
Rubric (graded):
- 1: Adds `<clear/>` but leaves nuget.org as a second source
- 5: `<clear/>` is first in `<packageSources>`; only Artifactory source listed; restore passes airgap
- 10: Also pins all `QaaS.*` versions (s13#9); confirms no external traffic
Solution sketch: Insert `<clear />` as the first element inside `<packageSources>` before the Artifactory `<add>` line.

---

### D-105: Template install from local .nupkg with version pin
Tier: T3
Goal: Install `qaas-runner` and `qaas-mocker` dotnet templates from local `.nupkg` files and scaffold a project with a pinned version.
SUT: Offline workstation; no internet; `.nupkg` files placed in `C:\qaas-packages\`; need to run `dotnet new qaas-runner`.
MOCK_REQUIRED: no — template install scenario
FB slices: s08, s13#9
Trap mines: s08 (templates not on nuget.org; must install from local path or feed), s13#9 (version pinning)
Hard because:
- `dotnet new install` path syntax differs between SDK versions
- Version must match exactly; `*` causes non-deterministic failure in airgap
- Template install and NuGet restore are separate operations often conflated
Verify (mechanical):
- `dotnet new install C:\qaas-packages\qaas-runner.4.5.1.nupkg` exits 0
- `dotnet new qaas-runner -o TestRunner` scaffolds project with `QaaS.Runner` version `4.5.1`
- `dotnet restore` against Artifactory feed exits 0; no nuget.org traffic
Rubric (graded):
- 1: Installs template but forgets to pin version; `*` left in csproj
- 5: Correct install command; csproj pins `4.5.1`; restore passes airgap
- 10: Both runner and mocker templates installed; all QaaS.Common.* versions pinned per s13#9
Solution sketch: Run `dotnet new install <path>.nupkg` for each template; scaffold projects; replace `Version="*"` with exact versions from s13#9 table.

---

### D-106: NU1102 from applying Runner version to Common.* packages
Tier: T3
Goal: Diagnose a restore failure where `QaaS.Common.Assertions` is mistakenly pinned to Runner version `4.5.1` instead of `3.5.1`.
SUT: Runner csproj with `QaaS.Common.Assertions Version="4.5.1"` copied from Runner reference.
MOCK_REQUIRED: no — package version forensics
FB slices: s13#9, s08
Trap mines: s13#9 (versions are INDEPENDENT per package — Common.* ≠ Runner version)
Hard because:
- NU1102 "Unable to find package" error doesn't explain the version mismatch cause
- Developers assume all QaaS packages share a version number
- Feed may contain the package but not at the wrong version
Verify (mechanical):
- `dotnet restore` exits non-zero with "NU1102 Unable to find package QaaS.Common.Assertions (>= 4.5.1)"
- Fix version to `3.5.1`; restore exits 0
- `dotnet build` exits 0
Rubric (graded):
- 1: Downgrades to an unverified version (e.g., `2.0.0`)
- 5: Pins to `3.5.1` per s13#9; restore and build pass
- 10: Audits and corrects ALL QaaS.Common.* package versions against the s13#9 table
Solution sketch: Replace `Version="4.5.1"` on `QaaS.Common.Assertions` (and any other `QaaS.Common.*`) with their documented independent versions from s13#9.

---

### D-107: `IsLocalhost:true` makes mocker unreachable in container
Tier: T3
Goal: Diagnose why a mocker container starts successfully but all HTTP requests from the runner time out.
SUT: Mocker YAML sets `IsLocalhost: true` on HTTP server; mocker runs in Docker; runner connects from host or another container.
MOCK_REQUIRED: yes — mocker networking configuration
FB slices: s03, s13, s14
Trap mines: s03 (IsLocalhost:true binds 127.0.0.1 only, unreachable outside container), s13#7 (correct base image)
Hard because:
- Container shows "HTTP Server started" — success appears complete
- Curl from inside container works; curl from host/runner fails
- The YAML flag name doesn't suggest a bind-address effect
Verify (mechanical):
- With `IsLocalhost: true`: `curl http://127.0.0.1:<port>/stub` from host → connection refused
- With `IsLocalhost: false` (or omitted): same curl returns expected stub response
- `docker inspect` shows port mapping; container logs show "0.0.0.0" binding after fix
Rubric (graded):
- 1: Changes runner port without addressing bind address
- 5: Removes `IsLocalhost: true`; container binds `0.0.0.0`; runner connects
- 10: Also documents that `IsLocalhost` should never be true in containerized deployments
Solution sketch: Remove or set `IsLocalhost: false` in mocker YAML's `Servers.Http` block; rebuild image or restart container; verify `0.0.0.0` binding in logs.

---

### D-108: Volume-mounted session-data storage path mismatch
Tier: T3
Goal: Ensure runner `FileSystem` storage resolves correctly when session-data directory is bind-mounted into the runner process from the host.
SUT: Runner YAML `Storages: - FileSystem: {Path: ./session-data}`; runner invoked with working directory that doesn't contain `session-data`.
MOCK_REQUIRED: no — storage path resolution
FB slices: s02, s13#2
Trap mines: s13#2 (correct storage shape `- FileSystem: {Path: …}`), relative path resolution from runner cwd
Hard because:
- Path is relative; silently resolves to wrong absolute location
- Runner may start without error but write zero session files
- Windows vs Linux path separator confusion in volume mount args
Verify (mechanical):
- Runner exits 0 but `session-data/` directory empty without correct cwd
- Invoke runner from directory containing `session-data/`; directory populated after run
- Or use absolute path in YAML; verify directory contains session JSON files
Rubric (graded):
- 1: Uses hardcoded Windows path that fails on CI Linux agent
- 5: Correct relative path with runner invoked from matching cwd; session files written
- 10: Uses absolute path or confirms cwd in CI script; cross-platform compatible
Solution sketch: Either invoke runner from the directory parent of `session-data`, or use an absolute path in the `FileSystem: {Path: …}` field.

---

### D-109: Single published port with internal-only service mesh
Tier: T3
Goal: Author a compose file where Redis and RabbitMQ are internal-only (no host port mapping) and only the mocker's port is published.
SUT: compose.yml with mocker + redis + rabbitmq; developer initially maps all three services to host ports.
MOCK_REQUIRED: yes — compose topology for mocker
FB slices: s13#19, s03
Trap mines: s13#19 (only publish service tested from host; internal deps use service names only)
Hard because:
- Developers habitually expose all infrastructure ports for debugging
- Test must still pass after removing host port mappings for internal services
- Mocker config must reference services by compose service name, not localhost
Verify (mechanical):
- `docker compose up -d`; only mocker port 8080 mapped to host
- `curl http://127.0.0.1:8080/stub` returns expected response
- `docker compose port redis 6379` returns empty (no host mapping)
Rubric (graded):
- 1: Exposes all ports; compose up succeeds but violates constraint
- 5: Only mocker port published; redis/rabbitmq service-name-only; compose up succeeds
- 10: Also adds `depends_on` ordering; explains service-name internal routing
Solution sketch: Remove `ports:` blocks from `redis` and `rabbitmq` services; ensure mocker config uses `redis:6379` and `rabbitmq:5672` as hostnames.

---

### D-110: Redis service name vs localhost in mocker container
Tier: T3
Goal: Fix a mocker that connects to `localhost:6379` for Redis inside a compose network where Redis runs as service `redis`.
SUT: Mocker YAML `Redis: {Host: localhost, Port: 6379}`; mocker runs as compose service; Redis runs as `redis` service.
MOCK_REQUIRED: yes — mocker redis controller config
FB slices: s03, s07, s13
Trap mines: s03 (127.0.0.1/localhost resolves to container loopback, not Redis service), s13#19
Hard because:
- Works perfectly on developer laptop where all services run on localhost
- Connection refused error in logs points at Redis, not at the hostname config
- Redis service may appear healthy from host but unreachable via localhost inside mocker container
Verify (mechanical):
- Mocker logs show "Connection refused localhost:6379" before fix
- Update YAML to `Host: redis`; restart mocker container; logs show "Connected to Redis"
- Runner transactions succeed end-to-end
Rubric (graded):
- 1: Changes Redis port instead of hostname
- 5: Sets `Host: redis` in mocker YAML; connection succeeds; controller initialized
- 10: Also adds `depends_on: redis` with healthcheck condition; documents networking rule
Solution sketch: Replace `Host: localhost` with `Host: redis` (compose service name) in mocker YAML's controller/Redis section.

---

### D-111: Multi-stage mocker image with custom processor baked in
Tier: T4
Goal: Build a mocker Docker image that compiles a custom C# processor in the SDK stage and packages it with the mocker binary in the aspnet runtime stage.
SUT: Mocker project with a `StatefulCounterProcessor.cs` custom processor; Dockerfile must copy compiled DLL to runtime stage.
MOCK_REQUIRED: yes — multi-stage image with custom processor
FB slices: s13#7, s13#18, s14, s08
Trap mines: s13#7 (aspnet base, not runtime), s13#18 (no trailing Dockerfile comments), custom processor assembly must be in same directory as mocker DLL
Hard because:
- Custom processor DLL must be copied explicitly from build stage alongside the mocker publish output
- Runtime stage silently ignores missing DLL; processor appears unregistered at run time
- `dotnet publish` may not copy the custom assembly unless it is a project reference
Verify (mechanical):
- `docker build` exits 0; no parse errors
- `docker run` logs show "HTTP Server started" (aspnet base confirmed)
- Request to stub using processor returns expected transformed payload
- `docker exec … ls /app` shows both mocker and custom processor DLLs
Rubric (graded):
- 1: Copies entire `/src` into runtime stage instead of only `/app` publish output
- 5: Multi-stage build; custom DLL present in `/app`; processor invoked correctly
- 10: Also uses `.dockerignore` to exclude `obj/` and `bin/`; build cache optimal
Solution sketch: Ensure custom processor is a project reference in the mocker `.csproj`; `dotnet publish` will include it; copy only `/app` in runtime stage with `aspnet:10.0` base.

---

### D-112: Env-var-driven YAML config file selection at container startup
Tier: T4
Goal: Author a mocker Dockerfile where the YAML config filename is specified via `QAAS_MOCKER_CONFIG` environment variable rather than hardcoded in ENTRYPOINT.
SUT: Mocker image must run two different configs (`staging.mocker.yaml`, `prod.mocker.yaml`) via the same image with different env vars.
MOCK_REQUIRED: yes — mocker image entrypoint design
FB slices: s14, s08, s13#18
Trap mines: s13#18 (comments on own line in Dockerfile), env var not set at runtime → blank config path → mocker crash
Hard because:
- Shell-form ENTRYPOINT is needed for `$VAR` expansion but exec-form is recommended for signal handling
- Missing env var causes silent empty-string config path; mocker exits with unhelpful error
- Quoting in `sh -c "exec dotnet …"` must be exact
Verify (mechanical):
- `docker run -e QAAS_MOCKER_CONFIG=staging.mocker.yaml` starts mocker with staging config
- `docker run -e QAAS_MOCKER_CONFIG=prod.mocker.yaml` starts mocker with prod config
- Omitting env var: container exits non-zero with "config not found" or similar
Rubric (graded):
- 1: Hardcodes config in ENTRYPOINT; env var has no effect
- 5: `ENTRYPOINT ["sh","-c","exec dotnet Mocker.dll \"$QAAS_MOCKER_CONFIG\""]`; both configs selectable
- 10: Also sets a default via `ENV QAAS_MOCKER_CONFIG=mocker.qaas.yaml`; fallback documented
Solution sketch: Use `ENTRYPOINT ["sh","-c","exec dotnet Mocker.dll \"$QAAS_MOCKER_CONFIG\""]` with `ENV QAAS_MOCKER_CONFIG=mocker.qaas.yaml` as default.

---

### D-113: Registry substitution for airgapped Docker builds
Tier: T4
Goal: Rewrite a mocker Dockerfile to pull base images from a private registry mirror instead of `mcr.microsoft.com` for airgapped CI.
SUT: Dockerfile with `FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build` and `FROM mcr.microsoft.com/dotnet/aspnet:10.0`; private registry at `registry.internal:5000/dotnet/`.
MOCK_REQUIRED: yes — airgapped mocker image build
FB slices: s08, s13#7, s14
Trap mines: s13#7 (aspnet base preserved after substitution, not accidentally reverted to runtime), registry mirror URL must include repository path prefix
Hard because:
- Registry URL format varies (with/without trailing path, tag format)
- Must ensure aspnet variant is mirrored, not only sdk or runtime
- Build arg pattern allows CI to inject registry without modifying Dockerfile
Verify (mechanical):
- `docker build --build-arg REGISTRY=registry.internal:5000 .` exits 0 with no external registry pull
- `docker history <image>` shows base layers from internal registry
- Final runtime stage is `aspnet` variant (not `runtime`)
Rubric (graded):
- 1: Hardcodes internal registry URL; not parameterizable
- 5: `ARG REGISTRY=mcr.microsoft.com`; both FROM lines use `${REGISTRY}/dotnet/sdk:10.0` and `aspnet:10.0`
- 10: Preserves aspnet variant; `.dockerignore` present; airgap build arg documented in CI script
Solution sketch: Add `ARG REGISTRY=mcr.microsoft.com` before each FROM stage; replace registry prefix with `${REGISTRY}`; CI passes `--build-arg REGISTRY=registry.internal:5000`.

---

### D-114: Layer caching invalidation via build-arg placement
Tier: T4
Goal: Diagnose why changing `QAAS_NUGET_SOURCE_URL` build-arg causes the entire restore layer to be rebuilt instead of only the affected layers.
SUT: Dockerfile places `ARG QAAS_NUGET_SOURCE_URL` after `COPY . .`; arg change doesn't bust cache before source copy.
MOCK_REQUIRED: yes — mocker Dockerfile cache optimization
FB slices: s08, s14, s13#18
Trap mines: ARG declared after COPY means cache is busted by source changes, not by arg changes; correct order is ARG → COPY NuGet.config → RUN restore → COPY . .
Hard because:
- Docker cache invalidation rules around ARG are non-obvious
- Swap of ARG and COPY order is subtle; build output looks identical
- Layer cache misses slow CI builds significantly
Verify (mechanical):
- Before fix: change QAAS_NUGET_SOURCE_URL; observe full COPY+restore cache miss
- After fix (ARG before COPY NuGet.config; restore; then COPY . .): source change doesn't bust restore cache
- `docker build --progress=plain` shows "CACHED" for restore layer when only source changes
Rubric (graded):
- 1: Moves ARG to top of file but still copies all sources before restore
- 5: Correct order: ARG → COPY NuGet.config → RUN restore → COPY . . → RUN publish
- 10: Also caches `.dockerignore` excludes; documents cache strategy
Solution sketch: Declare `ARG QAAS_NUGET_SOURCE_URL` before any `COPY`; copy only `NuGet.config` and `*.csproj` before `dotnet restore`; copy remaining sources after.

---

### D-115: Healthcheck + depends_on condition in compose
Tier: T4
Goal: Configure compose so the runner service only starts after the mocker service passes its HTTP healthcheck.
SUT: compose.yml with mocker and runner services; runner starts before mocker is ready, causing connection failure.
MOCK_REQUIRED: yes — compose topology with healthcheck gating
FB slices: s13#19, s03, s16
Trap mines: s13#19 (port collision), s13#16 (port contract across probe/mocker/runner), `depends_on` with `condition: service_healthy` requires `healthcheck:` on the dependency
Hard because:
- `depends_on: [mocker]` without condition doesn't wait for HTTP readiness
- Healthcheck `test` command must use `curl` which may not be in aspnet image
- Timeout and interval tuning affects CI reliability
Verify (mechanical):
- Without condition: runner logs show connection refused before fix
- With `condition: service_healthy` and healthcheck: runner starts only after mocker healthy
- `docker compose ps` shows mocker status "healthy" before runner starts
Rubric (graded):
- 1: Uses `depends_on: [mocker]` without condition; race condition remains
- 5: `healthcheck: test: ["CMD", "curl", "-f", "http://localhost:8080/health"]`; `depends_on: condition: service_healthy`
- 10: Also installs curl in Dockerfile if missing; interval/timeout/retries tuned for CI
Solution sketch: Add `healthcheck:` block to mocker service; add `depends_on: mocker: condition: service_healthy` to runner service.

---

### D-116: CI build script: build → test → tag → save tar
Tier: T4
Goal: Write a CI PowerShell script that builds the mocker image, runs integration tests, tags the image, and saves it as a tar for USB transfer.
SUT: Mocker image project; CI agent with Docker but no registry access; output must be `mocker-latest.tar`.
MOCK_REQUIRED: yes — CI mocker image pipeline
FB slices: s08, s14, s13#7
Trap mines: s13#7 (aspnet base in Dockerfile), `docker save` requires fully-qualified tag; `docker load` on target machine requires matching tag
Hard because:
- `docker save` syntax differs from `docker export` (containers vs images)
- Tests must run before tagging to avoid shipping broken images
- Tar file must include all layers; multi-stage final stage only
Verify (mechanical):
- Script exits non-zero if any step fails (set -e or PowerShell $ErrorActionPreference = 'Stop')
- `docker save mocker:ci -o mocker-latest.tar` produces non-empty tar file
- `docker load -i mocker-latest.tar` on clean machine; `docker images` shows mocker:ci
Rubric (graded):
- 1: Script doesn't propagate failures; broken image could be saved
- 5: `$ErrorActionPreference='Stop'`; build→test→tag→save in order; tar is valid
- 10: Also captures `docker build` exit code; annotates tar with SHA256; documents load procedure
Solution sketch: Use `$ErrorActionPreference = 'Stop'`; sequence `docker build`, runner invocation for smoke test, `docker tag`, `docker save -o mocker-latest.tar mocker:ci`.

---

### D-117: docker save/load offline flow for air-gapped USB transfer
Tier: T4
Goal: Produce and consume a Docker image tar bundle for an air-gapped target machine with no Docker registry access.
SUT: Airgapped CI lab; mocker image built on internet-connected workstation; transferred via USB; loaded and run on offline machine.
MOCK_REQUIRED: yes — offline image transfer
FB slices: s08, s14, s13#7
Trap mines: `docker save` must target the IMAGE (not container); tag must match exactly on load; aspnet base must be included in tar
Hard because:
- Developers confuse `docker save` (image) vs `docker export` (container filesystem)
- Transferred image tag may not match what the compose file expects
- Base image layers not included if image was built with `--cache-from` on different machine
Verify (mechanical):
- `docker save mocker:offline -o mocker-offline.tar`; tar file > 100 MB (includes aspnet layers)
- Transfer to offline machine; `docker load -i mocker-offline.tar`; `docker images` shows `mocker:offline`
- `docker run -p 8080:8080 mocker:offline` starts successfully; "HTTP Server started" in logs
Rubric (graded):
- 1: Uses `docker export` on running container; missing base layers; load fails
- 5: Correct `docker save`; load succeeds; container runs on offline machine
- 10: Also saves redis image in same tar bundle using `docker save img1 img2 -o bundle.tar`
Solution sketch: `docker save mocker:offline redis:7 -o bundle.tar`; transfer; `docker load -i bundle.tar`; compose up with loaded images.

---

### D-118: NuGet.config %VAR% expansion matrix across environments
Tier: T4
Goal: Configure NuGet.config with `%QAAS_NUGET_URL%` environment variable expansion so the same config file works in dev, staging, and CI without modification.
SUT: NuGet.config uses `%QAAS_NUGET_URL%` placeholder; three environments each set a different feed URL.
MOCK_REQUIRED: no — NuGet config expansion
FB slices: s08, s13#9
Trap mines: s08 (clear-first required), %VAR% is the NuGet native expansion syntax (not $VAR or ${VAR}), missing env var → literal `%QAAS_NUGET_URL%` in feed URL → NU1301
Hard because:
- `%VAR%` syntax is NuGet-specific; `$VAR` or `${VAR}` are NOT expanded by NuGet
- Missing environment variable silently sets the feed URL to the literal placeholder string
- NU1301 error message shows the unexpanded `%QAAS_NUGET_URL%` URL — helpful hint if recognized
Verify (mechanical):
- Set `$env:QAAS_NUGET_URL = "https://artifactory.example.com/nuget/v3/index.json"`; `dotnet restore` exits 0
- Unset env var; `dotnet restore` exits non-zero with NU1301 or NU1101
- Same NuGet.config used in all three environments; only env var differs
Rubric (graded):
- 1: Uses `${QAAS_NUGET_URL}` (shell syntax); NuGet doesn't expand it
- 5: `%QAAS_NUGET_URL%` in value attribute; restore passes when env var set; fails when unset
- 10: Also includes `<clear/>` first; documents the three environment variable values
Solution sketch: `<add key="QaaS" value="%QAAS_NUGET_URL%" />`; set env var in each environment; `<clear/>` is first in `<packageSources>`.

---

### D-119: NU1301 feed authentication failure forensics
Tier: T4
Goal: Diagnose and resolve NU1301 "Unable to load service index for source" caused by missing or incorrect Artifactory credentials in NuGet.config.
SUT: NuGet.config points to authenticated Artifactory feed; no `<packageSourceCredentials>` section; `dotnet restore` exits non-zero.
MOCK_REQUIRED: no — NuGet feed authentication
FB slices: s08, s13#9
Trap mines: s08 (credentials must be in NuGet.config or env; not in csproj), NU1301 vs NU1102 (auth vs missing package)
Hard because:
- NU1301 and NU1102 look similar but have different root causes
- Credentials in environment variables require specific NuGet env var names
- Plaintext passwords in NuGet.config are a security anti-pattern but required for CI
Verify (mechanical):
- `dotnet restore --verbosity detailed` shows 401 Unauthorized or connection failed → NU1301
- Add `<packageSourceCredentials>` with correct username/password; restore exits 0
- No nuget.org fallback (clear-first config); all packages resolve from Artifactory
Rubric (graded):
- 1: Adds credentials to csproj instead of NuGet.config; credentials ignored
- 5: `<packageSourceCredentials>` with `<username>` and `<password>` added; restore passes
- 10: Uses `%ARTIFACTORY_API_KEY%` env var in password value; no plaintext secrets in committed config
Solution sketch: Add `<packageSourceCredentials>` block referencing feed key; use `%ARTIFACTORY_API_KEY%` env var for password to avoid hardcoding secrets.

---

### D-120: Multi-arch mocker image build for arm64 CI runners
Tier: T4
Goal: Configure a mocker Dockerfile and CI build command to produce both `linux/amd64` and `linux/arm64` image variants using `docker buildx`.
SUT: Mocker project; CI fleet includes both x86 and ARM64 runners; single image tag must work on both.
MOCK_REQUIRED: yes — multi-arch mocker image
FB slices: s14, s13#7, s08
Trap mines: s13#7 (aspnet base must exist for both architectures at `mcr.microsoft.com/dotnet/aspnet:10.0` — it does), `--platform` must be specified in FROM when using buildx
Hard because:
- `docker buildx build --platform linux/amd64,linux/arm64` requires a buildx builder with multi-arch support
- Base image tag `aspnet:10.0` supports both arches; no change needed there
- Push to registry required for multi-arch manifest; `--load` only works for single arch
Verify (mechanical):
- `docker buildx create --use`; `docker buildx build --platform linux/amd64,linux/arm64 --push -t registry/mocker:latest .` exits 0
- `docker manifest inspect registry/mocker:latest` shows both amd64 and arm64 variants
- Pull on ARM64 runner; `docker run` starts successfully
Rubric (graded):
- 1: Builds only amd64; arm64 runners pull wrong arch; container crashes
- 5: Correct `buildx build --platform` command; manifest pushed; both arches present
- 10: Also adds `--provenance=false` for registries that don't support attestations; CI script documented
Solution sketch: `docker buildx build --platform linux/amd64,linux/arm64 --push -t <registry>/mocker:latest .`; aspnet:10.0 base supports both arches natively.

---

### D-121: Container log capture piped to assertion verification
Tier: T4
Goal: Show how to capture mocker container logs and assert they contain expected controller initialization messages matching s13#11 reality.
SUT: Compose topology; runner test finishes; CI script captures `docker logs` output and greps for expected strings.
MOCK_REQUIRED: yes — mocker log verification
FB slices: s13#11, s14
Trap mines: s13#11 (real log: "Initialized Redis controller for server 'X'" NOT "Controller channel ready: HelloMocker" as docs claim), grep pattern must match actual log text
Hard because:
- Developers write grep pattern from docs ("Controller channel ready") that never matches
- Log capture must happen before `docker compose down` cleans up containers
- Timing: logs captured too early may miss initialization messages
Verify (mechanical):
- `docker logs <container> 2>&1 | Select-String "Initialized Redis controller"` returns match
- `docker logs <container> 2>&1 | Select-String "Controller channel ready"` returns empty (confirms docs are wrong)
- CI script exits non-zero if expected log line absent
Rubric (graded):
- 1: Greps for docs-stated string "Controller channel ready"; always fails
- 5: Greps for "Initialized Redis controller" per s13#11; match confirmed
- 10: Also captures `Started control handler` line; saves full log artifact; CI reports pass
Solution sketch: After runner exits, `docker logs <mocker-container>`; grep for "Initialized Redis controller for server" per s13#11.

---

### D-122: Network isolation — mocker internal, runner on host
Tier: T4
Goal: Design a topology where the mocker runs as a compose service on an internal network but the runner executes on the host, communicating via a published port.
SUT: compose.yml with mocker on `mocker-net` internal network; runner process on host; mocker port 8080 published to `127.0.0.1:8080`.
MOCK_REQUIRED: yes — network isolation design
FB slices: s03, s13#19, s16
Trap mines: s13#19 (publish only mocker port), s13#16 (port contract: runner Http.Port must match published host port), s03 (IsLocalhost must be false in container)
Hard because:
- Runner on host must use `127.0.0.1:<published-port>`; mocker YAML uses internal port
- Internal services (redis) must not be reachable from host (security requirement)
- Port contract must be consistent across YAML and compose
Verify (mechanical):
- `docker compose up -d mocker`; `curl http://127.0.0.1:8080/stub` returns 200
- `docker network inspect mocker-net` shows only mocker (and redis) — no host
- Runner process on host invokes transactions; sessions complete; exit 0
Rubric (graded):
- 1: Maps all service ports to host; isolation broken
- 5: Only mocker:8080 published; runner on host connects via 127.0.0.1:8080; sessions pass
- 10: Compose network defined as `internal: true` for redis network; mocker bridges both networks
Solution sketch: Define `mocker` on `internal` network with redis; add port `127.0.0.1:8080:8080`; runner YAML `Http.Port: 8080`; no redis host port mapping.

---

### D-123: Port-conflict matrix diagnosis in parallel CI jobs
Tier: T4
Goal: Diagnose and resolve port conflicts when multiple CI jobs run the same compose stack in parallel on the same host, each binding port 8080.
SUT: Two CI pipeline jobs run `docker compose up` concurrently; second job fails with "port already allocated".
MOCK_REQUIRED: yes — parallel compose mocker topology
FB slices: s13#19, s16, s14
Trap mines: s13#16 (port must be consistent within one run), s13#19 (published port collision across runs)
Hard because:
- Each job must use a unique host port without modifying the mocker YAML
- Port must be consistent within one job's compose+runner pair
- Dynamic port selection in CI is non-trivial; must avoid race conditions
Verify (mechanical):
- Two concurrent jobs: first picks 8080, second picks 8081 via env var override
- Both compose stacks up simultaneously; no "port already allocated" error
- Each runner job uses the matching port; sessions complete; exit 0 for both
Rubric (graded):
- 1: Serializes CI jobs (no parallelism); doesn't solve the root problem
- 5: Uses `PORT=8081 docker compose up`; compose YAML parameterizes port via `${PORT:-8080}`
- 10: Full matrix tested (4 parallel jobs); port range pre-allocated in CI config; project-name also isolated
Solution sketch: Parameterize compose port with `${PORT:-8080}` in `ports:` and runner YAML; each CI job exports a unique `PORT` before `docker compose up`.

---

### D-124: Compose project-name isolation for parallel CI lanes
Tier: T4
Goal: Use `--project-name` (or `COMPOSE_PROJECT_NAME`) to isolate compose networks and volumes across parallel CI jobs running the same compose file.
SUT: Two CI jobs share one host; same `compose.yml`; without project-name, container names collide.
MOCK_REQUIRED: yes — compose topology isolation
FB slices: s14, s13#19
Trap mines: s13#19 (network collision), default project-name derived from directory name causes collisions when two jobs clone to same path
Hard because:
- Container name collision error is distinct from port collision; less obvious
- Networks and volumes also get prefixed with project name; must be consistent within each job
- Cleanup after job must target the correct project name
Verify (mechanical):
- `docker compose -p ci-job-1 up -d` and `docker compose -p ci-job-2 up -d` coexist
- `docker ps` shows `ci-job-1_mocker_1` and `ci-job-2_mocker_1` simultaneously
- `docker compose -p ci-job-1 down` cleans only job-1 resources
Rubric (graded):
- 1: Sets unique directory per job; fragile workaround
- 5: `COMPOSE_PROJECT_NAME=ci-job-$CI_JOB_ID` exported; projects isolated; cleanup works
- 10: Also sets unique `PORT` per job; full parallel isolation documented
Solution sketch: Export `COMPOSE_PROJECT_NAME=ci-job-$CI_BUILD_NUMBER`; CI script uses `docker compose -p $COMPOSE_PROJECT_NAME` for up/down; pair with unique PORT env var.

---

### D-125: OOM diagnosis during mocker container run
Tier: T4
Goal: Diagnose a mocker container that exits unexpectedly with exit code 137 (SIGKILL/OOM) when processing large payloads.
SUT: Mocker with a processor that buffers large request bodies; container memory limit set to 128 MB.
MOCK_REQUIRED: yes — mocker container OOM
FB slices: s14, s13
Trap mines: exit 137 ≠ application crash; means kernel OOM killer; `docker inspect` shows `OOMKilled: true`
Hard because:
- Exit code 137 in CI looks like any other failure without inspecting OOMKilled flag
- Application logs are truncated or absent when OOM kills the process
- Fix requires either increasing memory limit or reducing processor buffer usage
Verify (mechanical):
- `docker inspect <container> --format '{{.State.OOMKilled}}'` returns `true`
- Increase `--memory 512m`; container runs to completion
- Or: processor refactored to stream instead of buffer; memory stays under 128 MB
Rubric (graded):
- 1: Increases memory limit without investigating root cause; masks the issue
- 5: Identifies OOMKilled via docker inspect; explains exit 137 meaning; increases limit to stable value
- 10: Also profiles processor memory usage; implements streaming to minimize allocation
Solution sketch: `docker inspect` to confirm OOMKilled; increase compose memory limit to 512m as immediate fix; investigate and optimize processor memory allocation.

---

### D-126: Version pinning audit across all QaaS packages in airgap build
Tier: T4
Goal: Audit a multi-project solution (runner + mocker) and correct all `Version="*"` or mismatched QaaS package versions before airgap restore.
SUT: Solution with runner (QaaS.Runner), mocker (QaaS.Mocker), and shared hooks project; multiple packages use `*` or incorrect versions.
MOCK_REQUIRED: no — version audit scenario
FB slices: s13#9, s08
Trap mines: s13#9 (independent versions per package family), s08 (Version="*" non-deterministic in airgap)
Hard because:
- QaaS.Runner 4.5.1, QaaS.Mocker 2.4.1, QaaS.Common.* 3.5.1 or 1.5.1 — three different version numbers
- Applying Runner version to Common.* → NU1102 (package doesn't exist at that version)
- Wildcard `*` may resolve differently across airgap feed snapshots
Verify (mechanical):
- All `*.csproj` files grep-free of `Version="*"` for QaaS packages
- `dotnet restore --configfile NuGet.config` exits 0 against local feed
- `dotnet build` exits 0; no version mismatch warnings
Rubric (graded):
- 1: Pins all to `4.5.1`; Common.* restore fails with NU1102
- 5: Runner=4.5.1, Mocker=2.4.1, Common.Assertions/Generators=3.5.1, Probes/Processors=1.5.1
- 10: Automated audit script checks all csproj files; documents version matrix as comments
Solution sketch: Apply s13#9 version table exactly: Runner→4.5.1, Mocker→2.4.1, Common.Assertions/Generators→3.5.1, Common.Probes/Processors→1.5.1.

---

### D-127: Feed ordering and clear-first with multiple Artifactory repositories
Tier: T4
Goal: Configure NuGet.config with two Artifactory feeds (system packages, QaaS-specific) using `<clear/>` and verify correct package resolution order.
SUT: Enterprise environment with `system-nuget` feed (third-party packages) and `qaas-nuget` feed (QaaS packages); no internet access.
MOCK_REQUIRED: no — NuGet multi-feed configuration
FB slices: s08, s13#9
Trap mines: s08 (clear-first mandatory; without it nuget.org is fallback), NuGet resolves from feeds in listed order — QaaS packages must be found in qaas-nuget feed before resolution fails
Hard because:
- Package resolution order matters; wrong order can pick wrong version from wrong feed
- `<clear/>` removes both nuget.org and any machine-wide configured feeds
- NU1101 "package not found" may point to wrong feed being checked first
Verify (mechanical):
- `dotnet restore --verbosity detailed` shows packages resolved from correct feed
- No nuget.org in verbose output; all packages from Artifactory feeds
- QaaS.Runner 4.5.1 resolved from qaas-nuget; Newtonsoft.Json resolved from system-nuget
Rubric (graded):
- 1: Two feeds without `<clear/>`; nuget.org still reachable; fails in airgap
- 5: `<clear/>` first; both feeds listed in correct order; all packages resolve
- 10: Also uses `<packageSourceMapping>` to explicitly route packages to correct feed
Solution sketch: `<clear/>` → `<add key="system-nuget" …/>` → `<add key="qaas-nuget" …/>`; optionally add `<packageSourceMapping>` to route `QaaS.*` packages to qaas-nuget only.

---

### D-128: dotnet new template not found after .nupkg install on air-gapped machine
Tier: T4
Goal: Diagnose why `dotnet new qaas-runner` fails with "template not found" on an airgapped machine even though the .nupkg was copied over.
SUT: Airgapped machine; `qaas-runner-4.5.1.nupkg` copied; developer forgot to run `dotnet new install`; tries `dotnet new qaas-runner` directly.
MOCK_REQUIRED: no — template installation scenario
FB slices: s08, s13#9
Trap mines: s08 (templates are NOT auto-installed from a copied .nupkg; must run `dotnet new install <path>`), copying the nupkg to global-packages cache is not sufficient
Hard because:
- Copying .nupkg to NuGet cache folder doesn't trigger template installation
- Error "template not found" gives no hint about needing `dotnet new install`
- Distinguishing template install from package restore is conceptually confusing
Verify (mechanical):
- `dotnet new list qaas` before install: shows nothing
- `dotnet new install C:\packages\qaas-runner-4.5.1.nupkg` exits 0
- `dotnet new list qaas` after install: shows `qaas-runner` and `qaas-mocker`
- `dotnet new qaas-runner -o MyRunner` scaffolds project successfully
Rubric (graded):
- 1: Copies .nupkg to NuGet cache path manually; template still not found
- 5: Runs `dotnet new install <path>.nupkg`; template available; scaffolding succeeds
- 10: Also installs both runner and mocker templates; verifies version with `dotnet new list`
Solution sketch: `dotnet new install C:\packages\qaas-runner-4.5.1.nupkg`; `dotnet new install C:\packages\qaas-mocker-2.4.1.nupkg`; then scaffold.

---

### D-129: Probe port contract consistency across YAML files in compose topology
Tier: T4
Goal: Ensure the TCP probe port, mocker YAML `Servers.Http.Port`, runner YAML `Http.Port`, and compose `ports:` mapping all use the same single literal port value.
SUT: Compose topology where probe uses 8080, mocker binds 8081, runner connects to 8082 — three different values accumulated by copy-paste errors.
MOCK_REQUIRED: yes — port contract verification
FB slices: s13#16, s16, s03
Trap mines: s13#16 (one single literal port across all three places), probe on wrong port → loops full timeout → "MOCKER NEVER READY"; runner on wrong port → connection refused
Hard because:
- Three separate files (compose.yml, mocker.yaml, runner.yaml) must agree on one port
- Copy-paste drift is common; each file may look correct in isolation
- "MOCKER NEVER READY" message is ambiguous — points to probe, not mocker config
Verify (mechanical):
- Single port literal (e.g., 8080) appears in compose ports, mocker Servers.Http.Port, runner Http.Port
- `docker compose up`; probe succeeds within timeout (no "MOCKER NEVER READY")
- Runner transactions complete; exit 0
Rubric (graded):
- 1: Fixes probe port but not runner YAML; runner still connects to wrong port
- 5: All three values set to same literal; probe succeeds; runner connects; sessions pass
- 10: Port extracted to compose `.env` file as `MOCKER_PORT=8080`; all references use `${MOCKER_PORT}`
Solution sketch: Choose one port (e.g., 8080); set in compose `ports: ["8080:8080"]`, mocker `Port: 8080`, runner `Http.Port: 8080`; validate all three match before compose up.

---

### D-130: RabbitMQ internal service name vs `localhost` in async consumer test
Tier: T4
Goal: Fix a QaaS consumer test running in compose where the mocker's RabbitMQ config references `localhost:5672` instead of the compose service name `rabbitmq:5672`.
SUT: Compose with `rabbitmq` service and mocker service; mocker YAML `RabbitMq: {Host: localhost}`.
MOCK_REQUIRED: yes — mocker RabbitMQ service-name routing
FB slices: s03, s07, s13#19, s17
Trap mines: s13#17 (RabbitMQ topology must pre-exist; mocker doesn't create exchanges), s03 (localhost resolves to container loopback, not compose service)
Hard because:
- Connection to `localhost:5672` inside mocker container hits loopback, not the RabbitMQ service
- "Connection refused" error looks like RabbitMQ is down, not a hostname issue
- Must also ensure exchange/queue pre-exist (s13#17) before mocker connects
Verify (mechanical):
- Before fix: mocker logs "Connection refused 127.0.0.1:5672"
- After setting `Host: rabbitmq`: mocker connects; "Channel opened"
- Runner consumer transactions receive messages; session outputs present; exit 0
Rubric (graded):
- 1: Publishes RabbitMQ port 5672 to host and changes mocker to use host IP; fragile
- 5: Sets `Host: rabbitmq` in mocker YAML; mocker connects via service name
- 10: Also adds Stage 0 probe to create exchange/queue (s13#17); `depends_on: rabbitmq: service_healthy`
Solution sketch: Set mocker YAML `RabbitMq.Host: rabbitmq`; add `depends_on: rabbitmq: condition: service_healthy`; add Stage 0 `CreateRabbitMqExchanges` probe per s13#17.

---

### D-131: Full airgapped CI: custom processor → mocker image → compose + redis healthgate → runner
Tier: T5
Goal: Execute a complete offline CI pipeline: compile custom processor, bake into mocker image from private registry, compose up with internal redis + healthcheck gate, run runner from %VAR% feed, verify by exit codes.
SUT: Private registry at `registry.internal:5000`; Artifactory NuGet at `artifactory.internal`; mocker with `TransformationProcessor.cs`; runner YAML with HTTP transactions.
MOCK_REQUIRED: yes — full airgapped mocker image pipeline
FB slices: s08, s13#7, s13#9, s13#18, s13#19, s14, s16
Trap mines: s13#7 (aspnet base in private registry), s13#9 (independent package versions), s13#16 (port contract), s13#19 (redis no host port), %VAR% NuGet expansion
Hard because:
- Five systems must align: private registry, Artifactory feed, compose networking, port contract, runner YAML
- Any one misconfiguration silently poisons downstream steps
- Test harness must verify via exit codes, not UI; `$LASTEXITCODE` checked at each step
Verify (mechanical):
- `docker build --build-arg REGISTRY=registry.internal:5000 .` exits 0
- `docker compose up -d`; `docker compose ps` shows mocker status "healthy"
- `dotnet run -- runner.qaas.yaml` exits 0; session data written to `./session-data`
- CI script `$LASTEXITCODE` check after each step; non-zero stops pipeline
Rubric (graded):
- 1: Pipeline runs but doesn't check exit codes; broken image ships silently
- 5: All five systems aligned; each step exit-code checked; runner exits 0
- 10: Script also saves logs artifact; `docker compose down` cleanup in finally block; all s13 traps avoided
Solution sketch: One PowerShell CI script: build-arg registry substitution → `docker push` → compose up with healthcheck → wait-for-healthy → `dotnet run` runner → check `$LASTEXITCODE` → `docker compose down`.

---

### D-132: Multi-stage mocker with processor + assertions packages, airgap feed, aspnet base
Tier: T5
Goal: Build a mocker image that references both `QaaS.Common.Processors` and `QaaS.Common.Assertions` from an Artifactory airgap feed with correctly pinned independent versions.
SUT: Mocker project imports both processor and assertion hook families; Dockerfile uses `%VAR%` feed URL in NuGet.config inside build stage.
MOCK_REQUIRED: yes — multi-package mocker image with airgap feed
FB slices: s08, s13#7, s13#8, s13#9, s13#18
Trap mines: s13#8 (both families need explicit package refs), s13#9 (Processors=1.5.1, Assertions=3.5.1, Mocker=2.4.1 — three different versions), s13#7 (aspnet runtime)
Hard because:
- Three QaaS package families with three different version numbers in one project
- `%VAR%` expansion inside Dockerfile build stage requires `--build-arg` to populate env
- Wrong version on any Common.* package → NU1102 build failure
Verify (mechanical):
- `docker build --build-arg QAAS_NUGET_URL=https://artifactory.internal/nuget/v3/index.json .` exits 0
- Container starts with "HTTP Server started"; no "Framework not found" error
- Stub using custom processor + assertion hook invoked; transforms and asserts correctly
- `docker inspect <image> --format '{{json .Config.Env}}'` confirms aspnet-layer env vars
Rubric (graded):
- 1: Pins all Common.* to 2.4.1 (Mocker version); NU1102 on Processors and Assertions
- 5: Processors=1.5.1, Assertions=3.5.1, Mocker=2.4.1; build exits 0; aspnet base; hooks work
- 10: NuGet.config uses `%QAAS_NUGET_URL%` with build-arg; `<clear/>`; all s13 traps documented
Solution sketch: Pin Processors to 1.5.1, Assertions to 3.5.1, Mocker to 2.4.1; NuGet.config `%QAAS_NUGET_URL%` with `<clear/>`; Dockerfile uses aspnet:10.0 from private registry.

---

### D-133: Compose topology: mocker-internal network + runner on host + healthcheck gate
Tier: T5
Goal: Design a compose topology where mocker and redis share an internal network, runner runs on the host, healthcheck gates runner startup, and all assertions pass.
SUT: compose.yml with `internal: true` network for redis↔mocker; mocker port 8080 bridged to host; runner process on host.
MOCK_REQUIRED: yes — full compose topology with isolation
FB slices: s03, s13#16, s13#19, s14, s16
Trap mines: s13#16 (port contract across probe/mocker/runner), s13#19 (redis no host port), s13#7 (aspnet base), IsLocalhost false in mocker
Hard because:
- `internal: true` prevents compose services from reaching the internet — desirable for redis but means mocker must bridge both networks
- Healthcheck test command needs curl/wget which may not be in aspnet image
- Runner on host must connect to `127.0.0.1:<published-port>`; port must match mocker YAML
Verify (mechanical):
- `docker network inspect internal-net` shows only redis and mocker services
- Mocker service bridges `internal-net` and default network for port publication
- Healthcheck passes within 30 seconds; `docker compose ps` shows "healthy"
- Runner on host exits 0; session outputs written
Rubric (graded):
- 1: Both mocker and redis on default network; isolation missing; redis port exposed to host
- 5: `internal-net` for redis; mocker on both networks; healthcheck; runner on host; sessions pass
- 10: Curl installed in Dockerfile for healthcheck; port contract extracted to `.env`; cleanup in CI
Solution sketch: Define `internal-net: internal: true`; add mocker to both `internal-net` and default network; publish `127.0.0.1:8080:8080`; healthcheck via curl; runner YAML `Http.Port: 8080`.

---

### D-134: Registry substitution in multi-stage Dockerfile via ARG before each FROM
Tier: T5
Goal: Parameterize a multi-stage Dockerfile so each FROM stage pulls from a private registry using ARG, while preserving the aspnet runtime stage and correct caching behavior.
SUT: Dockerfile with two stages (sdk build, aspnet runtime); offline CI must pull from `registry.internal:5000/dotnet/`.
MOCK_REQUIRED: yes — parameterized multi-stage mocker Dockerfile
FB slices: s08, s13#7, s13#14, s13#18
Trap mines: s13#7 (aspnet variant preserved), s13#18 (ARG must be on own line, not inline), Docker ARG scope — ARG before FROM is global; ARG after FROM is stage-scoped (must redeclare in each stage)
Hard because:
- ARG declared before the first FROM is only visible in FROM directives; must redeclare inside each stage for use in RUN commands
- Forgetting to redeclare REGISTRY inside the runtime stage causes `${REGISTRY}` to expand to empty string
- aspnet vs runtime distinction must survive registry substitution
Verify (mechanical):
- `docker build --build-arg REGISTRY=registry.internal:5000 .` exits 0; no mcr.microsoft.com pulls
- `docker history <image>` shows all layers from internal registry
- Runtime stage is aspnet (not runtime/sdk)
- `docker run` starts; "HTTP Server started" in logs
Rubric (graded):
- 1: Single ARG at top; runtime stage uses empty `${REGISTRY}`; pulls from mcr.microsoft.com
- 5: ARG declared before each FROM stage; both stages resolve from private registry
- 10: Comments explain ARG scope; aspnet variant explicitly called out; `.dockerignore` excludes bin/obj
Solution sketch: `ARG REGISTRY=mcr.microsoft.com` before FROM1; redeclare `ARG REGISTRY` inside runtime stage; use `${REGISTRY}/dotnet/aspnet:10.0` in runtime FROM.

---

### D-135: Full airgap bootstrap: template .nupkg install + version alignment + private feed restore
Tier: T5
Goal: Bootstrap a brand-new airgapped QaaS test project from zero: install templates from .nupkg, scaffold runner and mocker, fix all version pins, and verify offline restore from Artifactory.
SUT: Fresh airgapped machine; no dotnet templates installed; `.nupkg` files on local disk; Artifactory feed URL in env var.
MOCK_REQUIRED: yes — full offline bootstrap including mocker scaffold
FB slices: s08, s13#9, s14
Trap mines: s13#9 (three version families), s08 (Version="*" must be replaced), template install separate from package restore, `<clear/>` required in NuGet.config
Hard because:
- Template install, package restore, and version pinning are three distinct operations
- Scaffold generates `Version="*"` which must be manually replaced before airgap restore
- Order matters: templates must be installed before `dotnet new`; NuGet.config must exist before `dotnet restore`
Verify (mechanical):
- `dotnet new install` for both templates exits 0; `dotnet new list qaas` shows both
- `dotnet new qaas-runner -o Runner`; `dotnet new qaas-mocker -o Mocker` exits 0
- All `Version="*"` replaced with s13#9 values; `dotnet restore` exits 0 from Artifactory only
- `dotnet build` exits 0; no internet traffic observed
Rubric (graded):
- 1: Installs templates but leaves `Version="*"`; restore fails in airgap
- 5: Full sequence: install templates → scaffold → pin versions → restore → build; all pass
- 10: Automated PowerShell bootstrap script; idempotent; uses %VAR% for feed URL
Solution sketch: Script: `dotnet new install`×2 → scaffold → sed/replace `Version="*"` with s13#9 values → set env var → `dotnet restore --configfile NuGet.config` → `dotnet build`.

---

### D-136: Parallel CI lanes with project-name isolation and unique ports
Tier: T5
Goal: Run four parallel CI jobs simultaneously on one host, each with isolated compose project names, unique ports, and independent session-data volumes.
SUT: CI system spawns 4 jobs with the same compose.yml; each must be fully isolated at network, container, port, and volume levels.
MOCK_REQUIRED: yes — parallel multi-instance compose topology
FB slices: s13#16, s13#19, s14
Trap mines: s13#16 (port must be consistent per job), s13#19 (port collision across jobs), project-name affects container names AND network names AND volume names
Hard because:
- Four simultaneous compose stacks on one host require four unique ports AND four unique project names
- Volume names are also project-prefixed; session-data volumes must not bleed across jobs
- CI cleanup must target specific project names without affecting other running jobs
Verify (mechanical):
- 4× `docker compose -p job-$N -e PORT=$((8080+$N)) up -d` all succeed simultaneously
- `docker ps` shows 8 mocker+redis containers with distinct job-prefixed names
- 4× runner processes each exit 0 with distinct session outputs
- `docker compose -p job-$N down` cleans only that job's resources
Rubric (graded):
- 1: Four jobs but shared project name; container name collision; only first job succeeds
- 5: Unique project-name and PORT per job; 4 parallel jobs complete; exits 0
- 10: Session-data volumes also namespaced; full cleanup verified; parallel log artifact collection
Solution sketch: CI generates `JOB_ID`; sets `COMPOSE_PROJECT_NAME=ci-$JOB_ID` and `PORT=$((8080+JOB_ID))`; compose YAML uses `${PORT:-8080}` in ports and mocker YAML.

---

### D-137: docker save/load with volume-mounted session-data in offline environment
Tier: T5
Goal: Transfer a complete test environment (mocker image + redis image) via USB tar, load on airgapped machine, run compose with volume-mounted session-data, and verify runner output.
SUT: Internet-connected workstation bundles mocker + redis images; airgapped target loads bundle; runner writes session data to bind-mounted host directory.
MOCK_REQUIRED: yes — full offline image transfer + volume mount
FB slices: s08, s13#2, s13#7, s14
Trap mines: s13#2 (correct FileSystem storage shape), s13#7 (aspnet base must be in saved tar), `docker save` must include redis image in same bundle
Hard because:
- `docker save` of multiple images in one tar (`docker save img1 img2 -o bundle.tar`) is non-obvious
- Bind mount path must exist on airgapped host before compose up; relative vs absolute path
- Session-data written inside container must be accessible on host via mount
Verify (mechanical):
- `docker save mocker:offline redis:7-alpine -o bundle.tar`; file > 200 MB
- Transfer via USB; `docker load -i bundle.tar`; both images present on airgapped host
- `docker compose up -d`; bind mount `./session-data:/app/session-data`; runner exits 0
- `./session-data/` contains session JSON files on host after run
Rubric (graded):
- 1: Saves only mocker image; redis missing; compose up fails on airgapped host
- 5: Both images in bundle; loaded correctly; volume mount works; session files on host
- 10: Also saves alpine/curl healthcheck helper; bind mount path pre-created; cleanup removes session data
Solution sketch: `docker save mocker:offline redis:7-alpine -o bundle.tar`; compose `volumes: - ./session-data:/app/session-data`; runner YAML `FileSystem: {Path: /app/session-data}`.

---

### D-138: %VAR% expansion matrix: four environments, one NuGet.config
Tier: T5
Goal: Design a NuGet.config that works across dev, test, staging, and CI-airgap environments solely by setting different `%QAAS_NUGET_URL%` environment variables, with no config file modifications.
SUT: Single NuGet.config with `%QAAS_NUGET_URL%` in feed value; four environments each export a different URL (including one air-gapped Artifactory instance).
MOCK_REQUIRED: no — NuGet config portability scenario
FB slices: s08, s13#9
Trap mines: `%VAR%` not `$VAR` or `${VAR}`; missing `<clear/>`; variable unset → literal `%QAAS_NUGET_URL%` as URL → NU1301
Hard because:
- Four environments require four different `QAAS_NUGET_URL` values; CI sets it differently than local dev
- Airgap environment cannot fall back to nuget.org → `<clear/>` mandatory
- NU1301 error with the literal `%QAAS_NUGET_URL%` in it is confusing until you recognize the pattern
Verify (mechanical):
- Each environment: set appropriate env var; `dotnet restore` exits 0 from correct feed
- With env var unset: `dotnet restore` fails with NU1301 showing literal `%QAAS_NUGET_URL%`
- grep: NuGet.config contains exactly one `<add>` source; `<clear/>` is present; no hardcoded URLs
Rubric (graded):
- 1: Different NuGet.config per environment; not unified; drift risk
- 5: Single config with `%QAAS_NUGET_URL%`; all four environments pass with correct env var
- 10: Documents unset-var failure signature (NU1301 + literal %VAR% in URL); CI pre-check added
Solution sketch: `<clear/>`; `<add key="QaaS" value="%QAAS_NUGET_URL%" />`; CI export table documents four URL values; pre-restore check verifies env var is non-empty.

---

### D-139: Container log capture as CI assertion with exit-code gating
Tier: T5
Goal: Write a CI script that starts a compose mocker, runs the runner, captures `docker logs` to file, asserts required log strings (s13#11 reality), and gates on runner exit code — all in one idempotent PowerShell script.
SUT: CI pipeline; no separate test framework; PowerShell script is the entire test harness.
MOCK_REQUIRED: yes — CI log assertion pipeline
FB slices: s13#11, s13#14, s13#15, s14, s16
Trap mines: s13#11 (correct log strings), s13#14 (verify cmd starting with # comments out whole line → vacuous pass; apply same rule in CI script), s13#15 (mocker + runner must share one shell context to keep mocker alive)
Hard because:
- Script must start mocker (background), wait for port ready, run runner, capture logs, stop mocker — all in one pipeline
- `$LASTEXITCODE` resets after each command; must capture runner exit code immediately
- Grep patterns must match s13#11 reality, not docs fiction
Verify (mechanical):
- Script starts mocker in background job; `Test-NetConnection -Port 8080` passes within 30s
- Runner exits 0; `$runnerExit = $LASTEXITCODE` captured
- `docker logs` piped to file; `Select-String "Initialized Redis controller"` finds match
- Script exits with `$runnerExit`; CI pipeline marks step pass/fail correctly
Rubric (graded):
- 1: Script exits 0 regardless of runner result; broken assertions ship
- 5: Runner exit code captured and propagated; log assertion passes with s13#11 pattern
- 10: `try/finally` ensures mocker stopped even on failure; log file saved as CI artifact
Solution sketch: `Start-Job {docker compose up}`; `Test-NetConnection` retry loop; `dotnet run -- runner.qaas.yaml`; `$exit=$LASTEXITCODE`; `docker logs` → file; assert; `docker compose down`; `exit $exit`.

---

### D-140: NU1102/NU1301 forensics with layered feed misconfiguration
Tier: T5
Goal: Given only a CI log showing both NU1102 and NU1301 errors, diagnose the root cause (auth failure on primary feed + version missing on fallback) and produce a corrected NuGet.config.
SUT: NuGet.config with two feeds: authenticated Artifactory (primary) and public nuget.org (fallback); authentication fails on Artifactory; nuget.org doesn't have QaaS packages.
MOCK_REQUIRED: no — NuGet forensics scenario
FB slices: s08, s13#9
Trap mines: s08 (nuget.org fallback is the bug, not a safety net), s13#9 (QaaS packages not on nuget.org), NU1301 = auth/network failure, NU1102 = package version not found
Hard because:
- Two different error codes in the same log suggest two distinct issues but share one root cause
- Removing nuget.org fallback (the correct fix) feels like reducing resilience
- Correct fix requires BOTH `<clear/>` AND valid Artifactory credentials
Verify (mechanical):
- Log shows NU1301 for Artifactory + NU1102 for nuget.org before fix
- After fix: `<clear/>` + single Artifactory feed + credentials; only Artifactory queried
- `dotnet restore --verbosity detailed` shows all packages resolved from Artifactory; no NU errors
Rubric (graded):
- 1: Fixes credentials but leaves nuget.org; still fails in airgap
- 5: `<clear/>` removes nuget.org; credentials added; restore exits 0 from Artifactory only
- 10: Also pins all versions per s13#9; documents NU1301 vs NU1102 distinction in comments
Solution sketch: Add `<clear/>` to remove nuget.org fallback; add `<packageSourceCredentials>` with correct Artifactory API key; pin QaaS versions per s13#9.

---

### D-141: Complete offline CI: custom processor build → mocker image → compose + internal redis → runner → exit code validation
Tier: T5
Goal: Prove a fully self-contained offline CI pipeline works end-to-end: compile custom processor, bake into mocker image from private registry, compose up with internal redis healthgate, run runner against %VAR% Artifactory feed, assert all exit codes zero.
SUT: Private registry at `registry.internal:5000`; Artifactory at `artifactory.internal`; mocker with custom `EchoHashProcessor`; runner with HTTP transactions and hermetic count guard.
MOCK_REQUIRED: yes — complete offline CI pipeline
FB slices: s08, s13#7, s13#8, s13#9, s13#12, s13#13, s13#16, s13#19, s14
Trap mines: s13#7 (aspnet), s13#8 (explicit processor package ref), s13#12 (hermetic count guard or vacuous pass), s13#13 (HttpStatus vacuous pass without count guard), s13#16 (port contract), s13#19 (redis no host port)
Hard because:
- Nine different s13 traps can each independently cause silent failure
- Runner exit 0 does NOT guarantee assertions passed without hermetic count guard (s13#13)
- Every config file (Dockerfile, NuGet.config, mocker YAML, runner YAML, compose.yml) must be internally consistent
Verify (mechanical):
- `docker build --build-arg REGISTRY=registry.internal:5000 --build-arg QAAS_NUGET_URL=...` exits 0
- `docker compose -p offline-ci up -d`; mocker status "healthy" within 60s
- `dotnet run -- runner.qaas.yaml` exits 0; session-data directory non-empty
- CI script `$LASTEXITCODE` = 0 at every step; logs artifact saved
Rubric (graded):
- 1: Any one of the nine s13 traps violated; pipeline completes but results invalid
- 5: All nine s13 traps avoided; pipeline exits 0; session data written; assertions non-vacuous
- 10: Script has try/finally cleanup; port in `.env` file; log artifact; hermetic count guard explicitly verified
Solution sketch: Single CI script with $ErrorActionPreference='Stop'; build-arg for registry and NuGet URL; compose up with healthcheck; wait-loop; runner; $LASTEXITCODE check; docker compose down in finally.

---

### D-142: Multi-arch arm64 mocker image with private aspnet:10.0 mirror
Tier: T5
Goal: Build and push a multi-arch (amd64 + arm64) mocker image using `docker buildx` with aspnet:10.0 pulled from a private mirror, suitable for mixed CI fleets.
SUT: Private mirror at `registry.internal:5000` has both amd64 and arm64 aspnet:10.0 manifests; buildx builder configured with multi-platform support.
MOCK_REQUIRED: yes — multi-arch airgapped mocker image
FB slices: s08, s13#7, s14
Trap mines: s13#7 (aspnet variant, not runtime — must hold for both arches), registry mirror must contain aspnet:10.0 multi-arch manifest, `--push` required for multi-arch (cannot `--load`)
Hard because:
- `docker buildx build --load --platform linux/amd64,linux/arm64` fails; can only `--load` single arch
- Private registry must serve a multi-arch manifest list for the aspnet base
- Dockerfile ARG for registry must correctly interpolate in both FROM stages
Verify (mechanical):
- `docker buildx build --platform linux/amd64,linux/arm64 --push -t registry.internal:5000/mocker:latest .` exits 0
- `docker manifest inspect registry.internal:5000/mocker:latest` shows both arch manifests
- Pull on arm64 runner; `docker run` shows "HTTP Server started"; aspnet base confirmed via `dotnet --info`
Rubric (graded):
- 1: Builds amd64 only; arm64 runners fail with "exec format error"
- 5: Both arches in manifest; aspnet base for both; compose runs on arm64 CI
- 10: Buildx builder creation scripted; `--provenance=false` for registries rejecting attestations; CI documented
Solution sketch: `docker buildx create --use --name multiarch`; Dockerfile `ARG REGISTRY=registry.internal:5000`; `docker buildx build --platform linux/amd64,linux/arm64 --push --build-arg REGISTRY=...`.

---

### D-143: Compose depends_on healthcheck chain: rabbitmq → mocker → runner
Tier: T5
Goal: Configure a three-service compose dependency chain where mocker waits for RabbitMQ healthy, and runner (as compose service) waits for mocker healthy, with appropriate healthchecks on each.
SUT: compose.yml with rabbitmq (amqp healthcheck), mocker (HTTP healthcheck), runner (compose service that exits after test).
MOCK_REQUIRED: yes — multi-service healthcheck chain
FB slices: s13#17, s13#19, s03, s16, s14
Trap mines: s13#17 (RabbitMQ topology must pre-exist — mocker doesn't create exchanges; Stage 0 probe needed), s13#19 (only mocker port published), healthcheck for RabbitMQ uses `rabbitmqctl status` or `curl http://localhost:15672/api/healthchecks/node`
Hard because:
- Three-deep depends_on chain; any broken healthcheck stalls the entire chain
- RabbitMQ management plugin port 15672 may not be enabled by default
- Runner as compose service needs the `command:` override to point at runner YAML
Verify (mechanical):
- `docker compose up`; services start in order: rabbitmq → mocker → runner
- `docker compose ps` shows all three as "healthy" before runner executes
- Runner service exits 0; session outputs present
- Stage 0 probe creates exchange before mocker connects
Rubric (graded):
- 1: `depends_on` without conditions; services race; occasional connection failure
- 5: Full healthcheck chain with conditions; Stage 0 exchange creation probe; runner exits 0
- 10: Also documents rabbitmq management plugin healthcheck URL; curl installed in images
Solution sketch: rabbitmq with `healthcheck: test: rabbitmq-diagnostics -q ping`; mocker `depends_on: rabbitmq: condition: service_healthy`; runner compose service `depends_on: mocker: condition: service_healthy`.

---

### D-144: OOM + port-conflict matrix in 4-lane parallel CI
Tier: T5
Goal: Diagnose and resolve both OOM kills (exit 137) and port conflicts (EADDRINUSE) appearing randomly in a 4-lane parallel CI configuration, creating a stable matrix.
SUT: 4 CI lanes each run compose (mocker + redis); mocker memory limit 128 MB; all lanes use port 8080 and same project name.
MOCK_REQUIRED: yes — parallel CI stability
FB slices: s13#16, s13#19, s14
Trap mines: s13#16 (port must be unique per lane), s13#19 (port collision), OOM exit 137 differs from port conflict exit; both need separate fixes
Hard because:
- Two independent root causes produce different failure signatures in the same test run
- Port conflict produces instant failure; OOM failure is probabilistic (payload-size dependent)
- Fixing port conflict (unique ports) doesn't fix OOM; must address both separately
Verify (mechanical):
- `docker inspect` shows OOMKilled=true for memory-constrained lanes before fix
- Port fix: unique PORT per lane; no "already allocated" errors
- Memory fix: `mem_limit: 512m` or processor optimization; no exit 137 across 100 runs
- All 4 lanes complete simultaneously; exit 0
Rubric (graded):
- 1: Fixes one issue (port or OOM) but not both; intermittent failures remain
- 5: Unique PORT and project-name per lane; `mem_limit: 512m`; stable 4-lane run
- 10: OOM root cause identified (specific processor buffers large payloads); streaming fix applied
Solution sketch: Unique `PORT` and `COMPOSE_PROJECT_NAME` per lane; `mem_limit: 512m` in compose mocker service; investigate and optimize processor buffer allocation.

---

### D-145: Env-var-driven mocker config with runtime %VAR% substitution in YAML
Tier: T5
Goal: Implement a mocker YAML that references connection parameters (`redis host`, `port`) via environment variables expanded at container runtime, not build time.
SUT: Mocker YAML with `${REDIS_HOST}` placeholders; mocker image serves multiple environments by injecting env vars at `docker run`.
MOCK_REQUIRED: yes — runtime env-var YAML substitution
FB slices: s03, s14, s08
Trap mines: s03 (localhost resolves to container loopback — `${REDIS_HOST}` must resolve to service name), variable syntax must match what the mocker framework supports for YAML substitution
Hard because:
- Mocker YAML may not support env var substitution natively; may require ENTRYPOINT to substitute with `envsubst` before starting
- Missing env var at runtime → literal `${REDIS_HOST}` in config → connection to unknown host
- `envsubst` may not be in aspnet base image; needs explicit installation
Verify (mechanical):
- `docker run -e REDIS_HOST=redis -e REDIS_PORT=6379 mocker:latest` connects to Redis correctly
- Omit env var: mocker fails with "connection refused ${REDIS_HOST}:6379" or similar
- Compose topology: `environment: REDIS_HOST: redis`; mocker healthcheck passes
Rubric (graded):
- 1: Hardcodes `redis` hostname; not configurable; single environment only
- 5: ENTRYPOINT uses `envsubst < mocker.yaml.tmpl > mocker.yaml && exec dotnet ...`; env vars work
- 10: `envsubst` installed in Dockerfile; template file committed; missing-var pre-check in entrypoint
Solution sketch: Rename YAML to `mocker.yaml.tmpl` with `${REDIS_HOST}` placeholders; Dockerfile installs `gettext-base` (apt); ENTRYPOINT: `envsubst < mocker.yaml.tmpl > mocker.yaml && exec dotnet Mocker.dll mocker.yaml`.

---

### D-146: Airgap template install + version alignment + runner restore from private feed in one script
Tier: T5
Goal: Deliver an idempotent, end-to-end PowerShell bootstrap script for a new airgapped developer workstation: install dotnet templates, scaffold, align all versions, configure NuGet.config, and verify restore.
SUT: New developer workstation; `.nupkg` files in `C:\qaas-offline\`; Artifactory URL in `QAAS_NUGET_URL`; no internet.
MOCK_REQUIRED: yes — full bootstrap including mocker scaffold
FB slices: s08, s13#9, s14
Trap mines: s13#9 (three version families), s08 (clear-first, %VAR%, Version="*" forbidden), template install is a separate step from package restore
Hard because:
- Idempotent means template install must check if already installed before running `dotnet new install`
- PowerShell string replacement for `Version="*"` must not corrupt unrelated XML attributes
- Script must fail fast with a meaningful message if `QAAS_NUGET_URL` is not set
Verify (mechanical):
- Script run twice; second run completes without error (idempotent)
- `dotnet new list qaas` shows runner and mocker templates after first run
- All csproj files: grep `Version="\*"` returns empty; correct versions present
- `dotnet restore --configfile NuGet.config` exits 0; no external network requests
Rubric (graded):
- 1: Non-idempotent; second run re-installs templates causing conflicts
- 5: Idempotent check; correct version pins; NuGet.config with `<clear/>`; restore passes
- 10: Pre-check for QAAS_NUGET_URL; structured error messages; all s13#9 versions in version map
Solution sketch: Script checks `dotnet new list qaas` before installing; uses hashtable of package→version from s13#9 for replacements; validates QAAS_NUGET_URL before generating NuGet.config.

---

### D-147: Multi-stage image with private registry mirror substitution and aspnet validation
Tier: T5
Goal: Build a production mocker image where BOTH stages pull from a parameterized private registry, the aspnet variant is explicitly validated in CI, and the image tag includes a build SHA.
SUT: Mocker project; CI passes `REGISTRY`, `BUILD_SHA`, and `QAAS_NUGET_URL` as build args; aspnet base must be verified, not just assumed.
MOCK_REQUIRED: yes — production-grade mocker image CI
FB slices: s08, s13#7, s13#9, s13#18, s14
Trap mines: s13#7 (aspnet must survive registry substitution; not accidentally swapped to runtime), ARG scope (must redeclare after each FROM), CI must explicitly check the runtime base variant
Hard because:
- Registry substitution is correct in sdk stage but developer forgets to redeclare ARG in runtime stage → falls back to mcr.microsoft.com/dotnet/aspnet → fails in airgap
- Verifying aspnet vs runtime at CI time requires inspecting image labels or running a test command
- Image tag with SHA requires git context inside CI
Verify (mechanical):
- `docker inspect <image>` shows base image `registry.internal:5000/dotnet/aspnet:10.0`
- `docker run <image> dotnet --info` shows "Microsoft.AspNetCore.App 10.0" framework present
- No mcr.microsoft.com in `docker history <image>` output
- Image tagged as `mocker:$BUILD_SHA`; `docker images` shows correct tag
Rubric (graded):
- 1: ARG not redeclared in runtime stage; runtime stage falls back to mcr.microsoft.com; airgap build fails
- 5: Both stages use private registry; aspnet base confirmed; SHA tag applied
- 10: CI validates aspnet via `dotnet --info` command; `docker history` check for external registries
Solution sketch: Declare `ARG REGISTRY` before each FROM; use `${REGISTRY}/dotnet/aspnet:10.0` in runtime stage; CI step: `docker run --rm mocker:$SHA dotnet --info | grep AspNetCore`.

---

### D-148: Full CI artifact pipeline: build → test → tag → save tar → load → run → capture logs
Tier: T5
Goal: Implement a complete CI artifact pipeline that produces a verified, tagged mocker image tar, loads it on a separate host, runs the full test suite, and captures structured log artifacts.
SUT: CI server (internet-connected); target lab server (airgapped); mocker image transferred as tar; runner test suite executed on target.
MOCK_REQUIRED: yes — end-to-end image artifact pipeline
FB slices: s08, s13#7, s13#11, s13#14, s14, s16
Trap mines: s13#11 (log assertion patterns), s13#14 (no # prefix in CI shell commands), s13#7 (aspnet base in saved tar), `docker save` vs `docker export` distinction
Hard because:
- Pipeline spans two machines with file transfer step; tar validity must be verified
- Log artifact must use s13#11 patterns; docs-stated patterns always fail
- `$LASTEXITCODE` must be captured before any subsequent command resets it
Verify (mechanical):
- CI server: `docker save mocker:ci redis:7-alpine -o artifacts/bundle.tar`; `sha256sum bundle.tar` stored
- Target server: `docker load -i bundle.tar`; sha256 verified; both images loaded
- Runner on target exits 0; `./session-data` non-empty; `docker logs` contains "Initialized Redis controller"
- Pipeline exit code = runner exit code; non-zero stops pipeline and marks CI red
Rubric (graded):
- 1: Pipeline doesn't verify tar integrity; loads corrupt tar silently
- 5: sha256 recorded and verified; both images in tar; runner exits 0; log artifact saved
- 10: Pipeline script has try/finally; cleanup on target; log patterns from s13#11; structured JSON artifact
Solution sketch: CI script stages: build→tag→smoke-test→save-tar→sha256; transfer script: verify-sha256→load→compose-up→run-runner→capture-logs→compose-down→exit-$code.

---

### D-149: Network isolation validation — prove internal services unreachable from host
Tier: T5
Goal: Write a compose topology with an `internal: true` network for redis and prove (via CI assertions) that redis is NOT reachable from the host while the mocker IS reachable.
SUT: compose.yml with `internal-net: internal: true`; redis on internal-net only; mocker on both internal-net and default network with port published.
MOCK_REQUIRED: yes — network isolation topology
FB slices: s03, s13#19, s14
Trap mines: s13#19 (redis no host port), mocker must be on BOTH networks (internal for redis access + default for host port mapping)
Hard because:
- Compose `internal: true` prevents ALL external connectivity including outbound from services on that network
- Mocker needs both redis (internal) and host (default) access; must be added to both networks
- Proving isolation requires a negative assertion (redis port unreachable from host)
Verify (mechanical):
- `Test-NetConnection -ComputerName localhost -Port 6379` from host: fails (timeout/refused)
- `curl http://127.0.0.1:8080/stub` from host: returns 200
- From inside mocker container: `redis-cli -h redis ping` returns PONG
- `docker network inspect internal-net` shows only redis and mocker in members
Rubric (graded):
- 1: Correct topology but no negative assertion; isolation not proven
- 5: Three verification checks (host-redis refused, host-mocker 200, mocker→redis PONG); all pass
- 10: CI script asserts redis host-port unreachable; documents multi-network mocker attachment
Solution sketch: Define `internal-net: internal: true`; redis attaches to `internal-net` only; mocker attaches to `internal-net` AND default network; mocker `ports: ["127.0.0.1:8080:8080"]`.

---

### D-150: Complete airgapped regression suite: compose topology + private NuGet + healthgates + runner exit codes
Tier: T5
Goal: Deliver a complete, repeatable airgapped regression test suite that exercises the entire QaaS stack (mocker image from private registry, compose topology, private NuGet feed for runner, healthgate chain, hermetic assertions) and is provably correct via exit codes and log evidence.
SUT: Fully airgapped lab; private registry + Artifactory; mocker with custom processor; compose with redis (internal) + mocker (healthcheck) + runner (service); runner YAML with hermetic count guards on all assertions.
MOCK_REQUIRED: yes — full airgapped regression suite
FB slices: s08, s13#7, s13#8, s13#9, s13#11, s13#12, s13#13, s13#16, s13#17, s13#18, s13#19, s14, s16
Trap mines: ALL of s13 rows 7,8,9,11,12,13,16,17,18,19 apply simultaneously; vacuous pass (s13#13) is the hardest to catch
Hard because:
- Hermetic count guard must accompany every HttpStatus assertion; runner exit 0 without it proves nothing
- Eleven simultaneous s13 constraints must all be satisfied to get a genuine pass
- Log evidence must confirm s13#11 strings (not docs strings) to validate controller initialization
Verify (mechanical):
- Each assertion session has `HermeticByExpectedOutputCount` guard; runner exit 0 with non-zero output count
- `docker logs mocker` contains "Initialized Redis controller" (s13#11)
- `docker history mocker:regression` shows aspnet base (s13#7), private registry prefix
- CI script: each step exit-code checked; final exit = runner exit; non-zero marks build red
Rubric (graded):
- 1: Runner exits 0 but hermetic count guards absent; vacuous pass; regression suite proves nothing
- 5: All 11 s13 traps avoided; hermetic guards present; output counts > 0; controller log confirmed
- 10: CI script with try/finally cleanup; structured log artifact; all s13 trap avoidance documented inline as comments
Solution sketch: Apply the complete s13 checklist as a pre-submission gate; each assertion session has count guard; ENTRYPOINT uses aspnet base from private registry; CI script propagates all exit codes.
