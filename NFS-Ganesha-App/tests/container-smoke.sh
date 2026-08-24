#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT
readonly IMAGE="${1:-ha-nfs-ganesha:smoke}"
TEST_TMP="$(mktemp -d)"
readonly TEST_TMP
readonly SERVER_NAME="ha-nfs-server-smoke-$$"

cleanup() {
  docker rm --force "${SERVER_NAME}" >/dev/null 2>&1 || true
  rm -rf "${TEST_TMP}"
}
trap cleanup EXIT

mkdir -p \
  "${TEST_TMP}/data/ganesha/recovery/v4recov" \
  "${TEST_TMP}/config" \
  "${TEST_TMP}/addon_configs" \
  "${TEST_TMP}/addons" \
  "${TEST_TMP}/ssl" \
  "${TEST_TMP}/backup" \
  "${TEST_TMP}/share" \
  "${TEST_TMP}/media"
cp "${ROOT}/tests/fixtures/valid.json" "${TEST_TMP}/data/options.json"
# A rootless CI user owns the bind source; HA's real /data volume is writable
# by container root. Reproduce that property without granting DAC_OVERRIDE.
chmod 0777 \
  "${TEST_TMP}/data" \
  "${TEST_TMP}/data/ganesha" \
  "${TEST_TMP}/data/ganesha/recovery" \
  "${TEST_TMP}/data/ganesha/recovery/v4recov"

docker run --detach \
  --name "${SERVER_NAME}" \
  --cap-drop ALL \
  --cap-add DAC_READ_SEARCH \
  --publish 127.0.0.1::2049 \
  --volume "${TEST_TMP}/data:/data" \
  --volume "${TEST_TMP}/config:/mnt/homeassistant/config" \
  --volume "${TEST_TMP}/addon_configs:/mnt/homeassistant/addon_configs" \
  --volume "${TEST_TMP}/addons:/mnt/homeassistant/addons" \
  --volume "${TEST_TMP}/ssl:/mnt/homeassistant/ssl" \
  --volume "${TEST_TMP}/backup:/mnt/homeassistant/backup" \
  --volume "${TEST_TMP}/share:/mnt/homeassistant/share" \
  --volume "${TEST_TMP}/media:/mnt/homeassistant/media" \
  "${IMAGE}" >/dev/null

for _ in {1..30}; do
  if docker logs "${SERVER_NAME}" 2>&1 | grep -Fq 'NFS SERVER INITIALIZED'; then
    break
  fi
  if [[ "$(docker inspect --format '{{.State.Status}}' "${SERVER_NAME}")" == "exited" ]]; then
    docker logs "${SERVER_NAME}" >&2
    exit 1
  fi
  sleep 1
done

docker logs "${SERVER_NAME}" 2>&1 | grep -Fq 'NFS SERVER INITIALIZED'
test "$(docker inspect --format '{{json .HostConfig.CapAdd}}' "${SERVER_NAME}")" = '["CAP_DAC_READ_SEARCH"]'
test "$(docker inspect --format '{{json .HostConfig.CapDrop}}' "${SERVER_NAME}")" = '["ALL"]'
test "$(docker inspect --format '{{.HostConfig.Privileged}}' "${SERVER_NAME}")" = 'false'
case "$(docker inspect --format '{{.HostConfig.NetworkMode}}' "${SERVER_NAME}")" in
  default|bridge) ;;
  *) printf 'unexpected container network mode\n' >&2; exit 1 ;;
esac

docker exec "${SERVER_NAME}" sh -c \
  'awk '\''$2 ~ /:0801$/ && $4 == "0A" {found=1} END {exit !found}'\'' /proc/net/tcp /proc/net/tcp6'
docker exec "${SERVER_NAME}" sh -c \
  'awk '\''NR > 1 && $4 == "0A" && $2 !~ /:0801$/ {bad=1} END {exit bad}'\'' /proc/net/tcp /proc/net/tcp6'
docker exec "${SERVER_NAME}" sh -c \
  'awk '\''$1 != "sl" {bad=1} END {exit bad}'\'' /proc/net/udp /proc/net/udp6'
test "$(docker exec "${SERVER_NAME}" sh -c 'find /usr/lib/ganesha -type f -name '\''libfsal*.so'\'' -printf '\''%f\n'\''')" = 'libfsalvfs.so'

persistent_id="$(docker exec "${SERVER_NAME}" sh -c 'cat /data/ganesha/server-id')"
readonly persistent_id
[[ "${persistent_id}" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$ ]]
docker restart "${SERVER_NAME}" >/dev/null
test "$(docker exec "${SERVER_NAME}" sh -c 'cat /data/ganesha/server-id')" = "${persistent_id}"

jq '.allowed_clients = []' "${ROOT}/tests/fixtures/valid.json" > "${TEST_TMP}/data/options.json"
docker restart "${SERVER_NAME}" >/dev/null
for _ in {1..10}; do
  [[ "$(docker inspect --format '{{.State.Running}}' "${SERVER_NAME}")" == "false" ]] && break
  sleep 1
done
if [[ "$(docker inspect --format '{{.State.Running}}' "${SERVER_NAME}")" == "true" ]]; then
  printf 'invalid options unexpectedly left the server running\n' >&2
  exit 1
fi
docker logs "${SERVER_NAME}" 2>&1 | grep -Fq 'allowed_clients must contain at least one IPv4 address or CIDR network'

printf 'container smoke checks passed\n'
