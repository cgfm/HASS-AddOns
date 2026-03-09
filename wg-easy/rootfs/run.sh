#!/usr/bin/env bash
set -euo pipefail

# Read HA add-on options and map to WG-Easy env vars
OPTIONS_FILE="/data/options.json"

read_opt() {
  local key=$1
  local default=${2-}
  if [[ -f "${OPTIONS_FILE}" ]]; then
    local value
    value=$(jq -r --arg k "$key" '.[$k] // empty' "${OPTIONS_FILE}" || true)
    if [[ -n "${value}" && "${value}" != "null" ]]; then
      echo -n "${value}"
      return 0
    fi
  fi
  echo -n "${default}"
}

# PORT is required by the new WG-Easy
export PORT="51821"

# Map HA options to new WG-Easy INIT_* env vars
INIT_HOST_VAL="$(read_opt wg_host "")"

# Fallback: if host is empty, try to determine the host's primary IP
if [[ -z "${INIT_HOST_VAL}" ]]; then
  DEFAULT_IF=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}' || true)
  if [[ -n "${DEFAULT_IF:-}" ]]; then
    HOST_IP=$(ip -4 addr show "$DEFAULT_IF" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1 || true)
  fi
  if [[ -z "${HOST_IP:-}" ]]; then
    HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
  fi
  if [[ -n "${HOST_IP:-}" ]]; then
    echo "[WG-Easy] wg_host not set. Falling back to ${HOST_IP}." >&2
    INIT_HOST_VAL="${HOST_IP}"
  else
    echo "[WG-Easy] ERROR: wg_host is not set and host IP could not be determined. Set 'wg_host' in add-on options." >&2
    exit 1
  fi
fi

export INIT_ENABLED="true"
export INIT_HOST="${INIT_HOST_VAL}"
export INIT_PORT="$(read_opt wg_port "51820")"
export INIT_DNS="$(read_opt default_dns "1.1.1.1, 1.0.0.1")"
export INIT_ALLOWED_IPS="$(read_opt allowed_ips "0.0.0.0/0, ::/0")"

# Username & password for initial setup
INIT_USERNAME_VAL="$(read_opt username "admin")"
INIT_PASSWORD_VAL="$(read_opt password "")"
if [[ -n "${INIT_USERNAME_VAL}" ]]; then
  export INIT_USERNAME="${INIT_USERNAME_VAL}"
fi
if [[ -n "${INIT_PASSWORD_VAL}" ]]; then
  export INIT_PASSWORD="${INIT_PASSWORD_VAL}"
fi

# Persist WireGuard config under /data and link to /etc/wireguard used by WG-Easy
mkdir -p /data/wireguard
# Remove existing directory/symlink before creating ours
rm -rf /etc/wireguard
ln -s /data/wireguard /etc/wireguard

# Show effective configuration (redact password)
echo "[WG-Easy] Starting with:" >&2
echo "  INIT_HOST=${INIT_HOST}" >&2
echo "  INIT_PORT=${INIT_PORT}" >&2
echo "  INIT_DNS=${INIT_DNS}" >&2
echo "  INIT_ALLOWED_IPS=${INIT_ALLOWED_IPS}" >&2
echo "  INIT_USERNAME=${INIT_USERNAME:-<not set>}" >&2
echo "  PORT=${PORT}" >&2

cd /app
exec dumb-init node server/index.mjs
