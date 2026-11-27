# Changelog

All notable changes to this project are documented here. The format follows
Keep a Changelog; the project uses semantic versioning.

## 0.1.0

### Added

- Workload image build (`Dockerfile`) that composes the official
  `@playwright/mcp` server with the Camoufox launcher, so the standard
  `browser_*` tool contract runs on the anti-detect Firefox engine.
- `server.mjs`: Camoufox `launchServer()` wrapper publishing its announced
  loopback WebSocket endpoint.
- `start.sh`: container entrypoint — starts the browser server, then attaches
  the official MCP server over stdio; carries the Firefox-class sandbox switches
  required by the ToolHive capability-drop posture.
- Pinned supply-chain control plane: `package.json` (catalog-backed exact pins),
  `pnpm-lock.yaml`, `pnpm-workspace.yaml` (Fortress baseline, single-project
  topology), with the Playwright pairing constraint recorded where it is
  enforced.
