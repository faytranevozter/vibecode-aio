FROM oven/bun:1.3.14

ARG NINEROUTER_VERSION=0.5.35
ARG OPENCODE_VERSION=1.18.3
ARG OPENCHAMBER_VERSION=1.16.2

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl g++ git make nodejs npm openssh-client python3 tini \
    && npm install -g \
        "9router@${NINEROUTER_VERSION}" \
        "opencode-ai@${OPENCODE_VERSION}" \
        "@openchamber/web@${OPENCHAMBER_VERSION}" \
    && rm -rf /var/lib/apt/lists/* /root/.npm

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
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/vibecode-entrypoint"]
