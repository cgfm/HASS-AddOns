# Secure NFSv4 Server

A least-privilege NFSv4 App for Home Assistant OS, based on NFS-Ganesha 9.14 and FSAL_VFS.

It provides only explicitly enabled Home Assistant directories to an explicit IPv4 allowlist. The default identity policy is `Root_Squash`; `/ssl` and `/backup` are disabled and preselected read-only. Empty or invalid client lists prevent startup.

No Ingress UI is included: configuration belongs on the normal Home Assistant App configuration page, and an artificial web interface would add attack surface without improving NFS security.

Read [DOCS.md](DOCS.md) before enabling write access. The detailed boundary and unresolved HAOS validation items are in [SECURITY.md](SECURITY.md).
