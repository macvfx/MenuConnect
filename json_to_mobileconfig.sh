#!/bin/bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<'EOF'
Usage:
  json_to_mobileconfig.sh -i SETUP_JSON [-o OUTPUT_FILE]
                          [--organization "Your Organization"]
                          [--identifier-prefix com.matx.SMBConnect]
                          [--allow-user-defined true|false]
                          [--display-name "SMB Connect Configuration"]
                          [--blank-username]

Description:
  Converts an existing SMB Connect setup JSON file (the same format the app
  exports and imports) into a macOS .mobileconfig MDM profile that force-sets
  the ManagedShares and AllowUserDefinedShares keys in the com.matx.SMBConnect
  preferences domain.

  This is the MDM equivalent of importing the JSON in the app UI. Use it when
  you already have a setup JSON and want a deployable profile from it.

What it maps:
  - shares[].connectionProtocol  -> protocol   (also accepts "protocol" in input)
  - shares[].source              -> dropped    (reader forces source = mdmManaged)
  - top-level configDate/shares wrapper -> flat ManagedShares array
  - every other share/endpoint field is copied through unchanged

Notes:
  - Passwords are never present in the JSON or the profile.
  - Fresh PayloadUUIDs are generated on every run.
  - AllowUserDefinedShares defaults to true. The input JSON may set a top-level
    "allowUserDefinedShares" boolean; the --allow-user-defined flag overrides it.
  - --blank-username drops defaultUsername from every managed share even when the
    JSON provides one, so each user fills in their own username locally. Use this
    when one server is accessed with a different account per macOS user.

Examples:
  ./scripts/json_to_mobileconfig.sh \
    -i ./Config/SMBConnectSetup-AVNAS.json \
    -o ./Config/generated/SMBConnectSetup-AVNAS.mobileconfig \
    --organization "Matx"

  ./scripts/json_to_mobileconfig.sh \
    -i ./Config/SMBConnectSetup-EXAMPLE.json \
    --allow-user-defined false
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

INPUT_FILE=""
OUTPUT_FILE=""
ORGANIZATION="Your Organization"
IDENTIFIER_PREFIX="com.matx.SMBConnect"
ALLOW_USER_DEFINED=""
DISPLAY_NAME="SMB Connect Configuration"
BLANK_USERNAME="false"

while (( $# > 0 )); do
  case "$1" in
    -i|--input)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      INPUT_FILE="$2"
      shift 2
      ;;
    -o|--output)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --organization)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      ORGANIZATION="$2"
      shift 2
      ;;
    --identifier-prefix)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      IDENTIFIER_PREFIX="$2"
      shift 2
      ;;
    --allow-user-defined)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      case "$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')" in
        true|yes|1) ALLOW_USER_DEFINED="true" ;;
        false|no|0) ALLOW_USER_DEFINED="false" ;;
        *) die "Invalid boolean value '$2'. Use true or false." ;;
      esac
      shift 2
      ;;
    --display-name)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      DISPLAY_NAME="$2"
      shift 2
      ;;
    --blank-username)
      BLANK_USERNAME="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$INPUT_FILE" ]] || die "Input file is required. Use -i SETUP_JSON."
[[ -f "$INPUT_FILE" ]] || die "Input file not found: $INPUT_FILE"

if [[ -z "$OUTPUT_FILE" ]]; then
  OUTPUT_FILE="${INPUT_FILE%.*}.mobileconfig"
fi

OUTPUT_DIR="$(dirname "$OUTPUT_FILE")"
mkdir -p "$OUTPUT_DIR"

command -v python3 >/dev/null 2>&1 || die "python3 is required but was not found in PATH."

INPUT_FILE="$INPUT_FILE" \
OUTPUT_FILE="$OUTPUT_FILE" \
ORGANIZATION="$ORGANIZATION" \
IDENTIFIER_PREFIX="$IDENTIFIER_PREFIX" \
ALLOW_USER_DEFINED="$ALLOW_USER_DEFINED" \
DISPLAY_NAME="$DISPLAY_NAME" \
BLANK_USERNAME="$BLANK_USERNAME" \
PAYLOAD_TYPE="com.matx.SMBConnect" \
python3 <<'PY'
import json
import os
import plistlib
import sys
import uuid

def die(msg):
    sys.stderr.write("Error: %s\n" % msg)
    sys.exit(1)

input_file = os.environ["INPUT_FILE"]
output_file = os.environ["OUTPUT_FILE"]
organization = os.environ["ORGANIZATION"]
identifier_prefix = os.environ["IDENTIFIER_PREFIX"]
allow_flag = os.environ["ALLOW_USER_DEFINED"]
display_name = os.environ["DISPLAY_NAME"]
blank_username = os.environ["BLANK_USERNAME"] == "true"
payload_type = os.environ["PAYLOAD_TYPE"]

try:
    with open(input_file, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except json.JSONDecodeError as exc:
    die("Input is not valid JSON: %s" % exc)

if not isinstance(data, dict):
    die("Top-level JSON must be an object with a 'shares' array.")

shares = data.get("shares")
if not isinstance(shares, list) or not shares:
    die("No 'shares' array found in %s" % input_file)

# AllowUserDefinedShares: flag overrides JSON, JSON overrides default (true).
if allow_flag in ("true", "false"):
    allow_user_defined = allow_flag == "true"
elif isinstance(data.get("allowUserDefinedShares"), bool):
    allow_user_defined = data["allowUserDefinedShares"]
else:
    allow_user_defined = True

def require_str(value, field, index):
    if not isinstance(value, str) or not value.strip():
        die("Share %d is missing required field '%s'." % (index + 1, field))
    return value

managed_shares = []
for index, share in enumerate(shares):
    if not isinstance(share, dict):
        die("Share %d is not an object." % (index + 1))

    alias = require_str(share.get("alias"), "alias", index)
    share_name = require_str(share.get("shareName"), "shareName", index)

    # The app's MDM reader expects "protocol"; setup JSON uses "connectionProtocol".
    proto = share.get("protocol") or share.get("connectionProtocol") or "smb"

    raw_endpoints = share.get("endpoints")
    if not isinstance(raw_endpoints, list) or not raw_endpoints:
        die("Share %d ('%s') has no endpoints." % (index + 1, alias))

    endpoints = []
    for ep_index, ep in enumerate(raw_endpoints):
        if not isinstance(ep, dict):
            die("Share %d endpoint %d is not an object." % (index + 1, ep_index + 1))
        server_ip = require_str(ep.get("serverIP"), "endpoints[].serverIP", index)
        network_type = require_str(ep.get("networkType"), "endpoints[].networkType", index)

        out_ep = {"serverIP": server_ip, "networkType": network_type}
        # Copy optional endpoint fields through only when present.
        if isinstance(ep.get("priority"), int):
            out_ep["priority"] = ep["priority"]
        if isinstance(ep.get("subnetPrefix"), int):
            out_ep["subnetPrefix"] = ep["subnetPrefix"]
        if isinstance(ep.get("label"), str) and ep["label"]:
            out_ep["label"] = ep["label"]
        endpoints.append(out_ep)

    managed = {
        "alias": alias,
        "protocol": proto,
        "shareName": share_name,
        "mountName": share.get("mountName") or share_name,
        "defaultUsername": "" if blank_username else (share.get("defaultUsername") or ""),
        "note": share.get("note") or "",
        "endpoints": endpoints,
    }
    managed_shares.append(managed)

settings_payload = {
    "PayloadType": payload_type,
    "PayloadVersion": 1,
    "PayloadIdentifier": identifier_prefix + ".settings",
    "PayloadUUID": str(uuid.uuid4()).upper(),
    "PayloadDisplayName": "SMB Connect Settings",
    "AllowUserDefinedShares": allow_user_defined,
    "ManagedShares": managed_shares,
}

profile = {
    "PayloadContent": [settings_payload],
    "PayloadDisplayName": display_name,
    "PayloadIdentifier": identifier_prefix + ".profile",
    "PayloadOrganization": organization,
    "PayloadType": "Configuration",
    "PayloadUUID": str(uuid.uuid4()).upper(),
    "PayloadVersion": 1,
}

with open(output_file, "wb") as fh:
    plistlib.dump(profile, fh)

print("Created:")
print("  %s" % output_file)
print("Processed %d share(s)." % len(managed_shares))
PY
