ARG BUILD_FROM
FROM ${BUILD_FROM}

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    curl \
    jq \
    nginx \
    tzdata

# Download the tado-api-proxy binary for the correct architecture
ARG BUILD_ARCH
RUN set -eux; \
    case "${BUILD_ARCH}" in \
        amd64)   ARCH_SUFFIX="x86_64" ;; \
        aarch64) ARCH_SUFFIX="arm64" ;; \
        *)       echo "Unsupported arch: ${BUILD_ARCH}" && exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/s1adem4n/tado-api-proxy/releases/download/v1.1.0/tado-api-proxy_linux_${ARCH_SUFFIX}.tar.gz" \
        | tar xz -C /usr/local/bin/ tado-api-proxy; \
    chmod +x /usr/local/bin/tado-api-proxy

# Create required directories
RUN mkdir -p /run/nginx /var/log/nginx /etc/nginx/templates

# Copy files
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY ingress.js /usr/share/ingress.js
COPY run.sh /
RUN chmod a+x /run.sh

ENTRYPOINT []
CMD [ "/run.sh" ]
