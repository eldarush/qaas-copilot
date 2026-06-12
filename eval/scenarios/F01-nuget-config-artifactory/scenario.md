# F01 — nuget-config-artifactory (offline)

**Complex system simulated:** The airgapped lab. Developers clone a runner project that
references `QaaS.Runner` but there is no nuget.org — only an internal Artifactory feed whose URL
differs per site and is injected through an environment variable. Restores must use ONLY that
feed.

**Weak-model job (single task):** author `NuGet.config` using the `<clear />` + env-var
substitution pattern (`value="%QAAS_NUGET_SOURCE_URL%"` — LAB-VERIFIED: NuGet expands `%VAR%`
in source values at restore time) plus `AIRGAP-RESTORE.md` documenting the exact operator steps.
The verify gate sets the env var to a real feed URL and runs a live `dotnet restore`.

- Category: offline
- Infra: none
- Seed: runner project (csproj + Program.cs + yaml) with no NuGet.config
- Live gates: restore with env-var-driven config exits 0; config contains `<clear />` and `%QAAS_NUGET_SOURCE_URL%`
