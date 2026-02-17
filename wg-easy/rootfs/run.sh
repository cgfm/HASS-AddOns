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

# Map options to env (keep upstream defaults if empty)
export WG_HOST="$(read_opt wg_host "${WG_HOST-}")"
export PASSWORD="$(read_opt password "${PASSWORD-}")"
export WG_PORT="$(read_opt wg_port "${WG_PORT-51820}")"
export WG_ALLOWED_IPS="$(read_opt allowed_ips "${WG_ALLOWED_IPS-0.0.0.0/0, ::/0}")"
export WG_DEFAULT_DNS="$(read_opt default_dns "${WG_DEFAULT_DNS-1.1.1.1, 1.0.0.1}")"
export WG_MTU="$(read_opt mtu "${WG_MTU-1420}")"
export WG_PERSISTENT_KEEPALIVE="$(read_opt persistent_keepalive "${WG_PERSISTENT_KEEPALIVE-0}")"
export WG_MAX_CLIENTS="$(read_opt max_clients "${WG_MAX_CLIENTS-10}")"

# Fallback: if WG_HOST is empty, try to determine the host's primary IP.
if [[ -z "${WG_HOST:-}" ]]; then
  DEFAULT_IF=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}' || true)
  if [[ -n "${DEFAULT_IF:-}" ]]; then
    HOST_IP=$(ip -4 addr show "$DEFAULT_IF" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1 || true)
  fi
  if [[ -z "${HOST_IP:-}" ]]; then
    HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
  fi
  if [[ -n "${HOST_IP:-}" ]]; then
    echo "[WG-Easy] WG_HOST not set. Falling back to ${HOST_IP}." >&2
    export WG_HOST="${HOST_IP}"
  else
    echo "[WG-Easy] ERROR: WG_HOST is not set and host IP could not be determined. Set 'wg_host' in add-on options (domain or public IP)." >&2
    exit 1
  fi
fi

# Persist WireGuard config under /data and link to /etc/wireguard used by WG-Easy
mkdir -p /data/wireguard
if [[ ! -e /etc/wireguard ]]; then
  ln -s /data/wireguard /etc/wireguard
fi

# Show effective configuration (redact password)
echo "[WG-Easy] Starting with:" >&2
echo "  WG_HOST=${WG_HOST:-<empty>}" >&2
echo "  WG_PORT=${WG_PORT}" >&2
echo "  WG_ALLOWED_IPS=${WG_ALLOWED_IPS}" >&2
echo "  WG_DEFAULT_DNS=${WG_DEFAULT_DNS}" >&2
echo "  WG_MTU=${WG_MTU}" >&2
echo "  WG_PERSISTENT_KEEPALIVE=${WG_PERSISTENT_KEEPALIVE}" >&2
echo "  WG_MAX_CLIENTS=${WG_MAX_CLIENTS}" >&2

cd /app
exec dumb-init node server.js
