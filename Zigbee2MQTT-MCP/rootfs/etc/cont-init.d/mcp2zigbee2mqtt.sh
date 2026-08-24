#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: Zigbee2MQTT-MCP
#
# Starts the Zigbee2MQTT-MCP server
# ==============================================================================

declare MQTT_BROKER_URL
declare MQTT_USERNAME
declare MQTT_PASSWORD
declare MQTT_BASE_TOPIC
declare TRANSPORT_MODE
declare API_KEY
declare ALLOWED_ORIGINS
declare SSL_ENABLED
declare CERTFILE
declare KEYFILE
declare MAX_SESSIONS
declare ALLOW_DESTRUCTIVE
declare LOG_LEVEL

MQTT_BROKER_URL=$(bashio::config 'mqtt_broker_url')
MQTT_USERNAME=$(bashio::config 'mqtt_username')
MQTT_PASSWORD=$(bashio::config 'mqtt_password')
MQTT_BASE_TOPIC=$(bashio::config 'mqtt_base_topic')
TRANSPORT_MODE=$(bashio::config 'transport_mode')
API_KEY=$(bashio::config 'api_key')
ALLOWED_ORIGINS=$(bashio::config 'allowed_origins')
SSL_ENABLED=$(bashio::config 'ssl')
CERTFILE=$(bashio::config 'certfile')
KEYFILE=$(bashio::config 'keyfile')
MAX_SESSIONS=$(bashio::config 'max_sessions')
ALLOW_DESTRUCTIVE=$(bashio::config 'allow_destructive')
LOG_LEVEL=$(bashio::config 'log_level')

# Fixed MCP server port
MCP_PORT=3235

# The add-on container cannot reliably determine Home Assistant's external IP.
HOST_IP="<your-ha-ip>"

bashio::log.info "Starting Zigbee2MQTT-MCP..."
MQTT_LOG_URL="${MQTT_BROKER_URL}"
if [[ "${MQTT_BROKER_URL}" == *"://"*"@"* ]]; then
    MQTT_SCHEME="${MQTT_BROKER_URL%%://*}"
    MQTT_AUTHORITY="${MQTT_BROKER_URL#*://}"
    MQTT_LOG_URL="${MQTT_SCHEME}://***:***@${MQTT_AUTHORITY#*@}"
fi
bashio::log.info "MQTT Broker: ${MQTT_LOG_URL}"
bashio::log.info "MQTT Base Topic: ${MQTT_BASE_TOPIC}"
bashio::log.info "Transport Mode: ${TRANSPORT_MODE}"

# Build environment
export MQTT_BROKER_URL="${MQTT_BROKER_URL}"
export MQTT_BASE_TOPIC="${MQTT_BASE_TOPIC}"
export TRANSPORT_MODE="${TRANSPORT_MODE}"
export HTTP_PORT="${MCP_PORT}"
export HTTP_HOST="0.0.0.0"
export DB_PATH="/data/mcp2zigbee2mqtt.db"
export LOG_LEVEL="${LOG_LEVEL}"
export ALLOWED_ORIGINS="${ALLOWED_ORIGINS}"
export MAX_SESSIONS="${MAX_SESSIONS}"
export ALLOW_DESTRUCTIVE="${ALLOW_DESTRUCTIVE}"

if ! bashio::config.is_empty 'mqtt_username'; then
    export MQTT_USERNAME="${MQTT_USERNAME}"
fi

if ! bashio::config.is_empty 'mqtt_password'; then
    export MQTT_PASSWORD="${MQTT_PASSWORD}"
fi

# Bearer access token. Existing generated keys remain valid for upgrades, but
# fresh installations must configure their own token so no secret enters logs.
umask 077
SCHEME="http"
if [[ "${TRANSPORT_MODE}" == "http" ]]; then
    if ! bashio::config.is_empty 'api_key'; then
        true
    else
        if [[ -s /data/.api_key ]]; then
            API_KEY=$(cat /data/.api_key)
            chmod 600 /data/.api_key
            bashio::log.warning "Using the legacy generated access token. Configure api_key explicitly when rotating it."
        else
            bashio::log.fatal "Configure a Bearer access token in the api_key option before starting HTTP mode."
            exit 1
        fi
    fi
    if (( ${#API_KEY} < 24 )); then
        bashio::log.fatal "The Bearer access token must contain at least 24 characters."
        exit 1
    fi
    if [[ ! "${API_KEY}" =~ ^[A-Za-z0-9._~+/-]+={0,}$ ]]; then
        bashio::log.fatal "The Bearer access token contains characters that are invalid in an Authorization header."
        exit 1
    fi
    export API_KEY="${API_KEY}"

    export SSL_ENABLED="${SSL_ENABLED}"
    if bashio::config.true 'ssl'; then
        export SSL_CERTFILE="/ssl/${CERTFILE}"
        export SSL_KEYFILE="/ssl/${KEYFILE}"
        if [[ ! -r "${SSL_CERTFILE}" || ! -r "${SSL_KEYFILE}" ]]; then
            bashio::log.fatal "TLS is enabled, but the configured certificate or key is not readable under /ssl."
            exit 1
        fi
        SCHEME="https"
    else
        bashio::log.warning "TLS is disabled. Only expose port ${MCP_PORT} on a trusted network or behind an HTTPS reverse proxy."
    fi
fi

if [[ "${TRANSPORT_MODE}" == "http" ]]; then
    bashio::log.info "---------------------------------------------------"
    bashio::log.info "MCP Server is reachable at:"
    bashio::log.info "  MCP:    ${SCHEME}://${HOST_IP}:${MCP_PORT}/mcp"
    bashio::log.info "  SSE:    ${SCHEME}://${HOST_IP}:${MCP_PORT}/sse (legacy)"
    bashio::log.info "  Health: ${SCHEME}://${HOST_IP}:${MCP_PORT}/health"
    bashio::log.info "  Bearer access token authentication: enabled"
    bashio::log.info "---------------------------------------------------"
fi

# Start the application
exec node /opt/mcp2zigbee2mqtt/dist/index.js
