# SMB Connect

`v0.4.0` · `macOS 14+` · `SwiftUI` · `Menu Bar Utility`

SMB Connect is a macOS menu bar app for mounting SMB shares with awareness of preferred and fallback network paths such as `10GbE`, `1GbE`, `25GbE`, and `100GbE`.

It is designed for environments where users regularly connect to multiple storage targets and need the app to:

- show whether each share is mounted
- prefer the fastest configured network path when available
- fall back cleanly to a slower path when needed
- keep passwords in the user’s Keychain
- support both JSON-based setup and MDM-managed deployment
- warn about duplicate mounts and `/Volumes` naming conflicts before they create `-1` mount paths
- *NEW* connect all ready shares in one click or automatically on app start

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

The repo includes sample configuration files in 
If you want to generate valid SMB Connect setup JSON and matching `.mobileconfig` profiles from a comma-separated `.csv` or `.txt` list, use:

- `generate_smbconnect_config.sh`
  
Usage details and sample input files are documented in the script read me

The script is here:

- [generate_smbconnect_config.sh](generate_smbconnect_config.sh)

Example inputs are here:

- [server-shares-example.csv](examples/server-shares-example.csv)
- [server-shares-example.txt](examples/server-shares-example.txt)
