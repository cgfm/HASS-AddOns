#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT
readonly LIB="${ROOT}/nfs_server/lib/config.sh"
readonly FIXTURE="${ROOT}/tests/fixtures/valid.json"
readonly SERVER_ID="11111111-1111-4111-8111-111111111111"
TEST_TMP="$(mktemp -d)"
readonly TEST_TMP
trap 'rm -rf "${TEST_TMP}"' EXIT

# shellcheck source=../nfs_server/lib/config.sh
source "${LIB}"

pass=0
fail=0

ok() { printf 'ok - %s\n' "$1"; ((pass+=1)) || true; }
not_ok() { printf 'not ok - %s\n' "$1" >&2; ((fail+=1)) || true; }

expect_success() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then ok "${name}"; else not_ok "${name}"; fi
}

expect_failure() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then not_ok "${name}"; else ok "${name}"; fi
}

make_variant() {
  local filter="$1" output="$2"
  jq "${filter}" "${FIXTURE}" > "${output}"
}

assert_contains() {
  local file="$1" pattern="$2"
  grep -F -- "${pattern}" "${file}" >/dev/null
}

assert_not_contains() {
  local file="$1" pattern="$2"
  ! grep -F -- "${pattern}" "${file}" >/dev/null
}

expect_success "valid individual IPv4 and CIDR" validate_options "${FIXTURE}"
expect_success "IPv4 /32" is_valid_ipv4_client "10.23.4.5/32"
expect_failure "invalid IPv4 octet" is_valid_ipv4_client "192.168.1.999"
expect_failure "invalid CIDR prefix" is_valid_ipv4_client "192.168.1.0/33"
expect_failure "IPv4 leading zero rejected" is_valid_ipv4_client "192.168.001.2"
expect_failure "config injection client rejected" is_valid_ipv4_client '192.168.1.1; Access_Type = RW;'
expect_failure "newline injection client rejected" is_valid_ipv4_client $'192.168.1.1\nClients = *'
expect_failure "IPv6 is explicitly unsupported" is_valid_ipv4_client "fd00::1"

make_variant '.allowed_clients = []' "${TEST_TMP}/empty.json"
expect_failure "empty client list fails closed" validate_options "${TEST_TMP}/empty.json"

make_variant '.allowed_clients = ["192.168.1.999"]' "${TEST_TMP}/bad-ip.json"
expect_failure "invalid client in options rejected" validate_options "${TEST_TMP}/bad-ip.json"

make_variant '.exports.config.access = "rw; Clients = *"' "${TEST_TMP}/bad-access.json"
expect_failure "access config injection rejected" validate_options "${TEST_TMP}/bad-access.json"

make_variant '.exports.config.enabled = false | .exports.addon_configs.enabled = false' "${TEST_TMP}/none.json"
expect_failure "all exports disabled rejected" validate_options "${TEST_TMP}/none.json"

make_variant '.exports.evil = {"enabled": true, "access": "rw"}' "${TEST_TMP}/unknown.json"
expect_failure "unknown export path rejected" validate_options "${TEST_TMP}/unknown.json"

make_variant '.identity.squash = "No_Root_Squash; Clients = *"' "${TEST_TMP}/bad-squash.json"
expect_failure "squash config injection rejected" validate_options "${TEST_TMP}/bad-squash.json"

expect_failure "server identity injection rejected" generate_ganesha_config "${FIXTURE}" "${TEST_TMP}/bad-server.conf" 'bad"; Clients = *;'

generate_ganesha_config "${FIXTURE}" "${TEST_TMP}/ganesha.conf" "${SERVER_ID}"
expect_success "NFSv4 only" assert_contains "${TEST_TMP}/ganesha.conf" "Protocols = 4;"
expect_success "TCP only" assert_contains "${TEST_TMP}/ganesha.conf" "Transports = TCP;"
expect_success "UDP disabled" assert_contains "${TEST_TMP}/ganesha.conf" "Enable_UDP = False;"
expect_success "deterministic config export ID" assert_contains "${TEST_TMP}/ganesha.conf" "Export_Id = 10;"
expect_success "deterministic addon_configs export ID" assert_contains "${TEST_TMP}/ganesha.conf" "Export_Id = 20;"
expect_success "enabled RW export generated" assert_contains "${TEST_TMP}/ganesha.conf" "Path = /mnt/homeassistant/config;"
expect_success "enabled RO export generated" assert_contains "${TEST_TMP}/ganesha.conf" "Path = /mnt/homeassistant/addon_configs;"
expect_success "disabled export omitted" assert_not_contains "${TEST_TMP}/ganesha.conf" "Path = /mnt/homeassistant/addons;"
expect_success "allowed clients exact" assert_contains "${TEST_TMP}/ganesha.conf" "Clients = 192.168.20.12, 192.168.30.0/24;"
expect_success "root squash default" assert_contains "${TEST_TMP}/ganesha.conf" "Squash = Root_Squash;"
expect_success "no wildcard authorization" assert_not_contains "${TEST_TMP}/ganesha.conf" "Clients = *"

if cmp -s "${TEST_TMP}/ganesha.conf" "${ROOT}/tests/fixtures/expected.conf"; then
  ok "generated configuration matches golden file"
else
  not_ok "generated configuration matches golden file"
fi

printf '%s tests passed; %s failed\n' "${pass}" "${fail}"
((fail == 0))
