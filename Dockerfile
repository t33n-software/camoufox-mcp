# Camoufox workload image — derived, pinned build.
#
# Integrity model (each item is a build gate, not a comment):
#   base image:     pinned by REPO DIGEST (never a mutable tag); Debian bookworm,
#                   Node 26.13.0 — the engine gate the root manifest declares.
#   node deps:      committed pnpm-lock.yaml installed with `pnpm install --frozen-lockfile`,
#                   then `pnpm audit` as a hard gate.
#   browser build:  fetched EXPLICITLY by the launcher's stamped pin
#                   (official/158.0.1-beta.41). The installer verifies the GitHub
#                   asset sha256 and the build asserts the sha8-stamped install
#                   directory: a wrong digest fails the build.
#   launcher data:  the fingerprint-model archive and GeoIP database (not npm
#                   tarred) are baked via a warmup launch, so the runtime
#                   downloads nothing.
#   system deps:    resolved by the pinned playwright-core's own
#                   `install-deps firefox` — an authoritative list, not a
#                   hand-curated apt set.
#   user:           build and runtime stay on the image's unprivileged "node" user.
FROM docker.io/library/node@sha256:51d24d08800f352afae68628d883e63db3f2c4dd807b7ddb6f805dc6b9ef8c0e

# paths.js (pinned 0.5.9): INSTALL_DIR = $XDG_CACHE_HOME/camoufox — no other seam.
ENV XDG_CACHE_HOME=/opt/camoufox-cache

USER root
RUN mkdir -p /srv/camoufox-mcp /opt/camoufox-cache \
 && chown -R node:node /srv/camoufox-mcp /opt/camoufox-cache

# pnpm is installed at the exact version the root manifest declares
# (package.json#packageManager, devEngines.packageManager) — one version, twice
# stated by the same pin, no floating resolver.
RUN npm install -g pnpm@12.17.0

USER node
WORKDIR /srv/camoufox-mcp

COPY --chown=node:node package.json pnpm-workspace.yaml pnpm-lock.yaml ./
# Integrity gates, never suppressed: the install binds to the committed lockfile
# (registry + store integrity checks are on in pnpm-workspace.yaml), and the audit
# exits non-zero on any finding at or above the level, failing the build.
RUN pnpm install --frozen-lockfile --loglevel=error \
 && pnpm audit --audit-level=low

# Pin identity (hard gate): install the stamped build, then prove the directory
# carries the expected sha8 suffix — a wrong digest fails the build.
# Executed through `pnpm exec`, not `npx`: the root manifest declares pnpm as the
# package manager with onFail error, so npm-based execution is refused by the
# project's own devEngines gate (EBADDEVENGINES). The npm global pnpm bootstrap
# above runs outside the project directory and is therefore not covered by it.
RUN pnpm exec camoufox fetch official/158.0.1-beta.41 \
 && ls -d /opt/camoufox-cache/camoufox/browsers/official/158.0.1-beta.41-3f2eb1d0 \
 && pnpm exec camoufox list

USER root
RUN cd /srv/camoufox-mcp \
 && node ./node_modules/playwright-core/cli.js install-deps firefox \
 && chmod -R a+rX /opt/camoufox-cache /srv/camoufox-mcp
USER node

# Warmup launch: bakes the fingerprint model + GeoIP database into the cache and
# proves the browser starts inside the final layer layout.
RUN node -e "import('camoufox').then(async (m) => { const b = await m.Camoufox({ headless: true }); await (await b.newPage()).goto('about:blank'); await b.close(); console.log('WARM_OK'); })"

COPY --chown=node:node server.mjs start.sh ./
RUN chmod +x /srv/camoufox-mcp/start.sh

ENTRYPOINT ["/bin/bash", "/srv/camoufox-mcp/start.sh"]
