# Repository Guidelines

## Project Structure & Module Organization

This directory packages the upstream MCP2ZigBee2MQTT Node.js server as the Zigbee2MQTT-MCP Home Assistant add-on. `Dockerfile` pins the upstream commit, applies `patches/0001-addon-runtime-fixes.patch`, and builds the application. `config.yaml` defines add-on metadata, ports, options, and validation. Runtime startup logic lives in `rootfs/etc/cont-init.d/mcp2zigbee2mqtt.sh`. Keep user-facing setup details in `DOCS.md`, the short repository overview in `README.md`, release notes in `CHANGELOG.md`, and localized option text in `translations/{en,de}.yaml`.

## Build, Test, and Development Commands

- `docker build --build-arg BUILD_ARCH=amd64 --build-arg BUILD_VERSION=dev -t mcp2zigbee2mqtt:dev .` builds the complete add-on image and verifies that the pinned upstream revision and patch apply.
- `bash -n rootfs/etc/cont-init.d/mcp2zigbee2mqtt.sh` checks startup-script syntax without running Home Assistant services.
- `git diff --check` detects trailing whitespace and malformed patch output before committing.
- `docker run --rm mcp2zigbee2mqtt:dev` is only a smoke test; normal startup expects the Home Assistant `/data` mount and add-on configuration supplied by Supervisor.

There is no local package manifest or standalone automated test suite. Upstream TypeScript is tested indirectly during the container build (`npm run build`).

## Coding Style & Naming Conventions

Use two-space indentation in YAML and four spaces in shell control blocks. Shell configuration variables are uppercase (`MQTT_BASE_TOPIC`); add-on option keys are lowercase snake case (`mqtt_base_topic`). Quote shell expansions and use `bashio::log` for runtime messages. Keep Docker stages focused and pin upstream commits and patched dependency versions for reproducible builds. When adding a configuration key, update `config.yaml`, the startup script, both translations, and `DOCS.md` together.

## Testing Guidelines

For every change, run the shell syntax check and a clean Docker build. Confirm `/health`, authenticated `/mcp`, and legacy `/sse` behavior when runtime or patch logic changes. Document manual MQTT or Home Assistant smoke-test results in the pull request.

## Commit & Pull Request Guidelines

Recent history uses short, imperative, title-case subjects such as `Fix MCP2ZigBee2MQTT startup logging` and `Add MCP2ZigBee2MQTT add-on`. Keep each commit scoped to one change. Pull requests should explain the user-visible effect, identify the tested architecture, list validation commands, and link related issues. Include relevant logs for runtime changes. Bump `version` in `config.yaml` and add a `CHANGELOG.md` entry for release-worthy behavior changes; include screenshots only for documentation or Supervisor UI changes.

## Security & Configuration

Never commit MQTT credentials, Bearer tokens, legacy `/data/.api_key` contents, or local broker addresses. Preserve authentication, Origin validation, request limits, and the rule that secrets must never be written to logs.
