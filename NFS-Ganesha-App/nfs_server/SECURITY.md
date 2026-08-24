# Security design and validation report

Status date: 2026-08-24

## Architecture

The App builds [NFS-Ganesha 9.14](https://github.com/nfs-ganesha/nfs-ganesha/releases/tag/V9.14) at the pinned upstream commit `7af850559957b244e712280dd3590c4cbaedaae8`, with its ntirpc submodule pinned to `366b5c3c1f8cb4090df942ce57e9913be96406a9`. NFS-Ganesha is the mature upstream userspace NFS implementation and [FSAL_VFS](https://github.com/nfs-ganesha/nfs-ganesha/wiki/FSAL_VFS) is its backend for local Linux filesystems.

The build enables NFSv4, TCP, and FSAL_VFS. It disables NFSv3, NLM, NFSACL3, RQUOTA, UDP use at runtime, rpcbind registration, 9P, RDMA, GSS, D-Bus, monitoring, administrative tools, and all optional remote-storage FSALs. FSAL_PSEUDO is statically linked because it is required for the NFSv4 namespace. Only `libfsalvfs.so` is copied as a dynamic FSAL module.

At startup a small Bash/jq implementation validates `/data/options.json`, creates or validates a persistent random server UUID, emits a complete configuration to `/data/ganesha/ganesha.conf`, logs a non-secret summary, and replaces itself with foreground Ganesha. The UUID supplies stable NFSv4 server owner/scope values, while fixed node ID 1 gives the single-node filesystem recovery backend a stable directory across container replacement. Home Assistant's s6 init remains PID 1 and cleanly supervises the foreground process and signals. Ganesha has no validate-only flag; the one real foreground process uses fatal config handling (`-x`) so parser or semantic errors remain visible and terminate startup.

## Privileges

### `DAC_READ_SEARCH`

This is the only capability requested in `config.yaml`. FSAL_VFS resolves persistent Linux file handles with `name_to_handle_at(2)` and opens them with `open_by_handle_at(2)`; upstream specifically documents `CAP_DAC_READ_SEARCH` for this operation in a container. It bypasses ordinary file read and directory-search permission checks, so compromise of the process is significant even though AppArmor and the bind-mount boundary still limit reachable paths.

Experimental evidence on the local Linux/Docker host:

- the image was run with `--cap-drop ALL --cap-add DAC_READ_SEARCH`;
- Ganesha 9.14 reported only `cap_dac_read_search=ep`;
- configuration and both VFS exports initialized;
- the log reached `NFS SERVER INITIALIZED`;
- TCP 2049 listened and no UDP 2049 socket existed.

No evidence supported adding `SYS_ADMIN`, `SYS_RESOURCE`, `NET_ADMIN`, `SYS_MODULE`, `NET_BIND_SERVICE`, `SETUID`, or `SETGID`. In particular, `Allow_Set_IO_Flusher_Fail = True` makes the optional `PR_SET_IO_FLUSHER` call fail safely with `EPERM`, avoiding `SYS_RESOURCE`.

Home Assistant's App metadata adds capabilities but cannot express Docker `--cap-drop ALL`. Docker may therefore supply its normal baseline set. The nested Ganesha AppArmor profile permits capability use only for `dac_read_search`; the successful cap-drop experiment shows that the other baseline capabilities are not required for startup.

## Attack surface

Network access is limited to NFSv4.1/4.2 over TCP port 2049 through ordinary Docker publishing. There is no Ingress service, web UI, UDP NFS, mountd, NLM, rpcbind registration, Supervisor API, Docker socket, host network, D-Bus, or kernel-module access. Some container runtimes create an IPv6 TCP listener for the published port even with Ganesha's IPv4 bind setting. IPv6 clients cannot enter the IPv4-only generated allowlist and consequently inherit `Access_Type = None`, but both IPv4 and IPv6 firewall policy should still block untrusted traffic.

The container can reach:

- read-only runtime binaries, shared libraries, generated configuration, NSS and resolver files;
- writable App state below `/data/ganesha` and runtime state below `/run/ganesha`;
- the seven fixed Supervisor bind mounts below `/mnt/homeassistant`;
- narrowly selected `/proc` mount/process and `/sys` CPU/node information required by Ganesha;
- IPv4/IPv6 TCP sockets; authorization inputs remain IPv4-only.

It cannot select arbitrary host paths. Validation accepts exactly seven known export keys, exact enum/number types, canonical IPv4/CIDR allowlist entries, and no free-form Ganesha text. Export IDs are fixed: pseudo-root 1, then 10 through 70 for the known data exports.

## AppArmor

The parent profile covers Home Assistant's s6 init, the fixed launcher tools, `/data`, `/run`, and transition into a dedicated `ganesha` child profile. The child allows only:

- `dac_read_search` capability use;
- IPv4/IPv6 stream networking because the service creates a dual-stack socket;
- the pinned Ganesha executable, runtime libraries, VFS module, and config;
- recovery/runtime state;
- read-only mount-table access and narrowly named OFD-lock probe files;
- the seven exact Home Assistant mount prefixes;
- limited NSS, device, procfs, and sysfs reads.

There is no `/** rw` rule. The policy compiles with AppArmor parser 4.0.1. It has not yet been exercised in enforce mode on Home Assistant OS; that remains an explicit validation item below.

The on-device acceptance procedure is deliberately audit-driven: temporarily add `complain` only to the Ganesha child profile on a test HAOS host, exercise startup, pseudo-root traversal, every RO/RW export, restart recovery, and SIGTERM, inspect `journalctl _TRANSPORT="audit" -g 'apparmor="ALLOWED"'`, add only path-specific rules that have a demonstrated purpose, then remove `complain` and repeat in enforce mode. This repository does not claim that step was performed on the present development host.

## Static bind-mount limitation

Supervisor `map` entries are install-time metadata, while export enablement and RO/RW are runtime options. A single App cannot dynamically change a bind mount from RW to RO. All seven paths are consequently mounted RW so that the UI can later enable RW for any predefined export. Ganesha denies disabled exports and enforces client-visible RO, but a Ganesha code-execution vulnerability would still encounter writable bind mounts that are disabled in the NFS configuration.

This is a real isolation deficit, not a rating issue. The safer operational policy is to leave sensitive `/ssl` and `/backup` exports disabled/RO, restrict clients and firewall rules, and avoid installing the App if static RW visibility of all seven trees is unacceptable. Stronger mount-level separation would require multiple immutable App variants or reduced functionality.

## Identity and authentication

Only `sec=sys`/AUTH_SYS is supported. It provides neither cryptographic client/user authentication nor encryption. Allowed source IPs are an outer authorization layer; client-provided numeric UID/GID values are then evaluated against POSIX ownership and modes.

The default `Root_Squash` maps client root to UID/GID 65534. `All_Squash` is available for deliberately owned drop locations. `No_Root_Squash` is intentionally conspicuous and unsafe: root on every allowed client can act as server root against an RW export. Anonymous UID/GID zero is rejected. POSIX ACL export is disabled to reduce build/runtime complexity, so access design should rely on numeric ownership and mode bits.

## Expected Home Assistant security rating

According to the current official Home Assistant App presentation documentation:

| Item | Score effect |
| --- | ---: |
| Base rating | 5 |
| Custom enabled `apparmor.txt` | +1 |
| `privileged: [DAC_READ_SEARCH]` | -1 |
| `full_access`, `docker_api`, host network/PID/UTS/D-Bus, `SYS_ADMIN` | 0 (not enabled) |
| Expected result | **5/6** |

The privileged penalty is applied once for the non-default capability. There is no Ingress UI and no artificial rating feature. `full_access` or `docker_api` would collapse the rating and are absent.

Reference: [Home Assistant App security rating](https://developers.home-assistant.io/docs/apps/presentation/).

There is an upstream denominator discrepancy as of the status date. The published developer documentation explicitly says “a scale of 1 to 6”, so the documented result is **5/6**. Current Supervisor `main` implements `rating_security()` with a clamp of 1–8 and its bundled UI describes a 1–8 scale; that implementation would display the same raw result as **5/8**. No additional point is warranted merely to reconcile the denominator: this App has neither genuine Ingress/authentication functionality nor a Codenotary signature. The exact denominator seen by a user therefore depends on the released Supervisor/UI version until Home Assistant aligns code and documentation.

Implementation reference: [Supervisor `rating_security()`](https://github.com/home-assistant/supervisor/blob/main/supervisor/apps/utils.py).

## Supply chain

- The Home Assistant Debian base is pinned by release and multi-architecture manifest digest.
- NFS-Ganesha and ntirpc are pinned by full commits, and the build verifies both checkouts.
- The final stage contains only declared runtime libraries, Ganesha core, and FSAL_VFS; build tools remain in the builder.
- GitHub Actions are pinned to immutable full commit SHAs.
- Release builds publish an amd64/aarch64 manifest to GHCR with provenance and SBOM attestations.
- Dependabot watches the Docker base and GitHub Actions.

Debian packages are resolved from the pinned base's configured Trixie repositories at build time rather than pinned to package-version strings. This keeps security updates flowing but means rebuilding the same source later is not byte-for-byte reproducible. The base digest and source commits are reproducible pins; the apt repository snapshot is not.

## Automated and experimental checks

- 27 configuration/golden tests cover valid IP/CIDR, invalid input, fail-closed empty lists, export modes, deterministic IDs, and injection attempts.
- Static security tests reject forbidden host flags/capabilities, extra ports, Docker socket access, missing AppArmor, and enabled NFSv3/9P/rpcbind.
- The AppArmor policy compiles locally.
- An amd64 image builds and starts with only `DAC_READ_SEARCH`; TCP 2049 and the sole VFS plugin are checked.
- A current HAOS installation loaded the enforcing profile, retained
  `cap_dac_read_search`, resolved the Supervisor bind mounts, initialized all
  configured export roots, and reached `NFS SERVER INITIALIZED` without an
  AppArmor or FSAL export error.
- CI defines native amd64 and emulated aarch64 builds, container smoke tests, and a Trivy HIGH/CRITICAL scan.

## Known limitations and open validation items

These points are not claimed as proven:

1. **Complete AppArmor data-path coverage:** enforcing HAOS startup and export-root initialization are proven. Client-driven read, write, rename, locking, extended-attribute, and ACL operations have not all been exercised under the profile yet.
2. **End-to-end file I/O:** an actual NFSv4 mount/read/write/rename/reboot-reclaim sequence has not been recorded yet. Listener and Supervisor export-root initialization are proven; client data-path correctness is not.
3. **HAOS file-handle support:** the target kernel/filesystems must provide `CONFIG_FHANDLE` and permit file handles for each mapped filesystem. Upstream requires this for FSAL_VFS; it has not been directly inspected on the target HAOS host.
4. **Published client source address:** ordinary Docker publishing normally retains the remote address, but routed/NAT installations can present another source. The log and allowlist must be checked on the actual network.
5. **aarch64 runtime:** the Dockerfile and CI matrix cover aarch64, but only amd64 was built and started in this local review. The hosted CI run itself has not yet executed.
6. **IPv6 authorization:** Ganesha supports IPv6 client expressions, but the complete Supervisor/Docker publication and validation path was not demonstrated. This release deliberately accepts IPv4 only and fails closed for other clients.
7. **Package-level reproducibility:** apt dependencies are not tied to a dated Debian snapshot, as described above.
8. **Rating denominator:** official developer documentation and current Supervisor source disagree between 1–6 and 1–8. The raw score calculation is unambiguously 5 in both.
9. **Optional GHCR visibility:** the App currently builds locally because `config.yaml` intentionally has no `image` key. Images produced by the optional release workflow are not used for installation unless a future release adds that key. Before doing so, the GHCR package must be public and the matching version tag must exist.

Do not expose this service to the Internet. Restrict TCP 2049 in both IPv4 and IPv6 firewall policy to the narrow trusted LAN/VLAN, keep the allowlist narrow, prefer RO, and retain `root_squash`.
