# Changelog

## 1.0.1

- Fix `friendly_name` conflicts caused by stale devices in the MCP database
- Restore name uniqueness in databases created by the previous local workaround
- Continue discovery when one Zigbee2MQTT device cannot be processed
- Route HTTP/SSE client messages to their MCP session
- Support Zigbee2MQTT friendly names containing `/`
- Pin the reviewed upstream revision and direct npm dependencies
- Remove non-functional Home Assistant Ingress configuration
- Avoid logging an existing API key on every start

## 1.0.0

- Initial release
- MCP Server bridge for ZigBee2MQTT via MQTT
- HTTP/SSE and stdio transport modes
- ZigBee device discovery and control via AI assistants
