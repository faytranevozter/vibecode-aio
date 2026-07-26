# syntax=docker/dockerfile:1.7

ARG NINEROUTER_VERSION=0.5.40
ARG OPENCODE_VERSION=1.18.5
ARG OPENCHAMBER_VERSION=1.16.3
ARG BUN_VERSION=1.3.14
ARG PLAYWRIGHT_MCP_VERSION=0.0.78
ARG CONTEXT7_MCP_VERSION=3.2.5
ARG CHROME_DEVTOOLS_MCP_VERSION=1.6.0
ARG CODEGRAPH_VERSION=1.5.0
ARG RTK_VERSION=0.43.0

# -----------------------------------------------------------------------------
# packages-alpine: install npm packages on Node LTS Alpine (musl)
# -----------------------------------------------------------------------------
FROM node:lts-alpine AS packages-alpine

ARG NINEROUTER_VERSION
ARG OPENCODE_VERSION
ARG OPENCHAMBER_VERSION
ARG PLAYWRIGHT_MCP_VERSION
ARG CONTEXT7_MCP_VERSION
ARG CHROME_DEVTOOLS_MCP_VERSION
ARG CODEGRAPH_VERSION

RUN apk add --no-cache python3 make g++ git \
    && PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 PUPPETEER_SKIP_DOWNLOAD=1 npm install -g \
        "9router@${NINEROUTER_VERSION}" \
        "opencode-ai@${OPENCODE_VERSION}" \
        "@openchamber/web@${OPENCHAMBER_VERSION}" \
        "@playwright/mcp@${PLAYWRIGHT_MCP_VERSION}" \
        "@upstash/context7-mcp@${CONTEXT7_MCP_VERSION}" \
        "chrome-devtools-mcp@${CHROME_DEVTOOLS_MCP_VERSION}" \
        "@colbymchenry/codegraph@${CODEGRAPH_VERSION}" \
        "pnpm" \
    && npm cache clean --force \
    && rm -rf \
        /usr/local/lib/node_modules/opencode-ai/node_modules/opencode-linux-arm64 \
        /usr/local/lib/node_modules/opencode-ai/node_modules/opencode-linux-x64 \
        /usr/local/lib/node_modules/opencode-ai/node_modules/opencode-linux-x64-baseline \
        /usr/local/lib/node_modules/opencode-ai/bin/opencode.exe \
    && ARCH="$(uname -m)" \
    && case "$ARCH" in \
         aarch64|arm64) OPENCODE_PKG=opencode-linux-arm64-musl ;; \
         x86_64|amd64) OPENCODE_PKG=opencode-linux-x64-musl ;; \
         *) echo "unsupported arch: $ARCH" >&2; exit 1 ;; \
       esac \
    && ln -sf "../node_modules/${OPENCODE_PKG}/bin/opencode" \
        /usr/local/lib/node_modules/opencode-ai/bin/opencode \
    && chmod 755 /usr/local/lib/node_modules/opencode-ai/bin/opencode

# -----------------------------------------------------------------------------
# packages-debian: install npm packages on Node LTS Debian (glibc)
# -----------------------------------------------------------------------------
FROM node:lts-bookworm-slim AS packages-debian

ARG NINEROUTER_VERSION
ARG OPENCODE_VERSION
ARG OPENCHAMBER_VERSION
ARG PLAYWRIGHT_MCP_VERSION
ARG CONTEXT7_MCP_VERSION
ARG CHROME_DEVTOOLS_MCP_VERSION
ARG CODEGRAPH_VERSION

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 make g++ git ca-certificates \
    && PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 PUPPETEER_SKIP_DOWNLOAD=1 npm install -g \
        "9router@${NINEROUTER_VERSION}" \
        "opencode-ai@${OPENCODE_VERSION}" \
        "@openchamber/web@${OPENCHAMBER_VERSION}" \
        "@playwright/mcp@${PLAYWRIGHT_MCP_VERSION}" \
        "@upstash/context7-mcp@${CONTEXT7_MCP_VERSION}" \
        "chrome-devtools-mcp@${CHROME_DEVTOOLS_MCP_VERSION}" \
        "@colbymchenry/codegraph@${CODEGRAPH_VERSION}" \
        "pnpm" \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/* \
        /usr/local/lib/node_modules/opencode-ai/node_modules/opencode-linux-arm64-musl \
        /usr/local/lib/node_modules/opencode-ai/node_modules/opencode-linux-x64-musl \
        /usr/local/lib/node_modules/opencode-ai/node_modules/opencode-linux-x64-baseline-musl \
        /usr/local/lib/node_modules/opencode-ai/bin/opencode.exe \
    && ARCH="$(uname -m)" \
    && case "$ARCH" in \
         aarch64|arm64) OPENCODE_PKG=opencode-linux-arm64 ;; \
         x86_64|amd64) OPENCODE_PKG=opencode-linux-x64 ;; \
         *) echo "unsupported arch: $ARCH" >&2; exit 1 ;; \
       esac \
    && ln -sf "../node_modules/${OPENCODE_PKG}/bin/opencode" \
        /usr/local/lib/node_modules/opencode-ai/bin/opencode \
    && chmod 755 /usr/local/lib/node_modules/opencode-ai/bin/opencode

# -----------------------------------------------------------------------------
# debian: glibc runtime (non-Alpine)
# -----------------------------------------------------------------------------
FROM oven/bun:${BUN_VERSION} AS debian

ARG RTK_VERSION

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        chromium \
        curl \
        git \
        gh \
        openssh-client \
        tini \
        xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    && if id -u bun >/dev/null 2>&1; then \
         usermod -l vibecoder bun; \
         groupmod -n vibecoder bun 2>/dev/null || true; \
         usermod -d /home/vibecoder -m vibecoder; \
       elif ! id -u vibecoder >/dev/null 2>&1; then \
         groupadd --gid 1000 vibecoder; \
         useradd --uid 1000 --gid vibecoder --create-home --shell /bin/bash vibecoder; \
        fi

RUN set -eu; \
    case "$(uname -m)" in \
      x86_64|amd64) RTK_TARGET=x86_64-unknown-linux-musl ;; \
      aarch64|arm64) RTK_TARGET=aarch64-unknown-linux-gnu ;; \
      *) echo "unsupported RTK architecture: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    RTK_BASE="https://github.com/rtk-ai/rtk/releases/download/v${RTK_VERSION}"; \
    mkdir -p /tmp/rtk; \
    curl -fsSL "${RTK_BASE}/rtk-${RTK_TARGET}.tar.gz" -o /tmp/rtk/rtk.tar.gz; \
    curl -fsSL "${RTK_BASE}/checksums.txt" -o /tmp/rtk/checksums.txt; \
    expected="$(awk -v file="rtk-${RTK_TARGET}.tar.gz" '$2 == file { print $1 }' /tmp/rtk/checksums.txt)"; \
    [ -n "$expected" ]; \
    actual="$(sha256sum /tmp/rtk/rtk.tar.gz | awk '{ print $1 }')"; \
    [ "$expected" = "$actual" ]; \
    tar -xzf /tmp/rtk/rtk.tar.gz -C /tmp/rtk; \
    install -m 0755 /tmp/rtk/rtk /usr/local/bin/rtk; \
    rtk --version; \
    rm -rf /tmp/rtk

COPY --from=packages-debian /usr/local/bin/node /usr/local/bin/node
COPY --from=packages-debian /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf ../lib/node_modules/9router/cli.js /usr/local/bin/9router \
    && ln -sf ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -sf ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && ln -sf ../lib/node_modules/pnpm/bin/pnpm.cjs /usr/local/bin/pnpm \
    && ln -sf ../lib/node_modules/pnpm/bin/pnpx.cjs /usr/local/bin/pnpx \
    && ln -sf ../lib/node_modules/@openchamber/web/bin/cli.js /usr/local/bin/openchamber \
    && ln -sf ../lib/node_modules/opencode-ai/bin/opencode /usr/local/bin/opencode \
    && ln -sf ../lib/node_modules/@playwright/mcp/cli.js /usr/local/bin/playwright-mcp \
    && ln -sf ../lib/node_modules/@upstash/context7-mcp/dist/index.js /usr/local/bin/context7-mcp \
    && ln -sf ../lib/node_modules/chrome-devtools-mcp/build/src/bin/chrome-devtools-mcp.js /usr/local/bin/chrome-devtools-mcp \
    && ln -sf ../lib/node_modules/@colbymchenry/codegraph/npm-shim.js /usr/local/bin/codegraph \
    && ln -sf /usr/bin/chromium /usr/local/bin/vibecode-chromium \
    && node --version

ENV HOME=/home/vibecoder \
    CHROME_PATH=/usr/local/bin/vibecode-chromium \
    RTK_OPENCODE_INIT=1 \
    RTK_TELEMETRY_DISABLED=1 \
    OPENCHAMBER_HOST=0.0.0.0 \
    OPENCODE_CONFIG_DIR=/home/vibecoder/.config/opencode \
    PORT=20128 \
    HOSTNAME=0.0.0.0 \
    DATA_DIR=/home/vibecoder/.local/share/9router \
    NEXT_TELEMETRY_DISABLED=1

RUN mkdir -p \
        /home/vibecoder/.config/openchamber \
        /home/vibecoder/.config/opencode \
        /home/vibecoder/.local/share/opencode \
        /home/vibecoder/.local/state/opencode \
        /home/vibecoder/.local/share/9router \
        /home/vibecoder/workspaces \
    && chown -R vibecoder:vibecoder /home/vibecoder

COPY --chown=vibecoder:vibecoder docker-entrypoint.sh /usr/local/bin/vibecode-entrypoint
COPY --chown=vibecoder:vibecoder opencode.default.json /usr/local/share/vibecode/opencode.default.json
RUN chmod 0755 /usr/local/bin/vibecode-entrypoint

USER vibecoder
WORKDIR /home/vibecoder/workspaces

VOLUME ["/home/vibecoder/.config/openchamber", "/home/vibecoder/.config/opencode", "/home/vibecoder/.local/share/opencode", "/home/vibecoder/.local/state/opencode", "/home/vibecoder/.local/share/9router", "/home/vibecoder/workspaces"]
EXPOSE 3000 20128
HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 CMD curl -fsS http://127.0.0.1:3000/health >/dev/null && curl -fsS http://127.0.0.1:20128/api/health >/dev/null || exit 1
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/vibecode-entrypoint"]

# -----------------------------------------------------------------------------
# alpine (default final stage): slim musl runtime
# -----------------------------------------------------------------------------
FROM oven/bun:${BUN_VERSION}-alpine AS alpine

ARG RTK_VERSION

RUN apk add --no-cache \
        bash \
        ca-certificates \
        chromium \
        curl \
        git \
        github-cli \
        libstdc++ \
        libgcc \
        openssh-client \
        shadow \
        tini \
    && if id bun >/dev/null 2>&1; then \
         usermod -l vibecoder bun; \
         groupmod -n vibecoder bun 2>/dev/null || true; \
         usermod -d /home/vibecoder -m vibecoder; \
       elif ! id vibecoder >/dev/null 2>&1; then \
         addgroup -g 1000 -S vibecoder; \
         adduser -u 1000 -S -G vibecoder -h /home/vibecoder -s /bin/bash vibecoder; \
        fi

RUN set -eu; \
    case "$(uname -m)" in \
      x86_64|amd64) RTK_TARGET=x86_64-unknown-linux-musl ;; \
      aarch64|arm64) echo "RTK skipped: upstream does not publish an Alpine-compatible arm64 build"; exit 0 ;; \
      *) echo "unsupported RTK architecture: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    RTK_BASE="https://github.com/rtk-ai/rtk/releases/download/v${RTK_VERSION}"; \
    mkdir -p /tmp/rtk; \
    curl -fsSL "${RTK_BASE}/rtk-${RTK_TARGET}.tar.gz" -o /tmp/rtk/rtk.tar.gz; \
    curl -fsSL "${RTK_BASE}/checksums.txt" -o /tmp/rtk/checksums.txt; \
    expected="$(awk -v file="rtk-${RTK_TARGET}.tar.gz" '$2 == file { print $1 }' /tmp/rtk/checksums.txt)"; \
    [ -n "$expected" ]; \
    actual="$(sha256sum /tmp/rtk/rtk.tar.gz | awk '{ print $1 }')"; \
    [ "$expected" = "$actual" ]; \
    tar -xzf /tmp/rtk/rtk.tar.gz -C /tmp/rtk; \
    install -m 0755 /tmp/rtk/rtk /usr/local/bin/rtk; \
    rtk --version; \
    rm -rf /tmp/rtk

COPY --from=packages-alpine /usr/local/bin/node /usr/local/bin/node
COPY --from=packages-alpine /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf ../lib/node_modules/9router/cli.js /usr/local/bin/9router \
    && ln -sf ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -sf ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && ln -sf ../lib/node_modules/pnpm/bin/pnpm.cjs /usr/local/bin/pnpm \
    && ln -sf ../lib/node_modules/pnpm/bin/pnpx.cjs /usr/local/bin/pnpx \
    && ln -sf ../lib/node_modules/@openchamber/web/bin/cli.js /usr/local/bin/openchamber \
    && ln -sf ../lib/node_modules/opencode-ai/bin/opencode /usr/local/bin/opencode \
    && ln -sf ../lib/node_modules/@playwright/mcp/cli.js /usr/local/bin/playwright-mcp \
    && ln -sf ../lib/node_modules/@upstash/context7-mcp/dist/index.js /usr/local/bin/context7-mcp \
    && ln -sf ../lib/node_modules/chrome-devtools-mcp/build/src/bin/chrome-devtools-mcp.js /usr/local/bin/chrome-devtools-mcp \
    && ln -sf ../lib/node_modules/@colbymchenry/codegraph/npm-shim.js /usr/local/bin/codegraph \
    && ln -sf /usr/bin/chromium-browser /usr/local/bin/vibecode-chromium \
    && node --version

ENV HOME=/home/vibecoder \
    CHROME_PATH=/usr/local/bin/vibecode-chromium \
    RTK_OPENCODE_INIT=1 \
    RTK_TELEMETRY_DISABLED=1 \
    OPENCHAMBER_HOST=0.0.0.0 \
    OPENCODE_CONFIG_DIR=/home/vibecoder/.config/opencode \
    PORT=20128 \
    HOSTNAME=0.0.0.0 \
    DATA_DIR=/home/vibecoder/.local/share/9router \
    NEXT_TELEMETRY_DISABLED=1

RUN mkdir -p \
        /home/vibecoder/.config/openchamber \
        /home/vibecoder/.config/opencode \
        /home/vibecoder/.local/share/opencode \
        /home/vibecoder/.local/state/opencode \
        /home/vibecoder/.local/share/9router \
        /home/vibecoder/workspaces \
    && chown -R vibecoder:vibecoder /home/vibecoder

COPY --chown=vibecoder:vibecoder docker-entrypoint.sh /usr/local/bin/vibecode-entrypoint
COPY --chown=vibecoder:vibecoder opencode.default.json /usr/local/share/vibecode/opencode.default.json
RUN chmod 0755 /usr/local/bin/vibecode-entrypoint

USER vibecoder
WORKDIR /home/vibecoder/workspaces

VOLUME ["/home/vibecoder/.config/openchamber", "/home/vibecoder/.config/opencode", "/home/vibecoder/.local/share/opencode", "/home/vibecoder/.local/state/opencode", "/home/vibecoder/.local/share/9router", "/home/vibecoder/workspaces"]
EXPOSE 3000 20128
HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 CMD curl -fsS http://127.0.0.1:3000/health >/dev/null && curl -fsS http://127.0.0.1:20128/api/health >/dev/null || exit 1
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/vibecode-entrypoint"]
