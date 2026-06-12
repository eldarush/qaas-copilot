# Batch H — Advanced Custom-Hook Scenarios (H-101..H-150)
<!-- tier-histogram: T3×10 (H-101..110) | T4×20 (H-111..130) | T5×20 (H-131..150) -->
<!-- FB slices used: s04, s13 | Drift rows: 1,4,5,5b,6,8,9,11,12,13,16 -->
<!-- All hooks: records+[Required]+null-tolerant ctor+synchronous probes+stateless processors -->
<!-- Generated per CLAUDE.md §2 constitution — DOCS-OR-SILENCE, no guessing -->

### H-101: Sequential ID Generator with Configurable Start/Step
Tier: T3
Goal: Author a `BaseGenerator<SeqConfig>` that yields incrementing integer IDs starting at a configured value with a configured step.
SUT:
- Runner project referencing `QaaS.Runner 4.5.1`
- YAML session calls generator by simple class name `SequentialIdGenerator`
- Downstream assertion verifies first output body contains `"id": <StartValue>`
MOCK_REQUIRED: no — generator produces synthetic data; no mocker needed
FB slices: s04, s13
Trap mines: s13#8 (missing hook assembly ref), s13#9 (version mismatch on QaaS.Runner), s13#12 (config typo silently ignored)
Hard because:
- Config record must use `[Required]` on nullable `uint?` fields; non-nullable uint without [Required] never triggers validation
- `Configuration` is null in ctor; reading `Configuration.StartValue` in ctor → NullReferenceException
- `yield return` streaming means loop must not capture mutable shared state
Verify (mechanical):
- `dotnet build` exit 0
- Runner log contains `Found IGenerator hook instance SequentialIdGenerator`
- First generated Data body deserializes to `{"id": <StartValue>}`
- Second body contains `{"id": <StartValue + Step>}`
Rubric (graded):
- Config record is a `record` with `[Required] public uint? StartValue`, `[Required] public uint? Step` (4 pts)
- `Generate` yields correct sequence without touching `Configuration` in ctor (3 pts)
- YAML references generator by exact class name, no leading assembly qualification (3 pts)
Solution sketch: Declare `SeqConfig` record with `[Required] public uint? StartValue` and `[Required] public uint? Step`; in `Generate` loop from `Configuration!.StartValue!.Value` using `Step.Value`; yield `new Data<object>` wrapping anonymous `{id}`.

### H-102: Output Field-Count Matches Input Field-Count Assertion
Tier: T3
Goal: Author a `BaseAssertion<object>` that passes iff every output JSON object has the same number of top-level keys as the corresponding input JSON object.
SUT:
- Runner project; single session with one transaction; input and output are JSON objects
- Assertion called by YAML using simple class name `FieldCountAssertion`
- No config needed → `object` TConfiguration
MOCK_REQUIRED: no — assertion only reads sessionDataList
FB slices: s04, s13
Trap mines: s13#6 (null output → broken assertion), s13#13 (vacuous pass on zero outputs)
Hard because:
- Must handle null output gracefully — set `AssertionStatus = Broken` rather than throw on null body
- `sessionDataList.AsSingle().GetOutputByName(name).CastCommunicationData<JsonElement>()` chain; wrong cast type → InvalidCastException
- Zero-output case passes vacuously unless a count-guard assertion co-exists in YAML
Verify (mechanical):
- `dotnet build` exit 0
- Runner log contains `Found IAssertion hook instance FieldCountAssertion`
- Assertion returns `true` when input and output field counts match; `false` otherwise
- `AssertionMessage` set before return
Rubric (graded):
- TConfiguration is `object`; no `NoConfiguration` usage (3 pts)
- Null-output handled by setting `AssertionStatus = Broken` + descriptive `AssertionMessage` (4 pts)
- `AssertionTrace` includes actual vs expected counts (3 pts)
Solution sketch: Use `object` TConfiguration; in `Assert` call `AsSingle()` then `GetOutputByName` + `CastCommunicationData<JsonElement>()`; compare `GetPropertyCount()` on input vs output bodies; set `AssertionMessage`/`AssertionTrace`; return bool.

### H-103: TCP Port Reachability Pre-Run Probe
Tier: T3
Goal: Author a `BaseProbe<TcpProbeConfig>` that synchronously checks a configured host:port is connectable before the test session starts, failing fast if not reachable.
SUT:
- Runner project with probe at Stage 0 before transactions
- Config fields: `Host` (string, required), `Port` (uint, required), `TimeoutMs` (uint, default 3000)
MOCK_REQUIRED: no — probe is self-contained TCP check
FB slices: s04, s13
Trap mines: s13#16 (PORT CONTRACT — probe port must match mocker port exactly), s04 (probe must be synchronous — no Task.Run)
Hard because:
- `Run` is `void` synchronous; using `TcpClient.ConnectAsync(...).Wait()` is acceptable but `Task.Run(...)` is not
- Probe should throw a descriptive exception on failure (not silently pass) so the runner marks the session Broken
- `TimeoutMs` default via property initializer, not via ctor (Configuration null in ctor)
Verify (mechanical):
- `dotnet build` exit 0
- Runner log contains `Found IProbe hook instance TcpReadinessProbe`
- Probe at Stage 0 appears in run log before transaction stages
- With a closed port: run log shows probe exception, session marked Broken
Rubric (graded):
- `Run` is synchronous; `TcpClient` used with timeout, no `Task.Run` (4 pts)
- Config record: `[Required] Host`, `[Required] Port`, `TimeoutMs` defaulting to 3000 (3 pts)
- Throws `InvalidOperationException` with host:port detail on failure (3 pts)
Solution sketch: `TcpReadinessProbe : BaseProbe<TcpProbeConfig>`; `Run` creates `TcpClient`, calls `Connect(host, port)` inside a `try/catch`; throws on failure. No async at all.

### H-104: Generator Reading External JSON File via DataSource
Tier: T3
Goal: Author a `BaseGenerator<JsonFileConfig>` that reads a JSON array from a named DataSource file and yields each element as a separate `Data<object>`.
SUT:
- Runner project; YAML session declares a `DataSourceNames` entry pointing to a JSON file
- Generator yields one `Data<object>` per array element
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s13#3 (DataSourceNames is REQUIRED), s13#12 (config typo silently ignored)
Hard because:
- Must use `dataSourceList.GetDataSourceByName(name)` from `QaaS.Framework.SDK.Extensions` namespace
- JSON file must be a JSON array; generator must handle empty array without error
- `DataSourceName` config field must be `[Required]` nullable string
Verify (mechanical):
- `dotnet build` exit 0
- Runner log contains `Found IGenerator hook instance JsonFileGenerator`
- With a 3-element JSON array file, exactly 3 Data objects yielded (confirmed via output count)
- Empty file yields 0 Data objects, no exception
Rubric (graded):
- `GetDataSourceByName` used with config-supplied name (4 pts)
- Handles empty array gracefully (3 pts)
- Config record is proper record with `[Required] public string? DataSourceName` (3 pts)
Solution sketch: `JsonFileGenerator : BaseGenerator<JsonFileConfig>`; in `Generate`, call `dataSourceList.GetDataSourceByName(Configuration!.DataSourceName!)` to get raw bytes/string; `JsonSerializer.Deserialize<JsonElement[]>` then foreach yield `new Data<object>(elem)`.

### H-105: Uniqueness-Invariant Assertion Across All Outputs
Tier: T3
Goal: Author a `BaseAssertion<UniquenessConfig>` that verifies a specified JSON field is unique across ALL output items in the session.
SUT:
- Runner project; multi-output transaction session (e.g. 5 outputs expected)
- Config: `FieldPath` (string, required), hermetic count guard co-exists in YAML
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s13#6 (null output crash), s13#13 (vacuous pass — must have count guard in YAML)
Hard because:
- Must iterate ALL outputs in `sessionDataList`, not just `AsSingle()`
- Duplicate detection via `HashSet<string>` — must serialize field value to string to handle numeric types
- If any output has null body, must set `AssertionStatus = Broken` not throw
Verify (mechanical):
- `dotnet build` exit 0
- Runner log contains `Found IAssertion hook instance UniquenessAssertion`
- With 3 outputs having duplicate IDs: assertion returns `false` + `AssertionMessage` names the duplicate
- With all unique: returns `true`
Rubric (graded):
- Iterates all `SessionData` items, not just first (4 pts)
- Duplicate detection uses HashSet with string serialization of field value (3 pts)
- AssertionMessage names the first duplicate value found (3 pts)
Solution sketch: Loop `sessionDataList`; for each session call `GetOutputByName` + `CastCommunicationData<JsonElement>()`; extract field via `GetProperty(FieldPath)`; add to `HashSet<string>`; on duplicate set `AssertionMessage` and return false.

### H-106: Timezone-Stable UTC Timestamp Generator
Tier: T3
Goal: Author a `BaseGenerator<TimestampConfig>` that yields a JSON payload containing a UTC ISO-8601 timestamp that is stable regardless of server timezone.
SUT:
- Runner project; config: `FieldName` (string, required), `Count` (uint, required)
- Downstream assertion verifies timestamp parses as UTC (DateTimeKind.Utc)
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s13#12 (config key typo silently ignored), s04 (Configuration null in ctor)
Hard because:
- Must use `DateTime.UtcNow` not `DateTime.Now` — local time varies per host timezone
- ISO-8601 format: `"O"` round-trip format or `"yyyy-MM-ddTHH:mm:ss.fffZ"` — must include `Z` suffix
- Config `Count` controls how many items yielded; loop uses `Configuration` not ctor-time value
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IGenerator hook instance UtcTimestampGenerator`
- Each yielded body contains field `FieldName` whose value `DateTime.Parse(..., DateTimeStyles.RoundtripKind).Kind == Utc`
- Server timezone set to UTC+5 in test: output still ends in `Z`
Rubric (graded):
- `DateTime.UtcNow.ToString("O")` or equivalent producing `Z`-suffixed string (4 pts)
- Config record correct with `[Required]` on both fields (3 pts)
- `Count` loop iterates exactly `Configuration!.Count!.Value` times (3 pts)
Solution sketch: `UtcTimestampGenerator : BaseGenerator<TimestampConfig>`; loop `i < Configuration!.Count!.Value`; yield `new Data<object>(new { [FieldName] = DateTime.UtcNow.ToString("O") })`.

### H-107: File-Existence Pre/Post Probe
Tier: T3
Goal: Author a `BaseProbe<FileProbeConfig>` that at Stage 0 asserts a file does NOT exist (clean state) and at Stage 99 asserts the file DOES exist (SUT created it).
SUT:
- Runner project; probe used at two stages with different `ExpectedExists` config values
- Config: `FilePath` (string, required), `ExpectedExists` (bool, required)
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (probe synchronous, no Task.Run), s13#12 (config key typo silently ignored)
Hard because:
- Same probe class used at two stages; config record must have `[Required] public bool? ExpectedExists` (nullable bool + [Required])
- `File.Exists` is synchronous — correct; no async needed
- Probe must throw on mismatch with a message indicating expected vs actual state
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IProbe hook instance FileExistenceProbe` (appears twice in stages 0 and 99)
- Stage 0 probe throws if file pre-exists; Stage 99 probe throws if file absent after SUT
- No `Task.Run` in probe body
Rubric (graded):
- Config uses `[Required] public bool? ExpectedExists` (nullable bool, not non-nullable) (4 pts)
- Probe uses `File.Exists` synchronously and throws `InvalidOperationException` on mismatch (3 pts)
- Descriptive exception message includes file path and expected vs actual (3 pts)
Solution sketch: `FileExistenceProbe : BaseProbe<FileProbeConfig>`; `Run` checks `File.Exists(Configuration!.FilePath!)` vs `Configuration.ExpectedExists!.Value`; throws descriptive exception on mismatch.

### H-108: Seeded Deterministic Pseudo-Random Generator
Tier: T3
Goal: Author a `BaseGenerator<SeededRandConfig>` that produces a deterministic sequence of random integers given a fixed seed, reproducible across runs.
SUT:
- Runner project; config: `Seed` (int, required), `Count` (uint, required), `Min`/`Max` (int, required)
- Assertion verifies that two runs with same seed produce identical first output value
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (Configuration null in ctor — cannot init `Random` with seed in ctor), s13#12 (config typo)
Hard because:
- `new Random(seed)` must happen inside `Generate` (not ctor) because Configuration is null in ctor
- `Random` is not thread-safe — new instance per `Generate` call is correct (stateless)
- `uint? Count` with `[Required]`; loop must use `.Value` after null-check via `!`
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IGenerator hook instance SeededRandomGenerator`
- Two runs with `Seed=42` produce same first `{"value": N}` body
- Different seed produces different first value
Rubric (graded):
- `new Random((int)Configuration!.Seed!.Value)` inside `Generate`, not ctor (4 pts)
- Config record `[Required]` on all four fields (3 pts)
- Yields exactly `Count` items; values in `[Min, Max)` (3 pts)
Solution sketch: `SeededRandomGenerator : BaseGenerator<SeededRandConfig>`; `Generate` creates `var rng = new Random((int)Configuration!.Seed!.Value)`; loops Count times yielding `new Data<object>(new { value = rng.Next(Min, Max) })`.

### H-109: Numeric Sum Invariant Assertion
Tier: T3
Goal: Author a `BaseAssertion<SumConfig>` that verifies the sum of a specified decimal field across all outputs equals a configured expected total.
SUT:
- Runner project; multi-output session; outputs are JSON with `amount` field
- Config: `FieldName` (string, required), `ExpectedSum` (decimal, required as `decimal?`)
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s13#6 (null output → broken), s13#13 (zero-output vacuous pass), s13#12 (config typo)
Hard because:
- Decimal config field: `[Required] public decimal? ExpectedSum` — using `double` loses precision
- Must sum across all `SessionData` entries; wrong to sum only within single session
- Floating-point tolerance: for decimal fields should use exact equality after `decimal.Parse`
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IAssertion hook instance SumAssertion`
- 3 outputs with amounts 10.5, 20.25, 19.25 and ExpectedSum 50.0 → passes
- With amounts summing to 49.9: assertion fails with `AssertionMessage` showing actual vs expected
Rubric (graded):
- `decimal?` config field with `[Required]`; decimal arithmetic not double (4 pts)
- Iterates all sessionDataList outputs; accumulates sum correctly (3 pts)
- `AssertionMessage` reports actual sum vs expected sum (3 pts)
Solution sketch: `SumAssertion : BaseAssertion<SumConfig>`; loop sessionDataList; parse `FieldName` field as `decimal`; accumulate; compare to `Configuration!.ExpectedSum!.Value`; set message; return bool.

### H-110: Config Record with Enum Field Validation
Tier: T3
Goal: Author a `BaseGenerator<EnumConfig>` where the config record contains an enum field (`OutputFormat`) that controls whether output is JSON or CSV-style, demonstrating enum validation in config records.
SUT:
- Runner project; config: `OutputFormat` (enum `FormatKind`, required as `FormatKind?`), `Count` (uint, required)
- Assertion verifies output body matches selected format
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (config record must be `record` type; enum as nullable + [Required]), s13#12 (typo in enum value silently yields default)
Hard because:
- Enum config field: `[Required] public FormatKind? OutputFormat` — non-nullable enum without [Required] silently defaults to 0
- `FormatKind` must be defined in same file or namespace; cannot reference non-existent SDK enum
- YAML must spell enum value exactly: `OutputFormat: Json` not `OutputFormat: JSON`
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IGenerator hook instance FormatAwareGenerator`
- With `OutputFormat: Json`: output bodies are valid JSON objects
- With `OutputFormat: Csv`: output bodies are comma-separated strings
Rubric (graded):
- Enum `FormatKind` defined in same project; config field is `[Required] public FormatKind? OutputFormat` (4 pts)
- Generator branches on `Configuration!.OutputFormat!.Value` (3 pts)
- YAML uses exact enum name spelling matching C# enum member (3 pts)
Solution sketch: Define `public enum FormatKind { Json, Csv }`; `EnumConfig record` with `[Required] public FormatKind? OutputFormat`; `Generate` switches on value to produce `JsonSerializer.Serialize(obj)` or `string.Join(",", values)`.

### H-111: Sliding-Window Generator (Last N Elements)
Tier: T4
Goal: Author a `BaseGenerator<WindowConfig>` that reads a DataSource list, partitions it into overlapping windows of size N with stride 1, and yields each window as a JSON array payload.
SUT:
- Runner project; DataSource JSON array of ≥10 items; config: `WindowSize` (uint, required), `DataSourceName` (string, required)
- Output count = max(0, len(items) - WindowSize + 1)
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s13#3 (DataSourceNames REQUIRED in YAML), s13#12 (config typo silently ignored), s04 (Configuration null in ctor)
Hard because:
- Must compute window bounds correctly; off-by-one produces wrong count or IndexOutOfRange
- DataSource read via `GetDataSourceByName`; must deserialize to `JsonElement[]`
- Yielding `List<JsonElement>` slices as `Data<object>` — serialization must produce valid JSON arrays
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IGenerator hook instance SlidingWindowGenerator`
- 10-element source + WindowSize=3 → exactly 8 outputs
- Each output body is a JSON array of length 3
Rubric (graded):
- Window bounds: `for i in 0..(len-WindowSize)` inclusive producing correct count (4 pts)
- DataSource accessed via `GetDataSourceByName`; deserialize to `JsonElement[]` (3 pts)
- Each yield wraps a `List<JsonElement>` slice correctly serialized (3 pts)
Solution sketch: `SlidingWindowGenerator : BaseGenerator<WindowConfig>`; `Generate` reads source array; outer loop `i=0; i<=items.Length - windowSize; i++`; yields `new Data<object>(items.Skip(i).Take(windowSize).ToList())`.

### H-112: JSON Schema Shape-Validating Assertion
Tier: T4
Goal: Author a `BaseAssertion<SchemaConfig>` that validates each output JSON body conforms to a required-fields list and expected field types (string/number/bool/array/object) without any third-party library.
SUT:
- Runner project; config: `RequiredFields` (list of `FieldSpec` with `Name` and `Type`), no external NuGet
- Assertion fails and sets AssertionTrace listing each schema violation
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (nested record — FieldSpec must also be a record with [Required]), s13#12 (config key typo silently ignored)
Hard because:
- Nested config: `SchemaConfig` contains `[Required] public List<FieldSpec>? Fields` where `FieldSpec` is itself a record
- Type checking via `JsonElement.ValueKind`; mapping string names ("string","number") to `JsonValueKind` enum values
- Must collect ALL violations before returning, not short-circuit on first failure
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IAssertion hook instance SchemaAssertion`
- Output missing required field: assertion fails, trace lists missing field name
- Output with wrong field type: trace lists type mismatch with expected vs actual ValueKind
Rubric (graded):
- `FieldSpec` is a nested `record` with `[Required]` on both `Name` and `Type` (4 pts)
- All violations collected into `AssertionTrace` before returning false (3 pts)
- `JsonValueKind` comparison for type validation — no third-party schema library (3 pts)
Solution sketch: Define `public record FieldSpec { [Required] public string? Name; [Required] public string? Type; }`; `SchemaAssertion.Assert` iterates Fields; for each checks `body.TryGetProperty(name, out var el)` and `el.ValueKind` match; aggregates failures.

### H-113: HMAC Signature Chain Generator
Tier: T4
Goal: Author a `BaseGenerator<HmacChainConfig>` that yields N payloads where each payload's `sig` field is the HMAC-SHA256 of the prior payload's body, seeding the chain with a configured secret.
SUT:
- Runner project; config: `Secret` (string, required), `Count` (uint, required), `PayloadTemplate` (string, required)
- Assertion verifies chain integrity: each sig = HMAC(prior body, secret)
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (Configuration null in ctor — cannot init HMACSHA256 in ctor), s13#12 (config typo)
Hard because:
- Must track `previousBodyBytes` across iterations within `Generate` method
- HMACSHA256 is `IDisposable`; create per-item or cache correctly
- First item has no predecessor — define seed as `HMAC(secret, Encoding.UTF8.GetBytes(secret))`
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IGenerator hook instance HmacChainGenerator`
- Output[1].sig == HMAC-SHA256(Output[0].body, secret) — verifiable with known secret
- Output[0].sig == HMAC-SHA256(secret_bytes, secret) (bootstrap)
Rubric (graded):
- No HMACSHA256 instantiation in ctor; created inside `Generate` (4 pts)
- Chain correctly threads `previousBodyBytes` from prior yield (3 pts)
- Base64-encoded sig stored in payload; same encoding used by verifying assertion (3 pts)
Solution sketch: `HmacChainGenerator : BaseGenerator<HmacChainConfig>`; `Generate` initialises `prevBytes = Encoding.UTF8.GetBytes(Configuration!.Secret!)`; loops Count; computes sig via `new HMACSHA256(keyBytes).ComputeHash(prevBytes)`; yields `{body=template, sig=Convert.ToBase64String(hash)}`; sets `prevBytes` to body bytes.

### H-114: Input-to-Output Field Cross-Correlation Assertion
Tier: T4
Goal: Author a `BaseAssertion<CrossFieldConfig>` that for each transaction verifies a set of specified input JSON fields appear verbatim in the output response JSON.
SUT:
- Runner project; single transaction session; SUT echoes subset of input fields in response
- Config: `FieldNames` (List<string>, required) listing fields that must be echoed
MOCK_REQUIRED: no — real SUT or mocker can echo; mocker not needed for hook authoring test
FB slices: s04, s13
Trap mines: s13#6 (null output → broken), s13#12 (config FieldNames typo gives empty list silently)
Hard because:
- Must extract input body from `SessionData` as well as output body — both via `CastCommunicationData<JsonElement>()`
- Need to distinguish input and output within a `SessionData`; input = `sessionData.Input`, output = `sessionData.Outputs`
- Field value comparison must use `JsonElement.ToString()` for structural equality, not reference equality
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IAssertion hook instance CrossFieldAssertion`
- SUT echoes all config fields: assertion passes
- SUT omits one field: assertion fails, `AssertionTrace` names missing field
Rubric (graded):
- Correctly accesses both Input and Output from SessionData object model (4 pts)
- Uses `JsonElement.ToString()` or equivalent for value comparison (3 pts)
- `FieldNames` config: `[Required] public List<string>? FieldNames` on record (3 pts)
Solution sketch: `CrossFieldAssertion : BaseAssertion<CrossFieldConfig>`; in `Assert` for each session call `.AsSingle()` to get SessionData; extract input JsonElement and output JsonElement; foreach FieldName check `inputEl.GetProperty(f).ToString() == outputEl.GetProperty(f).ToString()`; accumulate failures.

### H-115: Mocker Decrypt-Mutate-Resign Processor Chain
Tier: T4
Goal: Author a `BaseTransactionProcessor<CryptoChainConfig>` (mocker hook) that XOR-decodes the request body, mutates a JSON field, then XOR-re-encodes the response.
SUT:
- Mocker project referencing `QaaS.Mocker 2.4.1`; processor named `XorMutateProcessor` in mocker YAML
- Config: `XorKey` (byte, required as `byte?`), `MutateField` (string, required), `MutateValue` (string, required)
MOCK_REQUIRED: yes — processor lives in mocker project only
FB slices: s04, s13
Trap mines: s13#1 (mocker stub config key is `ProcessorConfiguration:` not `TransactionData:`), s13#8 (BaseTransactionProcessor needs QaaS.Mocker ref), s13#9 (Mocker version is 2.4.1 not 4.5.1)
Hard because:
- `BaseTransactionProcessor<T>` resolves ONLY from `QaaS.Mocker`; runner-only project → CS0246
- Processor instances are shared across requests → no mutable instance state; XorKey read from Configuration per-request
- `Process` must return `Data<object>` wrapping mutated + re-encoded body; original `requestData` must not be mutated
Verify (mechanical):
- `dotnet build` exit 0 (mocker project)
- Mocker log: `Found ITransactionProcessor hook instance XorMutateProcessor`
- Request with XOR-encoded body: response body has MutateField set to MutateValue, re-encoded
- Two concurrent requests produce independent correct results (statelessness)
Rubric (graded):
- Project references `QaaS.Mocker 2.4.1`; no `QaaS.Runner` ref (3 pts)
- Processor is stateless; XorKey read from `Configuration!.XorKey!.Value` per call (4 pts)
- `ProcessorConfiguration:` key used in mocker YAML stub (3 pts)
Solution sketch: `XorMutateProcessor : BaseTransactionProcessor<CryptoChainConfig>`; `Process` XOR-decodes `requestData.Body` bytes with key; parses JSON; sets field; re-encodes; returns `new Data<object>(reencoded)`.

### H-116: CSV File Data-Source Generator
Tier: T4
Goal: Author a `BaseGenerator<CsvSourceConfig>` that reads a CSV DataSource file (first line = headers) and yields each data row as a JSON object keyed by the headers.
SUT:
- Runner project; YAML declares DataSource pointing to `.csv` file; generator yields one object per row
- Config: `DataSourceName` (string, required), `Delimiter` (string, default `,`)
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s13#3 (DataSourceNames REQUIRED in YAML), s04 (Configuration null in ctor)
Hard because:
- CSV DataSource arrives as raw string; must split on newlines and delimiter without third-party library
- Must handle quoted fields containing the delimiter character (basic RFC 4180 escaping)
- Empty trailing rows (blank last line) must be skipped to avoid empty JSON objects
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IGenerator hook instance CsvFileGenerator`
- 3-row CSV with headers `id,name` → 3 outputs each with `{"id":"...","name":"..."}`
- CSV with quoted field `"Smith, Jr."` → field value is `Smith, Jr.` (no extra quotes)
Rubric (graded):
- Header parsing + per-row object construction correct for unquoted fields (4 pts)
- Skips blank/empty trailing rows (3 pts)
- DataSource name from config with `[Required]`; `Delimiter` defaults to `,` (3 pts)
Solution sketch: `CsvFileGenerator : BaseGenerator<CsvSourceConfig>`; `Generate` reads DataSource string; splits on `\n`; first line = headers; foreach remaining non-empty line split by `Delimiter`; zip headers with values into `Dictionary<string,string>`; yield `new Data<object>(dict)`.

### H-117: UTF-8 BOM Encoding Pitfall in File-Reading Generator
Tier: T4
Goal: Author a `BaseGenerator<BomAwareConfig>` that reads a JSON DataSource file and demonstrates the UTF-8 BOM pitfall: a BOM-prefixed file causes `JsonSerializer.Deserialize` to throw unless BOM is stripped.
SUT:
- Runner project; test supplies both a BOM-prefixed and a clean JSON file as DataSources
- Generator config: `DataSourceName` (string, required), `StripBom` (bool, default true)
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (config null in ctor), s13#12 (StripBom config key typo → silently false → BOM not stripped → JsonException)
Hard because:
- BOM bytes (`0xEF 0xBB 0xBF`) are invisible in most editors but cause JSON parse failure
- Must detect BOM via `string.StartsWith("\uFEFF")` and strip with `TrimStart('\uFEFF')`
- `StripBom` is optional bool; default `true` via property initializer on record
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IGenerator hook instance BomAwareJsonGenerator`
- BOM-prefixed file + `StripBom: true` → generator yields items successfully
- BOM-prefixed file + `StripBom: false` → `JsonException` thrown, session marked Broken
Rubric (graded):
- BOM detection via `\uFEFF` prefix check; `TrimStart('\uFEFF')` applied when `StripBom` true (4 pts)
- Config: `[Required] public string? DataSourceName`; `public bool StripBom { get; set; } = true` (3 pts)
- When `StripBom=false` and BOM present, exception propagates naturally (no swallow) (3 pts)
Solution sketch: `BomAwareJsonGenerator : BaseGenerator<BomAwareConfig>`; read DataSource raw string; if `StripBom && raw.StartsWith("\uFEFF")` call `raw = raw.TrimStart('\uFEFF')`; `JsonSerializer.Deserialize<JsonElement[]>(raw)`; yield each element.

### H-118: Decimal Rounding Integrity Assertion
Tier: T4
Goal: Author a `BaseAssertion<RoundingConfig>` that verifies each output's specified decimal field is rounded to exactly N decimal places with banker's rounding (MidpointRounding.ToEven).
SUT:
- Runner project; SUT produces JSON responses with a `price` field; config: `FieldName` (string, required), `DecimalPlaces` (uint, required)
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s13#12 (config typo on DecimalPlaces → silently 0 → assertion vacuously passes for integer outputs), s04 (Configuration null in ctor)
Hard because:
- Must parse field as `decimal` not `double` to preserve precision
- `Math.Round(value, places, MidpointRounding.ToEven) == value` is the check — no tolerance band
- `JsonElement.GetDecimal()` throws if value is not a JSON number; must handle gracefully
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IAssertion hook instance DecimalRoundingAssertion`
- Output with `price: 2.345` and `DecimalPlaces: 2` → fails (2.345 rounds to 2.34 ≠ 2.345)
- Output with `price: 2.34` and `DecimalPlaces: 2` → passes
Rubric (graded):
- `JsonElement.GetDecimal()` used; `decimal` arithmetic throughout (4 pts)
- `Math.Round(val, places, MidpointRounding.ToEven) == val` comparison (3 pts)
- Non-numeric field sets `AssertionStatus = Broken` + descriptive message (3 pts)
Solution sketch: `DecimalRoundingAssertion : BaseAssertion<RoundingConfig>`; for each output `GetProperty(FieldName).GetDecimal()` → round with `MidpointRounding.ToEven` → compare; accumulate violations; return bool.

### H-119: Ordering Invariant Assertion Across Multiple Outputs
Tier: T4
Goal: Author a `BaseAssertion<OrderingConfig>` that verifies a specified numeric/string field in all outputs is strictly monotonically increasing (or decreasing per config).
SUT:
- Runner project; multi-output session; SUT returns items with `sequenceNumber` field
- Config: `FieldName` (string, required), `Ascending` (bool, required as `bool?`)
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s13#13 (zero outputs pass vacuously — must have count guard), s13#6 (null output → broken)
Hard because:
- Must iterate ALL outputs in order; compare adjacent pairs
- Field may be string (lexicographic) or number; must handle both via `JsonValueKind` check
- Boolean config `bool?` with `[Required]`; default direction is ambiguous — must be explicit
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IAssertion hook instance OrderingAssertion`
- Outputs [1,2,3] with `Ascending: true` → passes
- Outputs [1,3,2] → fails, trace names position of violation (index 2)
Rubric (graded):
- Adjacent-pair comparison loop covers all N-1 pairs (4 pts)
- String vs number branch via `JsonValueKind`; correct comparison in each branch (3 pts)
- `AssertionTrace` names the violation index (3 pts)
Solution sketch: `OrderingAssertion : BaseAssertion<OrderingConfig>`; extract all FieldName values as `JsonElement` list; loop adjacent pairs; compare by ValueKind-appropriate comparator; set trace on violation; return false.

### H-120: Idempotency Probe Verifying Deterministic Re-execution
Tier: T4
Goal: Author a `BaseProbe<IdempotencyProbeConfig>` that computes a hash of all output bodies after Stage 1, stores it in a static field, and at Stage 99 verifies the hash matches (same run = same outputs).
SUT:
- Runner project; probe at Stage 1 (capture) and Stage 99 (verify); config: `OutputName` (string, required)
- Tests that SUT produces identical results when called twice within same session
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (probe must be synchronous, no Task.Run; static field is NOT per-request mutable state — it is capture+verify pattern), s13#12 (config key typo)
Hard because:
- Static field shared across two probe invocations in same process; must be thread-safe if parallelism
- Must distinguish capture stage from verify stage; use a second config bool `CaptureMode` (required)
- SHA256 hash over serialized output bodies; must use stable serialization (sorted keys or fixed order)
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IProbe hook instance IdempotencyProbe` (appears at both stages)
- Stage 1 (Capture): hash stored, no exception
- Stage 99 (Verify): hash matches → no exception; hash differs → throws with diff detail
Rubric (graded):
- Static field `_capturedHash` protected by `lock` for thread safety (4 pts)
- `CaptureMode` bool config field `[Required] public bool?`; stage 1 vs 99 YAML configs differ only in this field (3 pts)
- SHA256 computed via `SHA256.HashData(Encoding.UTF8.GetBytes(stableJson))` (3 pts)
Solution sketch: `IdempotencyProbe : BaseProbe<IdempotencyProbeConfig>`; static `string? _capturedHash` + lock object; `Run` collects outputs, serializes, SHA256-hashes; if `CaptureMode` stores hash; else compares and throws on mismatch.

### H-121: Culture-Invariant String Comparison Pitfall (tr-TR Casing)
Tier: T4
Goal: Author a `BaseAssertion<CultureConfig>` that verifies a string field equals an expected value using `StringComparison.OrdinalIgnoreCase`, demonstrating the tr-TR "dotless i" pitfall when using `ToLower()` or `CurrentCulture`.
SUT:
- Runner project; SUT returns JSON with a field that may contain "I" or "İ" characters
- Config: `FieldName` (string, required), `ExpectedValue` (string, required)
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (config null in ctor), s13#12 (config key typo silently ignored)
Hard because:
- `String.Equals(a, b, StringComparison.CurrentCultureIgnoreCase)` on tr-TR system maps "I"→"ı" (dotless i), breaking equality
- Must use `StringComparison.OrdinalIgnoreCase` for consistent cross-culture behavior
- Config record must specify `[Required]` on `ExpectedValue`; empty string must be distinguishable from null
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IAssertion hook instance CultureSafeStringAssertion`
- `"INFORMATION" == "information"` with OrdinalIgnoreCase → passes on any culture
- Same comparison with CurrentCultureIgnoreCase on tr-TR → would fail (demonstrates trap)
Rubric (graded):
- `String.Equals(..., StringComparison.OrdinalIgnoreCase)` used exclusively (4 pts)
- `AssertionTrace` includes culture-trap warning note in failure message (3 pts)
- Config `[Required] public string? ExpectedValue` — nullable + Required (3 pts)
Solution sketch: `CultureSafeStringAssertion : BaseAssertion<CultureConfig>`; extract field; `String.Equals(actual, Configuration!.ExpectedValue!, StringComparison.OrdinalIgnoreCase)`; set AssertionMessage noting OrdinalIgnoreCase was used; return bool.

### H-122: Coexisting Generator + Assertion + Probe in One Project Without DI Conflicts
Tier: T4
Goal: Author three hook classes (`MultiGenerator`, `MultiAssertion`, `MultiProbe`) in a single Runner project without any dependency-injection registration conflicts, verifying all three are discovered.
SUT:
- Runner project; single `.csproj` file; three hook `.cs` files; YAML session uses all three
- No shared state between hooks; each uses `object` as TConfiguration
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (discovery is assembly-scanning — all three discovered automatically; no DI registration needed), s13#8 (FTL if any hook's assembly not in AppDomain)
Hard because:
- Temptation to add a DI container — not needed; SDK discovers by reflection, not DI
- All three must compile independently; shared `using` block must cover all needed namespaces
- `object` TConfiguration requires NO config block in YAML — absence of config must not crash
Verify (mechanical):
- `dotnet build` exit 0
- Runner log contains all three: `Found IGenerator hook instance MultiGenerator`, `Found IAssertion...`, `Found IProbe...`
- YAML session runs without `FTL` or DI exception
- No `NoConfiguration` type used anywhere (CS0246)
Rubric (graded):
- Three separate classes each using `object` as TConfiguration, no DI registration (4 pts)
- All three discovered in single run log (3 pts)
- No `NoConfiguration` reference; `object` used correctly (3 pts)
Solution sketch: Three files in same project: `MultiGenerator : BaseGenerator<object>`, `MultiAssertion : BaseAssertion<object>`, `MultiProbe : BaseProbe<object>`; YAML references each by simple class name; no service registration.

### H-123: Process-Existence Synchronous Probe
Tier: T4
Goal: Author a `BaseProbe<ProcessProbeConfig>` that synchronously checks whether a named process is running, failing fast if the SUT process is absent before the test begins.
SUT:
- Runner project; probe at Stage 0; config: `ProcessName` (string, required), `MustExist` (bool, required as `bool?`)
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (synchronous probe — no Task.Run; Process.GetProcessesByName is synchronous), s13#12 (config typo)
Hard because:
- `Process.GetProcessesByName(name)` returns empty array if process absent — must check `.Length > 0`
- Process name on Windows excludes `.exe` extension; on Linux includes path — cross-platform ambiguity
- Probe must dispose `Process` objects after check to avoid handle leaks
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IProbe hook instance ProcessExistenceProbe`
- With running dotnet process and `MustExist: true` → probe passes silently
- With non-existent process name and `MustExist: true` → probe throws
Rubric (graded):
- `Process.GetProcessesByName` used synchronously; no Task.Run (4 pts)
- Each `Process` in result array disposed via `foreach` + `Dispose()` (3 pts)
- Throws `InvalidOperationException` with process name in message on mismatch (3 pts)
Solution sketch: `ProcessExistenceProbe : BaseProbe<ProcessProbeConfig>`; `Run` calls `Process.GetProcessesByName(Configuration!.ProcessName!)`; foreach `p` calls `p.Dispose()`; if count/MustExist mismatch throws.

### H-124: Large-Payload Generator (Configurable Size)
Tier: T4
Goal: Author a `BaseGenerator<LargePayloadConfig>` that yields a single JSON object with a `data` field containing a string of exactly `SizeKb * 1024` characters, testing large-payload handling.
SUT:
- Runner project; config: `SizeKb` (uint, required), `FillChar` (string, default `"A"`)
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (Configuration null in ctor — cannot pre-allocate in ctor), s13#12 (config key typo → SizeKb = 0 → empty payload, silently passes)
Hard because:
- Must not allocate `FillChar * SizeKb * 1024` in the constructor (Configuration is null)
- String allocation of 1024KB+ may be slow; use `new string(char, count)` not StringBuilder for simplicity
- FillChar config is a single-char string; must validate `.Length == 1` at runtime
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IGenerator hook instance LargePayloadGenerator`
- `SizeKb: 512` → yielded body's `data` field has length exactly 524288
- `SizeKb: 0` → yields one output with empty `data` string (not crash)
Rubric (graded):
- All allocation inside `Generate` after `Configuration!` access (not ctor) (4 pts)
- FillChar validation throws `InvalidOperationException` if `Length != 1` (3 pts)
- Correct byte-count: `SizeKb * 1024` characters (3 pts)
Solution sketch: `LargePayloadGenerator : BaseGenerator<LargePayloadConfig>`; `Generate` reads `SizeKb`/`FillChar` from Configuration; validates FillChar length; yields `new Data<object>(new { data = new string(FillChar[0], (int)(SizeKb * 1024)) })`.

### H-125: Config Record with Nested Required Object
Tier: T4
Goal: Author a `BaseGenerator<NestedConfig>` where the config record contains a required nested sub-record (`PaginationOptions` with `PageSize` and `PageCount`), demonstrating nested record validation.
SUT:
- Runner project; generator yields `PageCount` batches of `PageSize` items
- Config: top-level `[Required] public PaginationOptions? Pagination`; `PaginationOptions` is itself a record
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (nested record must also use C# `record` keyword with [Required] fields), s13#12 (typo in `Pagination` key → null Pagination → NullReferenceException in Generate)
Hard because:
- Nested `PaginationOptions` record fields must also use `[Required]` + nullable types
- When YAML omits `Pagination:` block entirely, `Pagination` is null; `Configuration!.Pagination!.PageSize` throws NRE
- Should validate `Pagination != null` in `Generate` and throw descriptive error
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IGenerator hook instance PaginatedGenerator`
- With `PageSize: 5, PageCount: 3` → 15 total items yielded in 3 groups
- Missing `Pagination:` YAML key → `Generate` throws with message naming the missing field
Rubric (graded):
- `PaginationOptions` is a `record` with `[Required] public uint? PageSize` and `[Required] public uint? PageCount` (4 pts)
- Null-check on `Configuration!.Pagination` with descriptive exception (3 pts)
- Yields `PageCount * PageSize` items total (3 pts)
Solution sketch: `public record PaginationOptions { [Required] public uint? PageSize; [Required] public uint? PageCount; }`; `NestedConfig record` with `[Required] public PaginationOptions? Pagination`; `Generate` validates non-null then double-loops.

### H-126: Stateful Generator with Per-Session Sequence Reset
Tier: T4
Goal: Author a `BaseGenerator<SeqResetConfig>` that uses a `static` counter but resets it at the START of each `Generate` call (not between sessions), ensuring sequence starts at `StartValue` every run.
SUT:
- Runner project; config: `StartValue` (uint, required), `Count` (uint, required)
- Demonstrates correct use of in-method local state vs shared static state
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (processors stateless — generators CAN use local state within Generate; shared static state is a trap for generators too if misused), s13#12 (config typo silently yields wrong start)
Hard because:
- Temptation to use `static int _counter` that persists across runs → second test run starts from wrong value
- Correct solution: local `int counter = (int)Configuration!.StartValue!.Value` inside `Generate`
- If static is used, must reset at entry of `Generate` — but then it is equivalent to local variable
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IGenerator hook instance ResettingSequenceGenerator`
- Run 1: outputs start at StartValue; Run 2 (same config): outputs also start at StartValue
- No carryover from run 1 to run 2
Rubric (graded):
- Counter is a local variable inside `Generate`, not static (4 pts)
- Explicit justification in comment: "local variable ensures per-call reset" (2 pts)
- Yields exactly `Count` sequential values starting at `StartValue` (4 pts)
Solution sketch: `ResettingSequenceGenerator : BaseGenerator<SeqResetConfig>`; `Generate` declares `var seq = (int)Configuration!.StartValue!.Value`; loop `Count` times; yield `{id = seq++}`.

### H-127: Request-to-Response Field Mirror Assertion
Tier: T4
Goal: Author a `BaseAssertion<MirrorConfig>` that verifies each output body contains an `echo` field whose value is a JSON-serialized subset of the original request body fields.
SUT:
- Runner project; SUT echoes selected request fields under `echo` key in response
- Config: `EchoFields` (List<string>, required); `EchoKey` (string, default `"echo"`)
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s13#6 (null output → broken), s13#12 (EchoFields typo → empty list → assertion passes vacuously)
Hard because:
- Must navigate into nested `echo` object inside output JSON, not top-level fields
- `JsonElement` navigation: `outputEl.GetProperty("echo").GetProperty(field)` — must handle missing `echo` key gracefully
- Empty `EchoFields` list after config deserialization is a silent bug; should warn if list is empty
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IAssertion hook instance MirrorFieldAssertion`
- SUT echoes all configured fields → passes
- SUT omits one echo field → fails, `AssertionTrace` names missing field + expected value
Rubric (graded):
- Navigates into nested `EchoKey` object in output JSON (4 pts)
- Handles missing `echo` key by setting `AssertionStatus = Broken` (3 pts)
- `EchoFields` is `[Required] public List<string>?`; non-empty validated at runtime (3 pts)
Solution sketch: `MirrorFieldAssertion : BaseAssertion<MirrorConfig>`; extract output body; `outputEl.TryGetProperty(EchoKey, out var echoEl)` → Broken if absent; foreach field check `inputEl.GetProperty(f) == echoEl.GetProperty(f)` toString.

### H-128: Processor with Static HttpClient for External Enrichment
Tier: T4
Goal: Author a `BaseTransactionProcessor<EnrichConfig>` (mocker hook) that calls an external enrichment endpoint via a `static HttpClient`, demonstrating correct stateless processor design with shared client.
SUT:
- Mocker project; processor enriches mock response with data from an auxiliary HTTP endpoint
- Config: `EnrichmentUrl` (string, required), `FieldToAdd` (string, required)
MOCK_REQUIRED: yes — this IS the mocker hook; mocker project required
FB slices: s04, s13
Trap mines: s04 (processor instances shared → static HttpClient correct; per-request new HttpClient → socket exhaustion), s13#1 (ProcessorConfiguration: key in mocker YAML), s13#9 (Mocker 2.4.1)
Hard because:
- `static HttpClient` must be initialized with field initializer, not in ctor (Configuration null in ctor)
- `Process` method must be synchronous void-return chain: `GetAsync(...).GetAwaiter().GetResult()` — acceptable for mocker processor
- Must not store per-request data in instance fields (only Configuration and static client)
Verify (mechanical):
- `dotnet build` exit 0 (mocker project)
- Mocker log: `Found ITransactionProcessor hook instance EnrichmentProcessor`
- `static readonly HttpClient _http` present in class; no `new HttpClient()` inside `Process`
- Two concurrent requests each get correctly enriched (no shared mutable state)
Rubric (graded):
- `static readonly HttpClient _http = new()` at class level (4 pts)
- `Process` calls `_http.GetAsync(...).GetAwaiter().GetResult()` — no instance-level state (3 pts)
- `ProcessorConfiguration:` used in mocker stub YAML (3 pts)
Solution sketch: `EnrichmentProcessor : BaseTransactionProcessor<EnrichConfig>`; `static readonly HttpClient _http = new()`; `Process` calls `_http.GetAsync(Configuration!.EnrichmentUrl!).GetAwaiter().GetResult()`; parses response; adds `FieldToAdd` to request body; returns new Data.

### H-129: Post-Session File Cleanup Probe
Tier: T4
Goal: Author a `BaseProbe<CleanupProbeConfig>` that at Stage 99 deletes a specified file created by the SUT and verifies deletion succeeded, ensuring test isolation.
SUT:
- Runner project; probe at Stage 99; config: `FilePath` (string, required), `FailIfAlreadyAbsent` (bool, default false)
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (probe synchronous; `File.Delete` is synchronous — correct), s13#12 (config key typo → FilePath null → NRE)
Hard because:
- `File.Delete` silently succeeds if file is already absent on Windows; must check pre-deletion existence if `FailIfAlreadyAbsent`
- Probe should verify deletion: `File.Exists` after `Delete` must return false; if not, throw
- Config `FailIfAlreadyAbsent` bool with property initializer default `false`; non-nullable bool is fine here (no [Required])
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IProbe hook instance CleanupProbe`
- File present at Stage 99 → deleted; subsequent `File.Exists` returns false
- File absent and `FailIfAlreadyAbsent: false` → probe silently passes
- File absent and `FailIfAlreadyAbsent: true` → probe throws
Rubric (graded):
- `File.Delete` called synchronously; no Task.Run (4 pts)
- Post-deletion verification via `File.Exists` + throw on failure (3 pts)
- `FailIfAlreadyAbsent` non-[Required] bool with default `false` (3 pts)
Solution sketch: `CleanupProbe : BaseProbe<CleanupProbeConfig>`; `Run` checks `File.Exists(path)`; if absent and `FailIfAlreadyAbsent` throw; else `File.Delete(path)`; verify `!File.Exists(path)` after.

### H-130: Configurable Date-Range Timezone-Stable Timestamp Generator
Tier: T4
Goal: Author a `BaseGenerator<DateRangeConfig>` that yields N timestamps uniformly distributed between a configured UTC start and end date, ensuring all timestamps are in UTC regardless of server timezone.
SUT:
- Runner project; config: `StartUtc` (string, required ISO-8601), `EndUtc` (string, required), `Count` (uint, required)
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (Configuration null in ctor — cannot parse dates in ctor), s13#12 (config key typo → null → NRE on DateTimeOffset.Parse)
Hard because:
- `DateTimeOffset.Parse(StartUtc, null, DateTimeStyles.RoundtripKind)` must be used; `DateTime.Parse` loses timezone info
- Uniform distribution: `range / (Count - 1)` — edge case when Count == 1 (yield start only)
- All output timestamps must be formatted with `"O"` format ensuring `Z` suffix
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IGenerator hook instance DateRangeGenerator`
- `StartUtc: "2024-01-01T00:00:00Z"`, `EndUtc: "2024-12-31T00:00:00Z"`, `Count: 5` → 5 outputs, all ending in `Z`
- `Count: 1` → yields only the start timestamp, no divide-by-zero
Rubric (graded):
- `DateTimeOffset.Parse` with `DateTimeStyles.RoundtripKind` (4 pts)
- Count==1 edge case handled (yields start only) (3 pts)
- All output timestamps formatted with `"O"` round-trip format (3 pts)
Solution sketch: `DateRangeGenerator : BaseGenerator<DateRangeConfig>`; parse start/end to `DateTimeOffset` in `Generate`; `var step = (end - start) / Math.Max(1, Count - 1)`; loop Count; yield `{timestamp = (start + step*i).ToString("O")}`.

### H-131: HMAC Signature Chain Integrity Assertion (T5)
Tier: T5
Goal: Author a `BaseAssertion<HmacVerifyConfig>` that verifies a multi-output session where each output's `sig` field equals HMAC-SHA256 of the prior output's full body, breaking on any chain gap.
SUT:
- Runner project; generator (H-113 variant) produces N chained outputs; this assertion verifies the chain
- Config: `Secret` (string, required), `BodyField` (string, required), `SigField` (string, required)
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s13#13 (zero outputs vacuously pass — must count guard), s13#6 (null output → broken), s04 (HMACSHA256 IDisposable)
Hard because:
- Must replay the chain: compute expected sig for each output from prior output's serialized body bytes
- First output's expected sig = HMAC of secret bytes bootstrapped per generator contract
- Base64 decoding of `sig` field from JsonElement must use `Convert.FromBase64String`; URL-safe variants fail
- Mis-ordered outputs silently fail the chain — ordering matters absolutely
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IAssertion hook instance HmacChainAssertion`
- Correct 5-output chain → passes
- Output[2] sig tampered → fails, `AssertionTrace` names index 2 as the break point
- Zero outputs with no count guard → passes vacuously (demonstration of trap)
Rubric (graded):
- Chain replay logic correct including bootstrap of first sig (5 pts)
- Base64 decode via `Convert.FromBase64String`; `HMACSHA256` disposed after each use (3 pts)
- `AssertionTrace` pinpoints first violation index and shows expected vs actual base64 (2 pts)
Solution sketch: `HmacChainAssertion.Assert` iterates outputs in order; maintains `prevBodyBytes`; computes expected sig with `new HMACSHA256(secretBytes).ComputeHash(prevBytes)`; compares to actual sig field base64; first mismatch → set trace + return false.

### H-132: Full Processor Chain: Base64-Decode → Mutate JSON → HMAC Re-Sign (T5)
Tier: T5
Goal: Author a `BaseTransactionProcessor<SignedMutateConfig>` (mocker) that base64-decodes the request body, mutates a JSON field, recomputes HMAC-SHA256 over the new body, and returns the re-signed response.
SUT:
- Mocker project; processor receives base64-encoded JSON; returns base64-encoded JSON + updated `sig`
- Config: `HmacSecret` (string, required), `MutateField` (string, required), `MutateValue` (string, required)
MOCK_REQUIRED: yes — mocker project only
FB slices: s04, s13
Trap mines: s13#1 (`ProcessorConfiguration:` key), s13#7 (aspnet Dockerfile base), s13#9 (Mocker 2.4.1), s04 (stateless processor, static HttpClient not applicable here but static HMACSHA256 key bytes are safe as static readonly)
Hard because:
- Three-phase transform (decode → mutate → resign) must be completely stateless: all state derived from `Configuration` and `requestData` per call
- Base64 of JSON → `JsonDocument.Parse` → mutate → `JsonSerializer.Serialize` → base64 encode → HMAC
- `requestData.Body` type is `object` — must cast or serialize to `string` or `byte[]` correctly
Verify (mechanical):
- `dotnet build` exit 0 (mocker project)
- Mocker log: `Found ITransactionProcessor hook instance SignedMutateProcessor`
- Known-input base64 JSON → response body is base64 of mutated JSON with correct sig
- Two concurrent requests yield independent correct transforms
Rubric (graded):
- All three phases in `Process` body; no instance state (5 pts)
- `requestData.Body` correctly extracted as string or byte array (3 pts)
- Output sig = HMAC-SHA256(new body bytes, secret bytes) — not old body sig (2 pts)
Solution sketch: `SignedMutateProcessor.Process`: cast `requestData.Body` to string; `Convert.FromBase64String` → `JsonDocument.Parse`; serialize mutated doc to bytes; compute `HMACSHA256(secret).ComputeHash(bodyBytes)`; return `new Data<object>(Convert.ToBase64String(bodyBytes) + "." + Convert.ToBase64String(sig))`.

### H-133: Multi-Output Sum + Ordering + Uniqueness Combined Assertion (T5)
Tier: T5
Goal: Author a `BaseAssertion<ComboInvariantConfig>` that in a single `Assert` call verifies three invariants over all outputs: (1) a sum field totals to expected, (2) a sequence field is strictly ascending, (3) an ID field has no duplicates.
SUT:
- Runner project; config contains three sub-configs: `SumSpec`, `OrderingSpec`, `UniquenessSpec`, all required nested records
- All three invariants checked; all violations aggregated in `AssertionTrace` before return
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s13#13 (count guard essential — zero outputs pass all three vacuously), s13#6 (null output → broken), s04 (nested records all need [Required])
Hard because:
- Three nested required records in one config; YAML must provide all three sub-blocks
- All violations from all three checks must be collected before returning false (not short-circuit)
- Interaction: an output that fails uniqueness also contributes to sum — must handle partial bodies gracefully
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IAssertion hook instance ComboInvariantAssertion`
- Outputs violating all three → `AssertionTrace` lists all three violation types
- Outputs satisfying all three → passes
- Missing one sub-config block in YAML → `AssertionStatus = Broken` with config validation message
Rubric (graded):
- Three nested `record` specs each with `[Required]` fields; outer config validates all non-null (5 pts)
- All three checks run even if earlier check fails; violations aggregated (3 pts)
- `AssertionTrace` sections labeled per-invariant (2 pts)
Solution sketch: `ComboInvariantAssertion.Assert` runs SumCheck, OrderingCheck, UniquenessCheck as private methods; each appends to a `List<string> violations`; `AssertionTrace = string.Join("\n", violations)`; returns `violations.Count == 0`.

### H-134: Sliding-Window State Persisted via DataSource File (T5)
Tier: T5
Goal: Author a `BaseGenerator<PersistentWindowConfig>` that reads the current window position from a JSON state DataSource file, yields the next window, and overwrites the state file — demonstrating cross-run state persistence via DataSource.
SUT:
- Runner project; DataSource `state.json` stores `{"lastIndex": N}`; generator advances and persists index
- Config: `DataSourceName` (string, required), `SourceDataName` (string, required), `WindowSize` (uint, required)
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s13#3 (DataSourceNames required in YAML for both sources), s04 (Configuration null in ctor)
Hard because:
- Generator must read state DataSource, then read source DataSource, yield window, then write state back
- DataSource objects via `GetDataSourceByName` are read-only in the API; state write requires `File.WriteAllText` to the DataSource file path — must read path from DataSource metadata
- Concurrent runs would corrupt state; must document serialization assumption
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IGenerator hook instance PersistentWindowGenerator`
- Run 1: state starts at 0, yields items 0..WindowSize-1, state written as `{"lastIndex": WindowSize}`
- Run 2: state reads WindowSize, yields items WindowSize..2*WindowSize-1
Rubric (graded):
- State read from DataSource; file path extracted for write-back (4 pts)
- Window advance logic correct with bounds check (wraps at end of source) (3 pts)
- Concurrency caveat documented in code comment (3 pts)
Solution sketch: `PersistentWindowGenerator.Generate` reads state JSON via `GetDataSourceByName("state")`; parses `lastIndex`; reads source array; yields `items.Skip(lastIndex).Take(windowSize)`; writes new state JSON to same file path.

### H-135: CSV Generator with Culture-Invariant Decimal Parsing (T5)
Tier: T5
Goal: Author a `BaseGenerator<CsvDecimalConfig>` that reads a CSV DataSource with decimal fields and parses them with `CultureInfo.InvariantCulture`, demonstrating failure mode when `double.Parse` uses current culture on a comma-decimal locale.
SUT:
- Runner project; CSV file uses `.` as decimal separator; config: `DataSourceName`, `DecimalFields` (List<string>, required)
- Generator yields JSON with parsed decimal values; assertion verifies values match expected within tolerance
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (Configuration null in ctor), s13#12 (config key typo → DecimalFields empty → no parsing), s13#3 (DataSourceNames required)
Hard because:
- `decimal.Parse("1.5", CultureInfo.CurrentCulture)` on a de-DE system treats `.` as thousands separator → parses 15 or throws
- Must use `decimal.Parse(val, CultureInfo.InvariantCulture)` for every decimal field
- Must distinguish configured decimal fields from string fields; non-decimal fields left as strings
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IGenerator hook instance CsvDecimalGenerator`
- CSV `id,amount` with row `1,19.99` → output `{"id":"1","amount":19.99}` (decimal not string)
- Same CSV parsed with CurrentCulture on de-DE would yield 1999 — demonstrates need for InvariantCulture
Rubric (graded):
- `decimal.Parse(val, CultureInfo.InvariantCulture)` used for all DecimalFields (5 pts)
- Non-decimal columns remain as strings in output JSON (2 pts)
- ParseException handled → `AssertionStatus` not applicable here; generator throws with field name (3 pts)
Solution sketch: `CsvDecimalGenerator.Generate` reads CSV; for each row builds `Dictionary<string,object>`; for fields in `DecimalFields` parses with `decimal.Parse(val, CultureInfo.InvariantCulture)`; others are strings; yield `new Data<object>(dict)`.

### H-136: JSON Schema Assertion Without Third-Party Library (Deep Traversal) (T5)
Tier: T5
Goal: Author a `BaseAssertion<DeepSchemaConfig>` that validates output JSON against a schema expressed as a config record with recursive `FieldSpec` nodes (each having `Name`, `Type`, and optional `Children`).
SUT:
- Runner project; config: `RootFields` (List<FieldSpec>, required); `FieldSpec` has `Name`, `Type`, optional `Children: List<FieldSpec>`
- Validates nested JSON objects to arbitrary depth via recursive traversal
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (nested record list with [Required]; recursive records unusual — lists of records bind correctly via JSON deserialization), s13#12 (config typo on Children → null → NullReferenceException in recursion)
Hard because:
- `FieldSpec` record with `Children: List<FieldSpec>?` — recursive type, must bind from YAML correctly
- Recursive `Assert` helper traversal must guard against null `Children` gracefully
- MaxDepth guard needed to prevent infinite recursion on malformed config
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IAssertion hook instance DeepSchemaAssertion`
- Flat schema (no children) → validates top-level fields correctly
- Nested schema `address.city` (string) → traverses into nested object
- Config with null Children → handled gracefully (treated as leaf node)
Rubric (graded):
- Recursive `ValidateNode` private method with depth guard (5 pts)
- Null `Children` treated as leaf — no NRE (3 pts)
- All violations from all depths aggregated before returning false (2 pts)
Solution sketch: `DeepSchemaAssertion` with `ValidateNode(JsonElement el, List<FieldSpec> specs, List<string> errors, int depth)` recursing into `Object` elements when `Children` non-null; max depth 20.

### H-137: Processor with Nested Config Records and Enum Validation (T5)
Tier: T5
Goal: Author a `BaseTransactionProcessor<RoutingConfig>` (mocker) where the config contains a nested `RoutingRules` record with an enum `MatchMode` and a required `TargetField` — demonstrating multi-level config validation in a mocker hook.
SUT:
- Mocker project; processor routes mock response to different shapes based on MatchMode (Exact, Prefix, Regex)
- Config: `Rules: List<RoutingRule>` (required); each `RoutingRule` has `MatchMode` (enum, required), `Pattern` (string, required), `ResponseTemplate` (string, required)
MOCK_REQUIRED: yes
FB slices: s04, s13
Trap mines: s13#1 (`ProcessorConfiguration:` key), s13#9 (Mocker 2.4.1), s04 (nested records; processor stateless)
Hard because:
- `List<RoutingRule>` in config: each rule is a record; YAML `Rules:` is a list of objects — must bind correctly
- `MatchMode` enum in nested record: `[Required] public MatchMode? Mode`; YAML must spell enum exactly
- Processor stateless: `Regex` objects for Regex mode should be cached in `static` or created per-request (per-request is correct here for simplicity)
Verify (mechanical):
- `dotnet build` exit 0 (mocker project)
- Mocker log: `Found ITransactionProcessor hook instance RoutingProcessor`
- Request body matching `Exact` rule → response uses that rule's template
- No matching rule → returns original requestData unmodified (fallthrough)
Rubric (graded):
- `RoutingRule` is a `record` with `[Required] public MatchMode? Mode`, `[Required] public string? Pattern`, `[Required] public string? ResponseTemplate` (5 pts)
- Fallthrough (no match) returns `requestData` unchanged (2 pts)
- Processor stateless — no per-request instance fields (3 pts)
Solution sketch: `public enum MatchMode { Exact, Prefix, Regex }`; `RoutingProcessor.Process` iterates `Configuration!.Rules!`; for each rule matches `requestData.Body.ToString()` per `Mode`; first match → returns new Data with template; fallthrough → returns requestData.

### H-138: Three-Check Synchronous Probe (TCP + File + Process) (T5)
Tier: T5
Goal: Author a `BaseProbe<TripleCheckConfig>` that in a single synchronous `Run` performs a TCP reachability check, a file-existence check, and a process-existence check, accumulating all failures before throwing.
SUT:
- Runner project at Stage 0; config: `TcpHost`, `TcpPort`, `FilePath`, `ProcessName` (all string/uint, required)
- All three checks run regardless of earlier failure; single throw enumerates all failures
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (probe synchronous; no Task.Run; TcpClient.Connect is synchronous — correct), s13#16 (TCP port must match mocker binding port if used with mocker)
Hard because:
- All three checks must execute even if first fails — must accumulate to list
- TcpClient.Connect with timeout: use `ConnectAsync().Wait(TimeoutMs)` — careful this IS .Wait() not Task.Run
- Must dispose TcpClient whether or not connection succeeds
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IProbe hook instance TripleReadinessProbe`
- All three failing: single exception message lists all three failures
- Two of three failing: message names both
- All passing: no exception
Rubric (graded):
- All three checks run; failures accumulated in `List<string>` before single throw (5 pts)
- TcpClient disposed via `using` block (3 pts)
- Exception message clearly lists each failure with type label (2 pts)
Solution sketch: `TripleReadinessProbe.Run` uses `List<string> failures`; `using var tcp = new TcpClient()`; try `tcp.ConnectAsync(host, port).Wait(timeout)` catch add to failures; check `File.Exists`; check `Process.GetProcessesByName(...).Length`; if failures.Count > 0 throw `InvalidOperationException(string.Join("; ", failures))`.

### H-139: Idempotency Assertion: Two Runs Must Hash Identically (T5)
Tier: T5
Goal: Author a `BaseAssertion<IdemHashConfig>` that computes SHA256 of all output bodies on first call, stores in a static field, and on subsequent calls verifies the hash matches — proving SUT is idempotent across runs.
SUT:
- Runner project; YAML session with two identical transaction blocks; assertion used on both; second call must match first
- Config: `OutputName` (string, required), `SessionKey` (string, required — used to key the static storage)
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (static field — processor rule says stateless, but assertions MAY use static capture+verify; processors must not), s13#6 (null output → broken on either call), s13#13 (zero output → vacuous pass)
Hard because:
- Static dictionary keyed by `SessionKey` to support multiple concurrent test configs
- Thread-safe: `ConcurrentDictionary<string, string>` for hash storage
- First call: hash stored and assertion passes; second call: hash compared; mismatch = fail
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IAssertion hook instance IdempotencyHashAssertion`
- Run with identical SUT calls → second assertion passes
- SUT returns different body on second call → second assertion fails with hash diff in trace
Rubric (graded):
- `ConcurrentDictionary<string, string>` used for thread-safe hash storage (5 pts)
- First-call capture and second-call verify branches clearly separated (3 pts)
- `AssertionTrace` includes both expected and actual hash on mismatch (2 pts)
Solution sketch: `static readonly ConcurrentDictionary<string, string> _hashes = new()`; `Assert` computes SHA256 of joined output bodies; `_hashes.TryAdd(SessionKey, hash)` → first call; if `TryAdd` returns false compare existing; return equality.

### H-140: Large-Payload Assertion Verifying Fields Without OOM (T5)
Tier: T5
Goal: Author a `BaseAssertion<LargeBodyConfig>` that validates specific fields in a multi-megabyte JSON output without loading the entire body into a string — using `JsonDocument` streaming to avoid OOM on 10MB+ payloads.
SUT:
- Runner project; SUT returns JSON bodies up to 10MB; assertion checks 3 specific field values
- Config: `FieldAssertions` (List<FieldAssertion>, required); each with `FieldName` and `ExpectedValue`
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s13#6 (null output → broken), s04 (nested record [Required]), s13#12 (config typo → empty FieldAssertions → vacuous pass)
Hard because:
- `CastCommunicationData<JsonElement>()` already materializes the full body — cannot avoid full parse via SDK helpers
- To demonstrate streaming intent: must use `JsonDocument.Parse(Encoding.UTF8.GetBytes(rawBody))` and dispose after
- `JsonDocument` is `IDisposable`; must use `using` to prevent pinned LOH growth
- Large output body means `ToString()` on `JsonElement` body must be avoided; use `GetRawText()` for field values
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IAssertion hook instance LargeBodyAssertion`
- 5MB body with correct field values → passes
- 5MB body with one wrong field value → fails, trace names field and expected vs actual
- `JsonDocument` disposed via `using` in all code paths (no finally needed with using statement)
Rubric (graded):
- `JsonDocument` wrapped in `using` statement; no `.ToString()` on full document (5 pts)
- `FieldAssertion` nested record with `[Required]` on both fields (3 pts)
- `GetRawText()` used for field value comparison (2 pts)
Solution sketch: `LargeBodyAssertion.Assert` gets body bytes; `using var doc = JsonDocument.Parse(bytes)`; foreach `FieldAssertion` in config uses `doc.RootElement.GetProperty(f.FieldName).GetRawText()` vs `f.ExpectedValue`; accumulates violations.

### H-141: Four-Hook Coexistence (Generator + Assertion + Probe + Processor) Without DI Conflicts (T5)
Tier: T5
Goal: Author all four hook types (`AllFourGenerator`, `AllFourAssertion`, `AllFourProbe`, `AllFourProcessor`) coexisting in a SINGLE `.csproj` that references BOTH `QaaS.Runner` (for G/A/P) and `QaaS.Mocker` (for Processor), verifying all four are discovered without DI or assembly conflicts.
SUT:
- One project file; YAML runner session uses generator + assertion + probe; separate mocker YAML uses processor
- All hooks use `object` as TConfiguration; no config needed for any
MOCK_REQUIRED: yes — because processor lives in mocker YAML context; project references both packages
FB slices: s04, s13
Trap mines: s04 (BaseTransactionProcessor resolves only from QaaS.Mocker; having both refs in one project is unusual but valid), s13#9 (version mismatch: QaaS.Runner 4.5.1 + QaaS.Mocker 2.4.1 — different versions in same project)
Hard because:
- Having both `QaaS.Runner` and `QaaS.Mocker` references in one project: must verify no transitive dependency conflicts
- SDK namespace `QaaS.Framework.SDK.Hooks.Processor` available transitively via both; no duplication
- All four hooks use `object` TConfig — no `NoConfiguration` (compile error); confirmed correct per FB s04
Verify (mechanical):
- `dotnet build` exit 0 with both package refs
- Runner log: all three runner hooks discovered in single run
- Mocker log: `AllFourProcessor` discovered in mocker run
- No `CS0246` or `NU1102` errors in build
Rubric (graded):
- `.csproj` has `QaaS.Runner 4.5.1` AND `QaaS.Mocker 2.4.1` at correct independent versions (5 pts)
- All four classes compile; each uses `object` TConfig with no `NoConfiguration` (3 pts)
- `dotnet build` exit 0 with no warnings about version conflicts (2 pts)
Solution sketch: Single `.csproj` with both PackageReference items at correct versions; four `.cs` files each with correct base class; YAML runner uses three hooks by name; mocker YAML uses processor by name.

### H-142: Seeded PRNG Generator Whose Seed Derives from Config + Session Metadata (T5)
Tier: T5
Goal: Author a `BaseGenerator<MetaSeededConfig>` that computes its PRNG seed by combining a config `BaseSeed` (int, required) with a hash of a `SeedSuffix` string (required), producing a deterministic but config-varied sequence.
SUT:
- Runner project; config: `BaseSeed` (int, required), `SeedSuffix` (string, required), `Count` (uint, required), `Range` (int, required)
- Two configs with same BaseSeed but different SeedSuffix → different sequences; same full config → identical sequences
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (Configuration null in ctor; Random must be created in Generate), s13#12 (config key typo → SeedSuffix null → NRE on GetHashCode)
Hard because:
- Seed derivation: `BaseSeed ^ SeedSuffix.GetHashCode()` — GetHashCode is NOT stable across .NET versions/runs by default for strings
- Stable alternative: `BitConverter.ToInt32(SHA256.HashData(Encoding.UTF8.GetBytes(SeedSuffix)), 0) ^ BaseSeed`
- `SeedSuffix` null check required; `Configuration!.SeedSuffix!` must be validated
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IGenerator hook instance MetaSeededGenerator`
- `BaseSeed=42, SeedSuffix="test"` → Run 1 and Run 2 produce identical sequences
- `BaseSeed=42, SeedSuffix="other"` → different first value
Rubric (graded):
- SHA256-based stable seed derivation (not `GetHashCode`) (5 pts)
- `new Random(derivedSeed)` inside `Generate`; not in ctor (3 pts)
- Count/Range config correct with `[Required]` (2 pts)
Solution sketch: `Generate` computes `int suffixHash = BitConverter.ToInt32(SHA256.HashData(Encoding.UTF8.GetBytes(Configuration!.SeedSuffix!)), 0)`; `int seed = Configuration.BaseSeed!.Value ^ suffixHash`; `new Random(seed)`; loop Count.

### H-143: Cross-Output Total = Sum of Subtotals Assertion (T5)
Tier: T5
Goal: Author a `BaseAssertion<SumCorrelationConfig>` that verifies `outputs[0].total == sum(outputs[1..N].amount)`, where output[0] is the "summary" output and outputs[1..N] are "detail" lines.
SUT:
- Runner project; multi-output session with one summary + N detail outputs; config: `TotalField` (string, required), `AmountField` (string, required), `SummaryOutputName` (string, required)
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s13#13 (zero detail outputs → sum=0; passes if total is also 0 — must also count guard), s13#6 (null summary output → broken), s04 (config [Required])
Hard because:
- Must identify summary output by name and detail outputs by exclusion; `GetOutputByName` for summary
- `decimal` arithmetic required; both fields parse via `JsonElement.GetDecimal()` — throws if non-numeric
- Tolerance: exact decimal equality (not floating point) — use `decimal` throughout
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IAssertion hook instance SumCorrelationAssertion`
- Summary total=50.0, details [10.0, 20.0, 20.0] → passes
- Summary total=50.0, details [10.0, 20.0, 21.0] → fails, trace shows expected 50.0 vs actual 51.0
- Summary output absent → `AssertionStatus = Broken`
Rubric (graded):
- Summary identified by `SummaryOutputName` via `GetOutputByName`; details = remaining outputs (5 pts)
- `decimal.GetDecimal()` throughout; exact equality (3 pts)
- Missing summary output → `Broken` status not exception (2 pts)
Solution sketch: `SumCorrelationAssertion.Assert` finds summary output; detail outputs = sessionDataList minus summary; sum `AmountField` as decimal; compare to summary `TotalField`; set AssertionMessage with values.

### H-144: Input-to-Output Schema Drift Detection Assertion (T5)
Tier: T5
Goal: Author a `BaseAssertion<SchemaDriftConfig>` that detects when the SUT drops or adds JSON fields in its response compared to the request — all input keys must appear in output, no extra undeclared output keys allowed.
SUT:
- Runner project; config: `AllowedExtraFields` (List<string>, default empty — fields the SUT may add), `RequiredInputFields` (List<string>, required — fields from input that must echo to output)
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s13#6 (null output → broken), s13#12 (config typo → AllowedExtraFields silently empty → false positives on new fields)
Hard because:
- Must enumerate ALL properties of input and output JsonElements via `EnumerateObject()`
- Set algebra: dropped = input_keys - output_keys; added = output_keys - input_keys - AllowedExtraFields
- JsonElement property enumeration returns `JsonProperty` objects; extract names to `HashSet<string>`
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IAssertion hook instance SchemaDriftAssertion`
- SUT drops `customerId` from response → fails, trace names `customerId` as dropped
- SUT adds undeclared `internalId` field → fails, trace names it as unexpected addition
- Both violations → both named in trace
Rubric (graded):
- `EnumerateObject()` used to build property name sets for both input and output (5 pts)
- Dropped and added fields reported separately in trace (3 pts)
- `AllowedExtraFields` list exempts known additions from "unexpected" violation (2 pts)
Solution sketch: `SchemaDriftAssertion.Assert` calls `inputEl.EnumerateObject().Select(p=>p.Name).ToHashSet()` and same for output; computes set differences; checks against `AllowedExtraFields`; aggregates into trace.

### H-145: AES-256 Decrypt → Validate → Re-Encrypt Processor (T5)
Tier: T5
Goal: Author a `BaseTransactionProcessor<AesChainConfig>` (mocker) that AES-256-CBC decrypts the request body using a config key and IV, validates a required JSON field exists, re-encrypts with a different config response key, and returns the encrypted response.
SUT:
- Mocker project; config: `RequestKey` (string, required, base64 32-byte key), `RequestIv` (string, required, base64 16-byte IV), `ResponseKey` (string, required), `ResponseIv` (string, required), `RequiredField` (string, required)
MOCK_REQUIRED: yes
FB slices: s04, s13
Trap mines: s13#1 (`ProcessorConfiguration:`), s13#9 (Mocker 2.4.1), s04 (stateless — create `Aes` per call, not static), s13#7 (aspnet Dockerfile)
Hard because:
- `System.Security.Cryptography.Aes` must be created per-call (`Aes.Create()`) — no shared state; `Aes` is IDisposable
- Base64 key/IV decoding must validate length: 32 bytes for key, 16 bytes for IV; wrong length → `ArgumentException` from `Aes`
- `CryptoStream` usage requires careful `using` nesting to avoid partial reads
Verify (mechanical):
- `dotnet build` exit 0 (mocker project)
- Mocker log: `Found ITransactionProcessor hook instance AesChainProcessor`
- Known plaintext request → correct decrypted JSON with RequiredField → re-encrypted response decryptable with ResponseKey/IV
- Request with wrong key → `CryptographicException` → mocker returns 500 (processor throws)
Rubric (graded):
- `using var aes = Aes.Create()` inside `Process`; no static `Aes` instance (5 pts)
- Base64 key/IV length validation with descriptive exception (3 pts)
- `RequiredField` validation returns failure response rather than throwing (2 pts)
Solution sketch: `AesChainProcessor.Process`: `using var aes = Aes.Create()`; set key/IV from base64 config; `CryptoStream` decrypt → `JsonDocument.Parse`; validate field; re-encrypt with response key/IV; return new Data.

### H-146: DST-Crossing Timestamp Generator with Sort Stability (T5)
Tier: T5
Goal: Author a `BaseGenerator<DstTimestampConfig>` that yields N timestamps that cross a Daylight Saving Time boundary, ensuring timestamps remain strictly sortable (no duplicates or inversions at the DST fold).
SUT:
- Runner project; config: `StartUtc` (string, required), `Count` (uint, required), `StepMinutes` (uint, required)
- Assertion verifies timestamps are strictly ascending and all have `Z` suffix (UTC, never local)
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (Configuration null in ctor), s13#12 (StepMinutes typo → 0 → all timestamps identical → sort test fails)
Hard because:
- UTC timestamps never have DST folds — the key insight is that `DateTimeOffset.UtcNow` arithmetic is always monotone; using `TimeZoneInfo.ConvertTime` to local would create duplicates at fold
- Generator must use `DateTimeOffset` throughout, never convert to local time
- `StepMinutes: 0` → all timestamps identical → downstream sort assertion fails; must validate > 0
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IGenerator hook instance DstStableTimestampGenerator`
- 120-minute range crossing US/Eastern spring-forward DST boundary → all 120 timestamps strictly ascending
- `StepMinutes: 0` → `InvalidOperationException` thrown in `Generate`
Rubric (graded):
- `DateTimeOffset` used exclusively; no `TimeZoneInfo` conversion to local (5 pts)
- `StepMinutes > 0` validation with descriptive exception (3 pts)
- All timestamps end in `Z` via `.ToString("O")` (2 pts)
Solution sketch: `DstStableTimestampGenerator.Generate`: parse `StartUtc` to `DateTimeOffset`; validate step > 0; loop `i < Count`; yield `{timestamp = (start + TimeSpan.FromMinutes(step * i)).ToString("O")}`.

### H-147: UTF-8 BOM + tr-TR Casing Double-Pitfall Assertion (T5)
Tier: T5
Goal: Author a `BaseAssertion<DoublePitfallConfig>` that reads expected values from a BOM-prefixed DataSource file whose content includes Turkish uppercase `İ` and verifies output fields using OrdinalIgnoreCase — demonstrating both pitfalls compounding.
SUT:
- Runner project; DataSource CSV with BOM + Turkish field names; config: `DataSourceName`, `FieldName`, `CaseSensitive` (bool, required as bool?)
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s13#3 (DataSourceNames required), s04 (Configuration null in ctor), s13#12 (CaseSensitive key typo → null → NRE)
Hard because:
- BOM strip must happen before CSV parse; failure to strip causes first column header to be `\uFEFFid` (invisible prefix) → `GetProperty` silently fails
- String comparison must use `Ordinal` or `OrdinalIgnoreCase` — never `CurrentCulture` which maps İ/i differently on tr-TR
- BOM detection in DataSource string: check `raw.StartsWith("\uFEFF")`; strip before split
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IAssertion hook instance DoublePitfallAssertion`
- BOM-prefixed CSV + `CaseSensitive: false` + Turkish field → correctly compared with OrdinalIgnoreCase
- Without BOM strip: first header prefixed with `\uFEFF` → field lookup fails → `Broken`
- Without Ordinal: tr-TR system maps `İ` to `i` differently → potential false negative
Rubric (graded):
- BOM strip via `\uFEFF` TrimStart before CSV parse (4 pts)
- `StringComparison.OrdinalIgnoreCase` or `.Ordinal` based on `CaseSensitive` config (4 pts)
- Both pitfalls called out in `AssertionTrace` when violation occurs (2 pts)
Solution sketch: `DoublePitfallAssertion.Assert` reads DataSource; strips BOM; parses CSV; compares values using `String.Equals(..., CaseSensitive ? Ordinal : OrdinalIgnoreCase)`; sets trace noting both pitfall mitigations.

### H-148: Three-Level Nested Config Record with Full Validation (T5)
Tier: T5
Goal: Author a `BaseGenerator<Level1Config>` where config nests three levels deep (`Level1Config` → `Level2Config` → `Level3Config`), all with `[Required]` fields, demonstrating that QaaS config binding handles arbitrary nesting.
SUT:
- Runner project; generator uses `Level3Config.BatchSize` and `Level3Config.Label` to yield items
- Config: `Level1 { [Required] Level2Options? Opts }` → `Level2Options { [Required] Level3Spec? Inner }` → `Level3Spec { [Required] uint? BatchSize; [Required] string? Label }`
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (all three nested records must be `record` types; [Required] on each nested record property), s13#12 (typo at any level silently yields null → NRE traversing to Level3)
Hard because:
- YAML nesting: three levels of indented blocks; must indent correctly
- Null-check cascade: `Configuration!.Opts?.Inner?.BatchSize` — if any level null, `!` operator throws; explicit null checks more defensive
- `[Required]` on nested object properties validates non-null during `LoadAndValidateConfiguration`; missing YAML block → validation error not NRE
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IGenerator hook instance DeepNestedGenerator`
- Full 3-level YAML config → generator yields `BatchSize` items with `Label` field
- Missing `Opts` YAML block → config validation error (not NRE in Generate)
Rubric (graded):
- All three records use `record` keyword; each nested property has `[Required]` (5 pts)
- YAML example shows correct 3-level indentation (3 pts)
- `Generate` accesses `Configuration!.Opts!.Inner!.BatchSize!.Value` with null-forgiving (2 pts)
Solution sketch: `public record Level3Spec { [Required] public uint? BatchSize; [Required] public string? Label; }`; `public record Level2Options { [Required] public Level3Spec? Inner; }`; `public record Level1Config { [Required] public Level2Options? Opts; }`; generator yields BatchSize items.

### H-149: Synchronous Probe: TCP + File + Redis PING All-in-One (T5)
Tier: T5
Goal: Author a `BaseProbe<InfraReadinessConfig>` that synchronously checks TCP connectivity to a Redis endpoint, existence of a config/seed file, and issues a Redis PING command — all without any async, all accumulated-fail.
SUT:
- Runner project at Stage 0; config: `RedisHost`, `RedisPort`, `FilePath` (all required); no StackExchange.Redis (not available) — raw TCP PING via socket
MOCK_REQUIRED: no
FB slices: s04, s13
Trap mines: s04 (probe synchronous — TcpClient.Connect sync; no Task.Run; raw socket write via NetworkStream), s13#16 (TCP port must match actual Redis port in mocker/env)
Hard because:
- Redis PING over raw TCP: connect, send `*1\r\n$4\r\nPING\r\n`, read response `+PONG\r\n` — must implement RESP protocol manually
- All three checks in one `Run`; failures accumulated even if Redis PING fails
- `NetworkStream.ReadTimeout` must be set; blocking read without timeout hangs probe indefinitely
Verify (mechanical):
- `dotnet build` exit 0
- Runner log: `Found IProbe hook instance InfraReadinessProbe`
- Redis available + file present → probe passes silently
- Redis absent + file absent → single exception lists both failures
- TCP connected but PONG not received within timeout → failure message includes "Redis PING timeout"
Rubric (graded):
- Raw RESP PING implemented (`*1\r\n$4\r\nPING\r\n`) with synchronous read (5 pts)
- `ReadTimeout` set on `NetworkStream` to prevent hang (3 pts)
- All failures accumulated in list; single throw at end (2 pts)
Solution sketch: `InfraReadinessProbe.Run`: `List<string> failures`; `using var tcp = new TcpClient()`; try `tcp.Connect(host, port)`; write PING bytes; read with ReadTimeout; check `+PONG`; check `File.Exists(FilePath)`; throw if failures.

### H-150: Full-Stack Hook Suite: Generator + Assertion + Probe + Processor with HMAC Chain, Nested Config, and Cross-Output Invariants (T5)
Tier: T5
Goal: Author a complete hook suite — `ChainGenerator` (HMAC chain), `ChainAssertion` (cross-output sum + ordering), `ReadinessProbe` (TCP + file), `SigningProcessor` (HMAC re-sign) — all in one project with nested config records, coexisting without DI conflicts; YAML wires all four.
SUT:
- One project referencing `QaaS.Runner 4.5.1` + `QaaS.Mocker 2.4.1`; two YAML files (runner + mocker)
- Each hook has its own config record (2 levels deep); all fields [Required]; probes synchronous; processor stateless
MOCK_REQUIRED: yes — processor lives in mocker YAML
FB slices: s04, s13
Trap mines: s13#1, s13#7, s13#9 (all mocker traps), s04 (all hook authoring rules), s13#13 (count guard on assertion), s13#16 (PORT CONTRACT — probe TCP port == mocker port)
Hard because:
- Four hooks in one project means one `.csproj`, four `.cs` files, both package refs at exact independent versions
- PORT CONTRACT: ReadinessProbe's `TcpPort` config, mocker YAML `Servers.Http.Port`, and runner YAML transaction `Http.Port` must all be the same literal; one wrong digit → 404 or probe failure
- Nested configs with [Required] across all four hooks; YAML must provide all blocks correctly
- ChainAssertion must include a hermetic output-count guard co-assertion in YAML (separate assertion block)
Verify (mechanical):
- `dotnet build` exit 0 (both package refs at correct versions)
- Runner log: all three runner hooks discovered; mocker log: processor discovered
- Full run with all hooks active: zero FTL errors; session passes
- Changing mocker port but not probe port → probe fails with port mismatch error
Rubric (graded):
- Single `.csproj` with `QaaS.Runner 4.5.1` + `QaaS.Mocker 2.4.1`; no version conflicts (4 pts)
- PORT CONTRACT maintained: same port literal in probe config, mocker YAML, runner YAML (3 pts)
- All four hooks discovered in respective run logs; count guard assertion present in runner YAML (3 pts)
Solution sketch: `ChainGenerator : BaseGenerator<ChainGenConfig>`; `ChainAssertion : BaseAssertion<ChainAssertConfig>`; `ReadinessProbe : BaseProbe<ReadinessConfig>`; `SigningProcessor : BaseTransactionProcessor<SignConfig>`; runner YAML wires G/A/P; mocker YAML wires P; single port literal threaded through all three places.
