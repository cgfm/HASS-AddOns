ARG BUILD_ARCH=amd64
ARG BUILD_VERSION=dev
ARG MCP2ZIGBEE2MQTT_COMMIT=cb4c9eb4239330e164313844c6873821c39aeab7

# ==============================================================================
# Build stage: clone repo, install deps, compile native modules
# ==============================================================================
FROM node:24-alpine AS builder

ARG MCP2ZIGBEE2MQTT_COMMIT

RUN apk add --no-cache git python3 make g++

RUN git init /build \
    && git -C /build remote add origin \
        https://github.com/ichbinder/MCP2ZigBee2MQTT.git \
    && git -C /build fetch --depth 1 origin "${MCP2ZIGBEE2MQTT_COMMIT}" \
    && git -C /build checkout --detach FETCH_HEAD \
    && test "$(git -C /build rev-parse HEAD)" = "${MCP2ZIGBEE2MQTT_COMMIT}"

WORKDIR /build

# Apply add-on-specific fixes on top of the pinned upstream revision.
COPY patches/0001-addon-runtime-fixes.patch /tmp/0001-addon-runtime-fixes.patch
RUN git apply --check /tmp/0001-addon-runtime-fixes.patch \
    && git apply /tmp/0001-addon-runtime-fixes.patch

COPY patches/0002-security-and-management.patch /tmp/0002-security-and-management.patch
RUN git apply --check /tmp/0002-security-and-management.patch \
    && git apply /tmp/0002-security-and-management.patch

COPY package-lock.json ./package-lock.json
RUN npm ci && npm run build

# Remove dev dependencies to slim down
RUN npm prune --omit=dev

# ==============================================================================
# Runtime stage: HA base image + Node.js runtime + built app
# ==============================================================================
FROM ghcr.io/home-assistant/base:3.23

ARG BUILD_ARCH
ARG BUILD_VERSION

LABEL io.hass.version="${BUILD_VERSION}" \
      io.hass.type="app" \
      io.hass.arch="${BUILD_ARCH}" \
      org.opencontainers.image.title="Zigbee2MQTT-MCP" \
      org.opencontainers.image.description="MCP Server bridging AI assistants to ZigBee2MQTT" \
      org.opencontainers.image.source="https://github.com/cgfm/HASS-AddOns" \
      org.opencontainers.image.licenses="MIT"

# Install runtime dependencies for Node.js (libstdc++ needed for native modules)
RUN apk add --no-cache libstdc++

# Copy Node.js binary from builder (ensures ABI match with native modules)
COPY --from=builder /usr/local/bin/node /usr/local/bin/node

# Copy built application
COPY --from=builder /build /opt/mcp2zigbee2mqtt

# Copy rootfs
COPY rootfs /

# Set permissions
RUN chmod a+x /etc/cont-init.d/mcp2zigbee2mqtt.sh

# Start service
CMD ["/init"]
