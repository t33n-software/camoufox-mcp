// Camoufox remote server for the workload container (README §Architecture).
// launchServer() draws a coherent device identity and serves a
// Playwright-protocol WebSocket endpoint on loopback; the official
// @playwright/mcp server attaches to it via --endpoint, so the MCP client sees
// the plain Playwright tool surface on the Camoufox engine.
import { launchServer } from 'camoufox';

const server = await launchServer({
    headless: true,
    port: Number(process.env.CAMOUFOX_SERVER_PORT ?? 29001),
    ws_path: 'camoufox',
});
// The entrypoint consumes THIS announced endpoint line: the launcher may bind
// the IPv6 loopback ([::1]), so a hardcoded 127.0.0.1 would ECONNREFUSE.
console.log('WS_ENDPOINT=' + server.wsEndpoint());
setInterval(() => {}, 60_000);
