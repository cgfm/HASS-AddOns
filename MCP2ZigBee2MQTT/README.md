# MCP2ZigBee2MQTT Home Assistant Add-on

[![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fcgfm%2FHASS-AddOns)

MCP Server that connects AI assistants (like Claude) to ZigBee2MQTT via MQTT for
ZigBee device discovery and control.

## About

This add-on wraps [MCP2ZigBee2MQTT](https://github.com/ichbinder/MCP2ZigBee2MQTT)
as a Home Assistant add-on. It provides a Model Context Protocol (MCP) interface
that AI assistants can use to interact with your ZigBee devices through ZigBee2MQTT.

## Features

- Discover ZigBee devices and their capabilities
- Read device states (sensors, switches, lights, etc.)
- Control devices via AI assistants
- HTTP/SSE transport for easy integration
- Optional API key authentication

## Prerequisites

- [ZigBee2MQTT](https://www.zigbee2mqtt.io/) running and configured
- An MQTT broker (e.g., the Mosquitto add-on)
