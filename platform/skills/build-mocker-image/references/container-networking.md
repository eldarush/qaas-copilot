# Container Networking (FB s07, FB s08)

## From host to container
`docker run -p 8080:8080` maps host port → container port.
`curl.exe http://127.0.0.1:8080/hello` works from the host.

## From container to host (Redis, RabbitMQ, etc.)
Inside the container, `127.0.0.1` is the **container loopback** — NOT the host machine (FB s07).

| Scenario | Address to use |
|---|---|
| Host-mode Docker (Linux only) | `127.0.0.1` works |
| Docker Desktop (Windows/Mac) | `host.docker.internal` |
| Docker Compose shared network | service name (e.g. `redis`) |
| Custom bridge network | container name / service name |

## Mocker Controller Redis host (FB s14#7, LAB L6)
```yaml
Controller:
  ServerName: HelloMocker
  Redis:
    Host: "host.docker.internal:6379"   # Docker Desktop Windows/Mac
    # Host: "redis:6379"                 # Docker Compose with redis service
```

## Docker Compose example (mocker + Redis)
```yaml
version: "3"
services:
  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
  hellomocker:
    image: hellomocker:lab
    ports: ["8080:8080"]
    environment:
      QAAS_NUGET_SOURCE_URL: https://artifactory.example.com/nuget/v3/index.json
```
With Compose, mocker YAML uses `Host: "redis:6379"` (service DNS).

## Verify container is reachable
```powershell
docker inspect <container> --format "{{.State.Status}}"   # should be "running"
docker logs <container> | Select-String "HTTP Server started"
curl.exe -s -o NUL -w "%{http_code}" http://127.0.0.1:8080/hello
```
