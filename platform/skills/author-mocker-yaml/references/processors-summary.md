# Processors Summary (FB s12)

9 built-in processors in `QaaS.Common.Processors`. Bind via `Processor: <Name>` + `ProcessorConfiguration:`.
All req = required field. All `Data<object> Process(IImmutableList<DataSource>, Data<object> requestData)`.

| # | Processor | Required config keys | Notes |
|---|---|---|---|
| 1 | `StaticResponseProcessor` | `Body`, `StatusCode`, `ContentType` | Fixed response. LAB-green minimal. |
| 2 | `StatusCodeTransactionProcessor` | `StatusCode` | Empty body. |
| 3 | `RequestEchoProcessor` | `StatusCode`, `ContentType` | Echo body+meta as JSON. Opt: IncludeRequestHeaders/PathParameters/Uri/ResponseHeaders. |
| 4 | `PassThroughProcessor` | `StatusCode` | Return body unchanged. Opt: ContentType/PreserveMetaData/ResponseHeaders. |
| 5 | `JsonEnvelopeProcessor` | `StatusCode`, `ContentType`, `BodyPropertyName` | Wrap body in JSON property. Opt: IncludeBodyType/Uri/RequestHeaders/PathParameters/ResponseHeaders. |
| 6 | `TextTransformProcessor` | `StatusCode`, `ContentType` | Trim→replace→prefix/suffix. Opt: TrimWhitespace/SearchText/ReplacementText/Prefix/Suffix/ResponseHeaders. |
| 7 | `ConditionalResponseProcessor` | `Rules[]` (each: ExpectedValue req; ResponseBody; StatusCode req; ContentType req), `DefaultStatusCode`, `DefaultContentType` | Route by header/path-param. First-match wins. Opt: DefaultBody/DefaultResponseHeaders. |
| 8 | `DataSourceResponseProcessor` | `SelectionMode` (First\|Last\|ByIndex req), `StatusCode` | Also add `DataSourceNames:` on Stub. Opt: Index/ContentType/FallbackBody/ResponseHeaders. |
| 9 | `ProblemDetailsProcessor` | `StatusCode`, `Title`, `Type`, `ContentType` (usually `application/problem+json`) | RFC 7807. Opt: Detail/Instance/UseRequestUriAsInstance/Extensions/ResponseHeaders. |

**CRITICAL**: Key is `ProcessorConfiguration:` — NEVER `TransactionData:` (FB s13#1).
Copy key names character-exact; unknown keys are silently ignored (FB s13#12).
