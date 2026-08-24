#!/usr/bin/env bash
# Configuration validation and deterministic NFS-Ganesha config generation.

log_error() { printf '[ERROR] %s\n' "$*" >&2; }
log_info() { printf '[INFO] %s\n' "$*"; }
log_debug() { printf '[DEBUG] %s\n' "$*"; }

die() {
  log_error "$*"
  return 1
}

is_valid_server_id() {
  [[ "$1" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$ ]]
}

get_or_create_server_id() {
  local id_file="$1" server_id tmp_file

  if [[ -e "${id_file}" ]]; then
    IFS= read -r server_id < "${id_file}" || true
    is_valid_server_id "${server_id}" || { die "Persistent server ID is invalid: ${id_file}"; return 1; }
    printf '%s' "${server_id}"
    return
  fi

  IFS= read -r server_id < /proc/sys/kernel/random/uuid
  is_valid_server_id "${server_id}" || { die "Kernel did not provide a valid random server ID"; return 1; }
  mkdir -p "$(dirname "${id_file}")"
  tmp_file="$(mktemp "${id_file}.XXXXXX")"
  chmod 0600 "${tmp_file}"
  printf '%s\n' "${server_id}" > "${tmp_file}"
  mv -f "${tmp_file}" "${id_file}"
  printf '%s' "${server_id}"
}

is_valid_ipv4_client() {
  local value="$1" address prefix octet
  local -a octets

  [[ "${value}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$ ]] || return 1
  address="${value%%/*}"
  if [[ "${value}" == */* ]]; then
    prefix="${value##*/}"
    ((10#${prefix} <= 32)) || return 1
  fi

  IFS='.' read -r -a octets <<< "${address}"
  for octet in "${octets[@]}"; do
    [[ "${octet}" == "0" || "${octet}" != 0* ]] || return 1
    ((10#${octet} <= 255)) || return 1
  done
}

validate_options() {
  local options_file="$1" client minor
  local -a clients minors

  [[ -r "${options_file}" ]] || { die "Options file is not readable: ${options_file}"; return 1; }
  jq -e '
    type == "object" and
    (.allowed_clients | type == "array") and
    (all(.allowed_clients[]; type == "string")) and
    (.exports | type == "object") and
    (.identity | type == "object") and
    (.advanced | type == "object") and
    (.log_level | type == "string")
  ' "${options_file}" >/dev/null || { die "Options have an invalid structure"; return 1; }

  mapfile -t clients < <(jq -r '.allowed_clients[]' "${options_file}")
  ((${#clients[@]} > 0)) || { die "allowed_clients must contain at least one IPv4 address or CIDR network (fail closed)"; return 1; }
  for client in "${clients[@]}"; do
    is_valid_ipv4_client "${client}" || { die "Invalid allowed client '${client}'; only canonical IPv4 addresses and IPv4 CIDR networks are accepted"; return 1; }
  done

  jq -e '
    (["config", "addon_configs", "addons", "ssl", "backup", "share", "media"] as $known |
      (.exports | keys | sort) == ($known | sort)) and
    all(.exports[]; (.enabled | type == "boolean") and (.access == "ro" or .access == "rw")) and
    (.identity.squash == "root_squash" or .identity.squash == "all_squash" or .identity.squash == "no_root_squash") and
    (.identity.anonymous_uid | type == "number" and floor == . and . >= 1 and . <= 2147483647) and
    (.identity.anonymous_gid | type == "number" and floor == . and . >= 1 and . <= 2147483647) and
    (.advanced.nfs_minor_versions | type == "array" and length > 0 and length <= 2) and
    (all(.advanced.nfs_minor_versions[]; . == 1 or . == 2)) and
    (.advanced.nfs_minor_versions | unique | length) == (.advanced.nfs_minor_versions | length) and
    (.advanced.lease_lifetime | type == "number" and floor == . and . >= 10 and . <= 120) and
    (.advanced.grace_period | type == "number" and floor == . and . >= 0 and . <= 180) and
    (.log_level == "error" or .log_level == "warning" or .log_level == "info" or .log_level == "debug")
  ' "${options_file}" >/dev/null || { die "An export, identity, advanced, or logging option is invalid"; return 1; }

  mapfile -t minors < <(jq -r '.advanced.nfs_minor_versions[]' "${options_file}")
  for minor in "${minors[@]}"; do
    [[ "${minor}" == "1" || "${minor}" == "2" ]] || { die "Invalid NFS minor version '${minor}'"; return 1; }
  done

  jq -e '[.exports[].enabled] | any' "${options_file}" >/dev/null || { die "At least one export must be enabled"; return 1; }
}

ganesha_log_level() {
  case "$1" in
    error) printf 'CRIT' ;;
    warning) printf 'WARN' ;;
    info) printf 'EVENT' ;;
    debug) printf 'DEBUG' ;;
    *) return 1 ;;
  esac
}

ganesha_squash() {
  case "$1" in
    root_squash) printf 'Root_Squash' ;;
    all_squash) printf 'All_Squash' ;;
    no_root_squash) printf 'No_Root_Squash' ;;
    *) return 1 ;;
  esac
}

generate_ganesha_config() {
  local options_file="$1" output_file="$2" server_id="$3" tmp_file
  local clients_csv minors_csv lease grace level squash anon_uid anon_gid
  local name enabled access export_id path pseudo
  local -a export_names=(config addon_configs addons ssl backup share media)

  validate_options "${options_file}" || return 1
  is_valid_server_id "${server_id}" || { die "Invalid NFS server ID"; return 1; }

  clients_csv="$(jq -r '.allowed_clients | join(", ")' "${options_file}")"
  minors_csv="$(jq -r '.advanced.nfs_minor_versions | sort | map(tostring) | join(", ")' "${options_file}")"
  lease="$(jq -r '.advanced.lease_lifetime' "${options_file}")"
  grace="$(jq -r '.advanced.grace_period' "${options_file}")"
  level="$(ganesha_log_level "$(jq -r '.log_level' "${options_file}")")"
  squash="$(ganesha_squash "$(jq -r '.identity.squash' "${options_file}")")"
  anon_uid="$(jq -r '.identity.anonymous_uid' "${options_file}")"
  anon_gid="$(jq -r '.identity.anonymous_gid' "${options_file}")"

  mkdir -p "$(dirname "${output_file}")"
  tmp_file="$(mktemp "${output_file}.XXXXXX")"
  chmod 0600 "${tmp_file}"

  {
    printf '# Generated from Home Assistant options; do not edit.\n\n'
    printf 'NFS_CORE_PARAM {\n'
    printf '    Protocols = 4;\n'
    printf '    NFS_Port = 2049;\n'
    printf '    Bind_Addr = 0.0.0.0;\n'
    printf '    Clustered = True;\n'
    printf '    Enable_UDP = False;\n'
    printf '    Enable_NFS_Stats = False;\n'
    printf '    Enable_FSAL_Stats = False;\n'
    printf '    Allow_Set_IO_Flusher_Fail = True;\n'
    printf '    Plugins_Dir = /usr/lib/ganesha;\n'
    printf '}\n\n'
    printf 'NFSv4 {\n'
    printf '    Minor_Versions = %s;\n' "${minors_csv}"
    printf '    Lease_Lifetime = %s;\n' "${lease}"
    printf '    Grace_Period = %s;\n' "${grace}"
    printf '    RecoveryBackend = fs_ng;\n'
    printf '    RecoveryRoot = /data/ganesha/recovery;\n'
    printf '    Server_Scope = "ha-nfs-%s";\n' "${server_id}"
    printf '    Server_Owner = "ha-nfs-%s";\n' "${server_id}"
    printf '    Only_Numeric_Owners = True;\n'
    printf '    Allow_Numeric_Owners = True;\n'
    printf '    Delegations = False;\n'
    printf '}\n\n'
    printf 'LOG {\n'
    printf '    Default_Log_Level = %s;\n' "${level}"
    printf '    Facility { name = STDOUT; destination = STDOUT; enable = active; }\n'
    printf '}\n\n'
    printf 'EXPORT_DEFAULTS {\n'
    printf '    Access_Type = None;\n'
    printf '    Protocols = 4;\n'
    printf '    Transports = TCP;\n'
    printf '    SecType = sys;\n'
    printf '    Squash = %s;\n' "${squash}"
    printf '    Anonymous_Uid = %s;\n' "${anon_uid}"
    printf '    Anonymous_Gid = %s;\n' "${anon_gid}"
    printf '}\n\n'
    printf 'EXPORT {\n'
    printf '    Export_Id = 1;\n'
    printf '    Path = /;\n'
    printf '    Pseudo = /;\n'
    printf '    Access_Type = None;\n'
    printf '    Protocols = 4;\n'
    printf '    Transports = TCP;\n'
    printf '    SecType = sys;\n'
    printf '    CLIENT { Clients = %s; Access_Type = MDONLY_RO; Protocols = 4; }\n' "${clients_csv}"
    printf '    FSAL { Name = PSEUDO; }\n'
    printf '}\n'

    export_id=10
    for name in "${export_names[@]}"; do
      enabled="$(jq -r --arg name "${name}" '.exports[$name].enabled' "${options_file}")"
      [[ "${enabled}" == "true" ]] || { ((export_id+=10)); continue; }
      access="$(jq -r --arg name "${name}" '.exports[$name].access | ascii_upcase' "${options_file}")"
      path="/mnt/homeassistant/${name}"
      pseudo="/${name}"

      printf '\nEXPORT {\n'
      printf '    Export_Id = %s;\n' "${export_id}"
      printf '    Path = %s;\n' "${path}"
      printf '    Pseudo = %s;\n' "${pseudo}"
      printf '    Access_Type = None;\n'
      printf '    Protocols = 4;\n'
      printf '    Transports = TCP;\n'
      printf '    SecType = sys;\n'
      printf '    Squash = %s;\n' "${squash}"
      printf '    Anonymous_Uid = %s;\n' "${anon_uid}"
      printf '    Anonymous_Gid = %s;\n' "${anon_gid}"
      printf '    CLIENT { Clients = %s; Access_Type = %s; Protocols = 4; }\n' "${clients_csv}" "${access}"
      printf '    FSAL { Name = VFS; }\n'
      printf '}\n'
      ((export_id+=10))
    done
  } > "${tmp_file}"

  mv -f "${tmp_file}" "${output_file}"
}

log_configuration_summary() {
  local options_file="$1" name enabled access
  local -a export_names=(config addon_configs addons ssl backup share media)

  log_info "Authorized IPv4 clients: $(jq -r '.allowed_clients | join(", ")' "${options_file}")"
  for name in "${export_names[@]}"; do
    enabled="$(jq -r --arg name "${name}" '.exports[$name].enabled' "${options_file}")"
    [[ "${enabled}" == "true" ]] || continue
    access="$(jq -r --arg name "${name}" '.exports[$name].access | ascii_upcase' "${options_file}")"
    log_info "Export /${name}: ${access}"
  done
  log_info "Identity policy: $(jq -r '.identity.squash' "${options_file}"); AUTH_SYS numeric UID/GID"
  log_info "NFS versions: 4.$(jq -r '.advanced.nfs_minor_versions | sort | map(tostring) | join(", 4.")' "${options_file}")"
}

log_generated_config() {
  local config_file="$1" line

  log_debug "Generated NFS-Ganesha configuration follows"
  while IFS= read -r line; do
    case "${line}" in
      *Server_Scope*) log_debug '    Server_Scope = "<persistent-id>";' ;;
      *Server_Owner*) log_debug '    Server_Owner = "<persistent-id>";' ;;
      *) log_debug "${line}" ;;
    esac
  done < "${config_file}"
}
