FROM node:22-alpine AS packages

ARG NINEROUTER_VERSION=0.5.35
ARG OPENCODE_VERSION=1.18.3
ARG OPENCHAMBER_VERSION=1.16.2

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

FROM oven/bun:1.3.14-alpine

RUN apk add --no-cache \
        bash \
        ca-certificates \
        curl \
        git \
        libstdc++ \
        nodejs \
        openssh-client \
        tini

COPY --from=packages /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf ../lib/node_modules/9router/cli.js /usr/local/bin/9router \
    && ln -sf ../lib/node_modules/@openchamber/web/bin/cli.js /usr/local/bin/openchamber \
    && ln -sf ../lib/node_modules/opencode-ai/bin/opencode /usr/local/bin/opencode

ENV HOME=/home/bun \
    OPENCHAMBER_HOST=0.0.0.0 \
    OPENCODE_CONFIG_DIR=/home/bun/.config/opencode \
    PORT=20128 \
    HOSTNAME=0.0.0.0 \
    DATA_DIR=/home/bun/.local/share/9router \
    NEXT_TELEMETRY_DISABLED=1

RUN mkdir -p \
        /home/bun/.config/openchamber \
        /home/bun/.config/opencode \
        /home/bun/.local/share/opencode \
        /home/bun/.local/state/opencode \
        /home/bun/.local/share/9router \
        /home/bun/workspaces \
    && chown -R bun:bun /home/bun

COPY --chown=bun:bun docker-entrypoint.sh /usr/local/bin/vibecode-entrypoint
RUN chmod 0755 /usr/local/bin/vibecode-entrypoint

USER bun
WORKDIR /home/bun/workspaces

VOLUME ["/home/bun/.config/openchamber", "/home/bun/.config/opencode", "/home/bun/.local/share/opencode", "/home/bun/.local/state/opencode", "/home/bun/.local/share/9router", "/home/bun/workspaces"]
EXPOSE 3000 20128
HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 CMD curl -fsS http://127.0.0.1:3000/health >/dev/null && curl -fsS http://127.0.0.1:20128/api/health >/dev/null || exit 1
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/vibecode-entrypoint"]
