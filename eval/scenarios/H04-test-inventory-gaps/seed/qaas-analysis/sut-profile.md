# SUT Profile — InventoryApi

## Protocols & Surfaces

| Surface | Method | Route | Request DTO | Response | Citation |
|---|---|---|---|---|---|
| List items | GET | /inventory/items | (none) | JSON array of InventoryItem | Program.cs:22 |
| Get item by id | GET | /inventory/items/{id} | path param `id` (string) | InventoryItem or 404 | Program.cs:26 |
| Reserve item | POST | /inventory/reserve | `ReserveRequest` { ItemId: string, Quantity: int } | `{ reserved, remaining }` or 404/400 | Program.cs:34 |

## Configuration

| EnvVar | Default | Source Citation |
|---|---|---|
| INVENTORY_PORT | 8085 | Program.cs:43 |

## Test-Relevant Behaviors

- In-memory store only — no database persistence; store resets on restart.
- POST /inventory/reserve mutates in-memory state; test ordering matters.
- No downstream dependencies (no database, no message broker). MOCK_REQUIRED: NO.
- 404 returned for unknown ItemId; 400 returned for insufficient stock.

## Open Questions

- Where will the InventoryApi SUT be running during CI test execution?
- Which port will INVENTORY_PORT be set to in the test environment?
