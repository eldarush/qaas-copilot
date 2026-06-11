## 12. CATALOG — 9 Mocker Processors (pkg `QaaS.Common.Processors`; src 05)
Bind in `Stubs[]` via `Processor` + `ProcessorConfiguration` (+ optional `DataSourceNames`).
Signature: `Data<object> Process(IImmutableList<DataSource>, Data<object> requestData)`.

1. **StaticResponseProcessor** — fixed body. `Body, StatusCode(req), ContentType(req),
   ResponseHeaders`. [LAB] minimal-green: `{Body:hello, StatusCode:200,
   ContentType: "text/plain; charset=utf-8"}`.
2. **StatusCodeTransactionProcessor** — status, empty body. `StatusCode(req)`.
3. **RequestEchoProcessor** — echo body(+meta) as JSON. `StatusCode, ContentType` (req);
   IncludeRequestHeaders/PathParameters/Uri, ResponseHeaders.
4. **PassThroughProcessor** — return body unchanged. `StatusCode(req)`, ContentType,
   PreserveMetaData, ResponseHeaders.
5. **JsonEnvelopeProcessor** — wrap body in JSON property. `StatusCode, ContentType, BodyPropertyName`
   (req); IncludeBodyType/Uri/RequestHeaders/PathParameters, ResponseHeaders.
6. **TextTransformProcessor** — trim→replace→prefix/suffix. `StatusCode, ContentType` (req);
   TrimWhitespace, SearchText, ReplacementText, Prefix, Suffix, ResponseHeaders.
7. **ConditionalResponseProcessor** — route by header/path param. `Rules[{RequestHeaderName|
   PathParameterName, ExpectedValue(req), ResponseBody, StatusCode(req), ContentType(req),
   ResponseHeaders}]`, `DefaultStatusCode(req), DefaultContentType(req), DefaultBody,
   DefaultResponseHeaders`. First match wins.
8. **DataSourceResponseProcessor** — return a generated item. `SelectionMode(First|Last|ByIndex,req),
   Index, StatusCode(req)`; DataSourceName, ContentType, FallbackBody, ResponseHeaders. + DataSourceNames.
9. **ProblemDetailsProcessor** — RFC 7807. `StatusCode, Title, Type, ContentType` (req;
   usually `application/problem+json`); Detail, Instance, UseRequestUriAsInstance, Extensions,
   ResponseHeaders.

---

