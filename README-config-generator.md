# SMB Connect Config Generator

This generator converts a comma-separated `.csv` or `.txt` file into:

- an SMB Connect setup JSON file
- a macOS `.mobileconfig` MDM profile

The script is here:

- [generate_smbconnect_config.sh](generate_smbconnect_config.sh)

Example inputs are here:

- [server-shares-example.csv](examples/server-shares-example.csv)
- [server-shares-example.txt](examples/server-shares-example.txt)
- [device-inventory-template.csv](examples/device-inventory-template.csv)
- [device-inventory-example.csv](examples/device-inventory-example.csv)

## Input format

The script requires this 10-column row format:

```text
alias,protocol,shareName,mountName,defaultUsername,note,preferredIP,preferredSpeed,fallbackIP,fallbackSpeed
```

Example:

```text
archives,smb,Archives,Archives,Archives.archivist,Primary archive share for editors,10.0.1.1,10g,192.168.1.1,1g
```

## Accepted values

- `protocol`: only `smb`
- `speed preferred` / `speed fallback`: `100g`, `40g`, `25g`, `10g`, `5g`, `2.5g`, `1g`, or `custom`
- `preferred ip` / `fallback ip`: IPv4 address

Blank lines and lines starting with `#` are ignored.

A header row is optional.

If both fallback columns are blank, the script creates a single-endpoint share and treats the listed IP as the preferred endpoint by default.

For a handoff-friendly inventory sheet, use [device-inventory-template.csv](examples/device-inventory-template.csv). It uses the same 10-column format with labels that make the preferred `10GbE` and fallback `1GbE` paths clear to the person filling it out. See [Device Inventory Template For SMB Connect](DEVICE-INVENTORY-TEMPLATE.md) for guidance.

## Usage

From the repo root:

```bash
chmod +x ./generate_smbconnect_config.sh
./generate_smbconnect_config.sh \
  -i ./examples/server-shares-example.csv \
  -o ./generated/SMBConnectSetup-Team
```

That produces:

```text
./generated/SMBConnectSetup-Team.json
./generated/SMBConnectSetup-Team.mobileconfig
```

## Optional flags

```text
--config-date YYYYMMDD
--organization "Your Organization"
--identifier-prefix com.example.SMBConnect
--allow-user-defined true|false
```

Example:

```bash
./generate_smbconnect_config.sh \
  -i ./examples/server-shares-example.txt \
  -o ./generated/SMBConnectSetup-Studios \
  --config-date 20260420 \
  --organization "Matx" \
  --identifier-prefix com.matx.SMBConnect \
  --allow-user-defined true
```

## What gets generated

The JSON output matches the app's setup import format.

The `.mobileconfig` output uses:

- `ManagedShares`
- `AllowUserDefinedShares`
- `protocol` for the managed share payload

Each generated endpoint gets:

- a normalized `networkType`
- the app's default priority for that network speed
- `subnetPrefix` set to `24`
- a label like `Preferred 10GbE` or `Fallback 1GbE`

## Validation rules

The script stops with an error if:

- a row has the wrong number of columns
- protocol is not `smb`
- an IP address is invalid
- a speed label is not recognized
- fallback IP and fallback speed do not appear together

## Notes

- Passwords are not stored in either output file.
- `source` is set to `imported` in the generated JSON.
- The script creates fresh UUIDs for every generated `.mobileconfig`.
