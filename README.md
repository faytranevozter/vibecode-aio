# vibecode-aio

One Alpine-based Docker image (multi-stage build) that installs and runs:

| App | Role | Package |
| --- | --- | --- |
| [9router](https://github.com/decolua/9router) | AI API gateway / router | `9router` |
| [OpenCode](https://github.com/anomalyco/opencode) | AI coding agent (managed by OpenChamber) | `opencode-ai` |
| [OpenChamber](https://github.com/openchamber/openchamber) | Web UI for OpenCode | `@openchamber/web` |

## Quick start

```bash
cp .env.example .env
# edit .env and set strong secrets

docker build -t vibecode-aio .
docker run --rm --env-file .env \
  -p 3000:3000 \
  -p 20128:20128 \
  -v vibecode-openchamber:/home/bun/.config/openchamber \
  -v vibecode-opencode-config:/home/bun/.config/opencode \
  -v vibecode-opencode-share:/home/bun/.local/share/opencode \
  -v vibecode-opencode-state:/home/bun/.local/state/opencode \
  -v vibecode-9router:/home/bun/.local/share/9router \
  -v vibecode-workspaces:/home/bun/workspaces \
  vibecode-aio
```

## URLs

| Service | URL |
| --- | --- |
| OpenChamber UI | http://localhost:3000 |
| 9router dashboard / API | http://localhost:20128 |
| 9router OpenAI-compatible API | http://localhost:20128/v1 |

Health checks:

- OpenChamber: `GET /health`
- 9router: `GET /api/health`

## Configuration

Copy `.env.example` to `.env` and set the required values:

| Variable | Description |
| --- | --- |
| `OPENCHAMBER_UI_PASSWORD` | Password for the OpenChamber browser UI |
| `JWT_SECRET` | Secret used by 9router for JWT signing |
| `INITIAL_PASSWORD` | Initial 9router dashboard password |
| `API_KEY_SECRET` | Secret used by 9router to hash API keys |
| `MACHINE_ID_SALT` | Salt used by 9router for stable machine IDs |

Pinned package versions (override at build time):

```bash
docker build \
  --build-arg NINEROUTER_VERSION=0.5.35 \
  --build-arg OPENCODE_VERSION=1.18.3 \
  --build-arg OPENCHAMBER_VERSION=1.16.2 \
  -t vibecode-aio .
```

## Volumes

| Path | Purpose |
| --- | --- |
| `/home/bun/.config/openchamber` | OpenChamber config |
| `/home/bun/.config/opencode` | OpenCode config |
| `/home/bun/.local/share/opencode` | OpenCode data |
| `/home/bun/.local/state/opencode` | OpenCode state |
| `/home/bun/.local/share/9router` | 9router data |
| `/home/bun/workspaces` | Coding workspaces |

## Build layout

Multi-stage Dockerfile:

1. **packages** (`node:22-alpine`) — install npm packages and compile native addons (`g++` / `make` / `python3` stay only in this stage)
2. **runtime** (`oven/bun:1.3.14-alpine`) — copy installed packages into a slim image with Bun, Node, and runtime tools only

## Notes

- OpenCode is started by OpenChamber automatically.
- Point OpenCode at 9router (`http://127.0.0.1:20128/v1`) from OpenCode/OpenChamber provider settings when you want model traffic routed through 9router.
- The image entrypoint starts 9router and OpenChamber together and stops both on container shutdown.
