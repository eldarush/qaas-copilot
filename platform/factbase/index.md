# Fact Base Index

Chunked, LAB-verified QaaS knowledge. Load only the slices a task needs (e.g. via `/qaas:fact sNN`).

| Slice | File | Size | Contents |
|---|---|---|---|
| FB §0 | s00-mental-model.md | 1.1KB | Mental model (Runner/Mocker/hooks/YAML) |
| FB §1 | s01-scaffold.md | 2KB | TASK: Scaffold a project (templates, csproj, feeds) |
| FB §2 | s02-runner-yaml.md | 9.5KB | TASK: Author Runner YAML (every section) |
| FB §3 | s03-mocker-yaml.md | 1.8KB | TASK: Author Mocker YAML (Servers/Stubs/Controller) |
| FB §4 | s04-custom-hooks.md | 3.3KB | TASK: Custom hooks (4 base classes, signatures, rules) |
| FB §5 | s05-config-as-code.md | 1.1KB | TASK: Configuration as Code (C# builders) |
| FB §6 | s06-cli.md | 2.6KB | TASK: CLI usage (verbs, flags, exit codes) |
| FB §7 | s07-diagnosis.md | 4.7KB | TASK: Artifacts & diagnosis (allure layout, error table) |
| FB §8 | s08-airgap.md | 0.8KB | TASK: Offline / airgap packaging |
| FB §9 | s09-assertions-catalog.md | 2.3KB | CATALOG: 11 assertions + exact config keys |
| FB §10 | s10-generators-catalog.md | 1.9KB | CATALOG: 11 generators + config |
| FB §11 | s11-probes-catalog.md | 1.5KB | CATALOG: probes (41 documented) |
| FB §12 | s12-processors-catalog.md | 1.9KB | CATALOG: 9 mocker processors |
| FB §13 | s13-doc-drift.md | 2.5KB | DOC-DRIFT table — critical traps (LAB-verified) |
| FB §14 | s14-golden-examples.md | 9.6KB | GOLDEN EXAMPLES (verbatim, LAB-green) |
| FB §15 | s15-source-index.md | 0.4KB | Source index |
| FB §16 | s16-docs-navigation.md | ~5KB | NAVIGATION: hook name index + discovery-before-denial protocol |

Rules: golden examples = §14; drift traps = §13; error signatures = §7. Always inject §13 alongside §2/§3/§14.
