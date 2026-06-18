# SMB Connect

`v0.5.3` · `macOS 14+` · `SwiftUI` · `Menu Bar Utility`

SMB Connect is a macOS menu bar app for mounting SMB shares with awareness of preferred, fallback, and remote-reachability network paths such as `10GbE`, `1GbE`, `25GbE`, `100GbE`, and VPN/custom endpoints.

It is designed for environments where users regularly connect to multiple storage targets and need the app to:

- *FIXED* v0.5.3 stops a false `Mounted Wrong` / duplicate state caused by macOS system and autofs volumes (for example the `auto_home` map named `home`) matching a configured share such as `Home`, and posts a quiet macOS notification when a share genuinely needs attention. The app version is also shown in the popup (next to `Quit`) and in the bottom-left of the Settings window.
- *FIXED* v0.5.2 gives MDM-managed shares a stable identity so usernames and passwords can be entered once and persist, and adds `json_to_mobileconfig.sh` to convert a setup JSON into a profile.
- *NEW* v0.5.0 auto-reconnects dropped shares when the server is still reachable, with stale mount cleanup and a 60-second cooldown.
- *FIXED* v0.5.1 removes main-thread publishing warnings in the mount service.
- v0.4.1 fixed the SMB Connect Settings window so it reliably comes to the front when opened from the menu bar app.

## What The App Does

- Configures shares by alias, share name, mount name, and one or more IP-based network paths
- Detects active local networks and selects the best reachable configured path
- Mounts SMB shares through macOS using stored user credentials
- Shows connection state in the menu bar popover with per-share status cards
- Connects all ready shares in one click (`Connect All`, `⌘K`) or automatically on app start
- Auto-reconnects dropped shares when the server is still reachable, with stale mount cleanup and a 60-second cooldown
- Detects duplicate mounts such as `Video` and `Video-1`
- Limits mount detection to genuine network shares under `/Volumes`, so macOS system and autofs volumes (for example the `auto_home` map named `home`) no longer trigger a false "Mounted Wrong" / duplicate state
- Posts a quiet macOS notification when a share newly needs attention, instead of relying on the popup alone
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
- [json_to_mobileconfig.sh](json_to_mobileconfig.sh) — convert an existing setup JSON into an MDM `.mobileconfig`

Generator usage is documented here:

- [README-config-generator.md](README-config-generator.md)
- [README-mount-import.md](README-mount-import.md)
- [README-json-to-mobileconfig.md](README-json-to-mobileconfig.md)

*EXTRA:* a small macOS SwiftUI companion app named **Mount Import Assistant** for the same mounted-share import workflow. Use the app or the portable shell scripts.

For endpoint planning, use the FASTEST local path first: prefer the fastest reachable local network such as `10GbE`, fall back to slower local paths such as `1GbE`, and use VPN/WireGuard/Tailscale addresses as remote reachability or fallback paths unless a device is intentionally VPN-only.

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
