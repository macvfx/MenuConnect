# SMB Connect Configuration Format

## Summary

SMB Connect can:

- import share definitions from JSON
- export the current configured share definitions back to JSON
- read managed share definitions from an MDM profile

---

## JSON Format

### Top-Level Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `configDate` | string | Yes | Date string in `YYYYMMDD` format, e.g. `"20260419"`. This is a human-readable version marker and import ordering hint. It is not part of the deduplication key. Content changes are detected from the file bytes, so you do not need to change `configDate` to make an updated file apply. |
| `shares` | array | Yes | Array of share definition objects (see below). |

### Share Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `alias` | string | Yes | Display name shown in the menu bar popover and settings. |
| `connectionProtocol` | string | No | Protocol string. Currently only `"smb"`. Defaults to `"smb"` if absent. |
| `shareName` | string | Yes | The SMB share path component, e.g. `Exports` in `smb://server/Exports`. |
| `mountName` | string | No | The volume name expected under `/Volumes` after mounting. Defaults to `shareName` if absent. |
| `defaultUsername` | string | No | Suggested username pre-filled in the Credentials section. The user must still save a password in Keychain. |
| `endpoints` | array | Yes | One or more IP-based network paths to this share. |
| `note` | string | No | Optional free-text note shown in the Settings detail pane. |
| `source` | string | No | Origin tag. Valid values: `"user"`, `"imported"`, `"mdmManaged"`. **This field is always overridden on import** — the app sets it to `"imported"` for JSON imports regardless of what the file contains. It is safe to include or omit it. |

### Endpoint Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `serverIP` | string | Yes | IPv4 address of the SMB server for this path. |
| `networkType` | string | Yes | Network speed label. See valid values below. |
| `priority` | integer | No | Lower values are preferred first. Each `networkType` has a sensible default (see table below). |
| `subnetPrefix` | integer | No | CIDR prefix length used for subnet matching. Defaults to `24` if absent. |
| `label` | string | No | Display label for this endpoint in the Settings UI. Falls back to `"networkType · serverIP"` if absent. |

### Valid `networkType` Values

| JSON value | Display name | Default priority |
|---|---|---|
| `"100gbe"` | 100GbE | −30 |
| `"40gbe"` | 40GbE | −20 |
| `"25gbe"` | 25GbE | −10 |
| `"10gbe"` | 10GbE | 0 |
| `"5gbe"` | 5GbE | 5 |
| `"2_5gbe"` | 2.5GbE | 8 |
| `"1gbe"` | 1GbE | 10 |
| `"custom"` | Custom Speed | 20 |

Lower default priority = preferred first. An explicit `priority` value in the JSON overrides the default.

### JSON Example

See examples folder.

Minimal valid structure:

```json
{
  "configDate": "20260419",
  "shares": [
    {
      "alias": "Exports NAS",
      "connectionProtocol": "smb",
      "shareName": "Exports",
      "mountName": "Exports",
      "defaultUsername": "user",
      "endpoints": [
        {
          "serverIP": "10.0.0.1",
          "networkType": "10gbe",
          "priority": 0,
          "subnetPrefix": 24,
          "label": "Primary 10GbE"
        },
        {
          "serverIP": "192.168.10.245",
          "networkType": "1gbe",
          "priority": 10,
          "subnetPrefix": 24,
          "label": "Fallback 1GbE"
        }
      ],
      "note": "Password is not stored in JSON. Save it locally in the app."
    }
  ]
}
```

### Generator Script For JSON And MDM

If you want to build a valid SMB Connect setup JSON file and matching `.mobileconfig` profile from a comma-separated server list, use:

- [generate_smbconnect_config.sh](generate_smbconnect_config.sh)

The generator accepts `.csv` and `.txt` inputs using this 10-column format:

```text
alias,protocol,shareName,mountName,defaultUsername,note,preferredIP,preferredSpeed,fallbackIP,fallbackSpeed
```

If `fallbackIP` and `fallbackSpeed` are both blank, the generated share will contain a single preferred endpoint.

Example input files:

- [server-shares-example.csv](examples/server-shares-example.csv)
- [server-shares-example.txt](examples/server-shares-example.txt)

Full generator usage details are documented in:

- [README-config-generator.md](README-config-generator.md)

---

## MDM Profile Format

MDM delivers preferences as a macOS configuration profile. The app reads managed values from `UserDefaults` forced preferences via `com.matx.SMBConnect`.

### Top-Level MDM Keys

| Key | Type | Description |
|---|---|---|
| `ManagedShares` | array of dicts | List of share definitions (see below). |
| `AllowUserDefinedShares` | boolean | Whether users can add and edit their own shares alongside MDM-managed ones. **If this key is absent, the app defaults to `false`** — users cannot add their own shares when `ManagedShares` is present but this key is not set. Set to `true` explicitly if you want both MDM shares and user-defined shares. |

### MDM Share Fields

| Key | Type | Required | Description |
|---|---|---|---|
| `alias` | string | Yes | Display name. |
| `protocol` | string | No | Protocol string. Use `"smb"`. Note: MDM payloads use `"protocol"`, not `"connectionProtocol"` (the JSON key). Both are accepted but `"protocol"` is canonical for MDM. |
| `shareName` | string | Yes | SMB share path component. |
| `mountName` | string | No | Volume name under `/Volumes`. Defaults to `shareName`. |
| `defaultUsername` | string | No | Pre-filled username suggestion. |
| `note` | string | No | Free-text note. |
| `endpoints` | array of dicts | Yes | One or more endpoint dicts (see below). |

### MDM Endpoint Fields

| Key | Type | Required | Description |
|---|---|---|---|
| `serverIP` | string | Yes | IPv4 address. |
| `networkType` | string | Yes | Network speed label. See the `networkType` table above — same values apply. |
| `priority` | integer | No | Lower = preferred first. Defaults to the `networkType` default priority. |
| `subnetPrefix` | integer | No | CIDR prefix. Defaults to `24`. |
| `label` | string | No | Display label. |

### MDM Example

```xml
<key>ManagedShares</key>
<array>
  <dict>
    <key>alias</key>       <string>Exports NAS</string>
    <key>protocol</key>    <string>smb</string>
    <key>shareName</key>   <string>Exports</string>
    <key>mountName</key>   <string>Exports</string>
    <key>defaultUsername</key> <string>user</string>
    <key>note</key>        <string>Preferred 10GbE, fallback 1GbE.</string>
    <key>endpoints</key>
    <array>
      <dict>
        <key>serverIP</key>     <string>10.0.0.1</string>
        <key>networkType</key>  <string>10gbe</string>
        <key>priority</key>     <integer>0</integer>
        <key>subnetPrefix</key> <integer>24</integer>
        <key>label</key>        <string>Preferred 10GbE</string>
      </dict>
      <dict>
        <key>serverIP</key>     <string>192.168.10.245</string>
        <key>networkType</key>  <string>1gbe</string>
        <key>priority</key>     <integer>10</integer>
        <key>subnetPrefix</key> <integer>24</integer>
        <key>label</key>        <string>Fallback 1GbE</string>
      </dict>
    </array>
  </dict>
</array>
<key>AllowUserDefinedShares</key>
<true/>
```

---

## Password Handling

Passwords are intentionally not stored in:

- exported JSON
- imported JSON
- MDM profiles

Passwords are saved locally in the user's Keychain after the user enters them in Settings. Credentials are stored with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — they survive reboots (needed for auto-connect at login) and do not sync to other devices via iCloud Keychain.

Usernames can be preloaded via `defaultUsername`. This lets admins pre-fill the expected account name without ever touching the password.

---

## Export Behaviour

When the app exports settings:

- user-editable and imported share definitions are written to JSON
- MDM-managed shares are excluded
- endpoint preferences, protocol, and `defaultUsername` are preserved
- `source` in the exported JSON will reflect each share's origin tag (`"user"` or `"imported"`)
- passwords are always omitted

The exported file is suitable for:

- backup and migration to another Mac
- creating a starting point for an MDM payload
- sharing a base configuration with a team (each user saves their own password)

---

## Setup Folder Auto-Import

The app scans `~/Library/Application Support/SMBConnect/Setup/` for `.json` files on every launch and on each 20-second refresh cycle.

### How a file is identified

Each file is tracked by a **content fingerprint**: `filename + SHA-256 hash of the file's raw bytes`. This means:

- **Identical content** — the same identifier is produced and the file is skipped.
- **Any content change** (updated IP, new endpoint, renamed alias, anything) — the hash changes, the identifier is new, and the file is re-applied automatically on the next launch or refresh.
- **`configDate` is not part of the deduplication key.** You do not need to change `configDate` to pick up updates. `configDate` is only used to order imports when multiple new files appear at the same time (older dates are applied first so newer ones win in the merge).

### How to update a deployed config

1. Edit the JSON file — change whatever you need (IPs, endpoints, alias, etc.).
2. Drop the updated file back into the setup folder, replacing the old one.
3. On the next app launch or `Refresh`, the new content hash is detected and the file is re-applied.

No `configDate` change is required. No filename change is required.

### How duplicate shares are prevented

Deduplication happens at two independent levels:

**Level 1 — File level (content fingerprint):**
The same file bytes are never applied twice. If nothing in the file changed, it is skipped.

**Level 2 — Share level (stableID merge):**
When a file is applied, each incoming share is merged by its `stableID` (`alias|shareName`, case-insensitive). If a share with that stableID already exists, it is **replaced** by the incoming version — not duplicated. This means:

- Two different files that define the same share (same alias + shareName) will never create two copies — the later file wins.
- A re-applied file after an edit updates the existing share in-place.

### What `configDate` is actually for

`configDate` is a human-readable version marker and an import ordering hint — nothing more. When multiple new files arrive simultaneously, older `configDate` values are applied first so that a newer config correctly overrides an older one. It is not required to be unique and does not drive deduplication.

### Avoiding duplicates: admin checklist

| Scenario | What happens | Action needed |
|---|---|---|
| Drop the same file twice | Content hash matches → skipped | None |
| Edit a file and redeploy | New hash → re-applied, existing share updated | None — just save the file |
| Two files define the same share (same alias + shareName) | Share-level merge → later file wins, one copy exists | None — safe by design |
| Rename a file but keep identical content | New filename → new identifier → re-applied, merge updates share | Fine, no duplicates |
| Two files with different aliases but same server IP | Two separate shares created | Intentional — different aliases are different shares |

---

## Key Name Reference: JSON vs MDM

| Concept | JSON key | MDM key |
|---|---|---|
| Protocol | `connectionProtocol` | `protocol` |
| All other share fields | same key name | same key name |
| All endpoint fields | same key name | same key name |

The app accepts `"protocol"` as a fallback in JSON (legacy compatibility) and accepts `"connectionProtocol"` as a fallback in MDM payloads, but the canonical forms above are recommended.

---

## Supported Protocol Values

| Value | Meaning |
|---|---|
| `"smb"` | SMB/CIFS (only supported protocol in current version) |
