# NuGet.config Templates (FB s08)

## Minimal single-feed (hardcoded URL)
```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="QaaS" value="https://artifactory.example.com/nuget/v3/index.json" />
  </packageSources>
</configuration>
```

## Env-var substitution pattern (docs deployMock.md, FB s08; LAB-VERIFIED)
`%VAR%` in the `value` attribute is expanded by NuGet at restore time — verified live:
a bad `%QAAS_NUGET_SOURCE_URL%` fails with NU1301 naming the expanded URL; a good one restores exit 0.
```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="%QAAS_NUGET_SOURCE_NAME%" value="%QAAS_NUGET_SOURCE_URL%" />
  </packageSources>
</configuration>
```
Set env vars before restore:
```powershell
$env:QAAS_NUGET_SOURCE_NAME = "QaaS"
$env:QAAS_NUGET_SOURCE_URL  = "https://artifactory.example.com/nuget/v3/index.json"
dotnet restore --configfile NuGet.config
```

## Local folder feed (for offline dev/testing)
```powershell
# Create local feed folder and add packages:
nuget init C:\packages C:\local-feed

# NuGet.config pointing to local folder:
```
```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="Local" value="C:\local-feed" />
  </packageSources>
</configuration>
```

## Verified package versions (FB s13#9, LAB)
| Package | Version |
|---|---|
| QaaS.Runner | 4.5.1 |
| QaaS.Mocker | 2.4.1 |
| QaaS.Common.Generators | (match Runner minor) |
| QaaS.Common.Assertions | (match Runner minor) |
| QaaS.Common.Processors | (match Mocker minor) |
| .NET SDK | 10.0.203 |
