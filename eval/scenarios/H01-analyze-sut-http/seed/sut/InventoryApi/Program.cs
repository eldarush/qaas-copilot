using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using InventoryApi.Models;
using System;
using System.Collections.Generic;
using System.Linq;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddEndpointsApiExplorer();
var app = builder.Build();

// In-memory inventory store initialised at startup
var items = new List<InventoryItem>
{
    new InventoryItem("ITM-001", "Widget A", 100),
    new InventoryItem("ITM-002", "Widget B", 50),
    new InventoryItem("ITM-003", "Gadget X", 25),
};

// GET /inventory/items — list all available items
app.MapGet("/inventory/items", () =>
    Results.Ok(items));

// GET /inventory/items/{id} — retrieve a single item by id
app.MapGet("/inventory/items/{id}", (string id) =>
{
    var item = items.FirstOrDefault(i => i.ItemId == id);
    return item is null
        ? Results.NotFound(new { error = "Item not found" })
        : Results.Ok(item);
});

// POST /inventory/reserve — reserve a quantity of an item
app.MapPost("/inventory/reserve", (ReserveRequest req) =>
{
    var item = items.FirstOrDefault(i => i.ItemId == req.ItemId);
    if (item is null)
        return Results.NotFound(new { error = "Item not found" });
    if (item.Available < req.Quantity)
        return Results.BadRequest(new { error = "Insufficient stock" });
    item.Available -= req.Quantity;
    return Results.Ok(new { reserved = req.Quantity, remaining = item.Available });
});

var port = int.Parse(Environment.GetEnvironmentVariable("INVENTORY_PORT") ?? "8085");
app.Run($"http://0.0.0.0:{port}");

internal record InventoryItem(string ItemId, string Name, int Available)
{
    public int Available { get; set; } = Available;
}
