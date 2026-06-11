# Mount Output To SMB Connect JSON

Use [mount_to_smbconnect_config.sh](mount_to_smbconnect_config.sh) to turn raw macOS `mount` output into an SMB Connect setup JSON file.

This is useful when someone already has SMB shares mounted and you want to bootstrap an import config from the mounted SMB URLs.

*EXTRA:* a small macOS SwiftUI companion app named **Mount Import Assistant** for the same mounted-share import workflow. Use the app or the portable shell scripts.

## Input

Capture mount output from the Mac that has the shares mounted:

```bash
mount > mount-output.txt
```

The script reads lines like:

```text
//user@192.0.2.20/Archives on /Volumes/Archives (smbfs, nodev, nosuid, mounted by user)
```

It ignores non-SMB mounts.

The example files use documentation-only IP ranges:

- `192.0.2.0/24` for example 10GbE paths
- `198.51.100.0/24` for example 1GbE paths
- `203.0.113.0/24` for example VPN or custom-speed paths

## Example

```bash
./mount_to_smbconnect_config.sh \
  -i ./examples/mount-output-example.txt \
  -o ./generated/SMBConnectSetup-FromMounts.json \
  --ip-speed 192.0.2.20=10g \
  --ip-speed 198.51.100.20=1g \
  --ip-speed 192.0.2.21=10g \
  --ip-speed 203.0.113.22=custom \
  --non-interactive
```

That writes:

- `generated/SMBConnectSetup-FromMounts.json`
- `generated/SMBConnectSetup-FromMounts.report.txt`

## Directly From `mount`

On a Mac with the shares currently mounted, you can pipe `mount` directly into the tool:

```bash
mount | ./mount_to_smbconnect_config.sh \
  -o ./generated/SMBConnectSetup-FromMounts.json \
  --non-interactive \
  --default-speed custom
```

Use `--ip-speed IP=SPEED` to label known paths in the same command:

```bash
mount | ./mount_to_smbconnect_config.sh \
  -o ./generated/SMBConnectSetup-FromMounts.json \
  --ip-speed 192.0.2.20=10g \
  --ip-speed 198.51.100.20=1g \
  --non-interactive
```

If you want the script to prompt for speeds, omit `--non-interactive`. When input is piped from `mount`, prompts are read from the terminal instead of from the pipe.

## Preferred And Fallback Paths

SMB Connect needs endpoint speeds so it can choose preferred and fallback paths. The script supports two modes:

- Interactive mode prompts once per detected server IP.
- Non-interactive mode uses `--ip-speed IP=SPEED` values, or `--default-speed custom` for anything not mapped.

Accepted speeds are:

```text
100g, 40g, 25g, 10g, 5g, 2.5g, 1g, custom
```

Lower-priority, faster speeds become preferred endpoints in the generated JSON. For example, `10g` is preferred over `1g`.

## Duplicate And Multi-IP Warnings

The script writes a report next to the JSON. Review the report before importing.

It calls out:

- the same share mounted from multiple server IPs
- Finder-style duplicate mount paths such as `/Volumes/Archives-1`, treated as broken extra mounts and grouped under the base mount name
- the same share appearing as multiple mounted volume names

These warnings are important because they may indicate the Mac has both preferred and fallback paths mounted, or that Finder created a duplicate `-1` or `-2` mount. In the generated JSON, duplicate suffix mounts are grouped under the base mount name.

## Usernames

Mounted SMB usernames are omitted from generated JSON by default. This avoids carrying personal account names from raw mount output into a reusable config.

Use `--include-usernames` only when you intentionally want the generated `defaultUsername` field to use the mounted SMB username.

For a bespoke per-device config, you can include usernames in either of these ways:

```bash
./mount_to_smbconnect_config.sh \
  -i mount-output.txt \
  -o ./generated/SMBConnectSetup-ThisMac.json \
  --include-usernames
```

That uses the SMB username from the mount URL when a share has one unique mounted username.

If you want every generated share to use the same account name, or the mount output contains multiple SMB usernames, use `--default-username`:

```bash
./mount_to_smbconnect_config.sh \
  -i mount-output.txt \
  -o ./generated/SMBConnectSetup-ThisMac.json \
  --default-username example.user
```

`--default-username` overrides mount-derived usernames for every generated share. Passwords are still never written to JSON; each user saves their password locally in SMB Connect.
