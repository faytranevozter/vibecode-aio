# syntax=docker/dockerfile:1.7

ARG NINEROUTER_VERSION=0.5.59
ARG OPENCODE_VERSION=1.18.25
ARG OPENCHAMBER_VERSION=1.22.0
ARG PLAYWRIGHT_MCP_VERSION=0.0.78
ARG CONTEXT7_MCP_VERSION=3.2.5
ARG CHROME_DEVTOOLS_MCP_VERSION=1.6.0
ARG CODEGRAPH_VERSION=1.5.0
ARG RTK_VERSION=0.43.0
ARG NVM_VERSION=0.40.6
ARG NODE_VERSION=--lts
# Optional toolchains: comma-separated names baked as image default (override with -e).
# Example: INSTALL_TOOLCHAINS=node,go,rust,python,ruby,deno,bun,php
# Entrypoint installs into $HOME on startup if missing (needs network once).
ARG INSTALL_TOOLCHAINS=node
ARG GO_VERSION=1.26.5
ARG RUST_VERSION=stable
ARG PYTHON_VERSION=3.15
ARG RUBY_VERSION=4.0.6
ARG DENO_VERSION=2.9.4
ARG BUN_TOOLCHAIN_VERSION=1.3.14
ARG PHP_VERSION=8.5.8

# -----------------------------------------------------------------------------
# packages-debian: install npm packages on Debian with nvm Node LTS
# -----------------------------------------------------------------------------
FROM debian:bookworm-slim AS packages-debian

ARG NINEROUTER_VERSION
ARG OPENCODE_VERSION
ARG OPENCHAMBER_VERSION
ARG PLAYWRIGHT_MCP_VERSION
ARG CONTEXT7_MCP_VERSION
ARG CHROME_DEVTOOLS_MCP_VERSION
ARG CODEGRAPH_VERSION
ARG NVM_VERSION
ARG NODE_VERSION

ENV HOME=/root \
    NVM_DIR=/root/.nvm

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash curl python3 make g++ git ca-certificates \
    && curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" | PROFILE=/dev/null bash \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install "$NODE_VERSION" \
    && nvm use --silent "$NODE_VERSION" \
    && nvm alias default "$(node --version)" \
    && PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 PUPPETEER_SKIP_DOWNLOAD=1 npm --prefix /usr/local install -g \
        "npm@latest" \
        "9router@${NINEROUTER_VERSION}" \
        "opencode-ai@${OPENCODE_VERSION}" \
        "@openchamber/web@${OPENCHAMBER_VERSION}" \
        "@playwright/mcp@${PLAYWRIGHT_MCP_VERSION}" \
        "@upstash/context7-mcp@${CONTEXT7_MCP_VERSION}" \
        "chrome-devtools-mcp@${CHROME_DEVTOOLS_MCP_VERSION}" \
        "@colbymchenry/codegraph@${CODEGRAPH_VERSION}" \
        "pnpm" \
    && cp "$(command -v node)" /usr/local/bin/node \
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
# debian: glibc runtime
# -----------------------------------------------------------------------------
FROM debian:bookworm-slim AS debian

ARG RTK_VERSION
ARG INSTALL_TOOLCHAINS=node
ARG NVM_VERSION=0.40.6
ARG NODE_VERSION=--lts
ARG GO_VERSION=1.26.5
ARG RUST_VERSION=stable
ARG PYTHON_VERSION=3.15
ARG RUBY_VERSION=4.0.6
ARG DENO_VERSION=2.9.4
ARG BUN_TOOLCHAIN_VERSION=1.3.14
ARG PHP_VERSION=8.5.8

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
    && if ! id -u vibecoder >/dev/null 2>&1; then \
         groupadd --gid 1000 vibecoder; \
         useradd --uid 1000 --gid vibecoder --create-home --shell /bin/bash vibecoder; \
        fi

RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && . /etc/os-release \
    && printf '%s\n' \
         "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" \
         > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
         docker-ce-cli \
         docker-buildx-plugin \
         docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

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
    if [ "$RTK_TARGET" = "x86_64-unknown-linux-musl" ]; then rtk --version; fi; \
    rm -rf /tmp/rtk

COPY --from=packages-debian /usr/local/bin/node /usr/local/bin/node
COPY --from=packages-debian /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf ../lib/node_modules/9router/cli.js /usr/local/bin/9router \
    && printf '%s\n' '#!/usr/bin/env sh' 'exec node /usr/local/lib/node_modules/npm/bin/npm-cli.js "$@"' > /usr/local/bin/npm \
    && printf '%s\n' '#!/usr/bin/env sh' 'exec node /usr/local/lib/node_modules/npm/bin/npx-cli.js "$@"' > /usr/local/bin/npx \
    && printf '%s\n' '#!/usr/bin/env sh' 'exec node /usr/local/lib/node_modules/pnpm/bin/pnpm.cjs "$@"' > /usr/local/bin/pnpm \
    && printf '%s\n' '#!/usr/bin/env sh' 'exec node /usr/local/lib/node_modules/pnpm/bin/pnpx.cjs "$@"' > /usr/local/bin/pnpx \
    && chmod 0755 /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/pnpm /usr/local/bin/pnpx \
    && printf '%s\n' 'export PATH="/home/vibecoder/.nvm/current/bin:${PATH}"' > /etc/profile.d/vibecode-node.sh \
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
    NEXT_TELEMETRY_DISABLED=1 \
    GOPATH=/home/vibecoder/go \
    GOROOT=/home/vibecoder/sdk/go \
    CARGO_HOME=/home/vibecoder/.cargo \
    RUSTUP_HOME=/home/vibecoder/.rustup \
    RBENV_ROOT=/home/vibecoder/.rbenv \
    PHPENV_ROOT=/home/vibecoder/.phpenv \
    DENO_INSTALL=/home/vibecoder/.deno \
    BUN_INSTALL=/home/vibecoder/.bun \
    NVM_DIR=/home/vibecoder/.nvm \
    UV_INSTALL_DIR=/home/vibecoder/.local \
    INSTALL_TOOLCHAINS=${INSTALL_TOOLCHAINS} \
    NVM_VERSION=${NVM_VERSION} \
    NODE_VERSION=${NODE_VERSION} \
    GO_VERSION=${GO_VERSION} \
    RUST_VERSION=${RUST_VERSION} \
    PYTHON_VERSION=${PYTHON_VERSION} \
    RUBY_VERSION=${RUBY_VERSION} \
    DENO_VERSION=${DENO_VERSION} \
    BUN_TOOLCHAIN_VERSION=${BUN_TOOLCHAIN_VERSION} \
    PHP_VERSION=${PHP_VERSION} \
    PATH=/home/vibecoder/.nvm/current/bin:/home/vibecoder/sdk/go/bin:/home/vibecoder/go/bin:/home/vibecoder/.cargo/bin:/home/vibecoder/.deno/bin:/home/vibecoder/.bun/bin:/home/vibecoder/.rbenv/shims:/home/vibecoder/.rbenv/bin:/home/vibecoder/.phpenv/shims:/home/vibecoder/.phpenv/bin:/home/vibecoder/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN mkdir -p \
        /home/vibecoder/.config/openchamber \
        /home/vibecoder/.config/opencode \
        /home/vibecoder/.local/share/opencode \
        /home/vibecoder/.local/state/opencode \
        /home/vibecoder/.local/share/9router \
        /home/vibecoder/.local/bin \
        /home/vibecoder/.nvm \
        /home/vibecoder/workspaces \
        /home/vibecoder/sdk \
        /home/vibecoder/go \
    && chown -R vibecoder:vibecoder /home/vibecoder

COPY --chown=vibecoder:vibecoder docker-entrypoint.sh /usr/local/bin/vibecode-entrypoint
COPY --chown=vibecoder:vibecoder opencode.default.json /usr/local/share/vibecode/opencode.default.json
COPY --chown=vibecoder:vibecoder scripts/install-node.sh scripts/install-go.sh scripts/install-rust.sh scripts/install-python.sh scripts/install-ruby.sh scripts/install-deno.sh scripts/install-bun.sh scripts/install-php.sh /usr/local/share/vibecode/
RUN chmod 0755 /usr/local/bin/vibecode-entrypoint \
        /usr/local/share/vibecode/install-node.sh \
        /usr/local/share/vibecode/install-go.sh \
        /usr/local/share/vibecode/install-rust.sh \
        /usr/local/share/vibecode/install-python.sh \
        /usr/local/share/vibecode/install-ruby.sh \
        /usr/local/share/vibecode/install-deno.sh \
        /usr/local/share/vibecode/install-bun.sh \
        /usr/local/share/vibecode/install-php.sh \
    && ln -sf /usr/local/share/vibecode/install-node.sh /usr/local/bin/install-node \
    && ln -sf /usr/local/share/vibecode/install-go.sh /usr/local/bin/install-go \
    && ln -sf /usr/local/share/vibecode/install-rust.sh /usr/local/bin/install-rust \
    && ln -sf /usr/local/share/vibecode/install-python.sh /usr/local/bin/install-python \
    && ln -sf /usr/local/share/vibecode/install-ruby.sh /usr/local/bin/install-ruby \
    && ln -sf /usr/local/share/vibecode/install-deno.sh /usr/local/bin/install-deno \
    && ln -sf /usr/local/share/vibecode/install-bun.sh /usr/local/bin/install-bun \
    && ln -sf /usr/local/share/vibecode/install-php.sh /usr/local/bin/install-php

USER vibecoder
WORKDIR /home/vibecoder/workspaces

VOLUME ["/home/vibecoder"]
EXPOSE 3000 20128
HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 CMD curl -fsS http://127.0.0.1:3000/health >/dev/null && curl -fsS http://127.0.0.1:20128/api/health >/dev/null || exit 1
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/vibecode-entrypoint"]
