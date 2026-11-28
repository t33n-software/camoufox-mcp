# camoufox-mcp

Camoufox engine behind the **official Playwright MCP tool contract**. The
workload serves the unchanged `browser_*` surface of
[`@playwright/mcp`](https://github.com/microsoft/playwright-mcp) while the
browser underneath is [`Camoufox`](https://github.com/daijro/camoufox) — a
Firefox build with fingerprint spoofing.

One scenario justifies it: an interaction-lane session that a target detects or
blocks on the default Chromium engine continues on the **same tool surface** with
a different fingerprint population. No wrapper contract, no invented endpoints,
no fork of either upstream — two official components composed by a pinned build.

## Architecture

```text
MCP client
    │  streamable-http  http://127.0.0.1:8933/mcp
    ▼
ToolHive workload: camoufox (stdio)
    ├─ @playwright/mcp 0.0.78      ← the tool surface the client sees
    │      --endpoint <announced>  ← attached as a remote Playwright client
    └─ camoufox launchServer       ← Playwright-protocol ws server, loopback
           engine: Camoufox 158.0.1-beta.41 (sha256-pinned build)
```

The default Chromium workload stays the primary engine: this one is a
purpose-bound fallback, never a silent default.

## Pinned versions

| Part | Pin |
|---|---|
| MCP server | `@playwright/mcp@0.0.78` (Apache-2.0) |
| Core pairing | `playwright-core@1.62.1` (launcher peer cap `<1.63`) |
| Launcher | `camoufox@0.5.9` (MIT, npm provenance attestation) |
| Engine build | `158.0.1-beta.41` · sha256 `3f2eb1d0451fa58e45e43e55f5e6181565069791ae60c0574f0ceb1f01341c33` |
| Base image | `docker.io/library/node@sha256:51d24d08800f352afae68628d883e63db3f2c4dd807b7ddb6f805dc6b9ef8c0e` (Debian bookworm, Node 26.13.0) |
| Toolchain | Node `26.13.0` (root engine gate), pnpm `12.17.0` |

The Playwright pairing is not arbitrary: 0.0.78 is the newest MCP server release
whose bundled client the Camoufox launcher accepts. Newer releases ship
Playwright 1.66 and the Juggler handshake refuses with
`428 Precondition Required`. Every bump is an explicit reviewed act on each pin
independently.

## Build

```bash
podman build -t localhost/local/camoufox-mcp:0.1.0 .
```

The build carries its own supply-chain gates: `pnpm install --frozen-lockfile`
from the committed lockfile, registry-signature/attestation checks, the browser
fetched **explicitly by its pinned version** with a sha256-verified install
directory asserted as a build gate, the Firefox runtime libraries resolved by the
pinned tool's own `install-deps firefox`, and a warmup launch that bakes the
fingerprint-model archive and GeoIP database into the image so the runtime
downloads nothing.

## Run (ToolHive)

```bash
thv run \
  --name camoufox \
  --transport stdio \
  --proxy-port 8933 \
  --isolate-network=false \
  localhost/local/camoufox-mcp:0.1.0
```

Client configuration:

```json
{
  "mcpServers": {
    "camoufox": {
      "type": "streamable-http",
      "url": "http://127.0.0.1:8933/mcp"
    }
  }
}
```

Acceptance after a start (contract + engine identity): `initialize` answers
`serverInfo.name = "Playwright"`, `tools/list` answers the `browser_*` surface,
`browser_navigate` renders a real page, and `browser_evaluate` of
`() => ({ ua: navigator.userAgent, webdriver: String(navigator.webdriver) })`
answers a `Firefox/158.0` UA with `webdriver` reported as `"false"`.

## The sandbox switch

ToolHive's workload runtime drops Linux capabilities including
`CAP_SYS_CHROOT`. Firefox's content and GPU child sandboxes require it, so their
processes die and every tool call answers `Target crashed`. `start.sh` therefore
exports `MOZ_DISABLE_CONTENT_SANDBOX=1` and `MOZ_DISABLE_GPU_SANDBOX=1` — the
documented Firefox-class equivalent of the `--no-sandbox` entrypoint the official
Playwright MCP image ships against the same constraint. The container boundary
and the orchestrator's capability drops stay untouched: no orchestrator is
weakened, no other workload changes.

## Tool surface

The official Playwright MCP surface at server version 0.0.78 — navigation,
interaction, inspection (`browser_snapshot`, `browser_evaluate`,
`browser_network_requests`, `browser_console_messages`), tabs, screenshot,
verification and mouse capabilities as enabled by the entrypoint flags. The tool
names are identical to the default Playwright workload on purpose: a lane
switch is a surface choice, not a rewrite of prompts or allowlists.

## Lane boundary

This surface is for interaction, end-to-end checks, rendered-DOM evaluation,
network and console observation, and reproducible evidence. Driving it to read
page content is a lane violation: content retrieval escalates through a fetch
ladder instead, and this workload stays a fallback engine rather than a default.

## Repository layout

| Path | Role |
|---|---|
| `Dockerfile` | The pinned workload build |
| `server.mjs` | Camoufox `launchServer()` wrapper (announces its endpoint) |
| `start.sh` | Container entrypoint: server + official MCP server on stdio |
| `package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml` | Toolchain + supply-chain control plane |

## License

Source-available: `LicenseRef-camoufox-mcp-NoRepublish-1.0` — see `LICENSE`. The
workload composes upstream components under their own licenses (MIT, Apache-2.0,
MPL-2.0); none of them is relicensed here.
