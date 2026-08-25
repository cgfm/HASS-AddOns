# Zigbee2MQTT-MCP Home Assistant Add-on

[![Release](https://img.shields.io/github/v/release/cgfm/Zigbee2MQTT-MCP?display_name=tag&sort=semver)](https://github.com/cgfm/Zigbee2MQTT-MCP/releases/latest)
[![CI](https://github.com/cgfm/Zigbee2MQTT-MCP/actions/workflows/pull-request.yml/badge.svg?branch=main)](https://github.com/cgfm/Zigbee2MQTT-MCP/actions/workflows/pull-request.yml)
[![GHCR image](https://img.shields.io/badge/GHCR-zigbee2mqtt--mcp-2496ED?logo=github)](https://github.com/cgfm/Zigbee2MQTT-MCP/pkgs/container/zigbee2mqtt-mcp)
[![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fcgfm%2FHASS-AddOns)

MCP server that connects AI assistants to Zigbee2MQTT via MQTT for device
discovery, control, and bridge management.

## About

This directory is the thin Home Assistant catalog entry for the maintained
[Zigbee2MQTT-MCP](https://github.com/cgfm/Zigbee2MQTT-MCP) project. Home
Assistant and regular Docker installations use the same published image. The
existing `mcp2zigbee2mqtt` add-on identity and configuration remain compatible
with earlier catalog releases.

## Features

- Discover ZigBee devices and their capabilities
- Read device states (sensors, switches, lights, etc.)
- Control devices via AI assistants
- Streamable HTTP transport at `/mcp` (legacy SSE remains available)
- Strict Bearer-token authentication, optional TLS, Origin checks, and session limits
- Manage groups, bindings, joining, OTA checks, network maps, and bridge health

Docker, Docker Compose, local-development, and MCP-client instructions live in
the [standalone project documentation](https://github.com/cgfm/Zigbee2MQTT-MCP#readme).

## Prerequisites

- [ZigBee2MQTT](https://www.zigbee2mqtt.io/) running and configured
- An MQTT broker (e.g., the Mosquitto add-on)
