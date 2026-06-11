# QaaS Skills Platform — Airgap Deployment & Runbook

This guide describes how to deploy, configure, and operate the **QaaS Skills Platform** inside a fully airgapped environment with **local models** (e.g., MiniMax M2.7, 128k context) and private package mirrors.

---

## 1. Architecture Overview

In an airgapped environment, you have access to:
1. **Local LLMs**: MiniMax M2.7 (128k context) or similar models running behind an OpenAI-compatible API gateway (such as `vLLM`, `sglang`, `llama.cpp`, or `LM Studio`).
2. **Local Package Repository**: JFrog Artifactory, Sonatype Nexus, or a local file-based folder acting as your NuGet feed.
3. **Docs Mirror**: A local copy of the QaaS documentation site (including `llms.txt` and `llms-full.txt`).
4. **Harness & Skills**: This repository, cloned and set up on a secure local workstation or server.

```
+---------------------------------------------------------------------------------+
|                               AIRGAPPED LAN                                     |
|                                                                                 |
|  +--------------------+      +--------------------+      +--------------------+ |
|  |     Local LLM      |      | Private Artifactory|      |    Docs Mirror     | |
|  |  (MiniMax-M2.7)    |      |  (QaaS NuGet Feed) |      | (C:\qaas\docs\...) | |
|  +---------+----------+      +---------+----------+      +---------+----------+ |
|            ^                           ^                           ^            |
|            |                           |                           |            |
|  +---------+---------------------------+---------------------------+----------+ |
|  | WORKSTATION                                                                | |
|  |                                                                            | |
|  |   +--------------------+       +--------------------+                      | |
|  |   |    QaaS Skills     | ----> |  Claude Code CLI   |                      | |
|  |   | (14 Task Contracts)|       |  (Natively Guided) |                      | |
|  |   +--------------------+       +---------+----------+                      | |
|  |                                          |                                 | |
|  |                                          v                                 | |
|  |                                +---------+----------+                      | |
|  |                                | Local Testbed (e2e)|                      | |
|  |                                | (Runner / Docker)  |                      | |
|  |                                +--------------------+                      | |
|  +----------------------------------------------------------------------------+ |
+---------------------------------------------------------------------------------+
```

---

## 2. Plug-and-Play Setup with Claude Code (One Button)

This platform ships as a **native Claude Code plugin**. Installing it makes Claude Code an
expert in planning, authoring, running, and debugging QaaS tests, while honoring all local docs
and airgap boundaries. **The only value you change for a new environment is `QAAS_DOCS_URL`.**

### Step 2.1: Install the plugin (airgapped)

On a connected machine, clone this repo and copy the folder to your airgapped host (USB,
internal git, artifact share). Then, inside Claude Code on the host, add the marketplace from
the **local path** and install:

```
/plugin marketplace add /opt/qaas-copilot
/plugin install qaas@qaas-copilot
```

(Connected machine? Use `/plugin marketplace add eldarush/qaas-copilot` instead. Or open the
repo itself — the committed `.claude/settings.json` auto-enables the plugin with zero commands.)
Full matrix: [INSTALL.md](./INSTALL.md).

### Step 2.2: Point it at your internal docs mirror (the one knob)

```bash
export QAAS_DOCS_URL="http://docs.internal.example.com"     # Linux/macOS
# setx QAAS_DOCS_URL "http://docs.internal.example.com"     # Windows (new shells)
```

That is the entire configuration. The plugin bundles 15 skills, 3 subagents, 5 commands, and
the full offline Fact Base, so it works even when the docs server is unreachable.

### Step 2.3: What you get natively in Claude Code

* The **QaaS Test-Authoring Constitution** and **16 Doc-Drift Traps** auto-load every session
  (via the `qaas-overview` skill + SessionStart hook) — so it never makes common schema mistakes.
* **14 task skills** invoked automatically by description (plan, scaffold, author YAML, hooks,
  run, diagnose, build mocker images, offline packaging, verify-done).
* **3 subagents**: `qaas-planner`, `qaas-test-author`, `qaas-debugger`.
* **Slash commands**: `/qaas:docs <path>` (curl-based live docs), `/qaas:fact <slice>` (offline
  Fact Base), `/qaas:new-test`, `/qaas:diagnose`, `/qaas:verify`.

### Step 2.4: Native docs fetching via curl (never WebFetch)

`/qaas:docs runner/configuration` shells out to `curl -fsSL` against `$QAAS_DOCS_URL` and
streams the text straight into context — no third-party dependencies, proxy-friendly, airgap-safe.
If the mirror is down, `/qaas:fact` serves the bundled, drift-corrected knowledge offline.

---

## 3. Setting Up Local LLM Gateways

The harness expects an **OpenAI-compatible** API endpoint. You can run MiniMax M2.7, llama.cpp, or vLLM easily on local GPU clusters.

### Environment Variables
Configure the harness to speak with your local endpoint by setting these variables on your workstation:

```powershell
# Point to your local LLM gateway
$env:QAAS_LLM_BASE_URL   = "http://your-local-llm-server:8000/v1"
$env:QAAS_LLM_MODEL      = "MiniMax-M2.7"

# (Optional) Point to a larger/smarter model for the adversarial Evaluator
$env:QAAS_LLM_EVAL_MODEL = "MiniMax-M2.7"

# Point to your local QaaS documentation mirror on disk
$env:QAAS_DOCS_MIRROR    = "C:\qaas\docs-mirror\docs"
```

---

## 3. Configuring Offline NuGet Feeds

Since the airgapped workstation cannot resolve `nuget.org`, you must feed your local package server with the required QaaS binaries and tell your project templates how to fetch them.

### Step 3.1: Pre-Mirror QaaS Packages
Mirror these core NuGet packages to your local Artifactory/Nexus feed:
* `QaaS.Runner` (v4.5.1+)
* `QaaS.Mocker` (v2.4.1+)
* `QaaS.Common.Assertions`
* `QaaS.Common.Generators`
* `QaaS.Common.Probes`
* `QaaS.Common.Processors`
* `QaaS.Framework.Core`
* `QaaS.Framework.Testing`

### Step 3.2: Configure the NuGet.config Template
To prevent dependency leakage or internet resolution hangs, our `scaffold-runner-project` and `scaffold-mocker-project` skills inject a secured, clear-first `NuGet.config`. 

Your environment-level variables dictate where these point. Set them globally in your session or user profiles:

```powershell
$env:QAAS_NUGET_SOURCE_NAME = "LocalArtifactory"
$env:QAAS_NUGET_SOURCE_URL  = "http://your-artifactory/artifactory/api/nuget/v3/qaas-nuget"
```

The resulting `NuGet.config` generated for your runner and mocker projects looks like this:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="%QAAS_NUGET_SOURCE_NAME%" value="%QAAS_NUGET_SOURCE_URL%" />
  </packageSources>
</configuration>
```
The `%QAAS_NUGET_SOURCE_NAME%` and `%QAAS_NUGET_SOURCE_URL%` tokens are fully expanded by NuGet at restore-time using environment variables, avoiding hardcoded URLs in committed code!

### Step 3.3: Pre-Install Project Templates Offline
Since `dotnet new install QaaS.Runner.Template` normally queries nuget.org, you must install templates offline.

1. Download the template `.nupkg` files (e.g. `QaaS.Runner.Template.x.y.z.nupkg` and `QaaS.Mocker.Template.x.y.z.nupkg`) on a connected machine.
2. Transfer them to your airgapped environment via secure media.
3. Install them directly from the local file path:
   ```powershell
   dotnet new install C:\packages\QaaS.Runner.Template.1.5.2.nupkg
   dotnet new install C:\packages\QaaS.Mocker.Template.1.5.2.nupkg
   ```

---

## 4. Local Containerization & Docker Setup

QaaS uses Docker for running mockers, stubs, and broker dependencies (RabbitMQ, Redis, Kafka) locally and hermetically.

### Step 4.1: Import Base Docker Images
Ensure your secure private container registry hosts these required base images:
* `sdk:10.0` (Microsoft official SDK)
* `aspnet:10.0` (Microsoft official ASP.NET runtime — **Crucial**: do *not* use generic `.NET Runtime` images as custom mockers run on ASP.NET Web API!)
* `rabbitmq:3-management` or `rabbitmq:4`
* `redis:7-alpine` or `redis:8`

### Step 4.2: Build the Mocker Base Image Locally
If building custom Docker mockers, the skills will generate a multi-stage `Dockerfile`. Ensure your `Dockerfile` has local registry endpoints substituted:

```dockerfile
FROM your-private-registry/dotnet/sdk:10.0 AS build
WORKDIR /app
COPY *.csproj ./
RUN dotnet restore
COPY . ./
RUN dotnet publish -c Release -o out

FROM your-private-registry/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/out .
EXPOSE 8080
ENTRYPOINT ["dotnet", "CustomMocker.dll"]
```

---

## 5. Executing Sprints Offline

Now that your infrastructure is primed, executing the Plan → Contract → Generate → Evaluate pipeline is straightforward.

### Step 5.1: Create a New Sprint Task
```powershell
# Create S02 sprint under a custom directory
.\platform\harness\new-sprint.ps1 -SprintsRoot .\sprints -SprintId S02 -Feature "Kafka Pipeline Integration"
```

### Step 5.2: Fill the Sprint Contract
Open `sprints\S02\sprint.json` and declare your tasks, mechanical `verify` scripts, and graded rubrics (or let your Planner agent generate it).

### Step 5.3: Kickoff the Loop
Run `loop.ps1` to execute the iteration pipeline. It will assemble the context (strictly under the 120k characters limit), feed it to the local model, apply files, run local Docker instances, verify exit codes, and request the local Evaluator's verdict.

```powershell
.\platform\harness\loop.ps1 -SprintDir .\sprints\S02 `
    -InvokeGenerator .\platform\harness\invoke-openai-compat.ps1 `
    -InvokeEvaluator .\platform\harness\invoke-openai-compat.ps1
```

If you do not have an evaluator model running locally, append `-SkipEvaluator` to rely entirely on mechanical test-run assertions:
```powershell
.\platform\harness\loop.ps1 -SprintDir .\sprints\S02 `
    -InvokeGenerator .\platform\harness\invoke-openai-compat.ps1 `
    -SkipEvaluator
```

---

## 6. Airgap Troubleshooting & Drifts

Here are the most common failures encountered in airgapped environments and how the QaaS Platform addresses them:

### A. NU1301: Failed to retrieve information from remote source
* **Cause**: NuGet is attempting to resolve an internet endpoint or the workstation lacks access to your private Artifactory.
* **Resolution**: Ensure `QAAS_NUGET_SOURCE_URL` is set correctly and the host is pingable. Run `dotnet restore --interactive` or check proxy/credential credentials in your `NuGet.config`.

### B. Unable to locate custom hook assembly
* **Cause**: The custom hook C# assembly wasn't compiled or wasn't placed in the scanned folder.
* **Resolution**: The `scaffold-runner-project` skill automatically sets up assembly output parameters to output custom hook DLLs to the execution directory. Verify the build step completed successfully.

### C. Mocker container exits instantly with 139 or port conflict
* **Cause**: Standard mockers compiled on `aspnet:10.0` but run on a base image without Web API components, or port `8080` is already in use.
* **Resolution**: Check the Docker logs using `docker logs <container_id>`. Verify that the base image is exactly `aspnet:10.0` and that no duplicate containers are bound to port `8080`.

### D. Silent Vacuous Passes
* **Cause**: A test asserts on `HttpStatus` without confirming that any requests were actually made, or `ExpectedCount` was left out.
* **Resolution**: Always review your test assertions using the `pick-assertion` skill. Ensure that you have active mocks listening, or that your runner YAML specifies non-zero expected request counts.
