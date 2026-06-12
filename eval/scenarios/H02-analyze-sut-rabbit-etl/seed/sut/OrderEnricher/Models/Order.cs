namespace OrderEnricher.Models;

public class Order
{
    public string OrderId { get; set; } = string.Empty;
    public string Region { get; set; } = string.Empty;
    public int Quantity { get; set; }
    public int UnitPriceCents { get; set; }
    public string Status { get; set; } = "NEW";
    public int TotalCents { get; set; }
}
