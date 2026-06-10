# Site And Device List Template

Use [site-device-list-template.csv](examples/site-device-list-template.csv) to collect a simple office, storage, and Mac device inventory before creating SMB Connect share imports.

This worksheet is for planning and handoff. It is not consumed directly by `generate_smbconnect_config.sh`. After it is filled out, use the server/storage rows to create the SMB Connect import rows in [device-inventory-template.csv](examples/device-inventory-template.csv).

## What It Captures

Use one row for each useful server/device pairing at a site. If one storage server is used by five Macs, add five rows. If you only need to list server storage without a specific Mac yet, leave the device columns blank.

| Column | What to enter |
|---|---|
| `office or region` | Site name, office, region, or remote group. |
| `site notes` | Optional context such as rack, VLAN, subnet, support owner, or access notes. |
| `main server or storage` | Server, NAS, SAN gateway, or storage system name. |
| `server role` | Example: primary edit storage, archive NAS, VPN gateway, backup server. |
| `share or service` | SMB share name or service exposed by the server. |
| `server 10GbE IP` | Server IP on the fast local network, if available. |
| `server 1GbE IP` | Server IP on the regular office network, if available. |
| `server WireGuard VPN IP` | Server IP reachable over WireGuard, if available. |
| `device owner or team` | Person, team, department, or role using the device. |
| `device type` | Example: Mac laptop, Mac desktop, Mac mini, Mac Studio. |
| `mac model` | Human-readable Mac model. |
| `device name` | Computer name or asset name. |
| `device 10GbE IP` | Device IP on the fast local network, if available. |
| `device 1GbE IP` | Device IP on the office network, if available. |
| `device Tailscale IP` | Device Tailscale IP, if available. |
| `device WireGuard IP` | Device WireGuard IP, if available. |
| `notes` | Anything that helps interpret the row. |

See [site-device-list-example.csv](examples/site-device-list-example.csv) for filled examples.

The examples use documentation-only IP ranges:

- `192.0.2.0/24` for example 10GbE paths
- `198.51.100.0/24` for example 1GbE paths
- `203.0.113.0/24` for example VPN, WireGuard, Tailscale, or custom-speed paths

## Turning This Into SMB Connect Config

For SMB Connect imports, each SMB share becomes a row in [device-inventory-template.csv](examples/device-inventory-template.csv).

Use these fields from the site/device list:

| Site/device list field | SMB Connect inventory field |
|---|---|
| `main server or storage` | `server alias` |
| `share or service` | `share name` and usually `mount name` |
| `server 10GbE IP` | `10GbE IP` |
| `server 1GbE IP` | `1GbE IP` |
| `server role`, `office or region`, `site notes` | `note` |

WireGuard and Tailscale addresses are useful for planning and support, but the current generator template only creates one preferred path and one fallback path. If a VPN path should be used as the fallback SMB address, put that VPN IP into the fallback IP column and set the fallback speed to `custom`.
