# vibecode-aio

Multi-stage Docker images that install and run:

| App | Role | Package |
| --- | --- | --- |
| [9router](https://github.com/decolua/9router) | AI API gateway / router | `9router` |
| [OpenCode](https://github.com/anomalyco/opencode) | AI coding agent (managed by OpenChamber) | `opencode-ai` |
| [OpenChamber](https://github.com/openchamber/openchamber) | Web UI for OpenCode | `@openchamber/web` |

## Variants

| Target | Base | Node | OpenCode binary | Default |
| --- | --- | --- | --- | --- |
| `alpine` | `oven/bun` Alpine | Node LTS (from builder) | musl | yes |
| `debian` | `oven/bun` Debian | Node LTS (from builder) | glibc | no |

## Quick start

```bash
cp .env.example .env
# edit .env and set strong secrets

# Alpine (default, smaller)
docker build -t vibecode-aio:alpine --target alpine .
docker run --rm --env-file .env \
  -p 3000:3000 \
  -p 20128:20128 \
  -v vibecode-openchamber:/home/bun/.config/openchamber \
  -v vibecode-opencode-config:/home/bun/.config/opencode \
  -v vibecode-opencode-share:/home/bun/.local/share/opencode \
  -v vibecode-opencode-state:/home/bun/.local/state/opencode \
  -v vibecode-9router:/home/bun/.local/share/9router \
  -v vibecode-workspaces:/home/bun/workspaces \
  vibecode-aio:alpine
```

Debian (non-Alpine):

```bash
docker build -t vibecode-aio:debian --target debian .
docker run --rm --env-file .env \
  -p 3000:3000 \
  -p 20128:20128 \
  -v vibecode-openchamber:/home/bun/.config/openchamber \
  -v vibecode-opencode-config:/home/bun/.config/opencode \
  -v vibecode-opencode-share:/home/bun/.local/share/opencode \
  -v vibecode-opencode-state:/home/bun/.local/state/opencode \
  -v vibecode-9router:/home/bun/.local/share/9router \
  -v vibecode-workspaces:/home/bun/workspaces \
  vibecode-aio:debian
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
docker build --target alpine \
  --build-arg NINEROUTER_VERSION=0.5.35 \
  --build-arg OPENCODE_VERSION=1.18.3 \
  --build-arg OPENCHAMBER_VERSION=1.16.2 \
  -t vibecode-aio:alpine .
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

Both targets use multi-stage builds:

1. **packages-*** (`node:lts-alpine` or `node:lts-bookworm-slim`) — install npm packages and compile native addons (`g++` / `make` / `python3` stay only in this stage)
2. **runtime** (`oven/bun` Alpine or Debian) — copy installed packages into a slim image with Bun and runtime tools only

Default `docker build` target is `alpine` (last stage). Explicit targets:

```bash
docker build --target alpine -t vibecode-aio:alpine .
docker build --target debian -t vibecode-aio:debian .
```

Package install stages use **Node.js LTS** (`node:lts-alpine` / `node:lts-bookworm-slim`).

## Versioning

| File | Role |
| --- | --- |
| `VERSION` | **Source of truth** for vibecode-aio semver (e.g. `0.1.0`) |
| `package.json` | Mirrors `VERSION` for tooling convenience |
| `Dockerfile` `ARG NINEROUTER_VERSION` / `OPENCODE_VERSION` / `OPENCHAMBER_VERSION` | Pinned upstream npm package versions |

Release git tags must match `VERSION` with a `v` prefix (example: `VERSION=0.1.0` → tag `v0.1.0`).

## GitHub Actions & GHCR

Images publish to:

```text
ghcr.io/faytranevozter/vibecode-aio
```

### Workflows

| Workflow | File | Trigger | What it does |
| --- | --- | --- | --- |
| **CI** | `.github/workflows/ci.yml` | PR/push changing Dockerfile, entrypoint, VERSION, package.json, workflows, or scripts | Builds `alpine` and `debian` (no push); smoke-checks CLIs |
| **Release** | `.github/workflows/release.yml` | Push tag `v*.*.*` | Builds both targets and **pushes** to GHCR |
| **Watch upstream** | `.github/workflows/watch-upstream.yml` | Every 3 hours + `workflow_dispatch` | Compares Dockerfile ARGs to npm latest; opens a **PR** that bumps ARGs + patch semver (no auto-merge, no auto-tag) |

### Image tags (on release `vX.Y.Z`)

| Tag | Meaning |
| --- | --- |
| `vX.Y.Z` | Default release tag → **alpine** |
| `vX.Y.Z-alpine` | Immutable alpine build for that release |
| `vX.Y.Z-debian` | Immutable debian build for that release |
| `alpine` | Floating latest alpine |
| `debian` | Floating latest debian |
| `latest` | Same as alpine (default variant) |

Examples (for git tag `v0.1.0`):

```text
ghcr.io/faytranevozter/vibecode-aio:v0.1.0
ghcr.io/faytranevozter/vibecode-aio:v0.1.0-alpine
ghcr.io/faytranevozter/vibecode-aio:v0.1.0-debian
ghcr.io/faytranevozter/vibecode-aio:alpine
ghcr.io/faytranevozter/vibecode-aio:debian
ghcr.io/faytranevozter/vibecode-aio:latest
```

### Publish a release (human steps)

1. Merge any open upstream-bump PR (or edit `VERSION` / Dockerfile ARGs yourself).
2. Ensure CI is green on `main`.
3. Tag and push (tag must equal `VERSION`):

```bash
git checkout main && git pull
git tag "v$(tr -d '[:space:]' < VERSION)"
git push origin "v$(tr -d '[:space:]' < VERSION)"
```

4. Confirm the **Release** workflow succeeded and images appear under the repo **Packages** tab.

### Required GitHub settings

| Permission / setting | Why |
| --- | --- |
| `packages: write` (Release workflow `GITHUB_TOKEN`) | Push to GHCR |
| `contents: write` + `pull-requests: write` (Watch upstream) | Open dependency bump PRs |
| Actions enabled | Run workflows |
| Package visibility | Set GHCR package public/private as needed after first push |

No extra secrets are required for GHCR when using `GITHUB_TOKEN` on the same repository.

### Local helpers

```bash
# Compare Dockerfile ARGs to npm latest
./scripts/check-upstream.sh

# Write newer ARGs into Dockerfile (used by CI watch job)
./scripts/check-upstream.sh --write

# Bump patch|minor|major in VERSION + package.json
./scripts/bump-semver.sh patch
```

## Notes

- OpenCode is started by OpenChamber automatically.
- Point OpenCode at 9router (`http://127.0.0.1:20128/v1`) from OpenCode/OpenChamber provider settings when you want model traffic routed through 9router.
- The image entrypoint starts 9router and OpenChamber together and stops both on container shutdown.
- Prefer Alpine for smaller images; use Debian if you need glibc compatibility.
