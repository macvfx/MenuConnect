# SMB Connect

`v0.2.0` · `macOS 14+` · `SwiftUI` · `Menu Bar Utility`

SMB Connect is a macOS menu bar app for mounting SMB shares with awareness of preferred and fallback network paths such as `10GbE`, `1GbE`, `25GbE`, and `100GbE`.

It is designed for environments where users regularly connect to multiple storage targets and need the app to:

- show whether each share is mounted
- prefer the fastest configured network path when available
- fall back cleanly to a slower path when needed
- keep passwords in the user’s Keychain
- support both JSON-based setup and MDM-managed deployment
- warn about duplicate mounts and `/Volumes` naming conflicts before they create `-1` mount paths

## What The App Does

- Configures shares by alias, share name, mount name, and one or more IP-based network paths
- Detects active local networks and selects the best reachable configured path
- Mounts SMB shares through macOS using stored user credentials
- Shows connection state in the menu bar popover with per-share status cards
- Detects duplicate mounts such as `Video` and `Video-1`
- Detects `/Volumes` name conflicts before mounting and blocks risky connects
- Exports and imports JSON configuration files
- Reads managed share definitions from an MDM profile

## Configuration Priority

Configuration is layered in this order:

1. MDM-managed share definitions
2. Setup JSON files in `~/Library/Application Support/SMBConnect/Setup/`
3. Imported JSON files from the app UI
4. User-edited local settings
5. User-specific credentials in Keychain

MDM and JSON can preload share names, IPs, preferred network order, and default usernames.
Passwords are intentionally user-local and are not stored in JSON or MDM.

## Build And Run

```bash
xcodegen generate
./script/build_and_run.sh
```

The script detects a valid `Apple Development` certificate in your Keychain and passes the corresponding team ID to `xcodebuild`. Hardened runtime requires a real signing identity, so a developer certificate enrolled in the Apple Developer Program is needed. If no certificate is found the script falls back to an unsigned build (suitable for quick compile checks only — the app will not launch due to hardened runtime restrictions).

To enrol: open Xcode → Preferences → Accounts → add your Apple ID → download certificates. Then re-run the script.

For a quick local verification:

```bash
./script/build_and_run.sh --verify
```

## Included Example Configuration

The repo includes sample configuration files in [Config](</Users/xavier/Downloads/All Code Projects/SMB Connect/Config>):

- [SMBConnectSetup-EXAMPLE.json](/Users/xavier/Downloads/All%20Code%20Projects/SMB%20Connect/Config/SMBConnectSetup-EXAMPLE.json:1)
- [SMBConnectSetup-AVNAS.json](/Users/xavier/Downloads/All%20Code%20Projects/SMB%20Connect/Config/SMBConnectSetup-AVNAS.json:1)
- [SMBConnectSetup-DEMO-SIX-SERVERS.json](/Users/xavier/Downloads/All%20Code%20Projects/SMB%20Connect/Config/SMBConnectSetup-DEMO-SIX-SERVERS.json:1)
- [com.matx.SMBConnect.mobileconfig](/Users/xavier/Downloads/All%20Code%20Projects/SMB%20Connect/Config/com.matx.SMBConnect.mobileconfig:1)

If you want to generate valid SMB Connect setup JSON and matching `.mobileconfig` profiles from a comma-separated `.csv` or `.txt` list, use:

- [scripts/generate_smbconnect_config.sh](/Users/xavier/Downloads/All%20Code%20Projects/SMB%20Connect/scripts/generate_smbconnect_config.sh:1)

Usage details and sample input files are documented in:

- [scripts/README-config-generator.md](/Users/xavier/Downloads/All%20Code%20Projects/SMB%20Connect/scripts/README-config-generator.md:1)

## Documentation

- [User Guide](docs/USER-GUIDE.md)
- [Configuration Format](docs/CONFIGURATION-FORMAT.md)
- [Config Generator README](scripts/README-config-generator.md)
- [Implementation Plan](docs/IMPLEMENTATION-PLAN.md)
- [Duplicate Mount Repair Plan](docs/DUPLICATE-MOUNT-REPAIR-PLAN.md)
