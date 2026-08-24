# syntax=docker/dockerfile:1.7@sha256:a57df69d0ea827fb7266491f2813635de6f17269be881f696fbfdf2d83dda33e
ARG BUILD_FROM=ghcr.io/home-assistant/base-debian:trixie-2026.06.1@sha256:3256be70f2e53c1b259e45fdc938ef4ca709623eadbf9cbabd5ed99ef644188b

FROM ${BUILD_FROM} AS builder

ARG GANESHA_VERSION=9.14
ARG GANESHA_COMMIT=7af850559957b244e712280dd3590c4cbaedaae8
ARG NTIRPC_COMMIT=366b5c3c1f8cb4090df942ce57e9913be96406a9

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bison \
        build-essential \
        ca-certificates \
        cmake \
        flex \
        git \
        libacl1-dev \
        libattr1-dev \
        libblkid-dev \
        libcap-dev \
        libnsl-dev \
        liburcu-dev \
        pkgconf \
        uuid-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

RUN git clone --depth 1 --branch "V${GANESHA_VERSION}" \
        https://github.com/nfs-ganesha/nfs-ganesha.git nfs-ganesha \
    && test "$(git -C nfs-ganesha rev-parse HEAD)" = "${GANESHA_COMMIT}" \
    && git -C nfs-ganesha submodule update --init --depth 1 src/libntirpc \
    && test "$(git -C nfs-ganesha/src/libntirpc rev-parse HEAD)" = "${NTIRPC_COMMIT}"

WORKDIR /usr/src/nfs-ganesha/build

RUN cmake ../src \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DSYSCONFDIR=/etc \
        -DLIB_INSTALL_DIR=/usr/lib \
        -DUSE_FSAL_VFS=ON \
        -DUSE_FSAL_PROXY_V4=OFF \
        -DUSE_FSAL_PROXY_V3=OFF \
        -DUSE_FSAL_LUSTRE=OFF \
        -DUSE_FSAL_LIZARDFS=OFF \
        -DUSE_FSAL_KVSFS=OFF \
        -DUSE_FSAL_CEPH=OFF \
        -DUSE_FSAL_GPFS=OFF \
        -DUSE_FSAL_XFS=OFF \
        -DUSE_FSAL_GLUSTER=OFF \
        -DUSE_FSAL_NULL=OFF \
        -DUSE_FSAL_RGW=OFF \
        -DUSE_FSAL_MEM=OFF \
        -DUSE_FSAL_SAUNAFS=OFF \
        -DUSE_9P=OFF \
        -DUSE_NFS3=OFF \
        -DUSE_NLM=OFF \
        -DUSE_NFSACL3=OFF \
        -DUSE_RQUOTA=OFF \
        -DUSE_NFS_RDMA=OFF \
        -DUSE_9P_RDMA=OFF \
        -DUSE_VSOCK=OFF \
        -DRPCBIND=OFF \
        -D_NO_TCP_REGISTER=ON \
        -DUSE_DBUS=OFF \
        -DUSE_MONITORING=OFF \
        -DUSE_GSS=OFF \
        -DUSE_NFSIDMAP=OFF \
        -D_MSPAC_SUPPORT=OFF \
        -DUSE_ADMIN_TOOLS=OFF \
        -DUSE_GUI_ADMIN_TOOLS=OFF \
        -DUSE_MAN_PAGE=OFF \
        -DUSE_LTTNG=OFF \
        -DUSE_RADOS_RECOV=OFF \
        -DRADOS_URLS=OFF \
        -DUSE_UNWIND=OFF \
        -DUSE_CUNIT=OFF \
        -DUSE_GTEST=OFF \
        -DENABLE_VFS_POSIX_ACL=OFF \
        -DUSE_ACL_MAPPING=ON \
        -DUSE_CAPS=ON \
        -DDISTNAME_HAS_GIT_DATA=OFF \
    && cmake --build . --parallel "$(nproc)" \
    && DESTDIR=/ganesha-root cmake --install . \
    && test -x /ganesha-root/usr/bin/ganesha.nfsd \
    && test -f /ganesha-root/usr/lib/ganesha/libfsalvfs.so

FROM ${BUILD_FROM}

ARG GANESHA_VERSION=9.14

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libattr1 \
        libacl1 \
        libblkid1 \
        libcap2 \
        libnsl2 \
        liburcu8t64 \
        libuuid1 \
    && rm -rf /var/lib/apt/lists/* \
    && install -d -m 0750 /etc/ganesha /run/ganesha /var/lib/nfs/ganesha

COPY --from=builder /ganesha-root/usr/bin/ganesha.nfsd /usr/bin/ganesha.nfsd
COPY --from=builder /ganesha-root/usr/lib/libganesha_nfsd.so* /usr/lib/
COPY --from=builder /ganesha-root/usr/lib/libntirpc.so* /usr/lib/
COPY --from=builder /ganesha-root/usr/lib/ganesha/ /usr/lib/ganesha/
COPY run.sh /usr/local/bin/run.sh
COPY lib/config.sh /usr/local/lib/nfs-server/config.sh

RUN chmod 0755 /usr/local/bin/run.sh /usr/local/lib/nfs-server/config.sh \
    && /usr/bin/ganesha.nfsd -v | grep -F "V${GANESHA_VERSION}"

LABEL \
    io.hass.name="Secure NFSv4 Server" \
    io.hass.description="Least-privilege NFS-Ganesha VFS server for Home Assistant" \
    io.hass.arch="amd64|aarch64" \
    org.opencontainers.image.source="https://github.com/cgfm/HASS-AddOns" \
    org.opencontainers.image.version="1.0.5" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.title="Home Assistant Secure NFSv4 Server" \
    org.opencontainers.image.description="NFS-Ganesha ${GANESHA_VERSION}, NFSv4/TCP and FSAL_VFS only"

EXPOSE 2049/tcp
STOPSIGNAL SIGTERM
CMD ["/usr/local/bin/run.sh"]
