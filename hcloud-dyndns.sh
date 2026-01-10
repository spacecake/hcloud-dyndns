#!/bin/sh
set -eu

VERBOSE=0
QUIET=0

usage() {
  echo "Usage: hcloud-dyndns.sh [--verbose|--quiet] [config_path]"
  echo "  Default: logs only when changes happen (SET/UPD) or on errors."
  echo "  API_TOKEN must be provided via environment."
}

while [ $# -gt 0 ]; do
  case "$1" in
    --verbose) VERBOSE=1; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --*) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    *) break ;;
  esac
done

CONF="${1:-/config/hcloud-dyndns.conf}"

# Load config
# shellcheck disable=SC1090
. "$CONF"

API_TOKEN="${API_TOKEN:-}"
: "${API_TOKEN:?missing API_TOKEN (set it as environment variable)}"
: "${ZONES_FILE:?missing ZONES_FILE}"

API_BASE="${API_BASE:-https://api.hetzner.cloud/v1}"
COMMENT="${COMMENT:-dyndns}"
IPV6="${IPV6:-0}"
BOTH="${BOTH:-0}"
IPV4_URL="${IPV4_URL:-https://api.ipify.org}"
IPV6_URL="${IPV6_URL:-https://api64.ipify.org}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 3; }; }
need curl
need jq

log() {
  lvl="$1"; msg="$2"
  if [ "$QUIET" = "1" ] && [ "$lvl" != "ERR" ]; then
    return
  fi
  echo "[$lvl] $msg"
}

api() {
  curl -fsS \
    -H "Authorization: Bearer ${API_TOKEN}" \
    -H "Content-Type: application/json" \
    "$@"
}

get_ip_a()    { curl -fsS "$IPV4_URL"; }
get_ip_aaaa() { curl -fsS "$IPV6_URL"; }

RECORD_TYPES="A"
if [ "$BOTH" = "1" ]; then
  RECORD_TYPES="A AAAA"
elif [ "$IPV6" = "1" ]; then
  RECORD_TYPES="AAAA"
fi

IP_A=""
IP_AAAA=""
for t in $RECORD_TYPES; do
  case "$t" in
    A)    IP_A="$(get_ip_a)" ;;
    AAAA) IP_AAAA="$(get_ip_aaaa)" ;;
    *)    log "ERR" "Unsupported record type: $t"; exit 4 ;;
  esac
done

rr_path() {
  [ "$1" = "@" ] && printf '%s' "%40" || printf '%s' "$1"
}

to_rr_name() {
  host="$1"
  zone="$2"

  h="$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]' | sed 's/\.$//')"
  z="$(printf '%s' "$zone" | tr '[:upper:]' '[:lower:]' | sed 's/\.$//')"

  if [ "$h" = "$z" ]; then
    printf '%s' "@"
    return
  fi

  case "$h" in
    *."$z") printf '%s' "${h%.$z}" ;;
    *)      printf '%s' "$h" ;;
  esac
}

set_rr() {
  zone_lc="$1"
  zone_id="$2"
  rr_name="$3"
  rr_type="$4"
  new_ip="$5"

  current="$(api "${API_BASE}/zones/${zone_id}/rrsets?name=${rr_name}&type=${rr_type}" \
    | jq -r '.rrsets[0].records[0].value // empty')"

  if [ "$current" = "$new_ip" ] && [ -n "$current" ]; then
    if [ "$VERBOSE" = "1" ]; then
      log "OK" "${zone_lc} ${rr_type} ${rr_name} already ${new_ip}"
    fi
    return
  fi

  payload="$(jq -nc --arg ip "$new_ip" --arg c "$COMMENT" '{records:[{value:$ip, comment:$c}]}' )"

  api -X POST \
    -d "$payload" \
    "${API_BASE}/zones/${zone_id}/rrsets/$(rr_path "$rr_name")/${rr_type}/actions/set_records" \
    >/dev/null

  if [ -n "$current" ]; then
    log "UPD" "${zone_lc} ${rr_type} ${rr_name}: ${current} -> ${new_ip}"
  else
    log "SET" "${zone_lc} ${rr_type} ${rr_name}: -> ${new_ip}"
  fi
}

if [ ! -f "$ZONES_FILE" ]; then
  log "ERR" "ZONES_FILE not found: $ZONES_FILE"
  exit 2
fi

while IFS= read -r line; do
  line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac

  zone="${line%% *}"
  rest=""
  [ "$line" != "$zone" ] && rest="${line#* }"

  zone_lc="$(printf '%s' "$zone" | tr '[:upper:]' '[:lower:]' | sed 's/\.$//')"

  ZONE_ID="$(api "${API_BASE}/zones?name=${zone_lc}" | jq -r '.zones[0].id // empty')"
  if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "null" ]; then
    log "ERR" "Zone not found: ${zone}"
    continue
  fi

  [ -z "$rest" ] && rest="$zone_lc"

  for host in $rest; do
    rr_name="$(to_rr_name "$host" "$zone_lc")"

    for t in $RECORD_TYPES; do
      if [ "$t" = "A" ]; then
        [ -n "$IP_A" ] || { log "ERR" "Failed to detect IPv4"; exit 5; }
        set_rr "$zone_lc" "$ZONE_ID" "$rr_name" "A" "$IP_A"
      else
        [ -n "$IP_AAAA" ] || { log "ERR" "Failed to detect IPv6"; exit 6; }
        set_rr "$zone_lc" "$ZONE_ID" "$rr_name" "AAAA" "$IP_AAAA"
      fi
    done
  done
done < "$ZONES_FILE"
