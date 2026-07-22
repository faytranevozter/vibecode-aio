# syntax=docker/dockerfile:1.7

ARG NINEROUTER_VERSION=0.5.40
ARG OPENCODE_VERSION=1.18.4
ARG OPENCHAMBER_VERSION=1.16.3
ARG BUN_VERSION=1.3.14

# -----------------------------------------------------------------------------
# packages-alpine: install npm packages on Node LTS Alpine (musl)
# -----------------------------------------------------------------------------
FROM node:lts-alpine AS packages-alpine

ARG NINEROUTER_VERSION
ARG OPENCODE_VERSION
ARG OPENCHAMBER_VERSION

RUN apk add --no-cache python3 make g++ git \
    && npm install -g \
        "9router@${NINEROUTER_VERSION}" \
        "opencode-ai@${OPENCODE_VERSION}" \
        "@openchamber/web@${OPENCHAMBER_VERSION}" \
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

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 make g++ git ca-certificates \
    && npm install -g \
        "9router@${NINEROUTER_VERSION}" \
        "opencode-ai@${OPENCODE_VERSION}" \
        "@openchamber/web@${OPENCHAMBER_VERSION}" \
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

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
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

COPY --from=packages-debian /usr/local/bin/node /usr/local/bin/node
COPY --from=packages-debian /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf ../lib/node_modules/9router/cli.js /usr/local/bin/9router \
    && ln -sf ../lib/node_modules/@openchamber/web/bin/cli.js /usr/local/bin/openchamber \
    && ln -sf ../lib/node_modules/opencode-ai/bin/opencode /usr/local/bin/opencode \
    && node --version

ENV HOME=/home/vibecoder \
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

RUN apk add --no-cache \
        bash \
        ca-certificates \
        curl \
        git \
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

COPY --from=packages-alpine /usr/local/bin/node /usr/local/bin/node
COPY --from=packages-alpine /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf ../lib/node_modules/9router/cli.js /usr/local/bin/9router \
    && ln -sf ../lib/node_modules/@openchamber/web/bin/cli.js /usr/local/bin/openchamber \
    && ln -sf ../lib/node_modules/opencode-ai/bin/opencode /usr/local/bin/opencode \
    && node --version

ENV HOME=/home/vibecoder \
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
RUN chmod 0755 /usr/local/bin/vibecode-entrypoint

USER vibecoder
WORKDIR /home/vibecoder/workspaces

VOLUME ["/home/vibecoder/.config/openchamber", "/home/vibecoder/.config/opencode", "/home/vibecoder/.local/share/opencode", "/home/vibecoder/.local/state/opencode", "/home/vibecoder/.local/share/9router", "/home/vibecoder/workspaces"]
EXPOSE 3000 20128
HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 CMD curl -fsS http://127.0.0.1:3000/health >/dev/null && curl -fsS http://127.0.0.1:20128/api/health >/dev/null || exit 1
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/vibecode-entrypoint"]
