# MCP2ZigBee2MQTT

This add-on runs the [MCP2ZigBee2MQTT](https://github.com/ichbinder/MCP2ZigBee2MQTT) server,
which provides a Model Context Protocol (MCP) interface to ZigBee2MQTT. This enables AI
assistants like Claude to discover and control ZigBee devices through your MQTT broker.

## How it works

The add-on connects to your MQTT broker (e.g., the Mosquitto add-on) and subscribes to
ZigBee2MQTT topics. It exposes an MCP-compatible HTTP/SSE endpoint that AI assistants can
use to:

- Discover all ZigBee devices and their capabilities
- Read device states (temperature, humidity, on/off, etc.)
- Control devices (turn on/off, set brightness, etc.)
- Query device history

## Configuration

### MQTT Broker URL

The URL of your MQTT broker. If you use the Mosquitto add-on, the default
`mqtt://core-mosquitto:1883` should work. For external brokers, use their full URL.

### MQTT Username / Password

Credentials for the MQTT broker. Leave empty if your broker doesn't require authentication.

### MQTT Base Topic

The base topic configured in ZigBee2MQTT. Default is `zigbee2mqtt`.

### Transport Mode

- **http** (recommended): Exposes HTTP/SSE endpoints for AI assistant integration.
  Endpoints: `/sse`, `/health`, `/messages`
- **stdio**: Standard I/O transport for direct process integration.

### API Key

Optional API key to protect the MCP HTTP endpoint. If set, clients must include it
in their requests.

### Log Level

Controls the verbosity of log output: `debug`, `info`, `warn`, `error`.

## Connecting an AI Assistant

Once the add-on is running, configure your MCP-compatible AI assistant to connect to
the add-on's HTTP/SSE endpoint. If using ingress, the endpoint is available through
the Home Assistant sidebar. For direct access, map the port in the network configuration.

### Example MCP client configuration

```json
{
  "mcpServers": {
    "zigbee2mqtt": {
      "url": "http://<your-ha-ip>:3235/sse",
      "apiKey": "<your-api-key>"
    }
  }
}
```
