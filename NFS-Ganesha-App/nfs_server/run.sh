#!/usr/bin/env bash
set -Eeuo pipefail

readonly OPTIONS_FILE="${OPTIONS_FILE:-/data/options.json}"
readonly CONFIG_FILE="${CONFIG_FILE:-/data/ganesha/ganesha.conf}"
readonly PID_FILE="${PID_FILE:-/run/ganesha/ganesha.pid}"
readonly SERVER_ID_FILE="${SERVER_ID_FILE:-/data/ganesha/server-id}"

# shellcheck source=lib/config.sh
source /usr/local/lib/nfs-server/config.sh

mkdir -p "$(dirname "${CONFIG_FILE}")" "$(dirname "${PID_FILE}")" /data/ganesha/recovery

persistent_server_id="$(get_or_create_server_id "${SERVER_ID_FILE}")"
readonly persistent_server_id
generate_ganesha_config "${OPTIONS_FILE}" "${CONFIG_FILE}" "${persistent_server_id}"
if jq -e '.log_level == "debug"' "${OPTIONS_FILE}" >/dev/null; then
  log_generated_config "${CONFIG_FILE}"
fi

log_configuration_summary "${OPTIONS_FILE}"
log_info "Starting and validating NFS-Ganesha V9.14 (NFSv4 only, TCP port 2049)"

exec /usr/bin/ganesha.nfsd \
  -F \
  -x \
  -I 1 \
  -f "${CONFIG_FILE}" \
  -p "${PID_FILE}" \
  -L STDOUT
