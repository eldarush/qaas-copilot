namespace InventoryApi.Models;

/// <summary>Request DTO for POST /inventory/reserve.</summary>
public record ReserveRequest(string ItemId, int Quantity);
