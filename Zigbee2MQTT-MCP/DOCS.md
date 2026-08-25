# Zigbee2MQTT-MCP

This add-on exposes Zigbee2MQTT through the Model Context Protocol (MCP). It discovers devices from retained MQTT messages, stores their schemas and current state locally, and sends control or administration requests through Zigbee2MQTT's documented MQTT API.

Since version 1.2.0 the implementation and container image are maintained in the standalone [Zigbee2MQTT-MCP repository](https://github.com/cgfm/Zigbee2MQTT-MCP). Existing installations keep the same `mcp2zigbee2mqtt` add-on identity, options, defaults, port, and data directory. No configuration migration is required.

## Configuration

- `mqtt_broker_url`, `mqtt_username`, `mqtt_password`: MQTT connection settings. The Mosquitto add-on normally uses `mqtt://core-mosquitto:1883`.
- `mqtt_base_topic`: Zigbee2MQTT base topic; normally `zigbee2mqtt`.
- `transport_mode`: Use `http` for network clients or `stdio` for a directly launched process.
- `api_key`: Despite the compatibility name, this is a **Bearer access token**, not a custom API-key header. New HTTP installations must configure one. Clients send `Authorization: Bearer <token>`.
- `allowed_origins`: Comma-separated exact browser origins, for example `https://home.example.net`. Leave empty for desktop/CLI clients that send no `Origin` header.
- `ssl`: Enables HTTPS using `certfile` and `keyfile` from Home Assistant's `/ssl` directory.
- `max_sessions`: Limits simultaneous MCP sessions; default `32`.
- `allow_destructive`: Exposes management writes. It defaults to `false`, so only read-only bridge tools and normal validated device control are registered. Deletion, binding removal and restart additionally require `confirm: true`.

Never expose unencrypted port `3235` to the internet. Enable TLS or place the add-on behind an authenticated HTTPS reverse proxy. Existing installations may continue using their old `/data/.api_key`; rotate it by setting `api_key` explicitly.

## Client connection

The preferred Streamable HTTP endpoint is:

```text
http://<home-assistant-ip>:3235/mcp
Authorization: Bearer <configured-token>
```

When TLS is enabled, use `https://`. `/sse` and `/messages` remain available only for older MCP clients. `/health` is intentionally unauthenticated and returns only service and MQTT connectivity status.

Example client configuration:

```json
{
  "mcpServers": {
    "zigbee2mqtt": {
      "url": "https://home.example.net:3235/mcp",
      "headers": {
        "Authorization": "Bearer <configured-token>"
      }
    }
  }
}
```

## Available operations

In addition to discovery, state reading, capability search, documentation, and validated device control, the server supports:

- Bridge information, health checks, coordinator checks, restart, and permit-join
- Group creation, deletion, rename, and membership changes
- Device options, reconfiguration, rename/removal, and binding/unbinding
- OTA availability checks and scheduled updates
- Network maps and read-only external-converter discovery

Administrative calls include a transaction ID and wait for Zigbee2MQTT's matching response. Write tools are hidden unless `allow_destructive` is enabled. The unstable user extension's converter save/remove and generated-definition tools are deliberately excluded: they write executable JavaScript into Zigbee2MQTT and are unsafe to expose to an AI client. Immediate OTA installation is also replaced with scheduling because an update can take many minutes.

## Troubleshooting

- `401 Unauthorized`: Verify the `Bearer ` prefix and configured token.
- `403 Origin not allowed`: Add the exact scheme, hostname, and port to `allowed_origins`; do not use a wildcard.
- `503 Session limit reached`: Close stale clients or increase `max_sessions` cautiously.
- MQTT request timeout: Check the Zigbee2MQTT log and ensure its `base_topic` matches this add-on.

For regular Docker and Docker Compose usage, see the [standalone project documentation](https://github.com/cgfm/Zigbee2MQTT-MCP#readme).
