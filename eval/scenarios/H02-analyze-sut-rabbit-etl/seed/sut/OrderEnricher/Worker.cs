using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using OrderEnricher.Models;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using System;
using System.Collections.Generic;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace OrderEnricher;

public class Worker : BackgroundService
{
    private readonly ILogger<Worker> _logger;
    private IConnection? _connection;
    private IModel? _channel;

    // Prometheus-style counter (simplified — real code uses prometheus-net)
    private long _ordersEnrichedTotal = 0;

    private static readonly string ConsumeQueue = "orders.incoming";
    private static readonly string PublishExchange = "orders.enriched";
    private static readonly string ExchangeType = "topic";

    public Worker(ILogger<Worker> logger) => _logger = logger;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var rabbitHost = Environment.GetEnvironmentVariable("RABBIT_HOST") ?? "localhost";
        var rabbitPort = int.Parse(Environment.GetEnvironmentVariable("RABBIT_PORT") ?? "5672");
        var prefetch = ushort.Parse(Environment.GetEnvironmentVariable("PREFETCH_COUNT") ?? "10");

        var factory = new ConnectionFactory
        {
            HostName = rabbitHost,
            Port = rabbitPort,
        };

        _connection = factory.CreateConnection();
        _channel = _connection.CreateModel();

        // Declare infrastructure
        _channel.ExchangeDeclare(exchange: PublishExchange, type: ExchangeType, durable: true);
        _channel.QueueDeclare(queue: ConsumeQueue, durable: true, exclusive: false, autoDelete: false);
        _channel.BasicQos(prefetchSize: 0, prefetchCount: prefetch, global: false);

        var consumer = new EventingBasicConsumer(_channel);
        consumer.Received += (_, ea) =>
        {
            var body = ea.Body.ToArray();
            var json = Encoding.UTF8.GetString(body);
            var order = JsonSerializer.Deserialize<Order>(json)!;

            // Data transformation contract
            order.TotalCents = order.Quantity * order.UnitPriceCents;
            order.Status = "PENDING_ENRICHMENT"; // was "NEW"

            var routingKey = $"order.enriched.{order.Region}";
            var outBytes = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(order));
            var props = _channel.CreateBasicProperties();
            props.Persistent = true;

            _channel.BasicPublish(
                exchange: PublishExchange,
                routingKey: routingKey,
                basicProperties: props,
                body: outBytes);

            _channel.BasicAck(ea.DeliveryTag, multiple: false);
            _ordersEnrichedTotal++;

            // Observability: log line template
            _logger.LogInformation("Enriched order {OrderId}", order.OrderId);
            // Metric: orders_enriched_total = _ordersEnrichedTotal
        };

        _channel.BasicConsume(queue: ConsumeQueue, autoAck: false, consumer: consumer);

        await Task.Delay(Timeout.Infinite, stoppingToken);
    }

    public override void Dispose()
    {
        _channel?.Close();
        _connection?.Close();
        base.Dispose();
    }
}
