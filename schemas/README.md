# Declarative Browser Configuration Schema

This directory contains declarative JSON schemas that define how BrowserParity mutates and inspects browser preferences across versions without hardcoding version assumptions.

## File: `browser-parity-schema.json`

The schema contains a list of rules grouped by browser (`Opera`, `Edge`, `Firefox`, `Chrome`).

### Rule Specification

```json
{
  "category": "Anti-Annoyance",
  "minVersion": 0,
  "targetFile": "Preferences",
  "path": ["profile", "default_content_setting_values", "notifications"],
  "value": 2,
  "action": "Set",
  "description": "Block website notification popup requests"
}
```

### Fields:
* **`category`**: Functional domain (`Search`, `AI-Bloat`, `Commercial-Bloat`, `Anti-Annoyance`, `Privacy`, `Network`, `Session`, `Typography`, `Theme`, `Client-Cert-PKI`).
* **`minVersion`**: Minimum browser major version required for this rule to apply (e.g. `110` for Edge Copilot toggles, `90` for Firefox OS client certs). If `0`, applies to all versions.
* **`targetFile`**: Target profile file (`Preferences`, `Local State`, or `user.js`).
* **`path`**: Array of JSON object keys leading to the target property (for Chromium JSON preferences).
* **`pref`**: Key name (for Firefox `user.js` preferences).
* **`value`**: Target value to enforce.
* **`action`**: Operation type (`Set`, `Remove`).
* **`description`**: Human and agent-readable purpose of the rule.

## How to Inspect via CLI:
```powershell
# Display all schema rules formatted in a table:
.\sync-browser-parity.ps1 -Schema
```