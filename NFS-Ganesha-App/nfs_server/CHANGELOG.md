# Changelog

## 1.0.5 - 2026-08-24

- Allow Ganesha to open the fixed `/mnt/homeassistant` path components and each
  exact export root while retaining per-export descendant confinement.
- Do not add `DAC_OVERRIDE`; HAOS confirmed that `DAC_READ_SEARCH` remains active
  and sufficient for directory traversal at the Unix capability layer.

## 1.0.4 - 2026-08-24

- Allow FSAL_VFS to read `/etc/mtab` when resolving Supervisor bind mounts.
- Allow only Ganesha's `/tmp/ganesha.nfsd.locktest*` OFD-lock probe files.
- Remove the unnecessary runtime `awk` version parser and its AppArmor execution permission.

## 1.0.3 - 2026-08-24

- Remove the artificial `-T` preflight process; NFS-Ganesha has no true validate-only mode.
- Perform fatal semantic validation in the single foreground process and preserve its complete startup errors in the App log.

## 1.0.2 - 2026-08-24

- Permit read-only access to the current s6-overlay service database under `/etc/s6-overlay/s6-rc.d` in the custom AppArmor profile.

## 1.0.1 - 2026-08-24

- Build locally from the pinned Dockerfile during installation instead of requiring a pre-published public GHCR image.
- Keep the optional GHCR multi-architecture release workflow for published releases.

## 1.0.0 - 2026-08-24

- Initial production-oriented Home Assistant App repository.
- Build NFS-Ganesha 9.14 and pinned ntirpc with NFSv4/TCP and FSAL_VFS only.
- Add fail-closed IPv4/CIDR authorization and fixed export generation.
- Add `Root_Squash` default with explicit identity modes and non-zero anonymous IDs.
- Add custom AppArmor confinement and request only `DAC_READ_SEARCH`.
- Add English/German configuration translations, automated tests, multi-architecture CI, and security documentation.
