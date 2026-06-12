# Batch P — PARSING/ETL TRANSFORMATION-CONTRACT Scenarios
# IDs: P-101..P-150 | Tier mix: 10×T3 (P-101..110) | 20×T4 (P-111..130) | 20×T5 (P-131..150)
# SUT is always PROVIDED (Docker image); model authors the QaaS test, never the SUT.
# FB refs: s02-runner-yaml.md, s13-doc-drift.md
# Generated: batch-P.md

---

### P-101: CSV→JSON Field Normalizer
Tier: T3
Goal: Verify the SUT converts a single-row CSV POST body into a correctly-typed JSON object.
SUT: HTTP service; POST `text/csv` → 200 JSON. Example: `id,name,amount\n1,Alice,9.99` → `{"id":1,"name":"Alice","amount":9.99}` (id=int, amount=float).
MOCK_REQUIRED: no — SUT is a real containerized service.
FB slices: s02 §2.6 Transactions, §2.9 Assertions, §2.5 DataSources
Trap mines: s13#3 (DataSourceNames required), s13#5 (no leading slash on Route), s13#13 (vacuous HttpStatus pass)
Hard because:
- Type coercion (CSV string → int/float) must be checked in body, not just via status code.
- Zero-output vacuous pass silently masks connection errors unless hermetic guard is added.
Verify (mechanical):
- Transaction returns 200; output count = 1.
- JsonField asserts `id`=1 (integer) and `amount`=9.99.
- HermeticByExpectedOutputCount = 1.
Rubric (graded):
- 3: HttpStatus 200 + DataSourceNames present, no body check.
- 7: JsonField assertions for field names and typed values.
- 10: Hermetic count guard + type coercion (id as int, not string) verified.
Solution sketch: HTTP Transaction POST CSV DataSource file; assert with JsonContent + HermeticByExpectedOutputCount(1).

---

### P-102: Fixed-Width Column Parser
Tier: T3
Goal: Verify the SUT extracts named columns from a fixed-width text line at correct byte offsets.
SUT: HTTP POST fixed-width line (cols: id[0-4], name[5-19], status[20-21]) → JSON. Example: `00042Alice          AC` → `{"id":"00042","name":"Alice","status":"AC"}`.
MOCK_REQUIRED: no — HTTP SUT only.
FB slices: s02 §2.6 Transactions, §2.9 Assertions
Trap mines: s13#3, s13#5, s13#13
Hard because:
- Off-by-one in column offsets means wrong values without obvious error.
- Trailing-space trimming behavior must be asserted explicitly.
Verify (mechanical):
- Response 200; output count = 1.
- JsonField: `name` = "Alice" (trimmed), `id` = "00042".
- Hermetic count = 1.
Rubric (graded):
- 3: Status 200 only.
- 7: Field value assertions including trimming.
- 10: All three columns asserted + hermetic guard.
Solution sketch: Single-file DataSource with one fixed-width line; Transaction POST; JsonField assertions per column.

---

### P-103: Log-Line Severity Enricher
Tier: T3
Goal: Verify the SUT enriches plain log lines published to an input queue with a parsed severity field.
SUT: RabbitMQ consumer/producer; reads `raw-logs`, writes enriched JSON to `enriched-logs`. Example: `"ERROR database timeout"` → `{"level":"ERROR","message":"database timeout","enriched":true}`.
MOCK_REQUIRED: no — SUT connects to real RabbitMQ.
FB slices: s02 §2.6 Publishers/Consumers, §2.9 Assertions, s02 §2.5
Trap mines: s13#17 (topology must pre-exist via CreateRabbitMqExchanges probe), s13#13 (vacuous pass if Consumer timeout too short)
Hard because:
- RabbitMQ exchange/queue must be created before Publisher runs (Stage 0 probe).
- Consumer TimeoutMs must exceed SUT processing time or outputs = 0.
Verify (mechanical):
- Consumer output count = input count (3 messages).
- JsonField: `level`="ERROR", `enriched`=true.
- Hermetic count = 3.
Rubric (graded):
- 3: Consumer receives outputs (count unverified).
- 7: JsonField assertions on level and message fields.
- 10: Hermetic count + topology probe at Stage 0.
Solution sketch: Stage-0 CreateRabbitMqExchanges probe; Stage-1 Publisher; Stage-0 Consumer with InitialTimeoutMs; HermeticByExpectedOutputCount.

---

### P-104: Currency Amount Half-Up Rounding
Tier: T3
Goal: Verify the SUT rounds monetary amounts using half-up rules to 2 decimal places.
SUT: HTTP POST `{"amount":"2.345","currency":"USD"}` → `{"rounded":"2.35","currency":"USD"}`. Also: 2.344 → 2.34.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions, §2.9 Assertions
Trap mines: s13#3, s13#5, s13#13
Hard because:
- Must test the boundary value (X.XX5) specifically — not just easy round-downs.
- Float representation of 2.345 may differ from decimal; assert exact string output.
Verify (mechanical):
- Two Transactions (2.345 and 2.344); each returns 200.
- JsonField: 2.345 → "2.35", 2.344 → "2.34".
- Hermetic count = 1 per transaction.
Rubric (graded):
- 3: Status 200 for both inputs.
- 7: JsonField correct for easy case (2.344→2.34).
- 10: Boundary case 2.345→2.35 asserted + hermetic guards.
Solution sketch: Two DataSource files (boundary and non-boundary); two Transactions; JsonField per response.

---

### P-105: UTC Timestamp Normalizer
Tier: T3
Goal: Verify the SUT converts a local timestamp with explicit UTC offset to ISO 8601 UTC.
SUT: HTTP POST `{"ts":"2024-03-10T14:00:00+02:00"}` → `{"ts_utc":"2024-03-10T12:00:00Z"}`.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions, §2.9 Assertions
Trap mines: s13#3, s13#5, s13#13
Hard because:
- Off-by-one-hour errors in offset arithmetic are common; exact UTC value must be asserted.
- Model must not confuse the SUT's expected behavior with its own TZ assumptions.
Verify (mechanical):
- Response 200; output count = 1.
- JsonField: `ts_utc` = "2024-03-10T12:00:00Z".
- Hermetic count = 1.
Rubric (graded):
- 3: Status 200 only.
- 7: JsonField asserts UTC value present.
- 10: Exact UTC string matched + hermetic guard.
Solution sketch: Single JSON DataSource file with offset timestamp; Transaction POST; JsonField exact match on ts_utc.

---

### P-106: Simple Deduplicator (Exact-Once)
Tier: T3
Goal: Verify the SUT suppresses duplicate messages (same id) and emits each unique record exactly once.
SUT: RabbitMQ consumer/producer; deduplicates by `id`. Input: 5 messages (ids 1,2,1,3,2) → Output queue: 3 unique (ids 1,2,3).
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Publishers/Consumers, §2.9 Assertions, s13#17
Trap mines: s13#17 (topology probe required), s13#6 (Consumer timeout too short → empty outputs → assertion broken)
Hard because:
- Must assert output count = 3, not 5 — a common mistake is using hermetic count = input count.
- Consumer TimeoutMs must be generous enough to drain the slow dedup logic.
Verify (mechanical):
- Consumer output count = 3.
- HermeticByExpectedOutputCount(3), NOT 5.
- No duplicate id in outputs.
Rubric (graded):
- 3: Consumer receives some outputs.
- 7: Output count = 3 asserted.
- 10: Hermetic count = 3 + no duplicate ids verified via JsonField or custom assertion.
Solution sketch: 5-message DataSource; Publisher; Consumer with TimeoutMs=10000; HermeticByExpectedOutputCount(3).

---

### P-107: Field Rename / Drop / Default Mapper
Tier: T3
Goal: Verify the SUT renames `src_id`→`id`, drops `internal_tag`, and injects default `status`="active" when absent.
SUT: HTTP POST JSON → transformed JSON. Example: `{"src_id":7,"internal_tag":"x","name":"Bob"}` → `{"id":7,"name":"Bob","status":"active"}`.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions, §2.9 Assertions
Trap mines: s13#3, s13#5, s13#13
Hard because:
- Must assert both presence of new field and ABSENCE of dropped field.
- Default injection only triggers when field is absent; must supply input without the field.
Verify (mechanical):
- Response 200; output count = 1.
- JsonField: `id`=7, `status`="active".
- JsonField absence: `internal_tag` not present (or custom assertion).
Rubric (graded):
- 3: Status 200 + renamed field present.
- 7: Renamed + dropped field absence asserted.
- 10: Default injection + hermetic count + dropped field absence all verified.
Solution sketch: JSON DataSource without `status`; Transaction POST; assert presence of `id`/`status` and absence of `internal_tag`.

---

### P-108: Email PII Masker
Tier: T3
Goal: Verify the SUT masks email addresses in a record, preserving domain but obscuring local part.
SUT: HTTP POST `{"email":"alice@example.com","name":"Alice"}` → `{"email":"a****@example.com","name":"Alice"}`.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions, §2.9 Assertions
Trap mines: s13#3, s13#5, s13#13
Hard because:
- Masking pattern (first-char + asterisks + domain) is exact; partial match is insufficient.
- `name` field must remain unmasked — over-masking is also a failure mode.
Verify (mechanical):
- Response 200; output count = 1.
- JsonField: `email` matches `a****@example.com`.
- JsonField: `name` = "Alice" (unmasked).
Rubric (graded):
- 3: Status 200 + email field present.
- 7: Email value contains asterisks.
- 10: Exact mask pattern + name unmodified + hermetic count.
Solution sketch: JSON DataSource; Transaction POST; JsonField regex or exact-match on masked email; JsonField on name.

---

### P-109: UTF-8 Multibyte Passthrough Validator
Tier: T3
Goal: Verify the SUT passes through UTF-8 multibyte characters (emoji, CJK) without corruption.
SUT: HTTP POST JSON with multibyte string → same string returned intact. Example: `{"text":"こんにちは🌍"}` → `{"text":"こんにちは🌍"}`.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions, §2.9 Assertions
Trap mines: s13#3, s13#5, s13#13
Hard because:
- Byte-garbling appears as replacement chars (?) without explicit value assertion.
- DataSource file must itself be saved as UTF-8; model must know to specify encoding.
Verify (mechanical):
- Response 200; output count = 1.
- JsonField: `text` = "こんにちは🌍" (exact match).
- Hermetic count = 1.
Rubric (graded):
- 3: Status 200 only.
- 7: JsonField asserts text field is present.
- 10: Exact multibyte value matched + hermetic guard.
Solution sketch: UTF-8 JSON DataSource file; Transaction POST with Content-Type application/json; JsonField exact match.

---

### P-110: 1→2 Record Fan-Out
Tier: T3
Goal: Verify the SUT splits each input record into exactly two output messages on separate queues.
SUT: RabbitMQ; 1 input → publishes to `out-a` and `out-b`. Example: `{"id":1,"payload":"x"}` → out-a: `{"id":1,"type":"A"}`, out-b: `{"id":1,"type":"B"}`.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Publishers/Consumers, §2.9 Assertions, s13#17
Trap mines: s13#17 (topology for both output queues), s13#13 (vacuous if one Consumer reads 0)
Hard because:
- Two separate Consumers (one per output queue) must both be asserted.
- Hermetic count must be 1 per Consumer, not 2.
Verify (mechanical):
- Consumer-A output count = 1; Consumer-B output count = 1.
- JsonField: Consumer-A `type`="A", Consumer-B `type`="B".
- HermeticByExpectedOutputCount(1) on each Consumer.
Rubric (graded):
- 3: One Consumer receives output.
- 7: Both Consumers receive output with correct type.
- 10: Hermetic count = 1 on both + id propagated correctly.
Solution sketch: Stage-0 topology probe; Stage-1 Publisher (1 msg); two Consumers at Stage-0; two HermeticByExpectedOutputCount assertions.

---

### P-111: CSV Embedded Commas and Quoted Fields
Tier: T4
Goal: Verify the SUT correctly parses CSV fields that contain commas and double-quotes per RFC 4180.
SUT: HTTP POST CSV → JSON array. Example: `"Smith, Jr.",42,"He said ""hello"""` → `[{"name":"Smith, Jr.","age":42,"quote":"He said \"hello\""}]`.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions, §2.9 Assertions
Trap mines: s13#3, s13#5, s13#13
Hard because:
- Naive parsers split on every comma; embedded-comma fields must stay intact.
- Escaped double-quotes (`""`) must be unescaped to `"` in output.
- DataSource file must encode the CSV exactly; model must not introduce extra escaping.
Verify (mechanical):
- Response 200; output count = 1.
- JsonField: `name`="Smith, Jr.", `quote` contains `"hello"`.
- HermeticByExpectedOutputCount(1).
Rubric (graded):
- 3: Status 200 + field count correct.
- 7: Embedded comma preserved in name field.
- 10: Escaped double-quote unescaped + all fields + hermetic count.
Solution sketch: DataSource CSV file with RFC-4180 quoting; Transaction POST; JsonField assertions for comma and quote cases.

---

### P-112: Fixed-Width Multi-Record Batch Parser
Tier: T4
Goal: Verify the SUT parses a 10-record fixed-width file into a JSON array of 10 objects.
SUT: HTTP POST multiline fixed-width text (cols: id[0-5], code[6-8], value[9-17]) → JSON array length=10. Example row: `000001 AB  00012345` → `{"id":"000001","code":"AB","value":"00012345"}`.
MOCK_REQUIRED: no.
FB slices: s02 §2.5 DataSources, §2.6 Transactions, §2.9 Assertions
Trap mines: s13#3, s13#5, s13#13
Hard because:
- Response is an array; must assert count=10 AND spot-check specific rows.
- Column offset drift across rows (e.g. row 5 wrong) only caught with index-specific assertions.
Verify (mechanical):
- Response 200; response body is JSON array of length 10.
- JsonField spot-check: row[0].id="000001", row[9].code of last record correct.
- HermeticByExpectedOutputCount(1) on the transaction output.
Rubric (graded):
- 3: Status 200 + non-empty array.
- 7: Array length = 10 asserted.
- 10: Spot-check first and last row fields + hermetic count.
Solution sketch: 10-line fixed-width DataSource; Transaction POST; JsonField array-length and row-index assertions.

---

### P-113: Log Enricher with Host and Environment Metadata
Tier: T4
Goal: Verify the SUT injects `host` and `environment` metadata fields from config into every enriched log record.
SUT: RabbitMQ pipeline; raw log in → enriched JSON out. Config supplies host="worker-01", env="staging". Example: `"WARN low memory"` → `{"level":"WARN","msg":"low memory","host":"worker-01","env":"staging"}`.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Publishers/Consumers, §2.9 Assertions, s13#17
Trap mines: s13#17 (topology probe Stage 0), s13#6 (Consumer timeout), s13#13 (vacuous if Consumer empty)
Hard because:
- Metadata values come from SUT config, not input; model must know the deployed config values.
- Multi-message batch (5 logs): all five must carry correct metadata, not just the first.
Verify (mechanical):
- Consumer output count = 5; HermeticByExpectedOutputCount(5).
- JsonField on first and last output: `host`="worker-01", `env`="staging".
- `level` parsed correctly from raw prefix.
Rubric (graded):
- 3: Consumer receives outputs with enriched structure.
- 7: host and env present on all outputs.
- 10: Hermetic count=5 + level parsed + topology probe.
Solution sketch: Stage-0 topology probe + 5-message DataSource; Publisher; Consumer(TimeoutMs=15000); HermeticByExpectedOutputCount(5).

---

### P-114: DST Spring-Forward Timestamp Normalization
Tier: T4
Goal: Verify the SUT converts Europe/London timestamps crossing the March DST boundary to correct UTC.
SUT: HTTP POST `{"ts":"2024-03-31T01:30:00","tz":"Europe/London"}` → `{"ts_utc":"2024-03-31T01:30:00Z"}` (before) and `{"ts":"2024-03-31T02:30:00","tz":"Europe/London"}` → `{"ts_utc":"2024-03-31T01:30:00Z"}` (non-existent time mapped to UTC).
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions, §2.9 Assertions
Trap mines: s13#3, s13#5, s13#13
Hard because:
- Spring-forward gap (01:00-02:00 local) means certain local times are invalid; SUT must handle gracefully.
- Two separate inputs with distinct expected UTC outputs require two Transactions.
Verify (mechanical):
- Both Transactions return 200.
- JsonField: pre-DST ts_utc = "2024-03-31T01:30:00Z"; gap-time ts_utc = SUT-documented behavior.
- Hermetic count = 1 per Transaction.
Rubric (graded):
- 3: Status 200 for easy pre-DST case.
- 7: Both inputs return 200 with non-empty ts_utc.
- 10: Exact UTC values asserted for both + hermetic guards.
Solution sketch: Two DataSource files (pre-DST and gap-time inputs); two Transactions; JsonField exact match per response.

---

### P-115: 5-Second Windowed Count Aggregator
Tier: T4
Goal: Verify the SUT aggregates all messages within a 5-second tumbling window and emits a count record.
SUT: RabbitMQ; N messages in over 5 s → one output `{"window":"5s","count":N}`. SUT waits window close then publishes.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Publishers/Consumers, §2.9 Assertions, §2.6 Stages (TimeoutBeforeSessionMs)
Trap mines: s13#17 (topology), s13#6 (Consumer timeout must exceed window + processing: ≥8000ms)
Hard because:
- Consumer must wait for window to close before first message arrives; InitialTimeoutMs critical.
- Count value in output must exactly match published input count.
Verify (mechanical):
- Consumer output count = 1 (aggregated window record).
- JsonField: `count` = N (matches Publisher iterations).
- HermeticByExpectedOutputCount(1).
Rubric (graded):
- 3: Consumer receives 1 output.
- 7: JsonField `count` = N.
- 10: Hermetic count = 1 + InitialTimeoutMs ≥ 8000 in YAML + count exact match.
Solution sketch: Publisher 10 iterations; Consumer InitialTimeoutMs=8000, TimeoutMs=3000; HermeticByExpectedOutputCount(1); JsonField count=10.

---

### P-116: Schema V1 Input Tolerance (Default Injection)
Tier: T4
Goal: Verify the SUT accepts a V1 schema record (missing V2 fields) and injects documented V2 defaults.
SUT: HTTP POST V1 JSON `{"id":5,"value":"hello"}` → V2 JSON `{"id":5,"value":"hello","version":2,"tags":[],"active":true}`.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions, §2.9 Assertions
Trap mines: s13#3, s13#5, s13#13
Hard because:
- Each V2 default must be individually asserted; missing one is a contract violation.
- Array default (`tags`:[] ) requires JsonField or JsonLength assertion.
Verify (mechanical):
- Response 200; output count = 1.
- JsonField: `version`=2, `active`=true, `tags`=[] (empty array).
- HermeticByExpectedOutputCount(1).
Rubric (graded):
- 3: Status 200 + new field present.
- 7: All three V2 defaults asserted.
- 10: Array default + bool default + numeric default + hermetic count.
Solution sketch: V1 JSON DataSource; Transaction POST; JsonField for each V2 default field.

---

### P-117: Malformed Record Quarantine (Good→Out, Bad→Error)
Tier: T4
Goal: Verify the SUT routes valid records to the output queue and malformed records to the error queue, emitting nothing to the wrong queue.
SUT: RabbitMQ; processes 5 records (3 valid, 2 malformed) → `processed-out` gets 3, `quarantine-errors` gets 2.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Publishers/Consumers, §2.9 Assertions, s13#17
Trap mines: s13#17 (both queues must exist), s13#13 (vacuous pass if either Consumer reads 0), s13#6
Hard because:
- Two Consumers (output + error queue) must both be asserted in same session.
- Counts are different per Consumer; using same hermetic count for both is wrong.
Verify (mechanical):
- Consumer-out count = 3; Consumer-error count = 2.
- HermeticByExpectedOutputCount(3) and HermeticByExpectedOutputCount(2) on respective Consumers.
- Total = 5 = publisher iterations.
Rubric (graded):
- 3: One Consumer receives any output.
- 7: Both Consumers receive output; counts asserted.
- 10: Exact counts (3+2=5) + both hermetic guards + topology probe.
Solution sketch: 5-item DataSource (3 valid, 2 malformed JSON); Publisher; two Consumers; two separate HermeticByExpectedOutputCount assertions.

---

### P-118: PII Phone and Email Combined Masker
Tier: T4
Goal: Verify the SUT masks both email (local-part asterisks) and phone (middle-digits asterisks) in a single record.
SUT: HTTP POST `{"email":"bob@corp.io","phone":"972-50-1234567","name":"Bob"}` → `{"email":"b**@corp.io","phone":"972-**-***4567","name":"Bob"}`.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions, §2.9 Assertions
Trap mines: s13#3, s13#5, s13#13
Hard because:
- Two independent masking rules; both must be verified; failure in one while other passes is a partial score.
- `name` must remain completely unmasked to verify no over-masking.
Verify (mechanical):
- Response 200; output count = 1.
- JsonField: `email` matches mask pattern, `phone` matches mask pattern, `name`="Bob".
- HermeticByExpectedOutputCount(1).
Rubric (graded):
- 3: Status 200; at least one field masked.
- 7: Both email and phone masked.
- 10: Exact mask patterns + name unmodified + hermetic count.
Solution sketch: JSON DataSource with email + phone; Transaction POST; JsonField regex assertions for both masking patterns.

---

### P-119: Idempotent Reprocessing (Same Message ID Twice)
Tier: T4
Goal: Verify the SUT emits exactly one output when the same message ID is published twice.
SUT: RabbitMQ; idempotency keyed on `msg_id`. Publish `{"msg_id":"abc","payload":"x"}` twice → output queue gets exactly 1 record.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Publishers/Consumers, §2.9 Assertions, s13#17
Trap mines: s13#17 (topology probe), s13#6 (Consumer timeout), s13#13 (vacuous if Consumer empty)
Hard because:
- Publisher Iterations=2 with same DataSource file; model must understand this sends the same message twice.
- Consumer TimeoutMs must be long enough for second duplicate to be processed and discarded.
Verify (mechanical):
- Consumer output count = 1 (not 2).
- HermeticByExpectedOutputCount(1).
- JsonField: `msg_id`="abc" on single output.
Rubric (graded):
- 3: Consumer receives at least 1 output.
- 7: Output count = 1.
- 10: Hermetic count = 1 + msg_id verified + Publisher Iterations=2 documented.
Solution sketch: Publisher Iterations=2 on single-record DataSource; Consumer InitialTimeoutMs=5000; HermeticByExpectedOutputCount(1).

---

### P-120: Ordering Preservation Through ETL
Tier: T4
Goal: Verify the SUT forwards records in the same order they were published (no reordering).
SUT: RabbitMQ passthrough with enrichment; 10 messages in with seq=1..10 → out with seq=1..10 in order.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Publishers/Consumers, §2.9 Assertions, s02 §2.5 DataArrangeOrder
Trap mines: s13#17 (topology), s13#6, s02 §2.5 (DataArrangeOrder: AsciiAsc for determinism)
Hard because:
- DataArrangeOrder must be AsciiAsc so Publisher sends in deterministic order.
- Ordering assertion requires checking seq values match positionally in Consumer outputs array.
Verify (mechanical):
- Consumer output count = 10; HermeticByExpectedOutputCount(10).
- JsonField: output[0].seq=1, output[9].seq=10.
- No gaps or duplicates in seq sequence.
Rubric (graded):
- 3: Consumer receives 10 outputs.
- 7: First and last seq values asserted.
- 10: AsciiAsc DataArrangeOrder + all 10 seq values spot-checked + hermetic count.
Solution sketch: 10-file DataSource with AsciiAsc order; Publisher; Consumer; ordering assertion via JsonField on index positions.

---

### P-121: High-Precision Decimal String Preservation
Tier: T4
Goal: Verify the SUT preserves a high-precision decimal (8 decimal places) without float truncation.
SUT: HTTP POST `{"amount":"1234567.89012345","currency":"ILS"}` → `{"amount":"1234567.89012345","currency":"ILS"}` unchanged.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions, §2.9 Assertions
Trap mines: s13#3, s13#5, s13#13
Hard because:
- Float64 can only represent ~15 significant digits; 1234567.89012345 has 15 sig-digits — rounding is possible.
- Model must assert the exact string representation, not a numeric approximation.
Verify (mechanical):
- Response 200; output count = 1.
- JsonField: `amount` = "1234567.89012345" (exact string match).
- HermeticByExpectedOutputCount(1).
Rubric (graded):
- 3: Status 200 + amount field present.
- 7: Amount value present and non-empty.
- 10: Exact 14-character decimal string matched + hermetic count.
Solution sketch: JSON DataSource; Transaction POST; JsonField exact string match on amount field.

---

### P-122: Windows-1255 Hebrew Encoding Decoder
Tier: T4
Goal: Verify the SUT decodes a Windows-1255 encoded payload and returns correctly decoded UTF-8 Hebrew text.
SUT: HTTP POST binary body (Windows-1255 bytes) with header `Content-Type: text/plain; charset=windows-1255` → JSON `{"text":"שלום"}` (UTF-8).
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions, §2.9 Assertions
Trap mines: s13#3, s13#5, s13#13
Hard because:
- DataSource file must contain raw Windows-1255 bytes; model must not accidentally save as UTF-8.
- Response must be verified for actual Hebrew Unicode codepoints, not replacement chars.
Verify (mechanical):
- Response 200; output count = 1.
- JsonField: `text` = "שלום" (exact Hebrew).
- HermeticByExpectedOutputCount(1).
Rubric (graded):
- 3: Status 200 + text field present.
- 7: text field non-empty and not containing replacement characters.
- 10: Exact Hebrew Unicode string matched + Content-Type header set correctly + hermetic count.
Solution sketch: Binary DataSource of Windows-1255 bytes; Transaction POST with charset header; JsonField exact Hebrew value.

---

### P-123: CSV With Embedded Newlines in Quoted Fields
Tier: T4
Goal: Verify the SUT parses a CSV field containing a literal newline (RFC 4180 multi-line field).
SUT: HTTP POST CSV → JSON. Example: `1,"line1\nline2",3` → `{"id":1,"description":"line1\nline2","count":3}`.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions, §2.9 Assertions
Trap mines: s13#3, s13#5, s13#13
Hard because:
- Naive line-based parsers split at the embedded newline, producing two records instead of one.
- DataSource file must contain a literal embedded newline inside quotes, which is tricky to author correctly.
Verify (mechanical):
- Response 200; output is a single JSON object (not array of 2).
- JsonField: `description` contains "\n" (newline character).
- HermeticByExpectedOutputCount(1).
Rubric (graded):
- 3: Status 200 + id field present.
- 7: Single object returned (not two records).
- 10: description field contains literal newline + hermetic count.
Solution sketch: DataSource file with RFC 4180 quoted multi-line field; Transaction POST; JsonField on description with embedded newline.

---

### P-124: Metrics Endpoint Record Count
Tier: T4
Goal: Verify the SUT exposes a Prometheus-style /metrics endpoint that reflects the number of records processed.
SUT: After processing N records, HTTP GET `/metrics` returns a line `etl_records_processed_total N`.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions (GET), §2.9 Assertions, s02 §2.6 Collectors
Trap mines: s13#3, s13#5 (route=metrics not /metrics), s13#13
Hard because:
- Metrics endpoint is queried AFTER a processing Transaction; session staging must be correct.
- Metric value must match the number of records sent in prior Transaction.
Verify (mechanical):
- GET /metrics returns 200.
- BodyContains assertion: line `etl_records_processed_total 5` present.
- Two Transactions in session: Stage 2 (POST data), Stage 3 (GET metrics).
Rubric (graded):
- 3: GET /metrics returns 200.
- 7: Body contains metric line.
- 10: Metric value = N (matches input count) + correct stage ordering.
Solution sketch: Session with Stage-2 POST Transaction (5 records) then Stage-3 GET Transaction to metrics; BodyContains assertion on metric line.

---

### P-125: Log Stream Queue Assertion via RabbitMQ
Tier: T4
Goal: Verify the SUT publishes a structured log entry to a log-stream queue after processing each record.
SUT: RabbitMQ; on each input record, SUT writes to `log-stream` queue: `{"event":"processed","id":N,"ts":"..."}`.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Publishers/Consumers, §2.9 Assertions, s13#17
Trap mines: s13#17 (log-stream queue topology), s13#6 (Consumer timeout), s13#13
Hard because:
- Two Consumer roles: one for output records, one for log entries — both must be asserted.
- Log queue Consumer must have sufficient InitialTimeoutMs for async log writes.
Verify (mechanical):
- Log-consumer output count = N (matches input Publisher iterations).
- JsonField: `event`="processed" on log entries.
- HermeticByExpectedOutputCount(N) on log Consumer.
Rubric (graded):
- 3: Log Consumer receives some output.
- 7: JsonField event="processed" verified.
- 10: Hermetic count on log Consumer = input count + id field present.
Solution sketch: Publisher 3 iterations; log-stream Consumer(InitialTimeoutMs=5000); HermeticByExpectedOutputCount(3); JsonField on log entries.

---

### P-126: Latency Budget Assertion (Sub-500ms Processing)
Tier: T4
Goal: Verify the SUT processes and responds to each HTTP request within a 500ms SLA.
SUT: HTTP POST JSON → transformed JSON; contract: P99 latency < 500ms.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions (TimeoutMs), §2.9 Assertions, s02 §2.7 Policies
Trap mines: s13#3, s13#5, s13#13
Hard because:
- TimeoutMs on Transaction must be set to exactly 500 to enforce the SLA; higher = vacuous pass.
- Latency assertion requires a dedicated assertion hook or checking TimeoutMs behavior.
Verify (mechanical):
- Transaction completes without timeout (exit code 0).
- Transaction TimeoutMs = 500 (documented in YAML).
- Run 10 iterations; all complete within budget (no timeout errors in output).
Rubric (graded):
- 3: Transaction completes; TimeoutMs not constrained.
- 7: TimeoutMs = 500 set in YAML.
- 10: 10 iterations all complete + latency assertion or output timestamp delta check.
Solution sketch: Transaction with TimeoutMs=500, Iterations=10; assert all outputs present (count=10) as proxy for latency compliance.

---

### P-127: Windowed Amount Total Aggregator
Tier: T4
Goal: Verify the SUT sums the `amount` field across all messages in a 5-second window and emits a total.
SUT: RabbitMQ; 5 messages with amounts [10.00, 20.50, 5.25, 100.00, 0.25] → output `{"window":"5s","total":"135.00"}`.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Publishers/Consumers, §2.9 Assertions, s13#17
Trap mines: s13#17 (topology), s13#6 (Consumer InitialTimeoutMs ≥ window duration), s13#13
Hard because:
- Floating-point summation may yield 135.00000000000003; SUT must use decimal arithmetic.
- Consumer must wait for window close; InitialTimeoutMs must exceed window duration + processing.
Verify (mechanical):
- Consumer output count = 1; HermeticByExpectedOutputCount(1).
- JsonField: `total` = "135.00" (exact decimal string).
- No float precision artifacts in total.
Rubric (graded):
- 3: Consumer receives 1 output.
- 7: total field present.
- 10: Exact "135.00" string matched + InitialTimeoutMs ≥ 7000 + hermetic count.
Solution sketch: Publisher 5 iterations with amount DataSource; Consumer InitialTimeoutMs=7000; HermeticByExpectedOutputCount(1); JsonField total="135.00".

---

### P-128: Conditional Default Field Injection
Tier: T4
Goal: Verify the SUT injects a default value for an optional field only when that field is absent, and leaves it unchanged when present.
SUT: HTTP POST; if `priority` absent → inject `priority`="normal"; if present → keep as-is. Test both paths.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions, §2.9 Assertions
Trap mines: s13#3, s13#5, s13#13
Hard because:
- Two separate inputs required (one without field, one with field); both paths must be tested.
- "Leave as-is" path is easy to break: an always-overwrite bug passes the default path but fails the present path.
Verify (mechanical):
- Transaction-A (no priority): response `priority`="normal".
- Transaction-B (priority="urgent"): response `priority`="urgent".
- HermeticByExpectedOutputCount(1) on each.
Rubric (graded):
- 3: Status 200 for both inputs.
- 7: Default injected correctly on absent-field case.
- 10: Both cases verified (default + preserve) + hermetic counts.
Solution sketch: Two DataSource files; two Transactions; JsonField on priority per response.

---

### P-129: PII Pass-Through — No Over-Masking
Tier: T4
Goal: Verify the SUT does NOT mask fields that are not designated PII, leaving a record with no PII completely unchanged.
SUT: HTTP POST `{"product":"widget","qty":5,"price":"9.99"}` → identical JSON (no masking applied).
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions, §2.9 Assertions
Trap mines: s13#3, s13#5, s13#13
Hard because:
- Over-masking is a regression where a greedy regex matches non-PII values; model must assert exact equality.
- Asserting exact response equality (not just presence) requires JsonContent or field-by-field JsonField.
Verify (mechanical):
- Response 200; output count = 1.
- JsonField: `product`="widget", `qty`=5, `price`="9.99" (all unchanged).
- HermeticByExpectedOutputCount(1).
Rubric (graded):
- 3: Status 200 only.
- 7: All three fields present.
- 10: Exact values matched (no asterisks in price) + hermetic count.
Solution sketch: Non-PII JSON DataSource; Transaction POST; JsonField exact match on all three fields.

---

### P-130: 1→N Fan-Out Hermetic Count Verification
Tier: T4
Goal: Verify the SUT publishes exactly N output messages per input (fan-out factor=3) across a single output queue.
SUT: RabbitMQ; each input record fans out to 3 output messages. Send 4 inputs → output queue must have exactly 12 records.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Publishers/Consumers, §2.9 Assertions, s13#17
Trap mines: s13#17 (topology), s13#13 (must use exact hermetic count=12 not 4), s13#6
Hard because:
- Hermetic count must be input_count × fan_factor (12), not input_count (4) — easy to get wrong.
- Consumer TimeoutMs must be generous: 12 output messages may arrive slowly.
Verify (mechanical):
- Consumer output count = 12.
- HermeticByExpectedOutputCount(12).
- Each fan-out record carries `origin_id` traceable to source.
Rubric (graded):
- 3: Consumer receives some outputs.
- 7: Output count > input count (fan-out happening).
- 10: Exact count = 12 (4×3) + hermetic count + origin_id tracing.
Solution sketch: Publisher 4 iterations; Consumer TimeoutMs=20000; HermeticByExpectedOutputCount(12); JsonField origin_id on first output.

---

### P-131: Mixed V1+V2 Stream Schema Evolution
Tier: T5
Goal: Verify the SUT correctly normalizes a mixed stream of V1 and V2 schema records into a unified V2 output shape.
SUT: RabbitMQ; V1 records have `{"type":"v1","val":X}`, V2 have `{"type":"v2","value":X,"unit":"USD"}`. Both → `{"value":X,"unit":"USD","version":"V1"|"V2"}` with V1 default unit="UNKNOWN".
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Publishers/Consumers, §2.9 Assertions, s02 §2.5, s13#17
Trap mines: s13#17 (topology), s13#13 (hermetic on mixed count), s13#6 (Consumer timeout for mixed batch)
Hard because:
- Two schema variants interleaved; Consumer must receive all (not just one type).
- V1 default unit injection and field rename must both be verified on same Consumer output.
- Mixed DataSource ordering via AsciiAsc must preserve V1/V2 interleaving.
Verify (mechanical):
- Consumer output count = total messages (V1+V2 combined); HermeticByExpectedOutputCount(6).
- JsonField: V1-derived record has `unit`="UNKNOWN", V2-derived has `unit`="USD".
- `version` field present on all outputs.
Rubric (graded):
- 3: Consumer receives all outputs.
- 7: V1 and V2 outputs both carry correct unit field.
- 10: version field correct per schema type + hermetic count + AsciiAsc ordering + unit default on V1.
Solution sketch: 6-item DataSource (3 V1, 3 V2 interleaved); AsciiAsc order; Publisher; Consumer; two JsonField groups; HermeticByExpectedOutputCount(6).

---

### P-132: Malformed Record Quarantine With Reason Codes
Tier: T5
Goal: Verify the SUT routes bad records to an error queue carrying a machine-readable `reason` code field.
SUT: RabbitMQ; 2 invalid records → `quarantine` queue, each with `{"original":..., "reason":"MISSING_REQUIRED_FIELD"|"INVALID_TYPE"}`.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Publishers/Consumers, §2.9 Assertions, s13#17
Trap mines: s13#17 (quarantine queue topology), s13#13 (vacuous on quarantine Consumer), s13#6
Hard because:
- Reason code values are contract-specific; model must assert exact string not just presence.
- Two different malformed inputs produce different reason codes; both must be verified individually.
- Total output + quarantine must equal input count (accounting assertion).
Verify (mechanical):
- Quarantine Consumer output count = 2; HermeticByExpectedOutputCount(2).
- JsonField: first quarantine record `reason`="MISSING_REQUIRED_FIELD", second = "INVALID_TYPE".
- Processed-out Consumer count + quarantine count = 5 (total inputs).
Rubric (graded):
- 3: Quarantine Consumer receives outputs.
- 7: reason field present on quarantine records.
- 10: Exact reason codes per record + accounting (out+error=5) + both hermetic counts.
Solution sketch: 5-item DataSource (3 valid, 1 missing-field, 1 wrong-type); two Consumers; JsonField per reason; two HermeticByExpectedOutputCount; accounting sum assertion.

---

### P-133: 10-Second Tumbling Window Aggregation
Tier: T5
Goal: Verify the SUT closes a 10-second tumbling window and emits exactly one aggregate record with count and sum.
SUT: RabbitMQ; messages with `amount` published over <10s; after window close SUT emits `{"window_start":...,"count":N,"sum":"..."}`.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Publishers/Consumers, §2.6 Sessions (TimeoutBeforeSessionMs), s13#17
Trap mines: s13#17, s13#6 (Consumer InitialTimeoutMs must exceed 10s window: ≥13000ms), s13#13
Hard because:
- Consumer InitialTimeoutMs < window duration means 0 outputs and broken assertion — critical config value.
- sum must be exact decimal (not float-corrupted) matching sum of input amounts.
- window_start timestamp in output must be within reasonable bounds.
Verify (mechanical):
- Consumer output count = 1; HermeticByExpectedOutputCount(1).
- JsonField: `count`=N, `sum` matches arithmetic sum of published amounts.
- Consumer InitialTimeoutMs = 13000 in YAML.
Rubric (graded):
- 3: Consumer receives 1 output.
- 7: count field = N.
- 10: sum exact decimal + InitialTimeoutMs=13000 documented + hermetic count + window_start present.
Solution sketch: Publisher N iterations; Consumer InitialTimeoutMs=13000, TimeoutMs=3000; HermeticByExpectedOutputCount(1); JsonField count+sum.

---

### P-134: Banker's Rounding (Round-Half-to-Even) Verification
Tier: T5
Goal: Verify the SUT applies banker's rounding (IEEE 754 round-half-to-even) rather than half-up to financial amounts.
SUT: HTTP POST `{"amount":"2.5"}` → `{"rounded":"2"}` (round to even: 2, not 3); `{"amount":"3.5"}` → `{"rounded":"4"}` (round to even: 4).
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions, §2.9 Assertions
Trap mines: s13#3, s13#5, s13#13
Hard because:
- Half-up rounds 2.5→3 but banker's rounds 2.5→2; a model using wrong expectation fails the test.
- Both even-nearest cases (2.5→2 and 3.5→4) must be tested to distinguish banker's from half-up.
- Rounding to 0 decimals: model must assert integer strings, not floats.
Verify (mechanical):
- Transaction-A: `rounded`="2" (2.5 rounds down to even).
- Transaction-B: `rounded`="4" (3.5 rounds up to even).
- Hermetic count = 1 per Transaction.
Rubric (graded):
- 3: Both transactions return 200.
- 7: One case correct (e.g. 3.5→4).
- 10: Both cases correct proving banker's rounding (not half-up) + hermetic counts.
Solution sketch: Two DataSource files (2.5 and 3.5); two Transactions; JsonField exact string match on rounded field.

---

### P-135: Metrics Counter Must Equal Hermetic Output Count
Tier: T5
Goal: Verify that the SUT's Prometheus counter `etl_processed_total` exactly equals the number of records consumed from the output queue.
SUT: Processes N RabbitMQ messages; publishes N to output queue; increments `etl_processed_total` by N.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions (GET metrics), §2.6 Consumers, §2.9 Assertions
Trap mines: s13#3, s13#5 (route=metrics), s13#13 (both Consumer AND metrics GET need hermetic guard)
Hard because:
- Must correlate two independent data sources: Consumer output count AND metrics value.
- Metrics endpoint must be polled AFTER Consumer drain completes (staging order critical).
- Model must assert that metrics_value == Consumer output count numerically.
Verify (mechanical):
- Consumer output count = N; HermeticByExpectedOutputCount(N).
- GET /metrics returns 200; BodyContains `etl_processed_total N`.
- Staging: Consumer at Stage 0, metrics GET at Stage 3 (after Consumer drain).
Rubric (graded):
- 3: Consumer receives N + GET metrics 200.
- 7: Metrics body contains metric line.
- 10: Metric value = N (matches consumer count) + stage ordering correct + both hermetic guards.
Solution sketch: Publisher N; Consumer Stage-0; metrics GET Transaction Stage-3; assert Consumer count=N and BodyContains metric line with value N.

---

### P-136: Windows-1255 ↔ UTF-8 Hebrew Text Roundtrip
Tier: T5
Goal: Verify the SUT normalizes Windows-1255 encoded Hebrew text to UTF-8 and outputs correct Unicode codepoints.
SUT: HTTP POST Windows-1255 binary of "שלום עולם" → JSON `{"text":"שלום עולם","encoding":"utf-8","length":9}`.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions, §2.9 Assertions
Trap mines: s13#3, s13#5, s13#13
Hard because:
- DataSource file must be binary Windows-1255; inadvertent UTF-8 save corrupts test data.
- Length field counts Unicode codepoints (9), not bytes (18 in UTF-8); byte-count bug = wrong value.
- Both the text value AND the length must be asserted together.
Verify (mechanical):
- Response 200; output count = 1.
- JsonField: `text`="שלום עולם", `encoding`="utf-8", `length`=9.
- HermeticByExpectedOutputCount(1).
Rubric (graded):
- 3: Status 200 + text field present.
- 7: text contains Hebrew characters (not replacement chars).
- 10: Exact Hebrew string + length=9 (codepoints not bytes) + encoding field + hermetic count.
Solution sketch: Binary Windows-1255 DataSource; Transaction POST charset=windows-1255; JsonField on text, length, encoding.

---

### P-137: 1→3 Fan-Out Hermetics Across Three Target Queues
Tier: T5
Goal: Verify the SUT fans out each input record to exactly three different output queues with correct routing metadata.
SUT: RabbitMQ; input → `out-region-us`, `out-region-eu`, `out-region-ap`; each gets `{"id":X,"region":"us"|"eu"|"ap"}`.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Publishers/Consumers, §2.9 Assertions, s13#17
Trap mines: s13#17 (all 3 output queues must have topology), s13#13 (3 separate hermetic guards needed), s13#6
Hard because:
- Three separate Consumers; all three must be asserted individually.
- If any queue receives 0 messages (routing bug), the hermetic guard catches it but vacuous-pass trap must be avoided.
- Region metadata must match queue name (no cross-routing).
Verify (mechanical):
- Each Consumer output count = 1; three separate HermeticByExpectedOutputCount(1).
- JsonField per Consumer: `region`="us", "eu", "ap" respectively.
- Publisher sends 1 message; all 3 fans confirmed.
Rubric (graded):
- 3: At least one Consumer receives output.
- 7: All three Consumers receive 1 output each.
- 10: region field matches queue per Consumer + three hermetic guards + topology probe for all queues.
Solution sketch: Stage-0 topology probe (all queues); Publisher 1 iteration; 3 Consumers; 3 HermeticByExpectedOutputCount(1); JsonField per region.

---

### P-138: DST Fall-Back Ambiguous Timestamp Handling
Tier: T5
Goal: Verify the SUT resolves the ambiguous fall-back hour (e.g. 01:30 occurs twice) using a documented disambiguation rule.
SUT: HTTP POST `{"ts":"2024-10-27T01:30:00","tz":"Europe/London","prefer":"first"}` → `{"ts_utc":"2024-10-27T00:30:00Z"}` (BST); `prefer":"second"` → `{"ts_utc":"2024-10-27T01:30:00Z"}` (GMT).
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions, §2.9 Assertions
Trap mines: s13#3, s13#5, s13#13
Hard because:
- Same local time maps to two UTC values; correct UTC depends on `prefer` field.
- Model must know the specific UTC offsets for BST (+1) and GMT (+0) on that date.
- Two separate Transactions with different expected UTC outputs.
Verify (mechanical):
- Transaction-first: `ts_utc`="2024-10-27T00:30:00Z".
- Transaction-second: `ts_utc`="2024-10-27T01:30:00Z".
- HermeticByExpectedOutputCount(1) per Transaction.
Rubric (graded):
- 3: Both return 200 with ts_utc field.
- 7: One case correct.
- 10: Both exact UTC values correct (BST vs GMT) + hermetic counts.
Solution sketch: Two DataSource files (prefer=first, prefer=second); two Transactions; JsonField exact UTC per case.

---

### P-139: Multi-Stage ETL Pipeline (Parse → Enrich → Validate)
Tier: T5
Goal: Verify a two-queue ETL pipeline: SUT parses raw input → enriches on queue-2 → validates and emits to final queue.
SUT: RabbitMQ 3-hop pipeline: raw-input → parsed-queue → enriched-queue → validated-out. Each hop transforms the record.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Publishers/Consumers, §2.9 Assertions, s13#17, s02 §2.6 Stages
Trap mines: s13#17 (all intermediate queues topology), s13#6 (Consumer timeout must cover multi-hop latency), s13#13
Hard because:
- Consumer on validated-out must wait for full 3-hop latency; TimeoutMs critically large.
- Can optionally assert intermediate queue (parsed-queue) to isolate stage failures.
- Total latency is cumulative; Consumer InitialTimeoutMs must be the sum of all hops.
Verify (mechanical):
- Consumer on validated-out count = input count; HermeticByExpectedOutputCount(3).
- JsonField on final output: all three transformation markers present.
- Optional: intermediate Consumer on parsed-queue also has count = 3.
Rubric (graded):
- 3: Final Consumer receives outputs.
- 7: Final output has all transformation fields.
- 10: Intermediate queue also asserted + all topology probes + hermetic count + adequate Consumer timeouts.
Solution sketch: Stage-0 topology probe for all 4 queues; Publisher; Consumer(InitialTimeoutMs=20000) on validated-out; optional intermediate Consumer; HermeticByExpectedOutputCount(3).

---

### P-140: Deduplication + Ordering Preservation Combined
Tier: T5
Goal: Verify the SUT deduplicates by id while preserving the original relative order of the first occurrence of each unique id.
SUT: RabbitMQ; input seq: id=[1,2,1,3,2,4] → output: id=[1,2,3,4] in that order (first-seen ordering).
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Publishers/Consumers, §2.9 Assertions, s02 §2.5 DataArrangeOrder, s13#17
Trap mines: s13#17, s13#6, s02 §2.5 (AsciiAsc required for deterministic publisher send order)
Hard because:
- AsciiAsc DataArrangeOrder must produce the intended interleaved sequence; file naming must encode order.
- Ordering assertion on outputs: index 0=id1, 1=id2, 2=id3, 3=id4 — must assert each position.
- Count = 4, not 6 — hermetic count captures dedup.
Verify (mechanical):
- Consumer output count = 4; HermeticByExpectedOutputCount(4).
- JsonField: output[0].id=1, output[1].id=2, output[2].id=3, output[3].id=4.
- DataArrangeOrder: AsciiAsc in DataSource config.
Rubric (graded):
- 3: Consumer count = 4.
- 7: First and last id values correct.
- 10: All 4 position-indexed id values correct + AsciiAsc + hermetic count = 4.
Solution sketch: 6-file DataSource (AsciiAsc ordering encoding 1,2,1,3,2,4 sequence); Publisher; Consumer; positional JsonField assertions.

---

### P-141: Quarantine Dual Assertion — Good Queue AND Error Queue Same Run
Tier: T5
Goal: Verify that in a single QaaS session both the success queue (3 records) and the error queue (2 records) are asserted with correct counts and content.
SUT: RabbitMQ; 5-record batch → `processed-out` (3 valid) + `quarantine-errors` (2 malformed), each record carrying routing metadata.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Publishers/Consumers, §2.9 Assertions, s13#17, s13#13
Trap mines: s13#13 (BOTH Consumers need hermetic guards independently), s13#17 (both queues topology), s13#6 (error Consumer must have sufficient timeout)
Hard because:
- Two Consumer assertions with DIFFERENT expected counts in the SAME session — a model often copies count incorrectly.
- Error Consumer must also have InitialTimeoutMs > SUT rejection latency; omission → 0 outputs → vacuous pass.
- Accounting: out_count + error_count must = 5 (publisher iterations).
Verify (mechanical):
- Consumer-out count = 3; HermeticByExpectedOutputCount(3).
- Consumer-error count = 2; HermeticByExpectedOutputCount(2).
- 3 + 2 = 5 = Publisher iterations (accounting assertion).
Rubric (graded):
- 3: One Consumer correctly asserted.
- 7: Both Consumers have correct counts.
- 10: Both hermetic guards + accounting (3+2=5) + JsonField on at least one error record's reason field.
Solution sketch: 5-item DataSource; Publisher; two Consumers with differing InitialTimeoutMs; two HermeticByExpectedOutputCount; accounting sum via custom assertion or docs-only approach.

---

### P-142: Idempotent Reprocessing State Probe via HTTP
Tier: T5
Goal: Verify the SUT's /state endpoint reports processed_count=N after the first batch, and still reports N (not 2N) after submitting the same batch again.
SUT: HTTP endpoints: POST /process (processes batch) + GET /state returns `{"processed_count":N,"duplicate_count":M}`. Idempotency key = batch_id.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions, §2.6 Sessions Stages, §2.9 Assertions
Trap mines: s13#3 (DataSourceNames on both Transactions), s13#5, s13#13
Hard because:
- Two sequential POST /process calls with same batch_id; stage ordering critical (Stage 2 → Stage 3 GET).
- Model must assert `duplicate_count` > 0 after second submission to confirm idempotency detected.
- Three Transactions in one session: POST-first, POST-second, GET-state.
Verify (mechanical):
- POST-first: 200; POST-second: 200 (or 409; per contract).
- GET /state: `processed_count`=N, `duplicate_count`≥1.
- Hermetic count = 1 per Transaction.
Rubric (graded):
- 3: All Transactions return non-error status.
- 7: processed_count = N asserted.
- 10: duplicate_count ≥ 1 asserted + stage ordering (POST×2 before GET) + hermetic counts.
Solution sketch: Three Transactions in one session with stage ordering; JsonField on state response; HermeticByExpectedOutputCount(1) each.

---

### P-143: Multiline Quoted CSV Field End-to-End Integrity
Tier: T5
Goal: Verify the SUT correctly segments a CSV file containing quoted multiline fields into the right number of records with intact field boundaries.
SUT: HTTP POST CSV with 3 records, one of which has a quoted field containing two embedded newlines → JSON array length=3; middle record's `notes` field contains "\n\n".
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions, §2.9 Assertions
Trap mines: s13#3, s13#5, s13#13
Hard because:
- Naive line-count of the raw file would yield 5 lines; correct parse yields 3 records — count assertion distinguishes.
- The multiline field must contain exactly two `\n` characters; any extra indicates wrong quote-handling.
- DataSource file must faithfully contain literal embedded newlines inside CSV quotes.
Verify (mechanical):
- Response 200; JSON array length = 3 (not 5).
- JsonField: record[1].notes contains exactly 2 embedded newlines.
- HermeticByExpectedOutputCount(1) on the Transaction output.
Rubric (graded):
- 3: Status 200 + array present.
- 7: Array length = 3.
- 10: notes field contains correct embedded newlines + array length exact + hermetic count.
Solution sketch: DataSource CSV with RFC 4180 multi-line quoted fields; Transaction POST; JsonField on array length and notes content.

---

### P-144: Float Accumulation vs Decimal Precision in Batch Sum
Tier: T5
Goal: Verify the SUT uses decimal (not float64) arithmetic when summing 100 amounts of 0.1, yielding exactly "10.00" not "10.000000000000002".
SUT: HTTP POST JSON array of 100 amounts `[0.1, 0.1, ..., 0.1]` → `{"sum":"10.00","count":100}`.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions, §2.9 Assertions
Trap mines: s13#3, s13#5, s13#13
Hard because:
- Float64 sum of 100×0.1 ≠ 10.0 exactly; only decimal/arbitrary-precision arithmetic gives "10.00".
- Model must assert exact string "10.00", not numeric proximity; a regex or exact JsonField match required.
- DataSource must contain all 100 array elements; this is a large but necessary payload.
Verify (mechanical):
- Response 200; output count = 1.
- JsonField: `sum` = "10.00" (exact string).
- JsonField: `count` = 100.
- HermeticByExpectedOutputCount(1).
Rubric (graded):
- 3: Status 200 + sum field present.
- 7: count = 100 asserted.
- 10: Exact "10.00" string (not "10.000000000000002") + count=100 + hermetic count.
Solution sketch: 100-element JSON array DataSource; Transaction POST; JsonField exact string on sum and count.

---

### P-145: Schema Evolution Combined With PII Masking
Tier: T5
Goal: Verify the SUT applies PII masking correctly to BOTH V1 and V2 schema records in a mixed stream.
SUT: RabbitMQ; V1 has `email` field, V2 has `contact.email` nested field. Both must be masked; non-PII fields unchanged.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Publishers/Consumers, §2.9 Assertions, s02 §2.5, s13#17
Trap mines: s13#17, s13#6, s13#13 (hermetic for combined stream)
Hard because:
- Two different schema paths for the same semantic field; masking must handle both shapes.
- Over-masking (affecting non-email fields) must be verified absent on both schema versions.
- Mixed interleaved DataSource with AsciiAsc ordering.
Verify (mechanical):
- Consumer output count = 6 (3 V1 + 3 V2); HermeticByExpectedOutputCount(6).
- JsonField: V1 output `email` masked; V2 output `contact.email` masked (nested path).
- Non-PII field `name` unchanged on both.
Rubric (graded):
- 3: Consumer receives all 6 outputs.
- 7: At least one schema's email field masked.
- 10: Both V1 email and V2 contact.email masked + name field unmasked on both + hermetic count.
Solution sketch: 6-item mixed DataSource; Publisher; Consumer; JsonField per schema version including nested path assertion; HermeticByExpectedOutputCount(6).

---

### P-146: Metrics Counter Reconciliation (processed + errors = total)
Tier: T5
Goal: Verify that SUT's metrics satisfy: `etl_processed_total` + `etl_errors_total` = total records published.
SUT: Processes 10 records (8 valid, 2 malformed); /metrics exposes `etl_processed_total 8` and `etl_errors_total 2`.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions, §2.6 Consumers, §2.9 Assertions
Trap mines: s13#3, s13#5 (metrics route no slash), s13#13 (metrics GET vacuous if SUT not ready)
Hard because:
- Two separate metric values must be retrieved and their sum asserted = 10.
- Metrics GET must be staged AFTER both queues have been drained (correct stage ordering).
- Model must not assume a single Counter line; must handle two distinct metric names.
Verify (mechanical):
- Consumer-out count = 8; Consumer-error count = 2.
- GET /metrics: BodyContains `etl_processed_total 8` AND `etl_errors_total 2`.
- Staging: Consumers Stage-0, metrics GET Stage-3.
Rubric (graded):
- 3: GET /metrics returns 200 + both metric lines present.
- 7: etl_processed_total = 8 verified.
- 10: Both metrics verified + 8+2=10 accounting + stage ordering + both Consumer hermetic counts.
Solution sketch: Publisher 10 iterations; two Consumers; Stage-3 GET /metrics; BodyContains for both metric lines; hermetic counts 8+2.

---

### P-147: Windowed Aggregator Late-Arrival Routing
Tier: T5
Goal: Verify the SUT routes a record arriving after window close to the NEXT window's aggregate rather than silently dropping it.
SUT: RabbitMQ; 5-second windows; first batch (3 records) → window-1 aggregate (count=3); late record arrives after 6s → window-2 aggregate (count=1).
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Publishers/Consumers, §2.6 Sessions (SleepTimeMs on Publisher), s13#17
Trap mines: s13#17, s13#6 (Consumer InitialTimeoutMs must cover both windows: ≥14000ms), s13#13
Hard because:
- Publisher must send batch-1 then sleep >5s then send late record; SleepTimeMs on Publisher must be set.
- Consumer must drain TWO window-close outputs; total output count = 2, not 1.
- Window-1 count=3 and Window-2 count=1 both asserted on same Consumer.
Verify (mechanical):
- Consumer output count = 2; HermeticByExpectedOutputCount(2).
- JsonField: output[0].count=3, output[1].count=1.
- Publisher SleepTimeMs ≥ 6000 between batches (via Loop or two Publisher stages).
Rubric (graded):
- 3: Consumer receives at least 1 window output.
- 7: Consumer count = 2.
- 10: Both window counts correct (3 and 1) + SleepTimeMs documented + hermetic count.
Solution sketch: Two Publisher stages (Stage-1 batch-1 × 3, Stage-2 × 1 after TimeoutBeforeSessionMs=7000); Consumer InitialTimeoutMs=14000; HermeticByExpectedOutputCount(2); JsonField per window count.

---

### P-148: Log Stream Enrichment Fields Assertion
Tier: T5
Goal: Verify the SUT writes structured log entries to a dedicated log queue with all documented envelope fields present and correctly valued.
SUT: RabbitMQ; each processed record → `audit-log` queue: `{"event":"etl.processed","ts":"ISO8601","input_id":X,"stage":"enrich","host":"worker-01"}`.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Publishers/Consumers, §2.9 Assertions, s13#17
Trap mines: s13#17 (audit-log topology), s13#6 (log Consumer timeout), s13#13 (hermetic on log Consumer)
Hard because:
- Five mandatory envelope fields must ALL be asserted, not just one; partial assertion is insufficient.
- `ts` is dynamic; model must assert it is present and ISO8601 format (regex or BodyContains), not exact value.
- Log Consumer and output Consumer both run; combined hermetic counts must match.
Verify (mechanical):
- Log Consumer output count = N (= Publisher iterations); HermeticByExpectedOutputCount(N).
- JsonField: `event`="etl.processed", `stage`="enrich", `host`="worker-01" on first log entry.
- `ts` field present and non-empty (regex assertion acceptable).
Rubric (graded):
- 3: Log Consumer receives outputs.
- 7: event, stage, host all verified.
- 10: All 5 envelope fields asserted + ts format check + hermetic count = publisher iterations.
Solution sketch: Publisher 3 iterations; log Consumer InitialTimeoutMs=5000; HermeticByExpectedOutputCount(3); JsonField per envelope field; regex on ts.

---

### P-149: Mixed Encoding Auto-Detection (UTF-8 vs ISO-8859-1)
Tier: T5
Goal: Verify the SUT auto-detects input encoding (UTF-8 or ISO-8859-1) and outputs correctly decoded text for both.
SUT: HTTP POST with `Content-Type: text/plain` (no charset); SUT detects encoding. UTF-8 input "café" (4 bytes) → `{"text":"café","detected":"utf-8"}`; ISO-8859-1 input (same word, different bytes) → `{"text":"café","detected":"iso-8859-1"}`.
MOCK_REQUIRED: no.
FB slices: s02 §2.6 Transactions, §2.9 Assertions
Trap mines: s13#3, s13#5, s13#13
Hard because:
- Two different binary DataSource files required; one valid UTF-8, one ISO-8859-1; model must not conflate.
- Output text must be identical Unicode ("café") despite different input byte sequences.
- `detected` field value must match the detected encoding label exactly.
Verify (mechanical):
- Transaction-UTF8: `text`="café", `detected`="utf-8".
- Transaction-ISO: `text`="café", `detected`="iso-8859-1".
- HermeticByExpectedOutputCount(1) per Transaction.
Rubric (graded):
- 3: Both Transactions return 200 with text field.
- 7: text="café" correct for at least one encoding.
- 10: Both text values + both detected values + hermetic counts per Transaction.
Solution sketch: Two binary DataSource files (UTF-8 bytes and ISO-8859-1 bytes); two Transactions; JsonField on text and detected per response.

---

### P-150: Full E2E ETL Contract (Parse + Enrich + Mask + Count + Metrics)
Tier: T5
Goal: Verify the complete ETL pipeline: CSV parse → field enrich → PII mask → RabbitMQ output, with metrics counter and hermetic counts all reconciled.
SUT: HTTP POST CSV → SUT parses, enriches with host metadata, masks email, publishes to `etl-out` queue; exposes `/metrics` with `etl_processed_total`.
MOCK_REQUIRED: no.
FB slices: s02 §2.5, §2.6 Transactions+Consumers, §2.9 Assertions, s13#17, s13#13, s13#3, s13#5
Trap mines: s13#17 (etl-out topology probe), s13#13 (Consumer + GET /metrics both need hermetic guards), s13#5 (Route=metrics not /metrics), s13#3 (DataSourceNames on POST Transaction)
Hard because:
- Four simultaneous contract obligations (parse, enrich, mask, metrics) must all pass; partial passes score lower.
- Stage ordering: Stage-0 topology probe + Stage-0 Consumer; Stage-2 POST Transaction; Stage-3 GET metrics.
- Hermetic: Consumer count = N AND metrics value = N must both be asserted and match.
Verify (mechanical):
- Consumer output count = N; HermeticByExpectedOutputCount(N).
- JsonField: `host`="worker-01" (enriched), `email` masked, CSV fields correctly parsed.
- GET /metrics: BodyContains `etl_processed_total N`.
- All four: parse correct + enrich present + mask applied + metrics = N.
Rubric (graded):
- 3: Consumer receives N outputs + metrics GET 200.
- 7: Any two of (parse/enrich/mask/metrics-value) asserted.
- 10: All four contract obligations verified + stage ordering correct + both hermetic guards + Consumer count = metrics value.
Solution sketch: Stage-0 topology + Consumer; Stage-2 POST Transaction (CSV DataSource); Stage-3 GET /metrics; JsonField per transform layer; HermeticByExpectedOutputCount(N) + BodyContains metric.
