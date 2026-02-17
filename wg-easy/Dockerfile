FROM ghcr.io/wg-easy/wg-easy:latest

# Add tools to parse options and determine host IP when needed
RUN apk add --no-cache jq bash iproute2

# Wrapper script to map HA options to WG-Easy env vars and start the app
COPY rootfs/run.sh /run.sh
RUN chmod +x /run.sh

CMD [ "/run.sh" ]
