#!/bin/bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<'EOF'
Usage:
  generate_smbconnect_config.sh -i INPUT_FILE [-o OUTPUT_BASENAME]
                                [--config-date YYYYMMDD]
                                [--organization "Your Organization"]
                                [--identifier-prefix com.example.SMBConnect]
                                [--allow-user-defined true|false]

Description:
  Reads a comma-separated .csv or .txt file and generates:
  - an SMB Connect setup JSON file
  - a macOS .mobileconfig MDM profile

Accepted input formats per non-empty line:
  10 columns:
    alias,protocol,shareName,mountName,defaultUsername,note,preferredIP,preferredSpeed,fallbackIP,fallbackSpeed

Notes:
  - Blank lines and lines starting with # are ignored.
  - A header row is optional and will be skipped automatically.
  - Supported speeds: 100g, 40g, 25g, 10g, 5g, 2.5g, 1g, custom
  - Protocol must be smb.
  - If fallbackIP and fallbackSpeed are both blank, a single preferred endpoint is generated.

Examples:
  ./scripts/generate_smbconnect_config.sh \
    -i ./scripts/examples/server-shares-example.csv \
    -o ./Config/generated/SMBConnectSetup-Team

  ./scripts/generate_smbconnect_config.sh \
    -i ./scripts/examples/server-shares-example.txt \
    --organization "Matx" \
    --identifier-prefix com.matx.SMBConnect \
    --allow-user-defined true
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

xml_escape() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  value="${value//\"/&quot;}"
  value="${value//\'/&apos;}"
  printf '%s' "$value"
}

normalize_boolean() {
  case "$(lower "$1")" in
    true|yes|1) printf 'true' ;;
    false|no|0) printf 'false' ;;
    *) die "Invalid boolean value '$1'. Use true or false." ;;
  esac
}

normalize_protocol() {
  local value
  value="$(lower "$(trim "$1")")"
  [[ "$value" == "smb" ]] || die "Unsupported protocol '$1'. Only 'smb' is allowed."
  printf 'smb'
}

normalize_speed() {
  local value
  value="$(lower "$(trim "$1")")"
  case "$value" in
    100g|100gbe) printf '100gbe' ;;
    40g|40gbe) printf '40gbe' ;;
    25g|25gbe) printf '25gbe' ;;
    10g|10gbe) printf '10gbe' ;;
    5g|5gbe) printf '5gbe' ;;
    2.5g|2_5g|2.5gbe|2_5gbe) printf '2_5gbe' ;;
    1g|1gbe) printf '1gbe' ;;
    custom) printf 'custom' ;;
    *) die "Unsupported speed '$1'. Use one of: 100g, 40g, 25g, 10g, 5g, 2.5g, 1g, custom." ;;
  esac
}

speed_priority() {
  case "$1" in
    100gbe) printf '%s' '-30' ;;
    40gbe) printf '%s' '-20' ;;
    25gbe) printf '%s' '-10' ;;
    10gbe) printf '%s' '0' ;;
    5gbe) printf '%s' '5' ;;
    2_5gbe) printf '%s' '8' ;;
    1gbe) printf '%s' '10' ;;
    custom) printf '%s' '20' ;;
    *) die "No default priority mapping for speed '$1'." ;;
  esac
}

speed_display() {
  case "$1" in
    100gbe) printf '100GbE' ;;
    40gbe) printf '40GbE' ;;
    25gbe) printf '25GbE' ;;
    10gbe) printf '10GbE' ;;
    5gbe) printf '5GbE' ;;
    2_5gbe) printf '2.5GbE' ;;
    1gbe) printf '1GbE' ;;
    custom) printf 'Custom Speed' ;;
    *) die "No display label mapping for speed '$1'." ;;
  esac
}

is_valid_ipv4() {
  local ip="$1"
  local IFS=.
  local octets
  read -r -a octets <<< "$ip"
  [[ "${#octets[@]}" -eq 4 ]] || return 1
  local part
  for part in "${octets[@]}"; do
    [[ "$part" =~ ^[0-9]{1,3}$ ]] || return 1
    (( part >= 0 && part <= 255 )) || return 1
  done
  return 0
}

parse_csv_line() {
  local line="$1"
  FIELDS=()
  local field=""
  local in_quotes=0
  local i=0
  local length=${#line}
  local char next

  while (( i < length )); do
    char="${line:i:1}"
    if (( in_quotes )); then
      if [[ "$char" == '"' ]]; then
        next=""
        if (( i + 1 < length )); then
          next="${line:i+1:1}"
        fi
        if [[ "$next" == '"' ]]; then
          field+='"'
          ((i+=2))
          continue
        fi
        in_quotes=0
      else
        field+="$char"
      fi
    else
      case "$char" in
        ',')
          FIELDS+=("$(trim "$field")")
          field=""
          ;;
        '"')
          in_quotes=1
          ;;
        *)
          field+="$char"
          ;;
      esac
    fi
    ((i+=1))
  done

  (( in_quotes == 0 )) || die "Unterminated quoted field in line: $line"
  FIELDS+=("$(trim "$field")")
}

is_header_row() {
  local joined lowered
  joined="$(printf '%s|' "${FIELDS[@]}")"
  lowered="$(lower "$joined")"
  [[ "$lowered" == *"alias"* && "$lowered" == *"protocol"* && "$lowered" == *"share"* ]]
}

INPUT_FILE=""
OUTPUT_BASENAME=""
CONFIG_DATE="$(date '+%Y%m%d')"
ORGANIZATION="Your Organization"
IDENTIFIER_PREFIX="com.example.SMBConnect"
ALLOW_USER_DEFINED="true"

while (( $# > 0 )); do
  case "$1" in
    -i|--input)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      INPUT_FILE="$2"
      shift 2
      ;;
    -o|--output-basename)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      OUTPUT_BASENAME="$2"
      shift 2
      ;;
    --config-date)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      CONFIG_DATE="$2"
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
      ALLOW_USER_DEFINED="$(normalize_boolean "$2")"
      shift 2
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

[[ -n "$INPUT_FILE" ]] || die "Input file is required. Use -i INPUT_FILE."
[[ -f "$INPUT_FILE" ]] || die "Input file not found: $INPUT_FILE"
[[ "$CONFIG_DATE" =~ ^[0-9]{8}$ ]] || die "configDate must be in YYYYMMDD format."

if [[ -z "$OUTPUT_BASENAME" ]]; then
  OUTPUT_BASENAME="${INPUT_FILE%.*}"
fi

OUTPUT_DIR="$(dirname "$OUTPUT_BASENAME")"
mkdir -p "$OUTPUT_DIR"

JSON_OUTPUT="${OUTPUT_BASENAME}.json"
PROFILE_OUTPUT="${OUTPUT_BASENAME}.mobileconfig"

TOP_PAYLOAD_UUID="$(uuidgen)"
SETTINGS_PAYLOAD_UUID="$(uuidgen)"

json_body=""
xml_body=""
share_count=0
line_number=0

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  ((line_number+=1))

  raw_line="${raw_line%$'\r'}"
  local_trimmed="$(trim "$raw_line")"

  if [[ -z "$local_trimmed" || "${local_trimmed:0:1}" == "#" ]]; then
    continue
  fi

  parse_csv_line "$raw_line"

  if is_header_row; then
    continue
  fi

  field_count="${#FIELDS[@]}"
  if [[ "$field_count" -ne 10 ]]; then
    die "Line $line_number has $field_count fields. Expected exactly 10."
  fi

  alias="$(trim "${FIELDS[0]}")"
  protocol="$(normalize_protocol "${FIELDS[1]}")"
  share_name="$(trim "${FIELDS[2]}")"
  mount_name="$(trim "${FIELDS[3]}")"
  default_username="$(trim "${FIELDS[4]}")"
  note="$(trim "${FIELDS[5]}")"
  preferred_ip="$(trim "${FIELDS[6]}")"
  preferred_speed="$(trim "${FIELDS[7]}")"
  fallback_ip="$(trim "${FIELDS[8]}")"
  fallback_speed="$(trim "${FIELDS[9]}")"

  [[ -n "$alias" ]] || die "Line $line_number is missing alias."
  [[ -n "$share_name" ]] || die "Line $line_number is missing shareName."
  [[ -n "$mount_name" ]] || mount_name="$share_name"
  [[ -n "$preferred_ip" ]] || die "Line $line_number is missing preferred IP."
  [[ -n "$preferred_speed" ]] || die "Line $line_number is missing preferred speed."

  is_valid_ipv4 "$preferred_ip" || die "Line $line_number has invalid preferred IP: $preferred_ip"
  preferred_speed="$(normalize_speed "$preferred_speed")"
  preferred_priority="$(speed_priority "$preferred_speed")"
  preferred_label="Preferred $(speed_display "$preferred_speed")"

  endpoints_json=$(
    cat <<EOF
        {
          "serverIP": "$(json_escape "$preferred_ip")",
          "networkType": "$(json_escape "$preferred_speed")",
          "priority": $preferred_priority,
          "subnetPrefix": 24,
          "label": "$(json_escape "$preferred_label")"
        }
EOF
  )

  endpoints_xml=$(
    cat <<EOF
						<dict>
							<key>serverIP</key>
							<string>$(xml_escape "$preferred_ip")</string>
							<key>networkType</key>
							<string>$(xml_escape "$preferred_speed")</string>
							<key>priority</key>
							<integer>$preferred_priority</integer>
							<key>subnetPrefix</key>
							<integer>24</integer>
							<key>label</key>
							<string>$(xml_escape "$preferred_label")</string>
						</dict>
EOF
  )

  if [[ -n "$fallback_ip" || -n "$fallback_speed" ]]; then
    [[ -n "$fallback_ip" && -n "$fallback_speed" ]] || die "Line $line_number fallback IP and fallback speed must either both be set or both be blank."
    is_valid_ipv4 "$fallback_ip" || die "Line $line_number has invalid fallback IP: $fallback_ip"
    fallback_speed="$(normalize_speed "$fallback_speed")"
    fallback_priority="$(speed_priority "$fallback_speed")"
    fallback_label="Fallback $(speed_display "$fallback_speed")"

    endpoints_json+=$(
      cat <<EOF
,
        {
          "serverIP": "$(json_escape "$fallback_ip")",
          "networkType": "$(json_escape "$fallback_speed")",
          "priority": $fallback_priority,
          "subnetPrefix": 24,
          "label": "$(json_escape "$fallback_label")"
        }
EOF
    )

    endpoints_xml+=$(
      cat <<EOF
						<dict>
							<key>serverIP</key>
							<string>$(xml_escape "$fallback_ip")</string>
							<key>networkType</key>
							<string>$(xml_escape "$fallback_speed")</string>
							<key>priority</key>
							<integer>$fallback_priority</integer>
							<key>subnetPrefix</key>
							<integer>24</integer>
							<key>label</key>
							<string>$(xml_escape "$fallback_label")</string>
						</dict>
EOF
    )
  fi

  if (( share_count > 0 )); then
    json_body+=","
  fi

  json_body+=$(
    cat <<EOF

    {
      "alias": "$(json_escape "$alias")",
      "connectionProtocol": "$(json_escape "$protocol")",
      "shareName": "$(json_escape "$share_name")",
      "mountName": "$(json_escape "$mount_name")",
      "defaultUsername": "$(json_escape "$default_username")",
      "endpoints": [
$endpoints_json
      ],
      "note": "$(json_escape "$note")",
      "source": "imported"
    }
EOF
  )

  xml_body+=$(
    cat <<EOF
				<dict>
					<key>alias</key>
					<string>$(xml_escape "$alias")</string>
					<key>protocol</key>
					<string>$(xml_escape "$protocol")</string>
					<key>shareName</key>
					<string>$(xml_escape "$share_name")</string>
					<key>mountName</key>
					<string>$(xml_escape "$mount_name")</string>
					<key>defaultUsername</key>
					<string>$(xml_escape "$default_username")</string>
					<key>note</key>
					<string>$(xml_escape "$note")</string>
					<key>endpoints</key>
					<array>
$endpoints_xml
					</array>
				</dict>
EOF
  )

  ((share_count+=1))
done < "$INPUT_FILE"

(( share_count > 0 )) || die "No share rows found in $INPUT_FILE"

cat > "$JSON_OUTPUT" <<EOF
{
  "configDate": "$CONFIG_DATE",
  "shares": [$json_body
  ]
}
EOF

if [[ "$ALLOW_USER_DEFINED" == "true" ]]; then
  ALLOW_USER_DEFINED_XML="<true/>"
else
  ALLOW_USER_DEFINED_XML="<false/>"
fi

cat > "$PROFILE_OUTPUT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>PayloadContent</key>
	<array>
		<dict>
			<key>PayloadType</key>
			<string>com.matx.SMBConnect</string>
			<key>PayloadVersion</key>
			<integer>1</integer>
			<key>PayloadIdentifier</key>
			<string>$(xml_escape "$IDENTIFIER_PREFIX").settings</string>
			<key>PayloadUUID</key>
			<string>$SETTINGS_PAYLOAD_UUID</string>
			<key>PayloadDisplayName</key>
			<string>SMB Connect Settings</string>

			<key>AllowUserDefinedShares</key>
			$ALLOW_USER_DEFINED_XML

			<key>ManagedShares</key>
			<array>
$xml_body
			</array>
		</dict>
	</array>
	<key>PayloadDisplayName</key>
	<string>SMB Connect Configuration</string>
	<key>PayloadIdentifier</key>
	<string>$(xml_escape "$IDENTIFIER_PREFIX").profile</string>
	<key>PayloadOrganization</key>
	<string>$(xml_escape "$ORGANIZATION")</string>
	<key>PayloadType</key>
	<string>Configuration</string>
	<key>PayloadUUID</key>
	<string>$TOP_PAYLOAD_UUID</string>
	<key>PayloadVersion</key>
	<integer>1</integer>
</dict>
</plist>
EOF

echo "Created:"
echo "  $JSON_OUTPUT"
echo "  $PROFILE_OUTPUT"
echo "Processed $share_count share(s)."
