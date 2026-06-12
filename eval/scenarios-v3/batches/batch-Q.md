# Batch Q — Advanced Messaging / Broker-Topology Scenarios
# IDs: Q-101..Q-150 | Tiers: T3×10 (Q-101..110), T4×20 (Q-111..130), T5×20 (Q-131..150)
# FB slices used: s02, s09, s11, s13 | Generated for QaaS Runner 4.5.1 / Mocker 2.4.1
# No duplicate IDs with batches A–H (existing scenarios A01–H07)
# Format: Goal→SUT→Traps→Hard-because→Verify→Rubric→Solution sketch

---

### Q-101: Direct Exchange Routing — Declare + Publish + Consume

**Tier:** T3
**Goal:** Verify that a RabbitMQ direct-exchange binding routes a published message to exactly one consumer queue.
**SUT:**
- Docker RabbitMQ 3-management; test owns topology via probes.
- Publisher sends 1 message; consumer reads from bound queue.

**MOCK_REQUIRED:** no — real broker in Docker is the SUT.
**FB slices:** s02 §2.6 (Publishers/Consumers), s11 §11.1 (topology probes), s13 #17.
**Trap mines:** s13 #17 (exchange must pre-exist — use `CreateRabbitMqExchanges` probe at Stage 0).
**Hard because:**
- Forgetting Stage-0 probe → `NOT_FOUND` classId=40, Outputs=0.
- `QaaS.Common.Probes` PackageReference missing → Autofac exit -532462766.
- Consumer `TimeoutMs` too short for broker round-trip → empty output.

**Verify (mechanical):**
1. Build: `dotnet build` exits 0.
2. Run: Outputs==1, ExitCode==0.
3. `HermeticByExpectedOutputCount` assertion passes (ExpectedCount=1).

**Rubric (graded):**
- 9-10: Probe at Stage 0, correct exchange type `direct`, hermetic guard, `QaaS.Common.Probes` referenced.
- 6-8: Topology set up but probe omits `Durable`/`Type`; hermetic guard present.
- 1-5: No probe; relies on pre-existing topology; vacuous pass risk.

**Solution sketch:** `CreateRabbitMqExchanges` probe Stage 0 → Publisher Stage 1 → Consumer Stage 0 (consumer starts before publisher by default); `HermeticByExpectedOutputCount ExpectedCount=1`.

---

### Q-102: Fanout Exchange — Two Queues Receive Same Message

**Tier:** T3
**Goal:** Confirm a fanout exchange delivers one published message to two independently bound queues.
**SUT:**
- RabbitMQ fanout exchange; two queues bound with `CreateRabbitMqBindings` probe.
- Two separate Consumers, one per queue.

**MOCK_REQUIRED:** no — real broker.
**FB slices:** s02 §2.6, s09 §9 (#3 HermeticByExpectedOutputCount), s11 §11.1.
**Trap mines:** s13 #17 (both queues must be pre-created); s13 #12 (silently ignored typo keys in AssertionConfiguration).
**Hard because:**
- Forgetting `CreateRabbitMqQueues` probe means bind fails (classId=50).
- Each consumer output must be guarded separately; a single aggregate guard misses one empty output.
- `QaaS.Common.Probes` pkg required.

**Verify (mechanical):**
1. Run produces 2 consumer outputs, each count=1.
2. Two `HermeticByExpectedOutputCount` assertions both pass.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: Distinct hermetic guard per output; probes declare both queues + bindings.
- 6-8: Single aggregate hermetic guard; topology correct.
- 1-5: No topology probes or no hermetic guards.

**Solution sketch:** Stage-0 probes: `CreateRabbitMqExchanges` (fanout) + `CreateRabbitMqQueues` (q1, q2) + `CreateRabbitMqBindings` (exchange→q1, exchange→q2); Publisher Stage 1; two Consumers Stage 0; two hermetic assertions.

---

### Q-103: Topic Exchange — Wildcard Routing Key Match

**Tier:** T3
**Goal:** Prove that a topic exchange routes messages with routing key `order.europe.express` only to the queue bound with `order.europe.*` and not to `order.asia.*`.
**SUT:**
- RabbitMQ topic exchange; two queues with different binding patterns.
- Publisher sends 3 messages with key `order.europe.express`.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.6 (Publisher `RoutingKey`), s11 §11.1, s09 #3.
**Trap mines:** s13 #17; s13 #12 (typo in routing key silently fails routing, Outputs=0 on wrong queue, vacuous pass if no hermetic guard on that output).
**Hard because:**
- Must assert BOTH queues: one with count=3, one with count=0 — an assertion on count=0 must use `HermeticByExpectedOutputCount ExpectedCount=0` correctly.
- Routing key is set on Publisher, not on Exchange declare; easy to forget.

**Verify (mechanical):**
1. Consumer for `europe` queue: Outputs==3.
2. Consumer for `asia` queue: Outputs==0.
3. Both hermetic assertions pass.

**Rubric (graded):**
- 9-10: Asserts zero delivery to wrong queue with hermetic guard; correct RoutingKey on publisher.
- 6-8: Only asserts positive queue; negative queue unguarded.
- 1-5: No distinction between queues; single consumer.

**Solution sketch:** Two queues + bindings at Stage 0; Publisher `RoutingKey: order.europe.express`; Consumer-Europe hermetic count=3; Consumer-Asia hermetic count=0.

---

### Q-104: Headers Exchange — Route by Message Header Value

**Tier:** T3
**Goal:** Verify a headers exchange routes a message to a queue bound with `x-match=all` header criteria.
**SUT:**
- RabbitMQ headers exchange; queue bound with `arguments: {x-match: all, region: eu, priority: high}`.
- Publisher sends headers `region=eu, priority=high`.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.6 (Publisher headers fields), s11 §11.1 (`CreateRabbitMqBindings` Arguments), s09 #3.
**Trap mines:** s13 #17; s13 #12 (Arguments silently ignored if key names wrong).
**Hard because:**
- `Arguments` on bindings must match header names exactly — case-sensitive, silently ignored on mismatch.
- QaaS Publisher `Headers` map must reproduce same keys; any delta → no routing → Outputs=0 vacuous pass.

**Verify (mechanical):**
1. Consumer output count==1; hermetic guard passes.
2. Publisher input count==1.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: Correct `x-match: all`, exact header keys on both binding and publisher.
- 6-8: Uses `x-match: any`; routing works but semantics differ from spec.
- 1-5: No binding arguments; exchange declared as direct instead of headers.

**Solution sketch:** `CreateRabbitMqExchanges` type=`headers`; `CreateRabbitMqBindings` with Arguments `x-match: all, region: eu, priority: high`; Publisher `Headers` map same keys; hermetic count=1.

---

### Q-105: Consumer TimeoutMs Tuning — Avoid Flaky Empty Output

**Tier:** T3
**Goal:** Demonstrate that a consumer with `TimeoutMs` shorter than the SUT processing latency produces empty output and a vacuous hermetic pass, while the correct timeout produces count=1.
**SUT:**
- RabbitMQ direct exchange; SUT adds 800 ms processing delay before publishing.
- Two sessions: one with `TimeoutMs: 200`, one with `TimeoutMs: 2000`.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.6 (Consumer `TimeoutMs`, `InitialTimeoutMs`), s09 #3, s13 #13.
**Trap mines:** s13 #13 (vacuous hermetic pass when Outputs=0 — applies equally to consumer assertions relying on HermeticByExpectedOutputCount with count=0 expected).
**Hard because:**
- Two sessions share same exchange; must isolate by queue to avoid cross-contamination.
- `InitialTimeoutMs` vs `TimeoutMs` distinction: initial waits for first message; `TimeoutMs` between messages.

**Verify (mechanical):**
1. Short-timeout session: Outputs==0, hermetic guard `ExpectedCount=0` passes (vacuous trap shown).
2. Long-timeout session: Outputs==1, hermetic guard `ExpectedCount=1` passes.
3. Report annotation explains why short timeout is insufficient.

**Rubric (graded):**
- 9-10: Both sessions present; short session correctly uses `InitialTimeoutMs`; trap clearly annotated.
- 6-8: Only long-timeout session; no contrast.
- 1-5: Single session; no discussion of timeout semantics.

**Solution sketch:** Session-A `InitialTimeoutMs: 200`, Session-B `InitialTimeoutMs: 3000`; separate queues; hermetic guards on both; comment in YAML explains vacuous-pass trap from s13 #13.

---

### Q-106: Publisher Iterations — Hermetic Count Equals Iterations

**Tier:** T3
**Goal:** Confirm that `Iterations: 10` on a Publisher produces exactly 10 consumed outputs and the hermetic assertion catches any drop.
**SUT:**
- RabbitMQ direct exchange + queue; Publisher `Iterations: 10`, Consumer with adequate timeout.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.6 (Publisher `Iterations`), s09 #3 (`HermeticByExpectedOutputCount`), s11 §11.1.
**Trap mines:** s13 #17 (topology must pre-exist); s13 #13 (vacuous pass if consumer timeout too short).
**Hard because:**
- `Iterations` multiplies messages per data source item; if DataSource has N rows, total = N×Iterations.
- Hermetic count must match actual sent count exactly; off-by-one if data source size misunderstood.

**Verify (mechanical):**
1. Publisher input count==10.
2. Consumer output count==10.
3. `HermeticByExpectedOutputCount ExpectedCount=10` passes.

**Rubric (graded):**
- 9-10: Correct ExpectedCount accounting for data source size × Iterations.
- 6-8: Correct count, but data source has exactly 1 item so no size ambiguity.
- 1-5: No hermetic guard; count not verified.

**Solution sketch:** Single-item data source; `Iterations: 10` on Publisher; `HermeticByExpectedOutputCount ExpectedCount=10`; topology probes at Stage 0.

---

### Q-107: Redis Pub/Sub — Publisher and Consumer via Redis Protocol

**Tier:** T3
**Goal:** Verify a QaaS Redis Publisher and Consumer exchange a message via Redis pub/sub channel.
**SUT:**
- Redis 7 in Docker; Publisher on channel `events`, Consumer subscribes same channel.

**MOCK_REQUIRED:** no — real Redis.
**FB slices:** s02 §2.6 (Publisher `Redis`, Consumer `Redis`), s09 #3, s11 (FlushAllRedis probe for cleanup).
**Trap mines:** s13 #12 (typo in channel name silently ignored); s13 #13 (Consumer timeout must cover pub delay).
**Hard because:**
- Redis pub/sub is fire-and-forget; Consumer must be active before Publisher fires (Consumer Stage 0, Publisher Stage 1).
- Channel name mismatch → Outputs=0, hermetic guard vacuous pass risk.

**Verify (mechanical):**
1. Consumer output count==1.
2. `HermeticByExpectedOutputCount ExpectedCount=1` passes.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: Consumer at Stage 0, Publisher at Stage 1; hermetic guard present; flush probe for isolation.
- 6-8: Stages correct; no cleanup probe.
- 1-5: Stages reversed; Consumer misses message.

**Solution sketch:** Consumer Stage 0 with `InitialTimeoutMs: 5000`; Publisher Stage 1; `FlushAllRedis` probe at teardown Stage 4; hermetic count=1.

---

### Q-108: Kafka Topic — Basic Publish and Consume

**Tier:** T3
**Goal:** Publish 5 messages to a Kafka topic and consume them, verifying hermetic count.
**SUT:**
- Kafka + Zookeeper in Docker; topic auto-created or pre-created; Publisher `KafkaTopic`, Consumer `KafkaTopic`.

**MOCK_REQUIRED:** no — real Kafka.
**FB slices:** s02 §2.6 (Publisher/Consumer KafkaTopic fields), s09 #3.
**Trap mines:** s13 #13 (vacuous pass if consumer offset starts at latest, missing earlier messages); consumer `TimeoutMs` must be adequate.
**Hard because:**
- Kafka consumer offset strategy: `auto.offset.reset=earliest` required to catch messages published before consumer starts.
- Consumer group ID uniqueness needed across test runs; stale offsets from a prior run cause Outputs=0.
- `/qaas:docs runner/actions/consumers/kafkaTopic` needed for exact field names (GroupId, AutoOffsetReset).

**Verify (mechanical):**
1. Consumer output count==5.
2. `HermeticByExpectedOutputCount ExpectedCount=5` passes.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: `AutoOffsetReset: Earliest` set; unique GroupId per run; hermetic guard.
- 6-8: GroupId unique but AutoOffsetReset not set; works only if consumer starts before publisher.
- 1-5: Default offsets; flaky depending on timing; no hermetic guard.

**Solution sketch:** Publisher Stage 1 `Iterations: 5`; Consumer Stage 0 `AutoOffsetReset: Earliest`; `HermeticByExpectedOutputCount ExpectedCount=5`; unique GroupId via variable.

---

### Q-109: Priority Queue — Declare With Arguments and Consume High-Priority First

**Tier:** T3
**Goal:** Declare a RabbitMQ priority queue (`x-max-priority`), publish messages at priority 1 and 10, and verify the high-priority message is consumed first.
**SUT:**
- RabbitMQ; queue with `Arguments: {x-max-priority: 10}`; Publisher sends low then high priority.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.6, s11 §11.1 (`CreateRabbitMqQueues` Arguments), s09 #3.
**Trap mines:** s13 #17 (queue must pre-exist with correct arguments; re-declaring without arguments creates a plain queue silently); s13 #12 (argument key silently ignored if mistyped).
**Hard because:**
- Priority queue arguments must be set at queue-creation time; you cannot add `x-max-priority` to an existing queue.
- QaaS Publisher `Priority` field path — requires `/qaas:docs runner/actions/publishers/rabbitMq` to confirm exact field name.
- Ordering assertion not available in the 11 built-ins; need `OutputContentByExpectedCsvResults` to verify first output body.

**Verify (mechanical):**
1. Consumer output count==2; hermetic count=2 passes.
2. First output body matches high-priority payload (via `OutputContentByExpectedCsvResults`).
3. ExitCode==0.

**Rubric (graded):**
- 9-10: Queue declared with `x-max-priority: 10`; priority set on publisher; ordering verified.
- 6-8: Queue declared correctly but ordering not asserted.
- 1-5: Plain queue; priority argument missing; ordering not tested.

**Solution sketch:** `CreateRabbitMqQueues` `Arguments: {x-max-priority: 10}`; two Publisher iterations with different priorities; `OutputContentByExpectedCsvResults` on first output; hermetic count=2.

---

### Q-110: Setup + Teardown Probes — Topology Lifecycle Across Sessions

**Tier:** T3
**Goal:** Demonstrate the full exchange/queue lifecycle: create at start (Stage 0), publish/consume, then delete at end (Stage 4) so each run is idempotent.
**SUT:**
- RabbitMQ direct exchange + queue; lifecycle managed entirely by QaaS probes.

**MOCK_REQUIRED:** no.
**FB slices:** s11 §11.1 (Create/Delete probes), s02 §2.6, s09 #3, s13 #17.
**Trap mines:** s13 #17 (missing setup probe → classId=40 failure); teardown probe wrong stage number → runs before consume → messages lost.
**Hard because:**
- Delete probe must be at a stage number AFTER consumer; Stage ordering must be explicit.
- `DeleteRabbitMqQueues` before `DeleteRabbitMqExchanges` avoids orphaned bindings.
- `QaaS.Common.Probes` pkg must be present.

**Verify (mechanical):**
1. Consumer output count==1; hermetic passes.
2. After run: exchange and queue no longer exist in broker (manual check or second run with delete-only session).
3. ExitCode==0.

**Rubric (graded):**
- 9-10: Correct Stage 0 setup, Stage 4 teardown, deletion order correct, `QaaS.Common.Probes` referenced.
- 6-8: Setup probe present but no teardown; runs not idempotent.
- 1-5: No probes; relies on pre-existing topology.

**Solution sketch:** Stage 0: `CreateRabbitMqExchanges` + `CreateRabbitMqQueues` + `CreateRabbitMqBindings`; Stage 1: Publisher; Stage 0 (earlier): Consumer; Stage 4: `DeleteRabbitMqQueues` + `DeleteRabbitMqExchanges`.

---

### Q-111: Dead-Letter Queue — TTL Expiry Routes to DLQ

**Tier:** T4
**Goal:** Verify that a message with `x-message-ttl` that expires in the source queue is automatically routed to a DLQ consumer.
**SUT:**
- RabbitMQ: source queue with `x-message-ttl: 500` and `x-dead-letter-exchange: dlx`; DLQ exchange + queue; publisher sends 1 message; no consumer on source queue (message expires); DLQ consumer reads dead-lettered message.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.6, s11 §11.1 (`CreateRabbitMqQueues` Arguments), s09 #3, s13 #17.
**Trap mines:** s13 #17 (both source queue and DLQ must be pre-declared with correct arguments); s13 #12 (argument keys must be exact — `x-dead-letter-exchange` not `deadLetterExchange`).
**Hard because:**
- Queue `Arguments` must include both `x-message-ttl` (ms) and `x-dead-letter-exchange` simultaneously at creation time.
- Consumer on source queue must be absent (or at a later stage so TTL fires first); timing sensitive.
- DLQ consumer `InitialTimeoutMs` must exceed TTL + routing latency.

**Verify (mechanical):**
1. Source queue consumer output==0 (or absent); DLQ consumer output==1.
2. `HermeticByExpectedOutputCount` on DLQ output: ExpectedCount=1 passes.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: Both queues declared with correct Arguments; DLQ consumer `InitialTimeoutMs ≥ 1500`; hermetic guard on DLQ output.
- 6-8: TTL set but DLQ exchange/binding missing; message discarded not dead-lettered.
- 1-5: No DLQ topology; source consumer present consuming message before TTL fires.

**Solution sketch:** Stage 0 probes: declare `dlx` exchange (direct), source queue `Arguments: {x-message-ttl: 500, x-dead-letter-exchange: dlx}`, DLQ queue, binding dlx→dlq; Publisher Stage 1 (no source consumer); DLQ Consumer Stage 0 `InitialTimeoutMs: 2000`; hermetic count=1.

---

### Q-112: Competing Consumers — Hermetic Percentage Math

**Tier:** T4
**Goal:** Publish 100 messages to one queue consumed by 3 parallel consumer instances; assert that aggregate delivery percentage is 100% using `HermeticByInputOutputPercentage`.
**SUT:**
- RabbitMQ direct exchange; 3 Consumers in the same session with `Parallel: {Parallelism: 3}` (or 3 separate Consumer entries), sharing one queue; Publisher `Iterations: 100`.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.6 (Consumer, Publisher `Parallel`), s09 #5 (`HermeticByInputOutputPercentage`), s11 §11.1.
**Trap mines:** s13 #13 (each consumer output may have partial count; total must be aggregated in assertion `OutputNames`); s13 #17; s13 #12.
**Hard because:**
- `HermeticByInputOutputPercentage` takes `InputNames` (publisher) and `OutputNames` (all consumers combined) — must list all consumer output names.
- Split of messages across consumers is non-deterministic; per-consumer hermetic count fails; only aggregate percentage is stable.
- `0 inputs + some outputs → fail` (s09 #5); publisher input must be registered first.

**Verify (mechanical):**
1. Sum of all consumer outputs==100.
2. `HermeticByInputOutputPercentage ExpectedPercentage=100` passes with all output names in `OutputNames`.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: All consumer output names in `OutputNames`; `ExpectedPercentage: 100`; publisher at Stage 1, consumers at Stage 0.
- 6-8: Single OutputName misses some messages; percentage < 100; assertion fails correctly.
- 1-5: Per-consumer hermetic count; fails non-deterministically.

**Solution sketch:** Stage 0: topology probe; Stage 0: 3 Consumers `TimeoutMs: 5000`; Stage 1: Publisher `Iterations: 100`; `HermeticByInputOutputPercentage InputNames: [PublisherName] OutputNames: [C1,C2,C3] ExpectedPercentage: 100`.

---

### Q-113: Publisher with LoadBalance Rate Policy — Hermetic Count in Window

**Tier:** T4
**Goal:** Use `LoadBalance{Rate: 10, TimeIntervalMs: 1000}` on a Publisher to send 50 messages over ~5 seconds and verify the hermetic count equals 50.
**SUT:**
- RabbitMQ direct exchange + queue; Publisher with `Policies: - LoadBalance: {Rate: 10, TimeIntervalMs: 1000}` and `Count: {Count: 50}`; Consumer with sufficient `TimeoutMs`.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.7 (Policies: LoadBalance, Count), s02 §2.6, s09 #3, s11 §11.1.
**Trap mines:** s13 #17; s13 #13 (Consumer `TimeoutMs` must exceed total send window ~5s + processing).
**Hard because:**
- `Count` policy caps total actions; without it, LoadBalance loops indefinitely.
- `TimeoutMs` on Consumer must be set after last message arrives; use `TimeoutMs: 2000` (time-since-last-message) not total window.
- Hermetic count must equal exact policy-capped total, not rate×window approximation.

**Verify (mechanical):**
1. Publisher input count==50.
2. Consumer output count==50.
3. `HermeticByExpectedOutputCount ExpectedCount=50` passes.

**Rubric (graded):**
- 9-10: `Count: {Count: 50}` + `LoadBalance` both present; Consumer `TimeoutMs` ≥ 2000; hermetic count=50.
- 6-8: `LoadBalance` present but no `Count` cap; publisher runs until session timeout; indeterminate count.
- 1-5: No policy; `Iterations: 50` used instead; misses rate-pacing requirement.

**Solution sketch:** Publisher policies: `LoadBalance: {Rate: 10, TimeIntervalMs: 1000}` + `Count: {Count: 50}`; Consumer Stage 0 `TimeoutMs: 3000`; hermetic count=50.

---

### Q-114: Kafka Consumer Group — Two Groups Same Topic Independent Offsets

**Tier:** T4
**Goal:** Publish 10 messages to a Kafka topic; two Consumer sessions with different GroupIds each independently receive all 10 messages.
**SUT:**
- Kafka; topic with 1 partition; Publisher `Iterations: 10`; two Consumers with distinct GroupIds and `AutoOffsetReset: Earliest`.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.6 (Consumer `KafkaTopic` GroupId field), s09 #3, s13 #13.
**Trap mines:** s13 #13 (vacuous pass if GroupId reused from prior run — stale offset skips messages); `/qaas:docs runner/actions/consumers/kafkaTopic` required to confirm `GroupId` and `AutoOffsetReset` exact field names.
**Hard because:**
- GroupId must be unique per run OR topic must be reset between runs; use variable `${variables:runId}` in GroupId.
- Both consumers must use `AutoOffsetReset: Earliest`; default `Latest` misses pre-published messages.
- Two consumers in same session risk offset race if same GroupId used.

**Verify (mechanical):**
1. Consumer-A output count==10; Consumer-B output count==10.
2. Two `HermeticByExpectedOutputCount ExpectedCount=10` assertions pass.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: Distinct GroupIds; `AutoOffsetReset: Earliest`; hermetic guards on both; unique GroupId via variable.
- 6-8: Distinct GroupIds hardcoded; works on first run only.
- 1-5: Same GroupId; second consumer gets no messages; assertion fails.

**Solution sketch:** Variable `runId: test-run-1`; Consumer-A `GroupId: group-a-${variables:runId}`; Consumer-B `GroupId: group-b-${variables:runId}`; both `AutoOffsetReset: Earliest`; hermetic count=10 each.

---

### Q-115: Redis Keyspace Events — Consumer on __keyevent@0__:set

**Tier:** T4
**Goal:** Publish a key-set command to Redis and verify a keyspace event consumer on `__keyevent@0__:set` receives the notification.
**SUT:**
- Redis with `notify-keyspace-events KEA` configured; Publisher writes a key; Consumer subscribes `__keyevent@0__:set`.

**MOCK_REQUIRED:** no — real Redis.
**FB slices:** s02 §2.6 (Publisher Redis, Consumer Redis channel pattern), s11 (ExecuteRedisCommand probe to enable keyspace notifications), s09 #3.
**Trap mines:** s13 #12 (channel pattern typo silently delivers nothing); keyspace events disabled by default — must be enabled via `ExecuteRedisCommand` probe or Redis config.
**Hard because:**
- Keyspace notifications disabled by default; `ExecuteRedisCommand` probe must run `CONFIG SET notify-keyspace-events KEA` at Stage 0.
- Consumer channel name `__keyevent@0__:set` must exactly match Redis notification channel including DB index.
- `/qaas:docs runner/actions/publishers/redis` and `/qaas:docs runner/actions/consumers/redis` needed for channel field name.

**Verify (mechanical):**
1. Consumer output count≥1 after Publisher writes key.
2. `HermeticByExpectedOutputCount ExpectedCount=1` passes.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: `ExecuteRedisCommand` probe enables keyspace events; Consumer channel matches; hermetic guard.
- 6-8: Channel correct but keyspace events assumed enabled externally.
- 1-5: No probe; no keyspace events; Outputs=0 vacuous pass.

**Solution sketch:** Stage 0 probe `ExecuteRedisCommand` `Command: CONFIG SET notify-keyspace-events KEA`; Consumer Stage 0 channel `__keyevent@0__:set`; Publisher Stage 1 writes key; hermetic count=1.

---

### Q-116: Fanout to Three Queues — Per-Queue Hermetic Count + Aggregate

**Tier:** T4
**Goal:** Publish 5 messages to a fanout exchange bound to 3 queues; assert each queue receives exactly 5 messages AND aggregate total is 15.
**SUT:**
- RabbitMQ fanout; 3 queues + bindings; Publisher `Iterations: 5`; 3 Consumers.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.6, s09 #3 (per-queue), s09 #5 (`HermeticByInputOutputPercentage` aggregate), s11 §11.1.
**Trap mines:** s13 #17 (all 3 queues + all 3 bindings must be pre-declared); s13 #13 (any consumer with TimeoutMs too short → partial output → aggregate % < 100).
**Hard because:**
- 3 separate hermetic assertions + 1 aggregate; total 4 assertion entries.
- Aggregate percentage `InputNames: [Publisher]` with 5 inputs, `OutputNames: [C1,C2,C3]` with 15 outputs → `ExpectedPercentage: 300` (each message replicated 3×).
- `HermeticByInputOutputPercentage` with percentage > 100 is valid for fanout.

**Verify (mechanical):**
1. Each of 3 consumer outputs: count==5.
2. Three `HermeticByExpectedOutputCount ExpectedCount=5` pass.
3. `HermeticByInputOutputPercentage ExpectedPercentage=300` passes.

**Rubric (graded):**
- 9-10: All 4 assertions present; percentage=300 correctly computed; all topology probes.
- 6-8: Per-queue hermetic guards but no aggregate; or aggregate present with wrong percentage.
- 1-5: Single aggregate only or no hermetic guards.

**Solution sketch:** 3 Create probes; Publisher `Iterations: 5`; 3 Consumers Stage 0; 3 `HermeticByExpectedOutputCount ExpectedCount=5`; 1 `HermeticByInputOutputPercentage ExpectedPercentage=300`.

---

### Q-117: Topic Exchange Routing Matrix — Four Binding Patterns

**Tier:** T4
**Goal:** Build a topic exchange routing matrix: 4 queues with patterns `order.*`, `*.eu`, `order.eu`, `#`; publish messages with 3 distinct routing keys and assert per-queue delivery counts.
**SUT:**
- RabbitMQ topic exchange; 4 queues; 3 Publisher sessions with different RoutingKeys.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.6, s11 §11.1, s09 #3, s13 #17.
**Trap mines:** s13 #17; routing key `order.eu` matches `order.*`, `*.eu`, `order.eu`, and `#` — 4 queues; key `order.us` matches `order.*` and `#` — 2 queues; key `payment.eu` matches `*.eu` and `#` — 2 queues. Counts: q1=2, q2=2, q3=1, q4=3.
**Hard because:**
- Must pre-compute expected counts for each queue given routing keys and binding patterns.
- 4 consumers + 4 hermetic assertions; any miscalculation fails an assertion and model must diagnose the routing algebra.
- Wildcard `*` matches exactly one word; `#` matches zero or more — easy to confuse.

**Verify (mechanical):**
1. `HermeticByExpectedOutputCount` for q1=2, q2=2, q3=1, q4=3 all pass.
2. ExitCode==0.

**Rubric (graded):**
- 9-10: Pre-computed counts correct; all 4 hermetic guards; topology probe declares correct binding patterns.
- 6-8: Counts for simple patterns correct; `#` catch-all count wrong.
- 1-5: Single queue or no hermetic guards; routing algebra not verified.

**Solution sketch:** 3 Publisher sessions each with `Iterations: 1` and distinct RoutingKeys; 4 Consumers; 4 hermetic assertions with pre-computed counts; Stage 0 topology.

---

### Q-118: Delayed Message via SleepTimeMs — Verify Delay Assertion

**Tier:** T4
**Goal:** Use `SleepTimeMs: 1000` between Publisher iterations to simulate message pacing and assert average delay between input timestamps and output timestamps is within bounds.
**SUT:**
- RabbitMQ direct exchange; Publisher `Iterations: 5, SleepTimeMs: 1000`; Consumer; `DelayByAverage` assertion.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.6 (Publisher `SleepTimeMs`), s09 #1 (`DelayByAverage`: `InputName, OutputName, MaximumDelayMs`), s11 §11.1.
**Trap mines:** s13 #13 (empty consumer output → DelayByAverage passes vacuously — always add hermetic guard alongside); s09 #1 (empty output → pass; must combine with hermetic count).
**Hard because:**
- `DelayByAverage` measures avg(input_ts) vs avg(output_ts); with uniform SleepTimeMs this is stable.
- `MaximumDelayMs` must account for broker latency + pacing; too tight fails on slow CI; too loose is meaningless.
- Must pair with `HermeticByExpectedOutputCount` to prevent vacuous pass.

**Verify (mechanical):**
1. Consumer output count==5; hermetic passes.
2. `DelayByAverage MaximumDelayMs: 3000` passes.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: `HermeticByExpectedOutputCount` paired with `DelayByAverage`; `MaximumDelayMs` ≥ 2500 for CI slack.
- 6-8: `DelayByAverage` present but no hermetic guard; vacuous-pass risk.
- 1-5: No delay assertion; `SleepTimeMs` not used; requirement unverified.

**Solution sketch:** Publisher `Iterations: 5, SleepTimeMs: 1000`; `DelayByAverage MaximumDelayMs: 3000`; `HermeticByExpectedOutputCount ExpectedCount=5`.

---

### Q-119: Large Message Body — Binary Serialization End-to-End

**Tier:** T4
**Goal:** Publish a 1 MB binary payload via RabbitMQ and consume it, verifying the body is deserializable and count is hermetically correct.
**SUT:**
- RabbitMQ direct exchange; Publisher with `Serialize: {Serializer: Binary}`; Consumer with `Deserialize: {Deserializer: Binary}`; data source file containing 1 MB binary blob.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.8 (Serializers/Deserializers), s02 §2.5 (DataSources `FromFileSystem`), s09 #8 (`OutputDeserializableTo`), s09 #3, s11 §11.1.
**Trap mines:** s13 #17; RabbitMQ default max message size (128 MB) not a concern at 1 MB but frame_max may be relevant for very large payloads; binary deserializer requires matching serializer on both ends.
**Hard because:**
- `OutputDeserializableTo` assertion verifies deserialization succeeds; requires `Deserialize.Deserializer: Binary` and matching `SpecificType` if typed.
- Data source file must be present at runner CWD; path relative to runner execution.
- `QaaS.Common.Assertions` package required for `OutputDeserializableTo`.

**Verify (mechanical):**
1. Consumer output count==1; hermetic passes.
2. `OutputDeserializableTo` assertion passes.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: Matching Binary serializer/deserializer on both sides; `OutputDeserializableTo` + hermetic guard.
- 6-8: Correct serializers; hermetic guard present; no `OutputDeserializableTo`.
- 1-5: No explicit serializer; assumes string body; large payload not tested.

**Solution sketch:** DataSource `FromFileSystem` pointing to binary test file; Publisher `Serialize: {Serializer: Binary}`; Consumer `Deserialize: {Deserializer: Binary}`; `OutputDeserializableTo` + `HermeticByExpectedOutputCount`.

---

### Q-120: Header Routing Matrix — Two Binding Variants, Assert Each

**Tier:** T4
**Goal:** Route messages to two different queues based on header values using a headers exchange with `x-match: any`; assert per-queue delivery counts from a 2×2 header matrix.
**SUT:**
- RabbitMQ headers exchange; Queue-A bound `{x-match: any, env: prod}`; Queue-B bound `{x-match: any, region: eu}`; 4 publisher messages with header combinations: `env=prod,region=us` → A only; `env=dev,region=eu` → B only; `env=prod,region=eu` → A+B; `env=dev,region=us` → neither.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.6, s11 §11.1 (`CreateRabbitMqBindings` Arguments), s09 #3, s13 #17.
**Trap mines:** s13 #12 (`x-match` key silently ignored if wrong); `any` vs `all` — `any` routes on first matching header; pre-compute: A gets 3 messages, B gets 2 messages.
**Hard because:**
- `x-match: any` means at least one header matches; routing algebra must be pre-computed for the assertion.
- Publisher must send per-message headers; QaaS Publisher `Headers` field must be parameterized via data source — requires `/qaas:docs runner/actions/publishers/rabbitMq` to confirm dynamic headers support.
- 4th message delivers to neither queue; must assert neither consumer receives it.

**Verify (mechanical):**
1. Queue-A consumer output==3; `HermeticByExpectedOutputCount ExpectedCount=3` passes.
2. Queue-B consumer output==2; `HermeticByExpectedOutputCount ExpectedCount=2` passes.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: Pre-computed counts correct for `x-match: any`; both hermetic guards; 4th message excluded.
- 6-8: Counts correct but 4th message not verified as unrouted.
- 1-5: Wrong `x-match`; single queue; counts incorrect.

**Solution sketch:** Stage 0 probes; 4-row JSON data source with per-row headers; Publisher iterates over data source; Queue-A hermetic=3, Queue-B hermetic=2.

---

### Q-121: Mixed-Broker Pipeline — HTTP Ingress → RabbitMQ Work Queue → Consumer Assert

**Tier:** T4
**Goal:** Verify a SUT that accepts HTTP POST requests and enqueues messages to RabbitMQ; QaaS Transaction sends the POST and a Consumer reads the resulting queue entry.
**SUT:**
- Dockerized HTTP service + RabbitMQ; HTTP endpoint POST `/ingest` writes to queue `work-queue`.

**MOCK_REQUIRED:** no (real SUT + real broker) — mocker not needed.
**FB slices:** s02 §2.6 (Transactions HTTP, Consumer RabbitMQ), s09 #3, s09 #11 (HttpStatus), s11 §11.1, s13 #5 (Route no leading slash), s13 #5b (lowercase route).
**Trap mines:** s13 #5 (`Route: ingest` not `Route: /ingest`); s13 #5b (all-lowercase); s13 #13 (HttpStatus vacuous pass if Transaction output=0 — add hermetic guard on Transaction output); s13 #3 (Transaction requires `DataSourceNames`).
**Hard because:**
- Two action types in one session: Transaction (HTTP) + Consumer (RabbitMQ) at different stages.
- Consumer must start before Transaction fires (Stage 0 vs Stage 2); otherwise messages may arrive before consumer subscribes.
- `DataSourceNames` required on Transaction even if body is trivial (s13 #3).

**Verify (mechanical):**
1. Transaction output count==1; `HttpStatus StatusCode: 202` passes.
2. Consumer (RabbitMQ) output count==1; hermetic count=1 passes.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: Transaction `DataSourceNames` set; `Route: ingest` (no slash, lowercase); Consumer at Stage 0; hermetic guards on both outputs.
- 6-8: `Route` correct; Transaction has DataSourceNames; no Consumer hermetic guard.
- 1-5: `Route: /ingest` trap; or Transaction missing DataSourceNames; Consumer empty.

**Solution sketch:** Consumer Stage 0 `InitialTimeoutMs: 5000`; Transaction Stage 2 `Route: ingest` (lowercase, no slash); `HttpStatus StatusCode: 202`; `HermeticByExpectedOutputCount` on both outputs.

---

### Q-122: Poison Message — DLQ After Max-Retry Count

**Tier:** T4
**Goal:** Configure a queue with `x-delivery-limit` (quorum queue) so that a message that cannot be processed is dead-lettered to a DLQ after 3 delivery attempts; assert DLQ consumer receives exactly 1 message.
**SUT:**
- RabbitMQ quorum queue with `x-delivery-limit: 3` and `x-dead-letter-exchange: poison-dlx`; consumer NACKs without requeue; after 3 attempts message routes to DLQ.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.6, s11 §11.1 (`CreateRabbitMqQueues` Arguments), s09 #3, s13 #17.
**Trap mines:** s13 #17 (quorum queue requires `durable: true` and type=quorum via Arguments); `x-delivery-limit` only works on quorum queues; classic queue ignores it silently (s13 #12 silent ignore).
**Hard because:**
- QaaS Consumer cannot NACK explicitly; need SUT-side consumer doing NACK + requeue loop — or test harness simulates by NOT consuming (let timeout → nack) N times.
- Quorum queue declaration uses `Arguments: {x-queue-type: quorum}` — if omitted, classic queue is created and `x-delivery-limit` is silently ignored.
- `/qaas:docs runner/actions/probes/createRabbitMqQueues` needed to verify quorum queue argument syntax.

**Verify (mechanical):**
1. DLQ consumer output==1; hermetic count=1 passes.
2. Source queue consumer output==0 (or absent).
3. ExitCode==0.

**Rubric (graded):**
- 9-10: Quorum queue with `x-queue-type: quorum` + `x-delivery-limit: 3`; DLQ topology; hermetic on DLQ.
- 6-8: Classic queue with TTL used as proxy; semantics differ from max-retry.
- 1-5: No DLQ; message lost; no assertion.

**Solution sketch:** Stage 0: declare quorum source queue `Arguments: {x-queue-type: quorum, x-delivery-limit: 3, x-dead-letter-exchange: poison-dlx}`; declare DLQ; Publisher sends 1 message; no source consumer (timeout→nack); DLQ Consumer `InitialTimeoutMs: 10000`; hermetic count=1.

---

### Q-123: Kafka Partition Ordering — Single Partition Guarantees Sequence

**Tier:** T4
**Goal:** Publish 10 messages to a single-partition Kafka topic with sequential numeric payloads and assert the consumer receives them in published order.
**SUT:**
- Kafka topic with `num.partitions=1`; Publisher `Iterations: 10`; Consumer; `OutputContentByExpectedCsvResults` validates ordering.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.6 (KafkaTopic Publisher/Consumer), s02 §2.5 (DataSources ordered), s09 #10 (`OutputContentByExpectedCsvResults`), s09 #3, s13 #13.
**Trap mines:** s13 #13 (vacuous hermetic pass if consumer gets 0 — add hermetic guard); `/qaas:docs runner/actions/publishers/kafkaTopic` for `PartitionKey` field; `DataArrangeOrder: AsciiAsc` ensures deterministic send order.
**Hard because:**
- Ordering is only guaranteed within a single partition; must ensure topic has exactly 1 partition.
- `OutputContentByExpectedCsvResults` needs a CSV data source with expected payload column ordered 1–10.
- Consumer must use `AutoOffsetReset: Earliest` and unique GroupId.

**Verify (mechanical):**
1. Consumer output count==10; hermetic passes.
2. `OutputContentByExpectedCsvResults` validates payload sequence 1–10 in order.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: Single partition; `AutoOffsetReset: Earliest`; ordering assertion with CSV; hermetic guard.
- 6-8: Hermetic count passes but ordering not asserted.
- 1-5: Multiple partitions; ordering not guaranteed; no ordering assertion.

**Solution sketch:** DataSource: CSV with 10 rows payload 1–10; Publisher `DataArrangeOrder: AsciiAsc`; Consumer `AutoOffsetReset: Earliest`; `OutputContentByExpectedCsvResults` with `CompareRowsNotInOrder: false`.

---

### Q-124: RabbitMQ PurgeQueue Probe — Isolation Between Test Runs

**Tier:** T4
**Goal:** Use `PurgeRabbitMqQueues` probe at the start of a session to drain leftover messages from a previous run, ensuring a clean-state hermetic assertion.
**SUT:**
- RabbitMQ with a persistent durable queue that may have leftover messages; Probe purges at Stage 0 before Publisher; hermetic count based only on messages sent this run.

**MOCK_REQUIRED:** no.
**FB slices:** s11 §11.1 (`PurgeRabbitMqQueues`), s02 §2.6, s09 #3, s13 #17.
**Trap mines:** s13 #17 (queue must exist before purge probe — declare with `CreateRabbitMqQueues` if not pre-existing); purge probe must be at a stage BEFORE publisher, not after.
**Hard because:**
- Order: purge (Stage 0) → Consumer (Stage 0 but higher action order) → Publisher (Stage 1); if purge fires after consumer starts, consumer may read stale messages.
- `QaaS.Common.Probes` pkg required.
- Without purge, hermetic count includes leftover messages → false positive.

**Verify (mechanical):**
1. Consumer output count==5 (Publisher `Iterations: 5`); no stale messages in count.
2. `HermeticByExpectedOutputCount ExpectedCount=5` passes on fresh run AND on repeated run.
3. ExitCode==0 on second consecutive run.

**Rubric (graded):**
- 9-10: Purge probe at Stage 0 before Consumer; hermetic count deterministic across runs.
- 6-8: Purge probe present but stage after Consumer; stale messages possible.
- 1-5: No purge probe; hermetic count non-deterministic on repeated runs.

**Solution sketch:** Stage 0: `PurgeRabbitMqQueues`; Stage 0 (later): Consumer; Stage 1: Publisher `Iterations: 5`; hermetic count=5.

---

### Q-125: Advanced Load Balance — Staged Ramp-Up With Hermetic Range

**Tier:** T4
**Goal:** Use `AdvancedLoadBalance` with three rate stages (ramp-up, sustain, ramp-down) and assert total delivered message count falls within an expected range.
**SUT:**
- RabbitMQ direct exchange; Publisher with `AdvancedLoadBalance{Stages:[{Rate:5,TimeoutMs:1000},{Rate:20,TimeoutMs:3000},{Rate:5,TimeoutMs:1000}]}`; Consumer.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.7 (`AdvancedLoadBalance` Stages fields: Rate, Amount, TimeIntervalMs, TimeoutMs), s09 #4 (`HermeticByExpectedOutputCountInRange`), s11 §11.1.
**Trap mines:** s13 #13 (Consumer timeout must cover full ramp window ~5s + slack); `AdvancedLoadBalance` stage `TimeoutMs` vs `TimeIntervalMs` — `TimeoutMs` ends the stage after that duration; `TimeIntervalMs` is the tick interval within the stage.
**Hard because:**
- Total messages ≈ 5×1 + 20×3 + 5×1 = 70; but `TimeIntervalMs` may not be 1000ms — must set explicitly.
- Use `HermeticByExpectedOutputCountInRange` with slack ±5% due to timing jitter.
- Consumer `TimeoutMs: 3000` (since-last-msg) must not fire during ramp pauses.

**Verify (mechanical):**
1. Publisher input count in [60, 80].
2. `HermeticByExpectedOutputCountInRange ExpectedMinimumCount=60 ExpectedMaximumCount=80` passes.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: All 3 stages specified; `TimeIntervalMs: 1000`; range assertion with slack; Consumer `TimeoutMs ≥ 3000`.
- 6-8: Two stages; `LoadBalance` instead of `AdvancedLoadBalance`; range too tight.
- 1-5: No rate policy; single `Iterations`; requirement unmet.

**Solution sketch:** `AdvancedLoadBalance Stages: [{Rate:5,TimeIntervalMs:1000,TimeoutMs:1000},{Rate:20,TimeIntervalMs:1000,TimeoutMs:3000},{Rate:5,TimeIntervalMs:1000,TimeoutMs:1000}]`; Consumer `TimeoutMs: 3000`; `HermeticByExpectedOutputCountInRange` [60, 80].

---

### Q-126: Throughput Window — 100 Messages in 5 Seconds, Hermetic Range

**Tier:** T4
**Goal:** Confirm the SUT can process 100 RabbitMQ messages within a 5-second window by publishing with `LoadBalance{Rate:20, TimeIntervalMs:1000}` and asserting consumer output count in range [95,105].
**SUT:**
- RabbitMQ + consumer SUT service; Publisher `LoadBalance{Rate:20,TimeIntervalMs:1000}` + `Count{Count:100}`.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.7 (LoadBalance, Count policies), s09 #4 (`HermeticByExpectedOutputCountInRange`), s11 §11.1, s13 #13.
**Trap mines:** s13 #13 (Consumer `InitialTimeoutMs` must cover the full 5s send window; use `InitialTimeoutMs: 7000`); `Count` policy without `LoadBalance` would send all 100 at once, not rate-limited.
**Hard because:**
- `Count: {Count: 100}` caps total; without it `LoadBalance` runs indefinitely.
- Rate=20, window=5s → exactly 100; but timing jitter means ±5 tolerance needed.
- Consumer `TimeoutMs` (between messages) must be set to survive brief gaps in the stream.

**Verify (mechanical):**
1. Publisher input count==100.
2. Consumer output count in [95,105]; `HermeticByExpectedOutputCountInRange` passes.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: `LoadBalance` + `Count: {Count: 100}`; Consumer `InitialTimeoutMs: 7000, TimeoutMs: 2000`; range assertion.
- 6-8: `Count` present but no `LoadBalance`; messages sent at max rate; throughput not tested.
- 1-5: No policies; `Iterations: 100`; instant burst; no range assertion.

**Solution sketch:** Publisher policies `LoadBalance: {Rate: 20, TimeIntervalMs: 1000}` + `Count: {Count: 100}`; Consumer `InitialTimeoutMs: 7000, TimeoutMs: 2000`; `HermeticByExpectedOutputCountInRange [95,105]`.

---

### Q-127: RabbitMQ Binding Probe — Exchange-to-Queue Wiring Before Publish

**Tier:** T4
**Goal:** Demonstrate that omitting `CreateRabbitMqBindings` (exchange+queue declared but not wired) causes Outputs=0, while adding the binding probe fixes delivery.
**SUT:**
- RabbitMQ direct exchange + queue; Session-A: exchange+queue declared but NO binding (negative test); Session-B: adds binding probe.

**MOCK_REQUIRED:** no.
**FB slices:** s11 §11.1 (`CreateRabbitMqBindings` — Exchange, Queue, RoutingKey fields), s02 §2.6, s09 #3, s13 #17.
**Trap mines:** s13 #17 covers exchange+queue existence but not binding — binding is a separate step; s13 #13 (Outputs=0 hermetic vacuous pass on Session-A — requires explicit ExpectedCount=0 to surface the negative case).
**Hard because:**
- Session-A must use hermetic count=0 to confirm that zero delivery is expected there (and not vacuously passing).
- `CreateRabbitMqBindings` requires `Exchange`, `Queue`, and `RoutingKey` fields in ProbeConfiguration.
- Two sessions must share the same exchange/queue but Session-A must not contaminate Session-B via leftover messages.

**Verify (mechanical):**
1. Session-A consumer output==0; `HermeticByExpectedOutputCount ExpectedCount=0` passes.
2. Session-B consumer output==1; `HermeticByExpectedOutputCount ExpectedCount=1` passes.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: Both sessions present; Session-A explicitly guards with count=0; Session-B adds binding probe.
- 6-8: Session-B only; negative case not demonstrated.
- 1-5: No binding probe; no hermetic guard; single session.

**Solution sketch:** Session-A (no binding): Publisher + Consumer + hermetic=0; Session-B: `CreateRabbitMqBindings` probe added at Stage 0; Publisher + Consumer + hermetic=1.

---

### Q-128: Kafka — Unique GroupId via Variable for Deterministic Reruns

**Tier:** T4
**Goal:** Parameterize the Kafka GroupId using a `variables` section so each test run gets a unique consumer group, preventing stale-offset issues across reruns.
**SUT:**
- Kafka topic; Publisher `Iterations: 5`; Consumer with `GroupId: ${variables:groupId}`; variable set via overwrite file per environment.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.2 (variables syntax `${variables:key}`), s02 §2.11 (overwrite files), s02 §2.6 (Consumer KafkaTopic), s09 #3, s13 #13.
**Trap mines:** s13 #13 (stale GroupId from prior run → consumer starts at latest offset → Outputs=0 → vacuous pass); variable syntax must use `${variables:key}` not `${{key}}` or `${key}`.
**Hard because:**
- Variable default value syntax `${variables:groupId??default-group}` allows fallback but hides misconfiguration.
- GroupId uniqueness in CI requires injection via `-r variables:groupId=<buildId>` CLI flag.
- `/qaas:docs qaas/quickStart/makeTestMoreMaintainable` for overwrite file format.

**Verify (mechanical):**
1. Two consecutive runs with different `-r variables:groupId=run1` and `run2` both produce output==5.
2. `HermeticByExpectedOutputCount ExpectedCount=5` passes on both runs.
3. ExitCode==0 both times.

**Rubric (graded):**
- 9-10: Variable-parameterized GroupId; overwrite file or `-r` flag documented; hermetic guard; `AutoOffsetReset: Earliest`.
- 6-8: Variable used but no `-r` flag guidance; single run only.
- 1-5: Hardcoded GroupId; second run may fail.

**Solution sketch:** `variables: groupId: test-run-1`; Consumer `GroupId: ${variables:groupId}`; overwrite `local.yaml` sets GroupId; `AutoOffsetReset: Earliest`; hermetic=5.

---

### Q-129: RabbitMQ Vhost Isolation — Two Vhosts, No Cross-Bleed

**Tier:** T4
**Goal:** Declare the same exchange name in two different RabbitMQ vhosts and verify messages published to vhost-A do not appear in vhost-B's consumer.
**SUT:**
- RabbitMQ with two vhosts `vh-a` and `vh-b`; probes create `CreateRabbitMqVirtualHosts` and then topology per vhost; two independent Publisher+Consumer pairs.

**MOCK_REQUIRED:** no.
**FB slices:** s11 §11.1 (`CreateRabbitMqVirtualHosts`, `UpsertRabbitMqPermissions`), s02 §2.6 (Publisher/Consumer `VirtualHost` field), s09 #3, s13 #17.
**Trap mines:** s13 #17 (topology must be created per vhost, not just on default vhost); `CreateRabbitMqExchanges` `VirtualHost` field must be set or defaults to `/` — declarations on wrong vhost cause classId=40.
**Hard because:**
- Vhost creation AND user permission grant must happen at Stage 0 before topology probes.
- Publisher/Consumer `VirtualHost` field must match exactly.
- Cross-bleed negative check requires vhost-B consumer to assert count=0 when only vhost-A receives messages.

**Verify (mechanical):**
1. vhost-A consumer output==1; hermetic passes.
2. vhost-B consumer output==0; `HermeticByExpectedOutputCount ExpectedCount=0` passes.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: Both vhosts created; permissions granted; topology per vhost; cross-bleed guard with count=0.
- 6-8: Topology correct per vhost; no cross-bleed check.
- 1-5: Default vhost only; vhost isolation not tested.

**Solution sketch:** Stage 0: `CreateRabbitMqVirtualHosts` for vh-a, vh-b + `UpsertRabbitMqPermissions`; topology probes with `VirtualHost` set; vhost-A Publisher+Consumer hermetic=1; vhost-B Consumer hermetic=0.

---

### Q-130: Kafka Topic — IncreasingLoadBalance with Hermetic Percentage Range

**Tier:** T4
**Goal:** Publish to Kafka with `IncreasingLoadBalance{StartRate:1, MaxRate:20, RateIncrease:1, RateIncreaseIntervalMs:500, TimeIntervalMs:1000}` capped by `Count{Count:50}` and assert delivery percentage is in [90,100].
**SUT:**
- Kafka topic; Publisher with `IncreasingLoadBalance` + `Count` policies; Consumer `AutoOffsetReset: Earliest`.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.7 (`IncreasingLoadBalance` exact fields), s02 §2.6, s09 #6 (`HermeticByInputOutputPercentageInRange`), s13 #13.
**Trap mines:** s13 #13 (Kafka consumer offset default=Latest; must set Earliest); `Count` policy required to prevent indefinite ramp; `IncreasingLoadBalance` rate can exceed `Count` — the Count cap is the actual sent total.
**Hard because:**
- `IncreasingLoadBalance` field names must be exact: `StartRate`, `MaxRate`, `RateIncrease`, `RateIncreaseIntervalMs`, `TimeIntervalMs` — any typo silently ignored.
- Consumer may not keep up with ramp; `HermeticByInputOutputPercentageInRange [90,100]` allows for lag.
- GroupId must be unique per run for Kafka.

**Verify (mechanical):**
1. Publisher input count==50 (capped by Count).
2. `HermeticByInputOutputPercentageInRange ExpectedMinimumPercentage=90 ExpectedMaximumPercentage=100` passes.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: All 5 `IncreasingLoadBalance` fields set; `Count: {Count: 50}`; range assertion [90,100]; unique GroupId.
- 6-8: `LoadBalance` instead; rate increase not demonstrated; range assertion present.
- 1-5: No policy; `Iterations: 50`; requirement unmet.

**Solution sketch:** Publisher `IncreasingLoadBalance: {StartRate:1,MaxRate:20,RateIncrease:1,RateIncreaseIntervalMs:500,TimeIntervalMs:1000}` + `Count: {Count:50}`; Consumer `AutoOffsetReset: Earliest, GroupId: ${variables:groupId}`; `HermeticByInputOutputPercentageInRange [90,100]`.

---

### Q-131: Topic Fan-Out to 4 Queues With Per-Queue TTL Cascading to Shared DLQ

**Tier:** T5
**Goal:** Fanout 5 messages across 4 topic-bound queues each with distinct TTLs (200ms, 400ms, 600ms, 800ms); all expire and route to a shared DLQ exchange; assert per-queue TTL fires before its consumer runs AND DLQ receives all 20 dead-lettered messages in total, with per-queue arrival-order assertions.
**SUT:**
- RabbitMQ topic exchange; 4 queues with `x-message-ttl` and `x-dead-letter-exchange: shared-dlx`; shared DLQ exchange + queue; Publisher sends 5 messages; no consumers on source queues (let TTL fire); DLQ Consumer with `InitialTimeoutMs: 3000`.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.6, s11 §11.1 (CreateRabbitMqQueues/Exchanges/Bindings with Arguments), s09 #3 (HermeticByExpectedOutputCount), s09 #5 (HermeticByInputOutputPercentage), s09 #1 (DelayByAverage per queue if consumers added), s13 #17, s13 #12.
**Trap mines:** s13 #17 (all 4 source queues + DLQ + DLQ binding must be pre-declared); s13 #12 (`x-dead-letter-exchange` silently ignored if key misspelled); s13 #13 (DLQ Consumer vacuous pass if `InitialTimeoutMs` < longest TTL 800ms + routing); per-queue hermetic only possible with per-queue DLQ routing — shared DLQ merges all messages.
**Hard because:**
- Shared DLQ receives 4 queues × 5 messages = 20 messages; hermetic count=20 on DLQ output.
- Must verify all 20 arrive (aggregate hermetic) AND per-queue origin can be traced via `x-death` header if consumer inspects it.
- `DelayByAverage` assertion is only meaningful if per-queue consumers are added for partial TTL check; otherwise aggregate timing only.
- 4+1 topology sets: 4 CreateRabbitMqQueues with distinct TTL Arguments; 1 DLQ exchange; 1 DLQ queue; 4 bindings to topic exchange + 1 DLQ exchange binding.

**Verify (mechanical):**
1. DLQ consumer output count==20; `HermeticByExpectedOutputCount ExpectedCount=20` passes.
2. DLQ consumer `InitialTimeoutMs ≥ 1500` (longest TTL + routing slack).
3. Per-queue hermetic counts each=5 if per-queue DLQ exchanges are used instead of shared.
4. ExitCode==0.

**Rubric (graded):**
- 9-10: 4 source queues with distinct TTLs; shared DLQ; hermetic count=20 on DLQ output; all topology probes correct; `x-dead-letter-exchange` key exact.
- 6-8: Shared DLQ but count=20 not verified; per-queue TTLs partially correct.
- 1-5: Only 1 queue with TTL; shared DLQ missing; aggregate count wrong.

**Solution sketch:** Stage 0: 5 probe calls (4 source queues, 1 DLQ exchange, 1 DLQ queue, 4+1 bindings); Publisher `Iterations: 5`; no source consumers; DLQ Consumer `InitialTimeoutMs: 2000`; `HermeticByExpectedOutputCount ExpectedCount=20`.

---

### Q-132: Competing Consumers With Increasing Load Balance — Hermetic Percentage + Per-Consumer Range

**Tier:** T5
**Goal:** Ramp message production from 5/s to 50/s using `IncreasingLoadBalance`; 5 competing consumers share one queue; assert aggregate delivery ≥ 95% AND each individual consumer receives a non-zero share using `HermeticByInputOutputPercentageInRange`.
**SUT:**
- RabbitMQ direct exchange + single queue; 5 Consumer entries in session; Publisher `IncreasingLoadBalance` + `Count{Count: 200}`.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.7 (IncreasingLoadBalance), s02 §2.6, s09 #5 (HermeticByInputOutputPercentage), s09 #6 (HermeticByInputOutputPercentageInRange), s11 §11.1, s13 #13.
**Trap mines:** s13 #13 (Consumer TimeoutMs must survive rate ramp gaps); s09 #5 (0 inputs + some outputs → fail — Publisher must fire before any consumer assertion reads); per-consumer range must allow for uneven distribution (some consumers may get 30%, others 10%).
**Hard because:**
- 5 consumer output names in both aggregate and per-consumer assertions → 6 assertion entries total.
- Per-consumer expected range must be realistic: `[1, 100]` percentage of publisher input is valid but trivial; a meaningful range like `[5, 60]` tests that no one consumer starves.
- `Count: {Count: 200}` must be placed correctly; without it `IncreasingLoadBalance` loops.

**Verify (mechanical):**
1. Sum of 5 consumer outputs ≥ 190; aggregate `HermeticByInputOutputPercentageInRange [95,110]` passes.
2. Each consumer output ≥ 1; per-consumer `HermeticByInputOutputPercentageInRange [1,80]` passes.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: Aggregate + 5 per-consumer assertions; range values realistic; `Count` policy; `IncreasingLoadBalance` all 5 fields.
- 6-8: Aggregate assertion only; no per-consumer fairness check.
- 1-5: No `IncreasingLoadBalance`; single Consumer; requirement unmet.

**Solution sketch:** `IncreasingLoadBalance{StartRate:5,MaxRate:50,RateIncrease:5,RateIncreaseIntervalMs:1000,TimeIntervalMs:1000}` + `Count{Count:200}`; 5 Consumers; aggregate `HermeticByInputOutputPercentageInRange [95,110]`; per-consumer `[1,80]`.

---

### Q-133: Broker Restart Resilience — OsRestartPods Probe Mid-Run

**Tier:** T5
**Goal:** Use `OsRestartPods` probe to restart the RabbitMQ pod mid-test after publishing batch-1; wait for readiness; then publish batch-2; assert aggregate consumer count equals batch-1+batch-2.
**SUT:**
- Kubernetes/OpenShift with RabbitMQ; first session: publish 10, restart broker pod, wait, publish 10 more; Consumer collects all 20.

**MOCK_REQUIRED:** no.
**FB slices:** s11 §11.1 (`OsRestartPods` probe), s02 §2.6 (Stages, Publishers, Consumers), s09 #3, s13 #17.
**Trap mines:** s13 #17 (after restart, topology declared as durable survives; non-durable exchanges/queues are lost → test must use `Durable: true` on all topology); Consumer must have `TimeoutMs` long enough to bridge the restart window.
**Hard because:**
- Stage ordering: Publisher-batch1 (Stage 1) → OsRestartPods (Stage 2) → readiness Probe (Stage 3, PingProbe/WaitForUrl) → Publisher-batch2 (Stage 4) → Consumer reads all.
- Consumer must remain connected or reconnect after restart; if Consumer drains before batch-2 arrives, timeout fires too early.
- Requires cluster access; `/qaas:docs runner/actions/probes/osRestartPods` needed for OsNamespace, OsDeploymentName fields.

**Verify (mechanical):**
1. Consumer output count==20; `HermeticByExpectedOutputCount ExpectedCount=20` passes.
2. Restart probe completes without error.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: All 5 stages ordered; durable topology; Consumer `TimeoutMs ≥ 15000`; hermetic count=20.
- 6-8: Restart probe present but non-durable topology; messages lost after restart; count < 20.
- 1-5: No restart probe; sequential publishers without broker disruption.

**Solution sketch:** Durable exchange + queue; Consumer Stage 0 `InitialTimeoutMs: 30000, TimeoutMs: 10000`; Publisher-batch1 Stage 1; `OsRestartPods` Stage 2; readiness `PingProbe` Stage 3; Publisher-batch2 Stage 4; hermetic count=20.

---

### Q-134: Three-Level DLQ Cascade — Source → DLQ1 → DLQ2 → Consumer

**Tier:** T5
**Goal:** Chain three queues: source queue (TTL→DLX1→DLQ1), DLQ1 (TTL→DLX2→DLQ2), DLQ2 consumed by QaaS consumer; assert the original message body arrives unchanged at DLQ2 consumer.
**SUT:**
- RabbitMQ; three queues with chained dead-letter-exchange arguments; Publisher sends 1 message; no consumers on source or DLQ1; DLQ2 Consumer asserts body.

**MOCK_REQUIRED:** no.
**FB slices:** s11 §11.1 (CreateRabbitMqQueues/Exchanges/Bindings, Arguments), s02 §2.6, s09 #10 (`OutputContentByExpectedCsvResults`), s09 #3, s13 #17, s13 #12.
**Trap mines:** s13 #12 (`x-dead-letter-exchange`, `x-message-ttl` keys must be exact — silently ignored on typo); cascade timing: total TTL chain = TTL1+TTL2; `InitialTimeoutMs` on DLQ2 Consumer must exceed TTL1+TTL2+routing; s13 #13 (vacuous pass if InitialTimeoutMs too short).
**Hard because:**
- 3 exchanges + 3 queues + 3 bindings = 9 topology probes at Stage 0.
- Body preservation through dead-lettering: RabbitMQ preserves original message body; assertion on DLQ2 output body must match publisher payload.
- Cascade TTL timing must be measurable: TTL1=500ms, TTL2=500ms → total chain ≥ 1000ms; `InitialTimeoutMs ≥ 3000`.

**Verify (mechanical):**
1. DLQ2 consumer output count==1; `HermeticByExpectedOutputCount ExpectedCount=1` passes.
2. `OutputContentByExpectedCsvResults` confirms body matches original payload.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: Full 3-level chain; all 9 topology probes; body assertion at final DLQ; InitialTimeoutMs covers cascade.
- 6-8: 2-level chain; body assertion present.
- 1-5: Single DLQ; no body assertion; cascade not demonstrated.

**Solution sketch:** Stage 0: declare src (TTL=500,DLX=dlx1), dlq1 (TTL=500,DLX=dlx2), dlq2; 3 exchanges + 3 bindings; Publisher Stage 1; DLQ2 Consumer `InitialTimeoutMs: 3000`; hermetic=1 + body assertion.

---

### Q-135: Headers Exchange `x-match: all` vs `x-match: any` — Side-by-Side Contrast

**Tier:** T5
**Goal:** Run two parallel sessions: one with `x-match: all` (strict) and one with `x-match: any` (lenient) bound to the same headers exchange; publish 4 header-variant messages; assert per-session delivery counts differ as expected.
**SUT:**
- RabbitMQ headers exchange; Queue-ALL bound `{x-match: all, env: prod, region: eu}`; Queue-ANY bound `{x-match: any, env: prod, region: eu}`; 4 messages: both match, env only, region only, neither.

**MOCK_REQUIRED:** no.
**FB slices:** s11 §11.1, s02 §2.6, s09 #3, s13 #12, s13 #17.
**Trap mines:** s13 #12 (silently ignored binding arguments if mistyped `x-match`); expected counts: Queue-ALL gets 1 (both headers match); Queue-ANY gets 3 (any one header matches); 4th message (neither) gets 0 on both.
**Hard because:**
- Dynamic per-message headers require data source with 4 rows; confirm QaaS RabbitMQ Publisher supports per-row header injection via data source metadata field (requires `/qaas:docs`).
- Two consumers with distinct queues + 2 hermetic assertions with different counts.
- Must assert Queue-ANY count=3 NOT count=1 (common confusion).

**Verify (mechanical):**
1. Queue-ALL output==1; `HermeticByExpectedOutputCount ExpectedCount=1` passes.
2. Queue-ANY output==3; `HermeticByExpectedOutputCount ExpectedCount=3` passes.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: Correct `x-match` on both bindings; correct pre-computed counts; per-row headers from data source; both hermetic guards.
- 6-8: Counts correct but headers statically set on publisher (not per-message); only 2 messages tested.
- 1-5: Single queue; `x-match` semantics not differentiated.

**Solution sketch:** 4-row JSON DataSource with headers field; Publisher iterates data source; Stage 0 topology; `HermeticByExpectedOutputCount ExpectedCount=1` (ALL), `ExpectedCount=3` (ANY).

---

### Q-136: Multi-Session Fanout — Sessions 1+2+3 Publish, Session 4 Aggregates

**Tier:** T5
**Goal:** Three publisher sessions each send 10 messages to the same fanout exchange; a fourth Consumer session aggregates all 30 into one queue; assert aggregate hermetic count=30 and per-session contribution visible via `HermeticByInputOutputPercentage`.
**SUT:**
- RabbitMQ fanout exchange bound to single aggregate queue; 3 Publisher sessions each with `Iterations: 10`; 1 Consumer session.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.6 (`SessionNames` in assertions span multiple sessions), s09 #3, s09 #5, s11 §11.1, s13 #17, s13 #13.
**Trap mines:** s13 #17 (topology must be declared once, not re-declared in each publisher session — re-declare attempts may fail or silently succeed for idempotent probes; use `CreateRabbitMqExchanges` once in first session); s13 #13 (Consumer TimeoutMs must cover all 3 publisher sessions completing).
**Hard because:**
- `Assertions` `SessionNames` must reference all 4 sessions to collect inputs+output.
- Total publisher inputs = 30 (3 sessions × 10); `HermeticByInputOutputPercentage InputNames: [P1,P2,P3] OutputNames: [Consumer] ExpectedPercentage: 100` where inputs=30 and outputs=30.
- Session execution order must be controlled so Consumer session starts before publishers; multi-session ordering via `RunUntilStage` or separate session stages.

**Verify (mechanical):**
1. Consumer output count==30; `HermeticByExpectedOutputCount ExpectedCount=30` passes.
2. `HermeticByInputOutputPercentage` [P1+P2+P3] → Consumer `ExpectedPercentage=100` passes.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: `SessionNames` spans all sessions; two assertion types; Consumer before publishers; topology once.
- 6-8: Hermetic count=30 correct; `SessionNames` only references Consumer session.
- 1-5: Single session; 3 publishers not tested; multi-session mechanics missing.

**Solution sketch:** Session-Consumer Stage 0 `InitialTimeoutMs: 15000`; Sessions P1/P2/P3 `TimeoutBeforeSessionMs: 0`; topology in P1 only; `HermeticByExpectedOutputCount SessionNames: [P1,P2,P3,Consumer] ExpectedCount=30`.

---

### Q-137: Kafka + RabbitMQ Mixed-Broker — Publish to Kafka, Shovel to Rabbit, Assert Consumer

**Tier:** T5
**Goal:** Use a SUT service that consumes from Kafka and republishes to RabbitMQ; QaaS publishes to Kafka (Publisher `KafkaTopic`) and asserts the RabbitMQ consumer receives the same message count.
**SUT:**
- Kafka + RabbitMQ + a SUT bridge service; QaaS: Kafka Publisher → SUT bridge → RabbitMQ Consumer.

**MOCK_REQUIRED:** no — both brokers are real; SUT bridge is the tested component.
**FB slices:** s02 §2.6 (Publisher KafkaTopic, Consumer RabbitMq), s09 #5, s11 §11.1, s13 #13, s13 #17.
**Trap mines:** s13 #13 (Consumer TimeoutMs must account for Kafka→bridge→Rabbit latency, which may be several seconds); s13 #17 (RabbitMQ topology must be pre-declared even though SUT bridge also declares it — test must not rely on bridge declaration timing); s13 #3 (any Transaction in session needs DataSourceNames).
**Hard because:**
- Two broker protocols in one session; Consumer at Stage 0 (before Publisher), Publisher at Stage 1, but bridge processing time is opaque.
- `HermeticByInputOutputPercentage` spans Kafka input (Publisher) and RabbitMQ output (Consumer) across different protocols.
- Kafka consumer group offset for the BRIDGE must be separate from test consumer; test publishes to Kafka, bridge consumes Kafka and republishes to Rabbit, test consumes Rabbit.

**Verify (mechanical):**
1. Kafka Publisher input count==5.
2. RabbitMQ Consumer output count==5; `HermeticByInputOutputPercentage ExpectedPercentage=100` passes.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: RabbitMQ topology probes; Consumer at Stage 0; `HermeticByInputOutputPercentage` spans both; adequate Consumer `InitialTimeoutMs ≥ 10000`.
- 6-8: Both brokers used; no hermetic percentage linking them.
- 1-5: Single broker; bridge not tested; protocols not mixed.

**Solution sketch:** Stage 0: RabbitMQ topology probes + Consumer `InitialTimeoutMs: 10000`; Stage 1: Kafka Publisher `Iterations: 5`; `HermeticByInputOutputPercentage InputNames: [KafkaPublisher] OutputNames: [RabbitConsumer] ExpectedPercentage=100`.

---

### Q-138: MockerCommand Consume — Assert Mocker Received Expected Messages

**Tier:** T5
**Goal:** Use `MockerCommands` `Consume` to drain messages from the mocker's internal queue and assert the mocker received exactly the messages the QaaS session sent.
**SUT:**
- QaaS Mocker with a RabbitMQ server and `Consume` MockerCommand; Runner sends messages via Publisher; `Consume` command drains and asserts mocker-side receipt.

**MOCK_REQUIRED:** yes — Mocker required for MockerCommands control plane.
**FB slices:** s02 §2.6 (MockerCommands: Consume, ServerName, Redis control plane), s03 §3 (Mocker YAML servers/stubs), s09 #3, s13 #11 (Controller boot log exact text), s13 #19 (Redis port not published externally).
**Trap mines:** s13 #11 (Mocker boot log must show `Initialized Redis controller` — if not, MockerCommands silently time out); s13 #19 (Redis inside compose must NOT publish port to host); `Consume` is destructive — drains queue once; must not consume before publisher finishes; `ServerName` in MockerCommand must byte-match mocker `Controller.ServerName`.
**Hard because:**
- `MockerCommands` requires Redis reachable on the same network as the Runner; compose network setup with Redis service (no host port mapping per s13 #19).
- `Consume` `TimeoutMs` must be set (required field per s02 §2.6).
- `Consume` output count is the drained-message count; assert this with hermetic guard.
- If Redis unreachable, `MockerCommands` silently time out (no error) → outputs=0 → vacuous pass (s02 §2.6 note).

**Verify (mechanical):**
1. `Consume` output count==5; `HermeticByExpectedOutputCount ExpectedCount=5` passes.
2. Mocker boot log shows `Initialized Redis controller` (not old `Controller channel ready` text).
3. ExitCode==0.

**Rubric (graded):**
- 9-10: `ServerName` exact match; Redis no host port; `Consume TimeoutMs` set; hermetic count; correct boot log expected.
- 6-8: ServerName correct; Redis port published (s13 #19 violation); works if port unused.
- 1-5: No MockerCommands; mocker-side receipt not verified.

**Solution sketch:** Compose: Redis service, no `ports` mapping; Mocker `Controller.ServerName: test-mocker`; Runner MockerCommand `Consume TimeoutMs: 5000 ServerName: test-mocker`; hermetic count=5.

---

### Q-139: Throughput + DelayByChunks — Chunks of 10, Max Delay 500ms Per Chunk

**Tier:** T5
**Goal:** Publish 50 messages in chunks of 10 (via Publisher `Chunk{ChunkSize: 10}`) and assert each chunk-to-chunk delay is ≤ 500ms using `DelayByChunks`.
**SUT:**
- RabbitMQ direct exchange; Publisher `Chunk: {ChunkSize: 10}, Iterations: 50`; Consumer; `DelayByChunks` assertion.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.6 (Publisher `Chunk{ChunkSize}`), s09 #2 (`DelayByChunks` — exact config: `Input{Name,ChunkSize,ChunkTimeOption}`, `Output{Name,ChunkSize,ChunkTimeOption}`, `MaximumDelayMs`), s09 #3, s11 §11.1, s13 #13.
**Trap mines:** s13 #13 (vacuous pass if Consumer output=0; pair with hermetic count); s09 #2 (`DelayByChunks` requires both Input and Output chunked — consumer output chunks must align with publisher input chunks; same ChunkSize on both sides).
**Hard because:**
- `DelayByChunks` Input `ChunkSize` and Output `ChunkSize` must match Publisher `Chunk.ChunkSize`; mismatch produces incorrect chunk boundaries.
- `ChunkTimeOption: First|Average|Last` selection affects measured delay; must pick consistently on both sides.
- Consumer must receive exactly 50 messages; any dropout invalidates chunk boundary alignment.

**Verify (mechanical):**
1. Consumer output count==50; `HermeticByExpectedOutputCount ExpectedCount=50` passes.
2. `DelayByChunks MaximumDelayMs=500` passes.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: Publisher `Chunk.ChunkSize=10`; `DelayByChunks` Input+Output both `ChunkSize=10, ChunkTimeOption=First`; hermetic count=50.
- 6-8: `DelayByAverage` used instead; chunk boundaries not verified.
- 1-5: No chunk assertion; no hermetic guard; requirement unmet.

**Solution sketch:** Publisher `Chunk: {ChunkSize: 10}, Iterations: 50`; `DelayByChunks Input: {Name: Pub, ChunkSize: 10, ChunkTimeOption: First} Output: {Name: Con, ChunkSize: 10, ChunkTimeOption: First} MaximumDelayMs: 500`; `HermeticByExpectedOutputCount ExpectedCount=50`.

---

### Q-140: End-to-End: HTTP Ingress → Fanout → 4 Consumers → Per-Queue DelayByAverage + Aggregate Hermetic

**Tier:** T5
**Goal:** Send 10 HTTP POST requests to a SUT that fans out each to 4 RabbitMQ queues; assert per-queue `DelayByAverage ≤ 2000ms` AND aggregate hermetic count=40 (4 queues × 10 messages).
**SUT:**
- HTTP service (Mocker stub or real SUT) + RabbitMQ fanout; Transaction (HTTP) as input; 4 Consumers as outputs.

**MOCK_REQUIRED:** yes — Mocker provides HTTP stub that also publishes to RabbitMQ fanout (via stub processor or real SUT).
**FB slices:** s02 §2.6 (Transaction HTTP, Consumer RabbitMq), s03 (Mocker stub), s09 #1 (DelayByAverage), s09 #3 (HermeticByExpectedOutputCount), s09 #5, s11 §11.1, s13 #5, s13 #5b, s13 #13, s13 #16 (port contract).
**Trap mines:** s13 #5 (`Route: ingest` no leading slash); s13 #5b (all-lowercase); s13 #16 (probe port, mocker port, transaction port must all be the same literal); s13 #3 (Transaction needs DataSourceNames); s13 #13 (HttpStatus vacuous pass — add hermetic on Transaction output); aggregate hermetic must list all 4 consumer output names.
**Hard because:**
- 4 `DelayByAverage` assertions (one per queue) + 1 aggregate `HermeticByExpectedOutputCount` = 5 assertion entries.
- Transaction `InputName` used in all 4 `DelayByAverage` assertions as input; all 4 consumers as respective outputs.
- Mocker stub must be configured with correct lowercase route; port must match in probe, mocker, and transaction.

**Verify (mechanical):**
1. Transaction output count==10; `HttpStatus StatusCode: 200` passes.
2. Each of 4 consumer outputs count==10; 4 `HermeticByExpectedOutputCount ExpectedCount=10` pass.
3. Aggregate `HermeticByExpectedOutputCount ExpectedCount=40` on all 4 consumer outputs passes.
4. 4 `DelayByAverage MaximumDelayMs=2000` assertions pass.

**Rubric (graded):**
- 9-10: All 9 assertions (1 HttpStatus + 4 hermetic-per-queue + 1 aggregate + 4 DelayByAverage — 10 total); port contract consistent; `Route` lowercase no slash; Transaction `DataSourceNames` set.
- 6-8: Hermetic counts correct; no `DelayByAverage` or no aggregate.
- 1-5: Single consumer; no per-queue assertions; HTTP route trap hit.

**Solution sketch:** Mocker stub `Path: ingest` (lowercase); port 8080 in probe/mocker/transaction; Transaction `DataSourceNames` + `Route: ingest`; Stage 0: 4 Consumers + RabbitMQ topology; Stage 2: Transaction `Iterations: 10`; 10 assertions total.

---

### Q-141: Kafka — Compacted Topic, Only Latest Value per Key Survives

**Tier:** T5
**Goal:** Publish multiple messages with the same Kafka message key to a compacted topic; after compaction runs, Consumer should receive only the latest value for each key; assert count via `HermeticByExpectedOutputCountInRange`.
**SUT:**
- Kafka compacted topic (`cleanup.policy=compact`); Publisher sends 5 messages with key `k1` (overwriting value each time); Consumer after forced compaction receives 1 message.

**MOCK_REQUIRED:** no — real Kafka.
**FB slices:** s02 §2.6 (KafkaTopic Publisher `MessageKey` field — confirm via `/qaas:docs runner/actions/publishers/kafkaTopic`), s09 #4 (`HermeticByExpectedOutputCountInRange`), s09 #3, s13 #13.
**Trap mines:** s13 #13 (compaction is async; Consumer may receive 1–5 messages depending on compaction timing; use `HermeticByExpectedOutputCountInRange [1,5]`); Kafka `AutoOffsetReset: Earliest` required; compaction only removes earlier offsets, not mid-flight messages visible to active consumers.
**Hard because:**
- Compaction is non-deterministic in timing; assertion must use range not exact count.
- `MessageKey` field name on QaaS KafkaTopic Publisher not in Fact Base — requires `/qaas:docs runner/actions/publishers/kafkaTopic`.
- Topic must be pre-created with `cleanup.policy=compact`; QaaS has no probe for Kafka topic creation — requires external seed or admin probe (document as blocker).

**Verify (mechanical):**
1. Consumer output in [1,5]; `HermeticByExpectedOutputCountInRange ExpectedMinimumCount=1 ExpectedMaximumCount=5` passes.
2. ExitCode==0.
3. Model must flag `/qaas:docs runner/actions/publishers/kafkaTopic` lookup for `MessageKey` field.

**Rubric (graded):**
- 9-10: Range assertion [1,5]; `/qaas:docs` lookup cited for `MessageKey`; compaction timing limitation documented; `AutoOffsetReset: Earliest`.
- 6-8: Exact count assertion used (fragile); docs lookup cited but field not confirmed.
- 1-5: Exact count=1 asserted without range; no compaction timing awareness.

**Solution sketch:** Pre-created compacted topic (external); Publisher `Iterations: 5` same key; Consumer `AutoOffsetReset: Earliest`; `HermeticByExpectedOutputCountInRange [1,5]`; note `/qaas:docs runner/actions/publishers/kafkaTopic` for `MessageKey`.

---

### Q-142: Redis Pub/Sub — Multiple Channels, Per-Channel Hermetic Count

**Tier:** T5
**Goal:** Publish 5 messages to Redis channel `events.orders` and 3 to `events.payments`; two Consumers each subscribed to one channel; assert per-channel counts and verify no cross-channel bleed.
**SUT:**
- Redis; Publisher-A channel `events.orders` `Iterations: 5`; Publisher-B channel `events.payments` `Iterations: 3`; Consumer-A on `events.orders`; Consumer-B on `events.payments`.

**MOCK_REQUIRED:** no — real Redis.
**FB slices:** s02 §2.6 (Publisher Redis channel, Consumer Redis channel), s09 #3, s11 (FlushAllRedis for isolation), s13 #12, s13 #13.
**Trap mines:** s13 #12 (channel name typo silently delivers to wrong channel); s13 #13 (Consumer-A must be at Stage 0 before Publisher-A at Stage 1; race condition if Publisher fires before Consumer subscribes = 0 messages).
**Hard because:**
- Two Publisher+Consumer pairs in one session; all 4 actions must be at correct stages.
- Cross-bleed check: Consumer-A must only receive `events.orders` messages; channel pattern must not use wildcards unless psubscribe is supported.
- `FlushAllRedis` probe between sessions ensures clean state.

**Verify (mechanical):**
1. Consumer-A output==5; `HermeticByExpectedOutputCount ExpectedCount=5` passes.
2. Consumer-B output==3; `HermeticByExpectedOutputCount ExpectedCount=3` passes.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: Both consumers at Stage 0; both publishers at Stage 1; per-channel hermetic guards; distinct channel names.
- 6-8: Stages correct; single hermetic guard covering only one channel.
- 1-5: Single channel; stages wrong (publisher before consumer); Outputs=0 vacuous pass.

**Solution sketch:** Consumer-A+B Stage 0 `InitialTimeoutMs: 5000`; Publisher-A+B Stage 1; `HermeticByExpectedOutputCount ExpectedCount=5` and `ExpectedCount=3`; `FlushAllRedis` Stage 4.

---

### Q-143: Kafka Consumer Group Rebalance — Two Consumers Same GroupId, Hermetic Range

**Tier:** T5
**Goal:** Two Consumers share the same Kafka GroupId on a 2-partition topic; Publisher sends 100 messages at 10/s; assert aggregate delivery in [85,100]% accounting for rebalance-window gaps.
**SUT:**
- Kafka 2-partition topic; Consumer-1 + Consumer-2 same GroupId; Publisher `IncreasingLoadBalance` + `Count{Count:100}`.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.6 (Consumer KafkaTopic `GroupId`), s02 §2.7 (LoadBalance, Count), s09 #6 (`HermeticByInputOutputPercentageInRange`), s13 #13.
**Trap mines:** s13 #13 (rebalance window may drop messages; range assertion handles this); `/qaas:docs runner/actions/consumers/kafkaTopic` for consumer config fields; `AutoOffsetReset: Earliest` for both consumers.
**Hard because:**
- Both consumers must use the SAME GroupId to form a consumer group; this is opposite of the Q-114 scenario.
- `HermeticByInputOutputPercentageInRange` must list both consumer outputs in `OutputNames`.
- Rebalance semantics: during rebalance partitions are unassigned; messages may be re-delivered or missed; range `[85,100]%` reflects this.

**Verify (mechanical):**
1. Combined consumer outputs in [85,100] of publisher inputs.
2. `HermeticByInputOutputPercentageInRange [85,100]` passes.
3. ExitCode==0.
4. Note: `/qaas:docs runner/actions/consumers/kafkaTopic` cited for consumer config fields.

**Rubric (graded):**
- 9-10: Same GroupId; 2-partition topic; range [85,100]; both outputs in `OutputNames`; docs lookup cited.
- 6-8: Range assertion present but GroupIds differ; rebalance not triggered.
- 1-5: Exact count=100; rebalance not considered; fails on slow CI.

**Solution sketch:** 2-partition topic; Consumer-1+2 Stage 0 same GroupId `AutoOffsetReset: Earliest`; Publisher 100 msgs at 10/s; `HermeticByInputOutputPercentageInRange [85,100] OutputNames: [C1,C2]`.

---

### Q-144: ValidateHermeticMetricsByInputOutputPercentage — Prometheus Collector Integration

**Tier:** T5
**Goal:** Use `ValidateHermeticMetricsByInputOutputPercentage` to cross-validate message counts from QaaS SessionData against a Prometheus counter metric emitted by the SUT.
**SUT:**
- RabbitMQ + SUT consumer that increments `messages_processed_total` per message; Prometheus scrapes SUT; QaaS Collector on Prometheus; assertion links SessionData counts to metric.

**MOCK_REQUIRED:** no — real Prometheus.
**FB slices:** s02 §2.6 (Collectors: Prometheus, CollectionRange), s09 #7 (`ValidateHermeticMetricsByInputOutputPercentage` all 6 required fields), s09 #3, s11 §11.1, s13 #12, s13 #13.
**Trap mines:** s13 #13 (Collector output must not be empty — hermetic guard needed); s13 #12 (`MetricOutputSourceName` typo silently skips metric comparison); s09 #7 requires `InputNames, OutputNames, MetricOutputSourceName, InputMetricName, OutputMetricName, Tolerance` — any missing field silently ignored.
**Hard because:**
- Prometheus `CollectionRange.EndTimeMs` must be set after SUT finishes processing; timing.
- `Tolerance` on metric assertion must account for Prometheus scrape interval lag.
- `MetricOutputSourceName` must match Collector output `Name` exactly.

**Verify (mechanical):**
1. Collector output non-empty; hermetic guard on Collector passes.
2. `ValidateHermeticMetricsByInputOutputPercentage Tolerance=5` passes.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: All 6 required fields in assertion; Collector `CollectionRange` covers full window; `Tolerance=5`; hermetic guard on collector.
- 6-8: Assertion present with correct fields; `Tolerance=0` (too tight for CI).
- 1-5: No Collector; no metric assertion; Prometheus not integrated.

**Solution sketch:** Collector `Prometheus Url: http://prom:9090 Expression: messages_processed_total CollectionRange: {EndTimeMs: 10000}`; `ValidateHermeticMetricsByInputOutputPercentage InputNames:[Pub] OutputNames:[Con] MetricOutputSourceName:Collector InputMetricName:messages_in_total OutputMetricName:messages_processed_total Tolerance:5`.

---

### Q-145: ObjectOutputJsonSchema — All Consumer Messages Match Schema

**Tier:** T5
**Goal:** Publish 10 structured JSON messages via RabbitMQ; consumer deserializes to JSON; `ObjectOutputJsonSchema` assertion verifies every output matches a JSON Schema definition from a data source file.
**SUT:**
- RabbitMQ direct exchange; Publisher `Serialize: {Serializer: Json}`; Consumer `Deserialize: {Deserializer: Json}`; JSON Schema file as DataSource for assertion.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.8 (Serializers Json), s02 §2.5 (DataSources FromFileSystem), s09 #9 (`ObjectOutputJsonSchema` — `OutputName` singular + `DataSourceNames`), s09 #3, s11 §11.1, s13 #12.
**Trap mines:** s13 #12 (`OutputName` singular in `ObjectOutputJsonSchema` — NOT `OutputNames`; confusing the two silently wrong); s13 #13 (if consumer output=0, assertion passes vacuously — pair with hermetic count).
**Hard because:**
- Schema file must be a valid JSON Schema document at the DataSource path.
- `ObjectOutputJsonSchema` asserts each output matches AT LEAST ONE schema from the data source; multiple schema files → any-match semantics.
- `QaaS.Common.Assertions` package required.

**Verify (mechanical):**
1. Consumer output count==10; `HermeticByExpectedOutputCount ExpectedCount=10` passes.
2. `ObjectOutputJsonSchema` passes for all 10 outputs.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: `OutputName` singular; JSON Schema file in DataSource; hermetic count paired; matched serializer/deserializer.
- 6-8: Schema assertion present; `OutputNames` (plural) used — silently wrong; count unverified.
- 1-5: No schema assertion; JSON deserialization not tested.

**Solution sketch:** DataSource `FromFileSystem Path: TestData/schema.json`; `ObjectOutputJsonSchema OutputName: ConsumerOutput DataSourceNames: [SchemaDS]`; `HermeticByExpectedOutputCount ExpectedCount=10`.

---

### Q-146: Delayed Exchange Plugin (x-delayed-message) — Docs-Thin Scenario

**Tier:** T5
**Goal:** Use the RabbitMQ `x-delayed-message` exchange plugin to delay message delivery by 2 seconds; assert consumer receives the message after the delay window using `DelayByAverage`.
**SUT:**
- RabbitMQ with rabbitmq-delayed-message-exchange plugin; exchange type `x-delayed-message` with `x-delayed-type: direct`; Publisher sends message with header `x-delay: 2000`.

**MOCK_REQUIRED:** no — real RabbitMQ with plugin.
**FB slices:** s02 §2.6, s11 §11.1 (CreateRabbitMqExchanges `Type` and `Arguments`), s09 #1 (DelayByAverage), s09 #3, s13 #17.
**Trap mines:** s13 #17 (plugin exchange type `x-delayed-message` must be declared; if plugin not installed, declare fails PRECONDITION_FAILED); `x-delay` header on published message requires `/qaas:docs runner/actions/publishers/rabbitMq` to confirm support.
**Hard because:**
- Both `x-delayed-type` in exchange `Arguments` AND `x-delay` header on published message required.
- `DelayByAverage MaximumDelayMs: 5000` must be paired with hermetic count; and model must also verify message arrives after 2s, not before.
- Plugin availability must be stated as a prerequisite; scenario is docs-thin for plugin syntax.

**Verify (mechanical):**
1. Consumer output count==1; hermetic count=1 passes.
2. `DelayByAverage MaximumDelayMs: 5000` passes.
3. ExitCode==0.
4. Model cites `/qaas:docs runner/actions/publishers/rabbitMq` for `x-delay` header syntax.

**Rubric (graded):**
- 9-10: Exchange `Type: x-delayed-message Arguments: {x-delayed-type: direct}`; Publisher `x-delay: 2000` header; `DelayByAverage` + hermetic; docs lookup cited.
- 6-8: Standard exchange + `SleepTimeMs` proxy; delay not broker-enforced; docs lookup absent.
- 1-5: No delay mechanism; immediate delivery; `DelayByAverage` absent.

**Solution sketch:** `CreateRabbitMqExchanges Type: x-delayed-message Arguments: {x-delayed-type: direct}`; Publisher `Headers: {x-delay: 2000}`; Consumer `InitialTimeoutMs: 7000`; `DelayByAverage MaximumDelayMs: 5000`; hermetic=1.

---

### Q-147: Cases — Three Data Variants Through Same Pipeline, Per-Case Assertions

**Tier:** T5
**Goal:** Use QaaS Cases (`-c`) to run the same three-session pipeline (Publish→SUT Transform→Assert) against three data variants (normal, boundary, empty body); assert per-case output counts and body content.
**SUT:**
- RabbitMQ direct exchange; SUT transformer reads input queue, transforms payload, writes to output queue.

**MOCK_REQUIRED:** no — real SUT.
**FB slices:** s02 §2.11 (Cases `-c <folder>`, path-key notation), s02 §2.6, s09 #10 (`OutputContentByExpectedCsvResults`), s09 #3, s11 §11.1, s13 #12, s13 #17.
**Trap mines:** s13 #12 (Cases path-key notation typo silently uses base value); s02 §2.3 (anchors don't cross overwrite files — same rule applies to case override files); path-key notation must use exact field names.
**Hard because:**
- Each case YAML overrides `DataSources:0:GeneratorConfiguration:FileSystem:Path` to case-specific folder.
- `OutputContentByExpectedCsvResults` `DataSourceNames` also varies per case; both overrides must be in each case file.
- Empty body case: SUT may reject; hermetic count must handle 0 or 1; case YAML sets `ExpectedCount` override.

**Verify (mechanical):**
1. Three case runs each produce correct output counts per case YAML.
2. `OutputContentByExpectedCsvResults` passes per case with correct expected CSV.
3. Allure report groups results by case folder.
4. ExitCode==0.

**Rubric (graded):**
- 9-10: Three case files; correct path-key overrides for DataSources AND assertion DataSourceNames; empty-body case explicitly handled; per-case hermetic override.
- 6-8: Cases present; DataSources override correct but assertion DataSource not overridden.
- 1-5: Single run; no cases; variants not tested.

**Solution sketch:** `cases/normal.yaml`, `cases/boundary.yaml`, `cases/empty.yaml`; each overrides `DataSources:0:GeneratorConfiguration:FileSystem:Path` and `Assertions:0:DataSourceNames`; runner invoked with `-c cases`; `OutputContentByExpectedCsvResults` per case.

---

### Q-148: Large-Scale Kafka — 1000 Messages, 4 Partitions, Hermetic Percentage

**Tier:** T5
**Goal:** Publish 1000 messages to a 4-partition Kafka topic using `IncreasingLoadBalance`; 4 Consumers same GroupId; assert aggregate delivery ≥ 98% with `HermeticByInputOutputPercentageInRange`.
**SUT:**
- Kafka 4-partition topic; Publisher `IncreasingLoadBalance` + `Count{Count:1000}`; 4 Consumers same GroupId `AutoOffsetReset: Earliest`.

**MOCK_REQUIRED:** no.
**FB slices:** s02 §2.7 (IncreasingLoadBalance all 5 fields), s02 §2.6 (Consumer KafkaTopic), s09 #6 (`HermeticByInputOutputPercentageInRange`), s13 #13.
**Trap mines:** s13 #13 (Consumer `TimeoutMs` must cover full ramp window); GroupId unique per run via variable; `AutoOffsetReset: Earliest`; per-consumer exact count non-deterministic — only aggregate percentage is stable.
**Hard because:**
- 1000 messages; 4 consumer outputs in `OutputNames` for aggregate assertion.
- `HermeticByInputOutputPercentageInRange [98,100]` — tight range requires reliable Kafka and high Consumer `InitialTimeoutMs`.
- Variable GroupId injection via `-r variables:groupId=<ci-build-id>`.

**Verify (mechanical):**
1. Publisher input count==1000.
2. Sum of 4 consumer outputs ≥ 980; range assertion [98,100] passes.
3. ExitCode==0.

**Rubric (graded):**
- 9-10: `Count: {Count:1000}`; `IncreasingLoadBalance` all 5 fields; 4 consumer outputs in `OutputNames`; range [98,100]; unique GroupId variable; `InitialTimeoutMs ≥ 30000`.
- 6-8: Range present but 2 consumers only; `Iterations: 1000` no rate policy.
- 1-5: Single consumer; exact count assertion; no rate policy.

**Solution sketch:** Publisher `IncreasingLoadBalance{StartRate:10,MaxRate:100,RateIncrease:10,RateIncreaseIntervalMs:1000,TimeIntervalMs:1000}` + `Count{Count:1000}`; 4 Consumers `InitialTimeoutMs:30000,TimeoutMs:5000,AutoOffsetReset:Earliest,GroupId:${variables:groupId}`; `HermeticByInputOutputPercentageInRange [98,100] OutputNames:[C1,C2,C3,C4]`.

---

### Q-149: Port Contract Violation — Probe Port Mismatches Mocker Port

**Tier:** T5
**Goal:** Construct a scenario where the `PingProbe` checks port 8081 but the Mocker HTTP server binds port 8080; demonstrate runner exits 9 (MOCKER NEVER READY); then fix by aligning all three ports to 8080.
**SUT:**
- QaaS Mocker HTTP server on port 8080; PingProbe configured for port 8081 (wrong); Transaction also uses port 8081.

**MOCK_REQUIRED:** yes — Mocker required to bind HTTP.
**FB slices:** s02 §2.6 (Transactions `Http.Port`), s11 §11.1 (PingProbe — confirm Port field via `/qaas:docs runner/actions/probes/ping`), s13 #16 (port contract all-same literal), s13 #14 (leading hash in cmd), s13 #15 (mocker + runner in one cmd).
**Trap mines:** s13 #16 (probe port differs from mocker port → probe loops full wait → exit 9); s13 #14 (verify cmd must not start with hash character); s13 #15 (mocker must start before runner in ONE combined shell command, not two separate verify entries).
**Hard because:**
- Two-part scenario: broken config demonstrates exit 9; fixed config aligns all three ports to single literal.
- `PingProbe` config field names need `/qaas:docs runner/actions/probes/ping` confirmation.
- Verify cmd must start mocker as background process, wait for port readiness, then run runner — all in one command string.

**Verify (mechanical):**
1. Broken config: runner exits 9; no output; `ExitCode=9` in cmd output.
2. Fixed config: Transaction output count==1; `HttpStatus StatusCode: 200` passes.
3. ExitCode==0 after fix.

**Rubric (graded):**
- 9-10: Broken config exits 9; fixed config aligns all three ports; s13 #16 cited; verify cmd follows s13 #15 (single cmd).
- 6-8: Fixed config correct; broken config not demonstrated as negative test.
- 1-5: Both configs use wrong port; exit 9 not understood; port contract not applied.

**Solution sketch:** Broken: `PingProbe Port:8081, Mocker Port:8080, Transaction Port:8081`; Fixed: all `Port:8080`; verify cmd: single PowerShell string that starts mocker background, waits for TCP, runs runner, captures exit code, kills mocker by PID.

---

### Q-150: Overwrite Files — Multi-Environment Fanout, Consumer Timeout Parameterized

**Tier:** T5
**Goal:** Use QaaS overwrite files (`-w`) to parameterize RabbitMQ host and Consumer timeout per environment (local/staging); run the same fanout pipeline in both environments from one base YAML; assert hermetic count=5 in each.
**SUT:**
- RabbitMQ fanout on two environments; base YAML uses `${variables:rabbitHost}` and `${variables:consumerTimeout}`; overwrite files `Variables/local.yaml` and `Variables/staging.yaml`.

**MOCK_REQUIRED:** no — real brokers.
**FB slices:** s02 §2.2 (variables, default syntax `${variables:key??default}`), s02 §2.11 (overwrite files `-w`, anchors don't cross files), s02 §2.6, s09 #3, s11 §11.1, s13 #17.
**Trap mines:** s02 §2.3 (anchors NOT usable across overwrite files); overwrite files use plain `.yaml` extension not `.qaas.yaml`; path-key notation must match camelCase of variable keys exactly; `Sessions:0:Consumers:0:TimeoutMs` path-key for timeout override.
**Hard because:**
- Variable syntax `${variables:rabbitHost??localhost}` fallback hides missing env-specific overwrite.
- `Consumer.TimeoutMs` must also be parameterized; overwrite files must override `Sessions:0:Consumers:0:TimeoutMs`.
- Anchors defined in base YAML for Consumer config are NOT usable in overwrite files.
- Hermetic count=5 must pass across both environments despite different latency profiles.

**Verify (mechanical):**
1. Run `-w Variables/local.yaml`: hermetic count=5 passes.
2. Run `-w Variables/staging.yaml`: hermetic count=5 passes.
3. ExitCode==0 for both runs.

**Rubric (graded):**
- 9-10: Two overwrite files with correct path-key notation; `Sessions:0:Consumers:0:TimeoutMs` parameterized; anchor limitation documented; variable default fallback; topology probes use `${variables:rabbitHost}`.
- 6-8: Two overwrite files; Consumer TimeoutMs not parameterized; anchors attempted across files.
- 1-5: Hardcoded host; no overwrite files; single environment only.

**Solution sketch:** Base YAML: `variables: {rabbitHost: localhost, consumerTimeout: 5000}`; `Consumer TimeoutMs: ${variables:consumerTimeout}`; topology `Host: ${variables:rabbitHost}`; overwrite `Variables/staging.yaml` sets `Variables:rabbitHost: rabbit.staging` + `Sessions:0:Consumers:0:TimeoutMs: 10000`; runner cmd `dotnet run -- runner -w Variables/local.yaml`.

---
