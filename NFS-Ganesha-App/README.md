# Secure NFSv4 Server for Home Assistant OS

This directory in the `cgfm/HASS-AddOns` repository provides a Home Assistant App that exports selected Supervisor-controlled directories through a deliberately small NFS-Ganesha server.

The design is NFSv4-over-TCP only, fail-closed client authorization, `AUTH_SYS` with `Root_Squash` by default, a custom AppArmor profile, and the single additional capability `DAC_READ_SEARCH`. It does not use host networking, the Docker API, Supervisor APIs, kernel modules, `SYS_ADMIN`, or full container access.

See [the app documentation](nfs_server/DOCS.md) for installation, configuration, client mounts, security boundaries, and troubleshooting. See [the security model](nfs_server/SECURITY.md) for the threat model, privilege analysis, expected Home Assistant rating, and known limitations.

## Repository URL

Add this URL in **Settings → Apps → App store → Repositories**:

```text
https://github.com/cgfm/HASS-AddOns
```

## Supported systems

- Home Assistant OS / Supervisor Apps
- `amd64`
- `aarch64`
- NFSv4.1 and NFSv4.2 clients over TCP

NFSv2, NFSv3, UDP, mountd, NLM, rpcbind registration, 9P, RPCSEC_GSS, arbitrary paths, and non-VFS FSAL modules are not included.

The App is built locally by Supervisor from the pinned Dockerfile. GHCR release images are optional artifacts and are not required for installation.

## License

App integration code is MIT licensed. NFS-Ganesha and its linked dependencies retain their upstream licenses.
