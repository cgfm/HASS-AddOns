# Changelog

## 1.1.0

- Add Streamable HTTP at `/mcp` while retaining legacy SSE compatibility
- Add transactional Zigbee2MQTT tools for groups, bindings, devices, OTA, network maps,
  bridge health, coordinator checks, joining, restarts, and converter discovery
- Hide management-write tools by default and require explicit confirmation for irreversible calls
- Validate device commands against writable Zigbee2MQTT exposes
- Remove stale devices and their cached schema/state after Zigbee2MQTT removal
- Enforce strict Bearer authentication with constant-time comparison and failure throttling
- Add Origin validation, request/session limits, optional TLS, and reduced health output
- Stop printing generated secrets; new HTTP installations must configure a token
- Pin the complete npm dependency graph and use `npm ci` for reproducible builds

## 1.0.3

- Stop calling a non-existent Bashio network helper during startup

## 1.0.2

- Fix builds and updates on Home Assistant Supervisor 2026.04 and newer
- Declare the runtime base image and required Home Assistant image labels directly
  in the Dockerfile

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
