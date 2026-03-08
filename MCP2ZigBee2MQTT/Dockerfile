ARG BUILD_FROM

# ==============================================================================
# Build stage: clone repo, install deps, compile native modules
# ==============================================================================
FROM node:24-alpine AS builder

RUN apk add --no-cache git python3 make g++

RUN git clone --depth 1 --branch main \
    https://github.com/ichbinder/MCP2ZigBee2MQTT.git /build

WORKDIR /build

RUN npm install && npm run build

# Remove dev dependencies to slim down
RUN npm prune --production

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
