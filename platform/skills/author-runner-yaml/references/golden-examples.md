# author-runner-yaml — Golden Examples Reference

Verbatim from FB s14 (LAB-green). Do not modify these snippets.

## FB s14.3 — RabbitMQ DummyApp test.qaas.yaml

```yaml
MetaData:
  Team: Smoke
  System: DummyApp

DataSources:
  - Name: FromFileSystemTestData
    Generator: FromFileSystem
    GeneratorConfiguration:
      DataArrangeOrder: AsciiAsc
      FileSystem: { Path: TestData }

Sessions:
  - Name: RabbitMqExchangeWithFromFileSystemTestData
    Publishers:
      - Name: Publisher
        DataSourceNames: [FromFileSystemTestData]
        Policies:
          - LoadBalance: { Rate: 50 }
        RabbitMq:
          Host: 127.0.0.1
          Username: admin
          Password: admin
          Port: 5672
          ExchangeName: dummy-app-tests-input
          RoutingKey: /
    Consumers:
      - Name: Consumer
        TimeoutMs: 5000
        RabbitMq:
          Host: 127.0.0.1
          Username: admin
          Password: admin
          Port: 5672
          ExchangeName: dummy-app-tests-output
          RoutingKey: /
        Deserialize: { Deserializer: Json }

Assertions:
  - Name: HermeticByInputOutputPercentage
    Assertion: HermeticByInputOutputPercentage
    SessionNames: [RabbitMqExchangeWithFromFileSystemTestData]
    AssertionConfiguration:
      OutputNames: [Consumer]
      InputNames: [Publisher]
      ExpectedPercentage: 100
  - Name: DelayByChunks
    Assertion: DelayByChunks
    SessionNames: [RabbitMqExchangeWithFromFileSystemTestData]
    AssertionConfiguration:
      Output: { Name: Consumer, ChunkSize: 1 }
      Input:  { Name: Publisher, ChunkSize: 1 }
      MaximumDelayMs: 10000
```

TestData/input.json: `[{"id":1,"message":"hello from DummyAppTests"}]`

## FB s14.8 — Variables + anchors + overwrite + cases

```yaml
variables:           # lowercase section
  mocker: {host: "http://127.0.0.1", port: 9999}
anchors:
  helloHttpAnchor: &helloHttpAnchor
    BaseAddress: ${variables:mocker:host}
    Port: ${variables:mocker:port}
    Method: Get
# Usage: Http: {<<: *helloHttpAnchor, Route: hello}
```

- `Variables\local.yaml` = `variables:\n  mocker:\n    port: 8080`
  Run: `dotnet run -- run test.qaas.yaml -w Variables\local.yaml`
- `Cases\helloRoute.yaml` = `Sessions:0:Transactions:0:Http:Route: hello`
  Run: `dotnet run -- run test.qaas.yaml -c Cases`
  → one execution per case file; allure suite label = `Cases\helloRoute.yaml`

Hermetic guard example (FB s14.8):
```yaml
  - Name: ExactlyOneOutput
    Assertion: HermeticByExpectedOutputCount
    SessionNames: [HelloSession]
    AssertionConfiguration:
      OutputNames: [CallHello]
      ExpectedCount: 1   # field is ExpectedCount, NOT ExpectedOutputCount (FB s13#12)
```

## FB s14.7 — Controller staged stub-swap

Mocker YAML addition:
```yaml
Controller:
  ServerName: HelloMocker        # must byte-match Runner MockerCommands[].ServerName
  Redis: {Host: 127.0.0.1:6379}  # single "host:port" string
```

Runner session (staged):
```yaml
    Transactions:
      - Name: CallHelloOk
        Stage: 1
        TimeoutMs: 3000
        DataSourceNames: [HelloData]
        Http: {BaseAddress: http://127.0.0.1, Port: 8080, Route: hello, Method: Get}
      - Name: CallHelloAfterSwap
        Stage: 3
        TimeoutMs: 3000
        DataSourceNames: [HelloData]
        Http: {BaseAddress: http://127.0.0.1, Port: 8080, Route: hello, Method: Get}
    MockerCommands:
      - Name: SwapToFailure
        ServerName: HelloMocker
        Stage: 2
        Redis: {Host: 127.0.0.1:6379}
        Command:
          ChangeActionStub: {ActionName: HelloOk, StubName: HelloFail}
```
