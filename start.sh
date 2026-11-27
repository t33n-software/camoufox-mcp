#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

# ToolHive's workload runtime drops CAP_SYS_CHROOT. Firefox's content/GPU child
# sandbox requires it — children would SIGSEGV and every tool call would answer
# "Target crashed". The browser-internal child sandbox is switched off here;
# the container boundary and the orchestrator's capability drops remain. This is
# the documented Firefox-class equivalent of the --no-sandbox entrypoint the
# OFFICIAL Playwright MCP image ships against the very same constraint.
export MOZ_DISABLE_CONTENT_SANDBOX=1
export MOZ_DISABLE_GPU_SANDBOX=1

# 1. Camoufox remote server (browser + identity engine), loopback ws endpoint.
node server.mjs > /tmp/camoufox-server.log 2>&1 &

# 2. Wait for the announced endpoint, then use it verbatim ([::1] vs 127.0.0.1).
for _ in $(seq 1 90); do
  grep -q 'WS_ENDPOINT=' /tmp/camoufox-server.log && break
  sleep 1
done
WS=$(sed -n 's/^WS_ENDPOINT=//p' /tmp/camoufox-server.log | tail -1)
echo "USING_ENDPOINT=$WS"
[ -n "$WS" ]

# 3. Official Playwright MCP server, stdio, attached to the Camoufox endpoint.
#    ToolHive owns the stdio -> streamable-http proxy; capability groups per
#    README §Tool surface. exec keeps it as PID 1 for a clean stop.
exec ./node_modules/.bin/playwright-mcp \
  --endpoint "$WS" \
  --caps=vision,pdf,testing
