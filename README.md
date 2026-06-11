# SMB Connect

`v0.4.1` · `macOS 14+` · `SwiftUI` · `Menu Bar Utility`

SMB Connect is a macOS menu bar app for mounting SMB shares with awareness of preferred and fallback network paths such as `10GbE`, `1GbE`, `25GbE`, and `100GbE`.

It is designed for environments where users regularly connect to multiple storage targets and need the app to:

- *NEW* v0.4.0 can connect all ready shares in one click or automatically on app start
- *FIXED* v0.4.1 fixes the SMB Connect Settings window so it reliably comes to the front when opened from the menu bar app.

## What The App Does

- Configures shares by alias, share name, mount name, and one or more IP-based network paths
- Detects active local networks and selects the best reachable configured path
- Mounts SMB shares through macOS using stored user credentials
- Shows connection state in the menu bar popover with per-share status cards
- Connects all ready shares in one click (`Connect All`, `⌘K`) or automatically on app start
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


## Included Example Configuration

This repo includes public sample inputs and a generator for creating valid SMB Connect setup JSON and matching `.mobileconfig` profiles.

The generator script is here:

- [generate_smbconnect_config.sh](generate_smbconnect_config.sh)
- [mount_to_smbconnect_config.sh](mount_to_smbconnect_config.sh)

Generator usage is documented here:

- [README-config-generator.md](README-config-generator.md)
- [README-mount-import.md](README-mount-import.md)

*EXTRA:* a small macOS SwiftUI companion app named **Mount Import Assistant** for the same mounted-share import workflow. Use the app or the portable shell scripts. 

External inventory handoff files are here:

- [DEVICE-INVENTORY-TEMPLATE.md](DEVICE-INVENTORY-TEMPLATE.md)
- [device-inventory-template.csv](examples/device-inventory-template.csv)
- [device-inventory-example.csv](examples/device-inventory-example.csv)
- [SITE-DEVICE-LIST-TEMPLATE.md](SITE-DEVICE-LIST-TEMPLATE.md)
- [site-device-list-template.csv](examples/site-device-list-template.csv)
- [site-device-list-example.csv](examples/site-device-list-example.csv)

Additional sample inputs are here:

- [server-shares-example.csv](examples/server-shares-example.csv)
- [server-shares-example.txt](examples/server-shares-example.txt)
- [mount-output-example.txt](examples/mount-output-example.txt)
