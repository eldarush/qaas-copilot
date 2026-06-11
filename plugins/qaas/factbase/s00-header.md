# QaaS Canonical Fact Base (for skill authoring)

Single source of truth for a weak model writing/running QaaS tests offline. Every fact is
tagged with its origin: a `docs/...` path, or `[LAB]` = verified by actually running QaaS in the
ground-truth lab. **When LAB conflicts with docs, LAB WINS.** Read the **DOC-DRIFT TABLE (§13)
first** — those are the traps that silently break the weak model.

Verified stack `[LAB]`: QaaS.Runner **4.5.1**, QaaS.Mocker **2.4.1**, QaaS.Common.* /
QaaS.Framework.* matching, on **.NET 10.0.203**, Docker 29.4.2, Windows. (Docs prose says "2.0.0+";
treat package versions above as real.)

---

