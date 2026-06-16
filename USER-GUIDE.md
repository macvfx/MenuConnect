# SMB Connect User Guide

## Overview

SMB Connect is a menu bar app for connecting to SMB shares by IP address while preferring the fastest configured network path.

Typical uses:

- connect to the same storage over `10GbE` when available and `1GbE` when not
- keep several shares ready in one menu bar utility
- preload share definitions from JSON or MDM
- let each user store their own password locally in Keychain

## How To Use The App

### 1. Open The Menu Bar App

Click the SMB Connect drive icon in the macOS menu bar.

The popover shows:

- a top banner with current active wired network information
- a `Connection Summary` section
- a `Shares` section with one status card per configured share
- `Refresh`, `Connect All`, `Settings`, and `Quit` actions at the bottom

### 2. Read The Connection Summary

The `Connection Summary` section gives a quick count of:

- `Mounted`
- `Preferred`
- `Fallback`
- `Attention`

Below that is a one-line summary per share so you can quickly scan which shares are connected and on what network speed.

### 3. Read A Share Card

Each share card is centered on one configured share alias.

A card shows:

- the share alias
- the SMB share name
- a `Connection` pill
- a `Status` pill
- a `Network` pill
- a summary line
- a detail line
- an action button such as `Connect`, `Disconnect`, `Fix Connection…`, or `Complete Setup…`

### 4. Understand The Main Pills

#### Connection

This tells you the broad connection state:

- `Connected`
- `Ready`
- `Blocked`
- `Not Connected`
- `Error`

#### Status

This tells you whether the share is on the expected path:

- `Preferred`
- `Fallback`
- `Fix Needed`
- `Duplicate`
- `Setup`
- `Blocked`

There may also be a second share-state pill such as:

- `Mounted`
- `Available`
- `Reconnect`
- `Setup Needed`
- `Rename /Volumes Item`

#### Network

This shows the current or selected network speed for that share, for example:

- `1GbE`
- `10GbE`
- `25GbE`
- `100GbE`

### 5. Use Connect All

The `Connect All` button (`⌘K`) in the footer connects every share that is currently in a ready state — meaning the preferred or fallback network path is reachable and credentials are saved in Keychain.

It is disabled when no shares are connectable (for example, when all shares are already mounted or no network paths are active).

Shares with missing credentials, name conflicts, or duplicate mounts are skipped and must be resolved individually.

## What The Main States Mean

### Connected On Preferred Network

The share is mounted and the app believes it is using the fastest configured preferred path.

### Connected On Fallback Network

The share is mounted, but the preferred path is not active or not selected.

### Preferred Network Available

The share is not mounted yet, but the preferred network path appears reachable and ready.

### Fallback Network Available

The share is not mounted yet, but only a slower fallback path appears available right now.

### Complete Setup

The share definition is present, but the user has not yet saved credentials in Keychain.

### Duplicate Mount Detected

The app has detected multiple mounted instances such as:

- `Video`
- `Video-1`

This is a warning condition and should usually be repaired before continuing work.

### Volume Name Conflict

The app found a local file or folder in `/Volumes` that already uses the share’s mount name.

Example:

- local folder: `/Volumes/Video`
- intended share mount: `Video`

If the app mounted anyway, macOS could create `Video-1`, which is exactly what SMB Connect is trying to prevent.

## Why `-1` Mount Paths Matter

If macOS mounts a share as `Video-1`, applications may record file paths using that full mounted path.

That is especially risky in Final Cut Pro because relinking later can become more difficult if media paths were recorded using a suffixed mount name.

SMB Connect tries to prevent this by:

- warning when duplicate mounts already exist
- blocking connects when a `/Volumes` name conflict would cause a `-1` mount
- offering repair guidance and reconnect workflows

## What To Do For A Volume Name Conflict

If the menu shows `Volume Name Conflict`:

1. Click `Open /Volumes in Finder`.
2. Inspect the conflicting item.
3. Rename or remove the local item that is occupying the intended mount name.
4. Return to SMB Connect and press `Refresh`.
5. Connect again.

If files are already open from that share, quit those apps first.

## What `Refresh` Does

`Refresh` does four things:

- re-evaluates any MDM managed preferences pushed since the last refresh
- rescans the setup folder for new JSON setup files
- rechecks active local network interfaces and reachability
- refreshes mounted volume and conflict status

Use it after:

- dropping a new setup JSON into the setup folder
- an MDM policy change is pushed to the device
- changing networks
- renaming or removing an item in `/Volumes`
- disconnecting or reconnecting shares outside the app

## Settings Window

Open `Settings…` from the menu bar popover.

The Settings window has a left sidebar and a right detail pane.

### Sidebar

The sidebar contains:

- `General`
- `Shares`

The `Shares` list shows each configured share alias, source, and preferred network summary.

### General Section

This contains:

- `Launch at login`
- `Connect all shares on start`
- `Setup Folder`
- `Refresh Status`

`Launch at login` registers the app with macOS to open automatically when the user logs in.

`Connect all shares on start` automatically connects every share that is in a ready state after the app finishes its first status check on launch. This works the same as pressing `Connect All` manually — only shares with saved credentials and a reachable network path are attempted. Shares with issues are skipped.

Pairing `Launch at login` with `Connect all shares on start` gives a fully automatic mount experience: the app opens at login and connects all ready shares without any user interaction.

`Setup Folder` is where the app looks for setup JSON files on startup and refresh:

`~/Library/Application Support/SMBConnect/Setup`

### Import / Export

This section is for:

- `Import JSON…`
- `Export JSON…`
- `Open Setup Folder`

Use `Import JSON…` to load a setup file manually from anywhere.

Use `Export JSON…` to save the current user-editable share definitions as JSON.

Passwords are not exported.

If you need to create a valid setup JSON file and a matching MDM `.mobileconfig` from a server list, the repo includes a helper script:

- [generate_smbconnect_config.sh](generate_smbconnect_config.sh)

It accepts a comma-separated `.csv` or `.txt` file using:

```text
alias,protocol,shareName,mountName,defaultUsername,note,preferredIP,preferredSpeed,fallbackIP,fallbackSpeed
```

and generates both output formats for SMB Connect.

Examples and usage details are here:

- [Config Generator README](README-config-generator.md)

If you already have a setup JSON and only need the matching MDM profile, convert
it directly:

- [json_to_mobileconfig.sh](json_to_mobileconfig.sh)
- [JSON → Profile README](README-json-to-mobileconfig.md)

### Share Settings

This section defines the core share identity.

Fields:

- `Source`
  Admin or config origin, such as user-defined, imported JSON, or MDM-managed.
- `Preferred Network`
  The first-choice network path for this share.
- `Alias`
  The display name shown in the menu bar.
- `Protocol`
  Currently `smb`.
- `Share Name`
  The SMB share path, such as `Outputs` in `smb://server/Video`.
- `Mount Name`
  The volume name expected in `/Volumes` after the share is mounted.
- `Default Username`
  A suggested username for the user.
- `Notes`
  Optional comments about the share.

### Network Paths

This section defines one or more IP-based paths to the same share.

Typical use:

- one preferred `10GbE` path
- one fallback `1GbE` path

For each network path, the app shows:

- `Server IP`
- `Network Speed`
- `Priority`
- `Subnet`
- `Label`

Lower priority numbers are preferred first.

### Credentials

This section stores the user’s login details in Keychain.

Fields:

- `Username`
- `Password`

Actions:

- `Save Credentials`
- `Delete Credentials`

Important:

- passwords are saved locally in Keychain
- passwords are not stored in JSON
- passwords are not stored in the MDM profile

### Current Status

This section shows the live status for the selected share and any repair guidance.

If the share needs repair or attention, this section explains why.

## JSON Configuration

SMB Connect can import and export JSON share definitions.

JSON is useful for:

- bootstrapping users
- copying a setup to another Mac
- keeping a backup of share definitions

JSON can define:

- alias
- protocol
- share name
- mount name
- default username
- one or more network paths
- path priority
- notes

Passwords are intentionally omitted.

## MDM Profile Configuration

SMB Connect also supports an MDM profile that preloads managed share definitions.

This is useful when IT wants to push:

- share aliases
- share names
- mount names
- preferred and fallback IPs
- network speed labels
- default usernames

The user can still enter and store their own password locally in Keychain.

You can build the profile directly from a setup JSON with
[json_to_mobileconfig.sh](json_to_mobileconfig.sh). Two options shape how it
behaves on the user's Mac:

- `--allow-user-defined true|false` — with `true` (the default) a deployed
  profile **keeps** each user's own imported shares and merges the managed ones
  on top, so pushing a profile does not wipe a user's existing setup. With
  `false`, the app shows only the managed shares.
- `--blank-username` — leave each managed share's `defaultUsername` empty so
  every user enters their own. Without it, the username from the JSON is baked
  into the profile and is identical (and locked) for all users on the device.

Passwords are never written to the profile. Full usage:

- [JSON → Profile README](README-json-to-mobileconfig.md)

## Recommended Admin Workflow

1. Create share definitions in JSON or MDM.
2. Preload alias, share name, mount name, and preferred/fallback IPs.
3. Optionally preload a default username, or use `--blank-username` so each user
   supplies their own.
4. To deploy by MDM, convert the JSON with
   [json_to_mobileconfig.sh](json_to_mobileconfig.sh) (or generate the profile
   directly). Keep `--allow-user-defined true` unless you want to lock users to
   only the managed shares.
5. Let the user open the app and save their password locally in Keychain.
6. Have the user connect from the menu bar app.

## Recommended User Workflow

1. Open SMB Connect from the menu bar.
2. Open `Settings…` if a share shows `Complete Setup`.
3. Save your username and password in the `Credentials` section.
4. Return to the menu bar app.
5. Press `Connect All` to mount all ready shares in one action, or connect individual shares as needed.
6. If warned about duplicate mounts or `/Volumes` conflicts, resolve those before editing media.

To connect automatically on every login, enable both `Launch at login` and `Connect all shares on start` in Settings → General.

## Troubleshooting

### The Share Does Not Connect

Check:

- the configured IP address
- whether the preferred or fallback network is actually active
- whether credentials were saved in Keychain
- whether the target SMB server is reachable

### The App Says `Volume Name Conflict`

There is already a local item in `/Volumes` using the mount name.
Open `/Volumes`, inspect the item, then rename or remove it before connecting.

### The App Says `Duplicate Mount Detected`

The share appears mounted more than once.
Use the repair workflow or manually disconnect all matching mounts and reconnect only once.

### The Share Mounted On The Wrong Network

If the app says the share is on a fallback or slower path, use the repair flow to disconnect and reconnect on the preferred network when available.
