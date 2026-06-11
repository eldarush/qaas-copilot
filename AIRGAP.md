# QaaS Copilot Airgap Runbook

This repo is designed for airgapped Claude Code usage with local docs, local package mirrors, and a single docs mirror knob: `QAAS_DOCS_URL`.

## Architecture

- Local model gateway: any OpenAI-compatible endpoint
- Docs mirror: your internal QaaS docs site
- Package mirror: your internal NuGet feed
- Claude Code: loads the shipped `qaas` plugin from this repo

## Setup

1. Copy this repo to your internal host.
2. Install the plugin from the local path.
3. Point `QAAS_DOCS_URL` at your internal docs mirror.
4. Use `/qaas:fact` for bundled offline guidance and `/qaas:docs` for live docs.

## NuGet feed

Set your internal source once and keep it private:

```powershell
$env:QAAS_NUGET_SOURCE_NAME = "LocalArtifactory"
$env:QAAS_NUGET_SOURCE_URL  = "http://your-artifactory/artifactory/api/nuget/v3/qaas-nuget"
```

The plugin assumes QaaS packages are mirrored internally before you author or run tests.

## Docker

Use the shipped Docker guidance in the plugin when you need mockers, brokers, or custom images. Keep the public repo docs focused on install/use; container specifics belong in the plugin skills and the QaaS docs mirror.

## Troubleshooting

- `QAAS_DOCS_URL` unreachable: `/qaas:fact` still works from the bundled Fact Base.
- NuGet restore failure: verify your internal feed URL and credentials.
- Container port conflict: make sure only one service binds the host port.
- Missing or stale QaaS field: run `validate-compatibility` before authoring.
