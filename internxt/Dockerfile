# Build argument must be declared before any FROM
ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest

# Multi-stage build - get internxt from their official image
FROM internxt/webdav:latest AS internxt-source

# Use Home Assistant base image
FROM ${BUILD_FROM}

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install requirements
RUN \
    apk add --no-cache \
        bash \
        jq \
        nodejs \
        npm

# Bashio is already included in Home Assistant base images, so we don't need to install it

# Copy the internxt CLI and dependencies from official image
COPY --from=internxt-source /usr/local /usr/local
COPY --from=internxt-source /app /app

# Copy the official entrypoint script from internxt image
COPY --from=internxt-source /app/docker/entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Copy root filesystem
COPY rootfs /

# Ensure scripts are executable
RUN chmod +x /etc/services.d/internxt/run /etc/services.d/internxt/finish /usr/local/bin/log-filter.sh

# Build arguments
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="cgfm"
