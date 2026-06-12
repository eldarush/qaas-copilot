## 8. TASK: Offline / airgap packaging ([LAB] env facts, 09)
- Single NuGet feed: `NuGet.config` with `<clear/>` + one `<add key=.. value=..>`; swap URL for
  Artifactory. Keep URL configurable (env var), pass into Docker/CI before `dotnet restore`.
- Scaffolds support env-var override `QAAS_NUGET_SOURCE_NAME` / `QAAS_NUGET_SOURCE_URL`
  (docs deployMock.md). `dotnet restore --configfile NuGet.config`.
- Templates `qaas-runner`/`qaas-mocker` are **not on nuget.org** → `dotnet new install <local path>`
  or ship template zips / host in Artifactory. [LAB]
- Pre-mirror all packages (Runner + Common.* + Framework.*) to Artifactory. Built-in hook families
  must be present as packages for assembly scanning to find them.
- Multi-stage Docker needs `sdk:10.0` + `aspnet:10.0` images locally (private registry in airgap).

---

