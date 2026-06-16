# SMB Connect JSON → MDM Profile

This converter turns an **existing SMB Connect setup JSON file** — the same
format the app exports and imports — into a deployable macOS `.mobileconfig`
MDM profile.

Use this when you already have a setup JSON (the file you would normally import
by hand) and want the MDM-managed equivalent. To generate both a JSON *and* a
profile from a CSV/TXT list instead, use
[generate_smbconnect_config.sh](generate_smbconnect_config.sh).

The script is here:

- [json_to_mobileconfig.sh](json_to_mobileconfig.sh)

## Usage

```bash
chmod +x ./json_to_mobileconfig.sh
./json_to_mobileconfig.sh \
  -i ./SMBConnectSetup-AVNAS.json \
  -o ./SMBConnectSetup-AVNAS.mobileconfig \
  --organization "Your Org"
```

If `-o` is omitted, the profile is written next to the input with a
`.mobileconfig` extension.

## Options

| Option | Required | Default | What it does |
| --- | --- | --- | --- |
| `-i`, `--input PATH` | yes | — | Source SMB Connect setup JSON file. |
| `-o`, `--output PATH` | no | input name with `.mobileconfig` | Where to write the profile. Parent directories are created. |
| `--organization NAME` | no | `Your Organization` | `PayloadOrganization` shown in the profile. |
| `--identifier-prefix ID` | no | `com.matx.SMBConnect` | Prefix for the profile and settings `PayloadIdentifier`s. Does **not** change the payload type (always `com.matx.SMBConnect`, the domain the app reads). |
| `--allow-user-defined true\|false` | no | from JSON, else `true` | Sets `AllowUserDefinedShares`. `true` keeps the user's own shares and merges managed ones on top; `false` locks the app to only the managed shares. |
| `--display-name NAME` | no | `SMB Connect Configuration` | `PayloadDisplayName` for the top-level profile. |
| `--blank-username` | no | off | Drops `defaultUsername` from every managed share even when the JSON provides one. |
| `-h`, `--help` | — | — | Print usage and exit. |

### `--allow-user-defined`

This is the override switch admins care about most:

- `true` (default) — a deployed profile **does not** wipe a user's JSON-imported
  shares. Managed shares are merged on top, keyed on `alias` + `shareName`, so a
  managed share only replaces a user share when both match exactly.
- `false` — the app shows **only** the managed shares; user-defined and
  previously imported shares are dropped from the active list.

### `--blank-username`

Drops `defaultUsername` from every managed share even when the input JSON
provides one, so the profile provisions the share (IPs, paths, fallback order)
while each user fills in their own username locally. Use it when the same server
is accessed with a different account per macOS user — a managed share's username
is otherwise locked and identical for every user on the device. Passwords are
never in the profile regardless of this flag.

## How the JSON maps to the profile

The profile force-sets two keys in the `com.matx.SMBConnect` preferences domain,
which is exactly what the app's managed-preferences reader looks for:

- `ManagedShares` — one dict per share
- `AllowUserDefinedShares` — whether users can still add their own shares

Field mapping:

| Setup JSON | MDM payload |
| --- | --- |
| `shares[].connectionProtocol` | `protocol` (input may also use `protocol`) |
| `shares[].source` | dropped (the reader forces `source = mdmManaged`) |
| top-level `configDate` / `shares` wrapper | dropped — flat `ManagedShares` array |
| `alias`, `shareName`, `mountName`, `defaultUsername`, `note` | copied unchanged (`defaultUsername` is blanked when `--blank-username` is set) |
| `endpoints[]` (`serverIP`, `networkType`, `priority`, `subnetPrefix`, `label`) | copied unchanged; optional endpoint fields are included only when present |

`AllowUserDefinedShares` resolution order: the `--allow-user-defined` flag wins;
otherwise a top-level `allowUserDefinedShares` boolean in the JSON is used;
otherwise it defaults to `true`.

## Notes

- Passwords are never present in the JSON or the profile — they stay user-local
  in Keychain.
- Fresh `PayloadUUID`s are generated on every run.
- Output is validated with `plutil -lint`.
- Requires `python3` (preinstalled on macOS), used only to parse the JSON and
  emit a valid plist.

## Validation rules

The script stops with an error if:

- the input is not valid JSON or has no `shares` array
- a share is missing `alias` or `shareName`
- a share has no `endpoints`
- an endpoint is missing `serverIP` or `networkType`
