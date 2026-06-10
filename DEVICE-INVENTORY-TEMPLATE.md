# Device Inventory Template For SMB Connect

Use [device-inventory-template.csv](examples/device-inventory-template.csv) when asking someone to collect SMB share details. The file is intentionally shaped to match the SMB Connect config generator, so a completed copy can be converted directly into setup JSON and a `.mobileconfig` profile.

## How To Fill It Out

Use one row per SMB share, not one row per physical server. If a server exposes three shares, add three rows.

| Column | What to enter |
|---|---|
| `server alias` | Friendly display name in SMB Connect, such as `edit-archive` or `exports-nas`. |
| `protocol` | Use `smb`. |
| `share name` | SMB share path component, such as `Archives` in `smb://server/Archives`. |
| `mount name` | Expected volume name under `/Volumes`. Usually the same as `share name`. |
| `user name` | Default username to prefill. Passwords are not stored in the CSV or generated config. |
| `note` | Optional device/location/context, such as rack, owner, or support notes. |
| `10GbE IP` | Fast/preferred server IP for this share. |
| `speed preferred` | Usually `10g` or `10gbe`. Other accepted values are `100g`, `40g`, `25g`, `5g`, `2.5g`, `1g`, and `custom`. |
| `1GbE IP` | Fallback server IP for this share. Leave blank if there is no fallback path. |
| `speed fallback` | Usually `1g` or `1gbe`. Leave blank if `1GbE IP` is blank. |

See [device-inventory-example.csv](examples/device-inventory-example.csv) for filled examples.

## Convert A Completed Inventory

From the repo root, save the completed CSV and run:

```bash
./generate_smbconnect_config.sh \
  -i ./examples/device-inventory-template.csv \
  -o ./generated/SMBConnectSetup-Inventory \
  --organization "Your Organization" \
  --identifier-prefix com.example.SMBConnect \
  --allow-user-defined true
```

That writes:

- `generated/SMBConnectSetup-Inventory.json`
- `generated/SMBConnectSetup-Inventory.mobileconfig`

Import the JSON in SMB Connect, or deploy the `.mobileconfig` through MDM.

## Notes For Collectors

- Use IPv4 addresses only.
- Put the fastest reliable path in the preferred columns.
- If a fallback IP is provided, a fallback speed must also be provided.
- Do not include passwords.
- Keep commas out of notes, or wrap the note in double quotes.
