using System.Collections.Immutable;
using QaaS.Framework.SDK.DataSourceObjects;
using QaaS.Framework.SDK.Hooks.Processor;
using QaaS.Framework.SDK.Session.DataObjects;
using QaaS.Framework.SDK.Session.MetaDataObjects;

public class CustomOkProcessor : BaseTransactionProcessor<object>
{
    public override Data<object> Process(
        IImmutableList<DataSource> dataSourceList, Data<object> requestData) =>
        new()
        {
            Body = "CUSTOM-OK"u8.ToArray(),
            MetaData = new MetaData { Http = new Http { StatusCode = 200 } }
        };
}
