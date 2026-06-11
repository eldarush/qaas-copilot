> SNAPSHOT at Runner 4.5.1 / Mocker 2.4.1 — fetch live docs first (see FB s16); verify against your docs when reachable.

## 9. CATALOG — 11 Assertions (pkg `QaaS.Common.Assertions`; src 05)
Required config keys in **bold**; HttpStatus shape is [LAB]-corrected (§13).

1. **DelayByAverage** — avg input ts vs avg output ts ≤ MaximumDelayMs. `InputName, OutputName,
   MaximumDelayMs`; opt InputsAreOutputs, MaximumNegativeDelayBufferMs. Empty output → pass.
2. **DelayByChunks** — chunk-to-chunk delay. `Input{Name,ChunkSize,ChunkTimeOption(First|Average|
   Last)}, Output{...}, MaximumDelayMs`; opt InputsAreOutputs, MaximumNegativeDelayBufferMs.
3. **HermeticByExpectedOutputCount** — Σoutputs == `ExpectedCount`. `OutputNames, ExpectedCount`.
4. **HermeticByExpectedOutputCountInRange** — Σoutputs in [min,max]. `OutputNames,
   ExpectedMinimumCount, ExpectedMaximumCount`.
5. **HermeticByInputOutputPercentage** — outputs == inputs×pct/100. `InputNames, OutputNames,
   ExpectedPercentage`; opt InputsAreOutputs, MidpointRounding(AwayFromZero|ToEven). 0in+some out→fail.
6. **HermeticByInputOutputPercentageInRange** — actual pct in [min,max]. `InputNames, OutputNames,
   ExpectedMinimumPercentage, ExpectedMaximumPercentage`.
7. **ValidateHermeticMetricsByInputOutputPercentage** — count ratio vs metric ratio
   `(Out+Process+Combine+Filtered)/(In+Split)×100`. Req: InputNames, OutputNames,
   MetricOutputSourceName, InputMetricName, OutputMetricName, Tolerance; opt Process/Combine/Filtered/
   SplitMetricName, InputsAreOutputs.
8. **OutputDeserializableTo** — all outputs deserialize. `OutputName, Deserialize{Deserializer,
   SpecificType{AssemblyName,TypeFullName}}`.
9. **ObjectOutputJsonSchema** — each output matches ≥1 schema from data source. `OutputName` +
   `DataSourceNames` (schemas). 
10. **OutputContentByExpectedCsvResults** — compare output JSON fields to CSV expectations.
    `OutputName, ColumnNameToFieldPathMap{COL:{Path:$.x, FieldValidationConfig{Type: ExactValue|
    ErrorRange|Override|Base64ToHex, ErrorRange{ErrorRange}}}}`; opt DataSourceName,
    ResultsMetaDataStorageKey, CompareRowsNotInOrder(false), JsonConverterType. + DataSourceNames(CSV).
11. **HttpStatus** — all outputs have expected HTTP status. **`StatusCode`(int) + `OutputNames`(list)**.
    ⚠️ NOT `ExpectedStatus`/`OutputName` (§13). Throws if any item lacks HTTP status metadata.

---

