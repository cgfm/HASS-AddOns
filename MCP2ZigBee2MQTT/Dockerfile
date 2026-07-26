ARG BUILD_FROM
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

RUN npm install && npm run build

# Remove dev dependencies to slim down
RUN npm prune --omit=dev

# ==============================================================================
# Runtime stage: HA base image + Node.js runtime + built app
# ==============================================================================
FROM ${BUILD_FROM}

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
