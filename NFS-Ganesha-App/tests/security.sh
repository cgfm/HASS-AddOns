#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT
readonly CONFIG="${ROOT}/nfs_server/config.yaml"
readonly DOCKERFILE="${ROOT}/nfs_server/Dockerfile"
readonly APPARMOR="${ROOT}/nfs_server/apparmor.txt"

fail() { printf 'security test failed: %s\n' "$1" >&2; exit 1; }

grep -Eq '^apparmor: true$' "${CONFIG}" || fail "AppArmor is not enabled"
test -s "${APPARMOR}" || fail "custom AppArmor profile missing"
grep -Eq '^  - DAC_READ_SEARCH$' "${CONFIG}" || fail "DAC_READ_SEARCH missing"
test "$(grep -Ec '^  - [A-Z_]+$' "${CONFIG}")" -eq 1 || fail "unexpected privileged capability"
! grep -Eq '^(full_access|docker_api|host_network|host_pid|host_uts|host_dbus|kernel_modules): true' "${CONFIG}" || fail "forbidden host access enabled"
! grep -Eq 'SYS_ADMIN|NET_ADMIN|SYS_MODULE' "${CONFIG}" || fail "forbidden capability present"
grep -Eq '^  2049/tcp: 2049$' "${CONFIG}" || fail "NFS port mapping missing"
test "$(awk '/^ports:/{in_ports=1; next} /^ports_description:/{in_ports=0} in_ports && /^  [0-9]+\/(tcp|udp):/{count++} END{print count+0}' "${CONFIG}")" -eq 1 || fail "unexpected additional port"
! grep -F '/var/run/docker.sock' "${CONFIG}" "${DOCKERFILE}" "${APPARMOR}" || fail "Docker socket reference present"
! grep -F '/** rw,' "${APPARMOR}" || fail "unrestricted AppArmor filesystem write rule present"
test "$(grep -Ec '^    capability [a-z_]+,$' "${APPARMOR}")" -eq 1 || fail "unexpected AppArmor capability permission"
grep -Eq '^    capability dac_read_search,$' "${APPARMOR}" || fail "AppArmor does not permit DAC_READ_SEARCH"
grep -F '/etc/s6-overlay/{,**} r,' "${APPARMOR}" >/dev/null || fail "current s6-overlay service database is not readable"
grep -F '/etc/mtab r,' "${APPARMOR}" >/dev/null || fail "FSAL_VFS mount-table access is missing"
grep -F '/proc/[0-9]*/mounts r,' "${APPARMOR}" >/dev/null || fail "resolved procfs mount-table access is missing"
grep -F '/tmp/ganesha.nfsd.locktest* rwk,' "${APPARMOR}" >/dev/null || fail "Ganesha OFD-lock probe access is missing"
grep -Fx '    / r,' "${APPARMOR}" >/dev/null || fail "FSAL path walk root access is missing"
grep -F '/mnt r,' "${APPARMOR}" >/dev/null || fail "exact /mnt path access is missing"
grep -F '/mnt/homeassistant r,' "${APPARMOR}" >/dev/null || fail "exact Supervisor mount parent access is missing"
grep -F '/mnt/homeassistant/ r,' "${APPARMOR}" >/dev/null || fail "Supervisor mount parent traversal is missing"
for export_name in config addon_configs addons ssl backup share media; do
  grep -F "/mnt/homeassistant/${export_name} r," "${APPARMOR}" >/dev/null || fail "exact ${export_name} export-root access is missing"
  grep -F "/mnt/homeassistant/${export_name}/** rwk," "${APPARMOR}" >/dev/null || fail "confined ${export_name} descendant access is missing"
done
grep -F -- '-DUSE_NFS3=OFF' "${DOCKERFILE}" >/dev/null || fail "NFSv3 build not disabled"
grep -F -- '-DUSE_9P=OFF' "${DOCKERFILE}" >/dev/null || fail "9P build not disabled"
grep -F -- '-DRPCBIND=OFF' "${DOCKERFILE}" >/dev/null || fail "rpcbind registration not disabled"

printf 'security metadata checks passed\n'
