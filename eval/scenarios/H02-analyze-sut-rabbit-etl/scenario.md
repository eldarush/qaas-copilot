# H02 — analyze-sut-rabbit-etl (analysis)

**Goal:** Read the seeded `sut/OrderEnricher/` RabbitMQ ETL worker source and produce a structured
`qaas-analysis/sut-profile.md` capturing broker topology, data-transformation contract,
observability, env config, and a QaaS test-mapping section.

- Category: analysis
- Infra: None
- Seed: `sut/OrderEnricher/` — Program.cs, Worker.cs (consume orders.incoming, publish orders.enriched topic, routing key order.enriched.{Region}), Models/Order.cs, csproj
- Live gates: none (analysis only)
- Traps tested:
  - Missing routing-key pattern (`order.enriched.{Region}`) — dynamic, not static
  - Missing TotalCents formula (Quantity * UnitPriceCents)
  - Missing Status transition NEW→PENDING_ENRICHMENT
  - Missing metric name `orders_enriched_total`
  - Missing PREFETCH_COUNT env var
  - Not identifying Publisher+Consumer as the correct QaaS session types
