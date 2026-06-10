#!/bin/bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<'EOF'
Usage:
  mount_to_smbconnect_config.sh -i MOUNT_OUTPUT [-o OUTPUT_JSON]
                                 [--config-date YYYYMMDD]
                                 [--default-speed SPEED]
                                 [--ip-speed IP=SPEED]
                                 [--non-interactive]
                                 [--include-usernames]
                                 [--default-username USERNAME]

Description:
  Reads raw macOS `mount` output, finds SMB mounts, and creates an SMB Connect
  setup JSON file. The script groups mounted shares by SMB share name and base
  /Volumes mount name, strips Finder duplicate suffixes such as -1 for grouping,
  and adds one endpoint for each detected server IP.

Notes:
  - Speeds must be one of: 100g, 40g, 25g, 10g, 5g, 2.5g, 1g, custom.
  - In interactive mode, the script prompts for a network speed per unique IP.
  - Use --ip-speed more than once to pre-label known IPs.
  - Mounted usernames are omitted by default. Use --include-usernames only if
    the generated JSON should prefill usernames from the mount output.
  - Use --default-username to force a username into every generated share.
  - A report is written next to OUTPUT_JSON, or to stderr when writing JSON to stdout.

Examples:
  ./scripts/mount_to_smbconnect_config.sh \
    -i ./scripts/examples/mount-output-example.txt \
    -o ./Config/generated/SMBConnectSetup-FromMounts.json \
    --ip-speed 192.0.2.20=10g \
    --ip-speed 198.51.100.20=1g \
    --ip-speed 203.0.113.22=custom

  mount | ./scripts/mount_to_smbconnect_config.sh \
    -o ./Config/generated/SMBConnectSetup-FromMounts.json \
    --non-interactive \
    --default-speed custom
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

url_decode() {
  local value="${1//+/ }"
  printf '%b' "${value//%/\\x}"
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

contains_value() {
  local needle="$1"
  shift
  local value
  for value in "$@"; do
    [[ "$value" == "$needle" ]] && return 0
  done
  return 1
}

DELIM=$'\034'

lookup_ip_speed() {
  local ip="$1"
  local mapping key value
  (( ${#IP_SPEED_MAPPINGS[@]} > 0 )) || return 1
  for mapping in "${IP_SPEED_MAPPINGS[@]}"; do
    key="${mapping%%=*}"
    value="${mapping#*=}"
    if [[ "$key" == "$ip" ]]; then
      normalize_speed "$value"
      return 0
    fi
  done
  return 1
}

speed_for_ip() {
  local ip="$1"
  local speed
  if speed="$(lookup_ip_speed "$ip")"; then
    printf '%s' "$speed"
    return
  fi

  if [[ "$NON_INTERACTIVE" == "true" ]]; then
    printf '%s' "$DEFAULT_SPEED"
    return
  fi

  local answer
  while true; do
    printf 'Network speed for server IP %s [%s]: ' "$ip" "$(speed_display "$DEFAULT_SPEED")" >&2
    if [[ "$INPUT_FILE" == "/dev/stdin" && -r /dev/tty ]]; then
      IFS= read -r answer </dev/tty
    elif [[ "$INPUT_FILE" == "/dev/stdin" ]]; then
      echo "Cannot prompt for network speeds while reading mount output from stdin without a terminal." >&2
      echo "Use --non-interactive with --default-speed, or save mount output to a file and pass -i FILE." >&2
      exit 1
    else
      IFS= read -r answer
    fi
    answer="$(trim "$answer")"
    [[ -n "$answer" ]] || answer="$DEFAULT_SPEED"
    if speed="$(normalize_speed "$answer" 2>/dev/null)"; then
      printf '%s' "$speed"
      return
    fi
    echo "Use one of: 100g, 40g, 25g, 10g, 5g, 2.5g, 1g, custom." >&2
  done
}

records_for_group() {
  local group_key="$1"
  local record
  for record in "${RECORDS[@]}"; do
    IFS="$DELIM" read -r username ip share volume base_volume suffix raw_key <<< "$record"
    if [[ "$raw_key" == "$group_key" ]]; then
      printf '%s\n' "$record"
    fi
  done
}

INPUT_FILE=""
OUTPUT_JSON=""
CONFIG_DATE="$(date '+%Y%m%d')"
DEFAULT_SPEED="custom"
NON_INTERACTIVE="false"
INCLUDE_USERNAMES="false"
DEFAULT_USERNAME_OVERRIDE=""
IP_SPEED_MAPPINGS=()

while (( $# > 0 )); do
  case "$1" in
    -i|--input)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      INPUT_FILE="$2"
      shift 2
      ;;
    -o|--output)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      OUTPUT_JSON="$2"
      shift 2
      ;;
    --config-date)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      CONFIG_DATE="$2"
      shift 2
      ;;
    --default-speed)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      DEFAULT_SPEED="$(normalize_speed "$2")"
      shift 2
      ;;
    --ip-speed)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      [[ "$2" == *=* ]] || die "--ip-speed must use IP=SPEED format."
      ip_key="${2%%=*}"
      is_valid_ipv4 "$ip_key" || die "--ip-speed has invalid IP: $ip_key"
      normalize_speed "${2#*=}" >/dev/null
      IP_SPEED_MAPPINGS+=("$2")
      shift 2
      ;;
    --non-interactive)
      NON_INTERACTIVE="true"
      shift
      ;;
    --include-usernames)
      INCLUDE_USERNAMES="true"
      shift
      ;;
    --default-username)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      DEFAULT_USERNAME_OVERRIDE="$2"
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

[[ "$CONFIG_DATE" =~ ^[0-9]{8}$ ]] || die "configDate must be in YYYYMMDD format."

if [[ -n "$INPUT_FILE" ]]; then
  [[ -f "$INPUT_FILE" ]] || die "Input file not found: $INPUT_FILE"
else
  INPUT_FILE="/dev/stdin"
fi

RECORDS=()
GROUP_KEYS=()
UNIQUE_IPS=()

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ ^//([^@]+)@([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/([^[:space:]]+)[[:space:]]on[[:space:]]/Volumes/(.*)[[:space:]]\(smbfs, ]]; then
    username="${BASH_REMATCH[1]}"
    ip="${BASH_REMATCH[2]}"
    share="$(url_decode "${BASH_REMATCH[3]}")"
    volume="${BASH_REMATCH[4]}"
    base_volume="$volume"
    suffix=""
    if [[ "$volume" =~ ^(.+)-([0-9]+)$ ]]; then
      base_volume="${BASH_REMATCH[1]}"
      suffix="${BASH_REMATCH[2]}"
    fi

    group_key="${share}|${base_volume}"
    RECORDS+=("${username}${DELIM}${ip}${DELIM}${share}${DELIM}${volume}${DELIM}${base_volume}${DELIM}${suffix}${DELIM}${group_key}")
    if (( ${#GROUP_KEYS[@]} == 0 )) || ! contains_value "$group_key" "${GROUP_KEYS[@]}"; then
      GROUP_KEYS+=("$group_key")
    fi
    if (( ${#UNIQUE_IPS[@]} == 0 )) || ! contains_value "$ip" "${UNIQUE_IPS[@]}"; then
      UNIQUE_IPS+=("$ip")
    fi
  fi
done < "$INPUT_FILE"

(( ${#RECORDS[@]} > 0 )) || die "No SMB mount lines found."

IP_SPEEDS=()
for ip in "${UNIQUE_IPS[@]}"; do
  IP_SPEEDS+=("${ip}=$(speed_for_ip "$ip")")
done

json='{
  "configDate": "'"$(json_escape "$CONFIG_DATE")"'",
  "shares": ['

report=""
share_count=0

for group_key in "${GROUP_KEYS[@]}"; do
  group_records="$(records_for_group "$group_key")"
  first_record="$(printf '%s\n' "$group_records" | sed -n '1p')"
  IFS="$DELIM" read -r first_user first_ip share_name first_volume mount_name first_suffix unused_key <<< "$first_record"

  group_ips=()
  group_users=()
  group_volumes=()
  group_suffixes=()
  while IFS="$DELIM" read -r username ip share volume base_volume suffix raw_key; do
    if (( ${#group_ips[@]} == 0 )) || ! contains_value "$ip" "${group_ips[@]}"; then
      group_ips+=("$ip")
    fi
    if (( ${#group_users[@]} == 0 )) || ! contains_value "$username" "${group_users[@]}"; then
      group_users+=("$username")
    fi
    if (( ${#group_volumes[@]} == 0 )) || ! contains_value "$volume" "${group_volumes[@]}"; then
      group_volumes+=("$volume")
    fi
    [[ -z "$suffix" ]] || group_suffixes+=("$volume")
  done <<< "$group_records"

  if (( ${#group_ips[@]} > 1 )); then
    report+=$'\n'"REVIEW: ${share_name} mounted from multiple server IPs: ${group_ips[*]}. Confirm preferred vs fallback endpoint order."
  fi
  if (( ${#group_suffixes[@]} > 0 )); then
    report+=$'\n'"WARNING: ${share_name} has Finder-style duplicate mount path(s): ${group_suffixes[*]}."
  fi
  if (( ${#group_volumes[@]} > 1 )); then
    report+=$'\n'"WARNING: ${share_name} appears as multiple mounted volume names: ${group_volumes[*]}."
  fi
  if (( ${#group_users[@]} > 1 )); then
    if [[ -n "$DEFAULT_USERNAME_OVERRIDE" ]]; then
      report+=$'\n'"REVIEW: ${share_name} was mounted by multiple SMB usernames. Generated JSON uses --default-username for this share."
    else
      report+=$'\n'"REVIEW: ${share_name} was mounted by multiple SMB usernames. Generated JSON uses a blank defaultUsername unless --default-username is set."
    fi
  fi

  endpoint_rows=()
  for ip in "${group_ips[@]}"; do
    speed="$DEFAULT_SPEED"
    for mapping in "${IP_SPEEDS[@]}"; do
      if [[ "${mapping%%=*}" == "$ip" ]]; then
        speed="${mapping#*=}"
        break
      fi
    done
    endpoint_rows+=("$(speed_priority "$speed")"$'\t'"$ip"$'\t'"$speed")
  done

  sorted_endpoints="$(printf '%s\n' "${endpoint_rows[@]}" | sort -n -k1,1)"
  endpoints_json=""
  endpoint_count=0
  while IFS=$'\t' read -r priority ip speed; do
    label_prefix="Preferred"
    (( endpoint_count > 0 )) && label_prefix="Fallback"
    if (( endpoint_count > 0 )); then
      endpoints_json+=","
    fi
    endpoints_json+=$'\n'"        {"$'\n'
    endpoints_json+="          \"serverIP\": \"$(json_escape "$ip")\","$'\n'
    endpoints_json+="          \"networkType\": \"$(json_escape "$speed")\","$'\n'
    endpoints_json+="          \"priority\": $priority,"$'\n'
    endpoints_json+="          \"subnetPrefix\": 24,"$'\n'
    endpoints_json+="          \"label\": \"$(json_escape "$label_prefix $(speed_display "$speed")")\""$'\n'
    endpoints_json+="        }"
    ((endpoint_count+=1))
  done <<< "$sorted_endpoints"

  default_username=""
  if [[ -n "$DEFAULT_USERNAME_OVERRIDE" ]]; then
    default_username="$DEFAULT_USERNAME_OVERRIDE"
  elif [[ "$INCLUDE_USERNAMES" == "true" && "${#group_users[@]}" -eq 1 ]]; then
    default_username="${group_users[0]}"
  fi

  if (( share_count > 0 )); then
    json+=","
  fi
  note="Imported from macOS mount output. Review endpoint labels and preferred/fallback order before deployment."
  json+=$'\n'"    {"$'\n'
  json+="      \"alias\": \"$(json_escape "$mount_name")\","$'\n'
  json+="      \"connectionProtocol\": \"smb\","$'\n'
  json+="      \"shareName\": \"$(json_escape "$share_name")\","$'\n'
  json+="      \"mountName\": \"$(json_escape "$mount_name")\","$'\n'
  json+="      \"defaultUsername\": \"$(json_escape "$default_username")\","$'\n'
  json+="      \"endpoints\": [$endpoints_json"$'\n'
  json+="      ],"$'\n'
  json+="      \"note\": \"$(json_escape "$note")\","$'\n'
  json+="      \"source\": \"imported\""$'\n'
  json+="    }"
  ((share_count+=1))
done

json+=$'\n'"  ]"$'\n'"}"$'\n'

report_header="SMB Connect mount import report
Detected SMB mount rows: ${#RECORDS[@]}
Generated share definitions: $share_count
Detected server IPs: ${UNIQUE_IPS[*]}
"

if [[ -n "$OUTPUT_JSON" ]]; then
  output_dir="$(dirname "$OUTPUT_JSON")"
  mkdir -p "$output_dir"
  printf '%s' "$json" > "$OUTPUT_JSON"
  report_path="${OUTPUT_JSON%.*}.report.txt"
  printf '%s\n%s\n' "$report_header" "${report:-No duplicate or multi-IP review warnings.}" > "$report_path"
  echo "Created:"
  echo "  $OUTPUT_JSON"
  echo "  $report_path"
  echo "Processed $share_count share(s)."
else
  printf '%s' "$json"
  {
    printf '\n%s\n' "$report_header"
    printf '%s\n' "${report:-No duplicate or multi-IP review warnings.}"
  } >&2
fi
