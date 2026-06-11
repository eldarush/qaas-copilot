## 5. TASK: Configuration as Code (C# builders) (09)
`Bootstrap.New(args)` (falls back to `["run","test.qaas.yaml"]` if no args; empty `{}` yaml OK) →
`runner.ExecutionBuilders.AsSingle()`. Builders map 1:1 to YAML:
- `DataSourceBuilder().Named(name).HookNamed(nameof(FromFileSystem)).Configure(cfgObj)`
- `PublisherBuilder().Named().AddDataSource().AddPolicy(new PolicyBuilder().Configure(new
  LoadBalancePolicyConfig{Rate=50})).Configure(new RabbitMqSenderConfig{...})`
- `ConsumerBuilder().Named().WithTimeout(5000).Configure(new RabbitMqReaderConfig{...})
  .WithDeserializer(new DeserializeConfig{Deserializer=SerializationType.Json})`
- `SessionBuilder().Named().AddPublisher(p).AddConsumer(c)`
- `AssertionBuilder{AssertionInstance=null!,Reporter=null!}.Named().HookNamed(nameof(X))
  .AddSessionName(s.Name!).Configure(new XConfiguration{...})`
- `executionBuilder.WithMetadata(new MetaDataConfig{Team,System}).AddDataSource(..).AddSession(..)
  .AddAssertion(..); runner.Run();`
Use code-first for dynamic rates/env, conditional sessions, DRY shared config, loops, IntelliSense.

---

