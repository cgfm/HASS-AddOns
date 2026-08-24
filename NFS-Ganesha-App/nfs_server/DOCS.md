# Home Assistant App: Secure NFSv4 Server

## What this app does

The app publishes a fixed set of Supervisor-provided Home Assistant directories through NFSv4.1/4.2 on TCP port 2049. It builds NFS-Ganesha 9.14 from the pinned upstream commit and includes only FSAL_VFS. NFSv3-era helpers and unrelated storage backends are disabled at build time.

This is suitable for a trusted private LAN or storage VLAN. NFS with `sec=sys` is not an Internet-facing file-sharing protocol.

## Installation

1. In Home Assistant, open **Settings → Apps → App store**.
2. Open the repository menu and add `https://github.com/cgfm/HASS-AddOns`.
3. Install **Secure NFSv4 Server**.
4. On the **Configuration** tab, keep the host mapping for `2049/tcp` at `2049` unless a conflict requires another host port. Standard NFS clients expect 2049.
5. Add only the required client addresses or narrowly scoped CIDR networks to `allowed_clients`.
6. Enable only the needed exports and choose `ro` wherever possible.
7. Review the identity policy. Keep `root_squash` unless you understand the consequences described below.
8. Save and start the app. The log lists active exports, RO/RW mode, authorized networks, protocol versions, and port.

There is intentionally no broad default network. With an empty or invalid `allowed_clients` list the process exits before Ganesha starts.

## Configuration example

```yaml
allowed_clients:
  - 192.168.20.12
  - 192.168.20.15
  - 192.168.30.0/24
exports:
  config:
    enabled: true
    access: rw
  addon_configs:
    enabled: true
    access: rw
  addons:
    enabled: false
    access: rw
  ssl:
    enabled: false
    access: ro
  backup:
    enabled: false
    access: ro
  share:
    enabled: false
    access: rw
  media:
    enabled: false
    access: rw
identity:
  squash: root_squash
  anonymous_uid: 65534
  anonymous_gid: 65534
advanced:
  nfs_minor_versions:
    - 1
    - 2
  lease_lifetime: 60
  grace_period: 90
log_level: info
```

Only canonical IPv4 addresses and IPv4 CIDR networks are accepted. Hostnames, wildcards, netgroups, IPv6, strings with leading-zero octets, and arbitrary Ganesha client syntax are rejected. IPv6 is omitted because reliable end-to-end filtering through the Home Assistant port-publishing path has not been demonstrated for this app.

At least one export must be enabled. Export IDs and paths are fixed:

| Export | Container source | NFS pseudo path | Default |
| --- | --- | --- | --- |
| Home Assistant Config | `/mnt/homeassistant/config` | `/config` | RW, enabled |
| App Configs | `/mnt/homeassistant/addon_configs` | `/addon_configs` | RW, enabled |
| Local Apps | `/mnt/homeassistant/addons` | `/addons` | RW, disabled |
| SSL | `/mnt/homeassistant/ssl` | `/ssl` | RO, disabled |
| Backups | `/mnt/homeassistant/backup` | `/backup` | RO, disabled |
| Share | `/mnt/homeassistant/share` | `/share` | RW, disabled |
| Media | `/mnt/homeassistant/media` | `/media` | RW, disabled |

No option accepts a path, pseudo-path, export ID, Ganesha fragment, or free-form logging destination.

### Advanced options

- `nfs_minor_versions`: one or both of `1` and `2`. NFSv4.0 is intentionally not exposed; 4.1/4.2 have the session model expected by modern clients.
- `lease_lifetime`: 10–120 seconds, default 60.
- `grace_period`: 0–180 seconds, default 90. Setting 0 weakens restart recovery semantics and should be deliberate.
- `log_level`: `error`, `warning`, `info`, or `debug`. Debug logging is noisy and can reveal filesystem metadata.

## Mounting from Linux

Install the NFS client package for your distribution, create an empty mount point, then mount an export:

```bash
sudo mkdir -p /mnt/ha-config
sudo mount -t nfs4 192.168.20.2:/config /mnt/ha-config
```

```bash
sudo mkdir -p /mnt/ha-addon-configs
sudo mount -t nfs4 192.168.20.2:/addon_configs /mnt/ha-addon-configs
```

To browse the complete NFSv4 pseudo-root containing all enabled exports:

```bash
sudo mkdir -p /mnt/homeassistant
sudo mount -t nfs4 192.168.20.2:/ /mnt/homeassistant
```

To require a specific supported minor version while diagnosing negotiation:

```bash
sudo mount -t nfs4 -o vers=4.2,proto=tcp 192.168.20.2:/config /mnt/ha-config
```

### `/etc/fstab`

```fstab
192.168.20.2:/config /mnt/ha-config nfs4 rw,vers=4.2,proto=tcp,_netdev,nofail,x-systemd.automount 0 0
192.168.20.2:/backup /mnt/ha-backup nfs4 ro,vers=4.2,proto=tcp,_netdev,nofail,x-systemd.automount 0 0
```

The client-side `ro` option is defense in depth, not a replacement for selecting `ro` in the App configuration.

## Mounting from macOS

Create a mount point and use the NFS URL form:

```bash
sudo mkdir -p /Volumes/ha-config
sudo mount_nfs -o vers=4,tcp 192.168.20.2:/config /Volumes/ha-config
```

macOS may present numeric ownership differently from Linux. Do not “fix” that by selecting `no_root_squash`; align ownership and permissions deliberately.

## Security model

### IP authorization and network exposure

Every export and the NFSv4 pseudo-root default to `Access_Type = None`. A generated `CLIENT` block grants access only to the validated allowlist. This is fail-closed Ganesha authorization, but the container still listens on `0.0.0.0:2049` behind the Supervisor's Docker port mapping.

Use a host/router firewall so TCP 2049 is reachable only from the trusted LAN or storage VLAN. Never forward TCP 2049 from the Internet. Source IP authorization is not cryptographic identity, can be undermined by a compromised peer or network, and does not encrypt traffic.

### `sec=sys`, UID/GID, and squashing

The server intentionally uses only `AUTH_SYS` (`sec=sys`). Clients supply numeric UID, GID, and supplementary groups; Ganesha applies normal POSIX permissions to the underlying files. There is no password, per-user login, integrity protection, or transport encryption.

The secure default is `root_squash`: requests from client UID/GID 0 are mapped to `anonymous_uid`/`anonymous_gid` (default 65534, commonly `nobody:nogroup`). Non-root numeric IDs remain unchanged. Consequences are expected:

- A client user can write only where its numeric IDs and mode bits permit it.
- Squashed client root commonly sees `permission denied` on root-owned files.
- Files created by a squashed identity may appear as `nobody:nogroup`.

`all_squash` maps every client identity to the configured anonymous IDs. It can simplify a dedicated drop directory only when the target directory is deliberately owned by that identity; it is not a general write-access shortcut.

`no_root_squash` is an explicit high-risk compatibility option. It lets root on every allowed client act as root against exported content. On `/config`, `/addons`, or `/ssl`, compromise of one allowed client can become compromise of Home Assistant configuration, local app code, or private keys. Anonymous UID/GID 0 is forbidden even for `all_squash`.

### Read-only versus read-write

Ganesha enforces each export's selected access type. Keep `/ssl` and `/backup` disabled or read-only. Enable write access only for clients and directories that require it. A read-only NFS export does not protect data from a process already inside a compromised app container; AppArmor and the static mount boundary are separate controls.

### Static Supervisor bind mounts

Home Assistant defines `map` entries statically in `config.yaml`; changing an App option cannot remount an individual bind mount RO/RW. To support runtime switching of every predefined export, all seven potential sources are therefore always mounted read-write inside the container, even when an export is disabled or selected `ro`.

This is the principal least-privilege limitation. Disabled/RO exports are enforced by generated Ganesha policy, not by a read-only bind mount. The custom AppArmor service profile restricts filesystem access to exactly these seven trees, but must also allow writes to all seven because AppArmor rules cannot change with Home Assistant options. A code-execution flaw in Ganesha could consequently reach more than the active NFS exports.

A stricter alternative would require separate immutable App variants/profiles (for example, an RO-only sensitive-data app) or reinstall-time static configuration. This repository keeps one understandable App and documents the tradeoff instead of claiming dynamic mount isolation.

### Capability and AppArmor

FSAL_VFS uses Linux `name_to_handle_at(2)` and `open_by_handle_at(2)`. Upstream states that container use requires `CAP_DAC_READ_SEARCH`; the app requests exactly `DAC_READ_SEARCH`. A local smoke test also starts the image after dropping Docker's complete baseline capability set and adding back only this capability. Home Assistant's metadata has no generic `cap_drop` field, so the Ganesha AppArmor child profile independently permits only `dac_read_search`. It does not request `SYS_ADMIN`.

Ganesha also attempts the optional `PR_SET_IO_FLUSHER` optimization, which requires `SYS_RESOURCE`. The generated configuration sets upstream's `Allow_Set_IO_Flusher_Fail = True`, so an `EPERM` is logged and safely ignored. Granting `SYS_RESOURCE` merely to enable this optimization would violate the least-privilege goal.

The AppArmor profile permits IPv4/IPv6 TCP streams (Ganesha creates a dual-stack service socket), Ganesha's one required capability, its libraries and configuration, recovery state below `/data/ganesha`, limited `/proc` mount information, and the seven mapped trees. It does not contain a blanket `/** rw` rule, access to Docker/Supervisor sockets, host devices, kernel modules, or unrelated Home Assistant paths.

The shipped profile was derived from upstream syscall requirements and Home Assistant's current s6 template. It still requires audit-log refinement on a real HAOS installation; see the open validation item in `SECURITY.md` before treating it as universally proven.

## Troubleshooting

### `permission denied`

Confirm the client IP matches the allowlist, the export is enabled, and its mode is `rw` if writing. Then inspect numeric ownership on both sides with `id` and `ls -ln`. Client root is deliberately squashed.

### UID/GID mismatch or `nobody:nogroup`

`sec=sys` uses numbers, not matching user names. Align client UID/GID with file ownership where appropriate, change directory permissions narrowly, or use a dedicated non-root identity. `nobody:nogroup` normally indicates root/all squashing; it is not evidence that Ganesha lost the username database.

### Client not authorized

The log prints the active allowlist. Docker port mapping usually preserves the LAN source address, but routed/NAT networks may present a different source. Authorize the actual narrow source only; do not add an entire RFC1918 range as a shortcut.

### TCP port 2049 is unreachable

Verify the App is running, its Network configuration maps `2049/tcp`, no other service owns the host port, and local/router firewalls allow TCP 2049 from the client. No UDP listener exists.

### An NFSv3 client tries to connect

NFSv3, mountd, NLM, UDP, and rpcbind registration are absent. Force `vers=4.1` or `vers=4.2`, update the client, and mount the pseudo-path directly. `showmount` is an NFSv3/mountd diagnostic and is not expected to work.

### Wrong mount path

Use `/config`, `/addon_configs`, `/addons`, `/ssl`, `/backup`, `/share`, `/media`, or `/` for the pseudo-root. Container paths such as `/mnt/homeassistant/config` are internal and are not client mount paths.

### `read-only filesystem`

Check both the server export selection and client mount flags. Remount the client `rw` only if the App export is intentionally `rw`. `/ssl` and `/backup` default to `ro` for safety.

### App fails immediately after saving options

Read the first error line. Invalid IP syntax, empty clients, unknown/malformed values, duplicate NFS minor versions, or disabling every export are rejected before Ganesha is executed. Ganesha has no dedicated validate-only switch, so the single foreground process starts with fatal config handling (`-x`). Any syntactic or semantic Ganesha error is written to the App log and terminates startup instead of continuing with a partial configuration.

## Backup and updates

Ganesha's NFSv4 client recovery state is stored below `/data/ganesha/recovery` and is included in normal App backups. The App declares cold-backup mode, so Supervisor stops it briefly while capturing consistent state. Review release notes before major-version updates. A restart enters the configured grace period so clients can reclaim state.

## Further security detail

See [SECURITY.md](SECURITY.md) for privileges, attack surface, expected Home Assistant rating, source pins, test evidence, and open HAOS-specific validation work.
