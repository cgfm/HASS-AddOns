#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: MCP2ZigBee2MQTT
#
# Starts the MCP2ZigBee2MQTT server
# ==============================================================================

declare MQTT_BROKER_URL
declare MQTT_USERNAME
declare MQTT_PASSWORD
declare MQTT_BASE_TOPIC
declare TRANSPORT_MODE
declare API_KEY
declare LOG_LEVEL

MQTT_BROKER_URL=$(bashio::config 'mqtt_broker_url')
MQTT_USERNAME=$(bashio::config 'mqtt_username')
MQTT_PASSWORD=$(bashio::config 'mqtt_password')
MQTT_BASE_TOPIC=$(bashio::config 'mqtt_base_topic')
TRANSPORT_MODE=$(bashio::config 'transport_mode')
API_KEY=$(bashio::config 'api_key')
LOG_LEVEL=$(bashio::config 'log_level')

# Fixed MCP server port
MCP_PORT=3235

# Get the external HA URL for log output
HOST_IP=$(bashio::network.ip_address || echo "<your-ha-ip>")

bashio::log.info "Starting MCP2ZigBee2MQTT..."
bashio::log.info "MQTT Broker: ${MQTT_BROKER_URL}"
bashio::log.info "MQTT Base Topic: ${MQTT_BASE_TOPIC}"
bashio::log.info "Transport Mode: ${TRANSPORT_MODE}"

# Build environment
export MQTT_BROKER_URL="${MQTT_BROKER_URL}"
export MQTT_BASE_TOPIC="${MQTT_BASE_TOPIC}"
export TRANSPORT_MODE="${TRANSPORT_MODE}"
export HTTP_PORT="${MCP_PORT}"
export DB_PATH="/data/mcp2zigbee2mqtt.db"
export LOG_LEVEL="${LOG_LEVEL}"

if ! bashio::config.is_empty 'mqtt_username'; then
    export MQTT_USERNAME="${MQTT_USERNAME}"
fi

if ! bashio::config.is_empty 'mqtt_password'; then
    export MQTT_PASSWORD="${MQTT_PASSWORD}"
fi

# API Key: use configured key, or auto-generate and persist one
if ! bashio::config.is_empty 'api_key'; then
    export API_KEY="${API_KEY}"
else
    # Auto-generate a persistent API key on first run
    if [[ -f /data/.api_key ]]; then
        API_KEY=$(cat /data/.api_key)
    else
        API_KEY=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)
        echo -n "${API_KEY}" > /data/.api_key
        bashio::log.warning "---------------------------------------------------"
        bashio::log.warning "No API key configured. Auto-generated a secure key."
        bashio::log.warning "Generated API key: ${API_KEY}"
        bashio::log.warning "You can set your own key in the add-on configuration."
        bashio::log.warning "Save this key now; it will not be logged again."
        bashio::log.warning "---------------------------------------------------"
    fi
    export API_KEY="${API_KEY}"
fi

# Log connection info
bashio::log.info "---------------------------------------------------"
bashio::log.info "MCP Server is reachable at:"
bashio::log.info "  URL:    http://${HOST_IP}:${MCP_PORT}/sse"
bashio::log.info "  Health: http://${HOST_IP}:${MCP_PORT}/health"
bashio::log.info "  API key authentication: enabled"
bashio::log.info "---------------------------------------------------"

# Start the application
exec node /opt/mcp2zigbee2mqtt/dist/index.js
