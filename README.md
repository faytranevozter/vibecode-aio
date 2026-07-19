# vibecode-aio

One container with **9router** (model gateway), **OpenCode** (AI coding agent), and **OpenChamber** (web UI).

**Image:** [`ghcr.io/faytranevozter/vibecode-aio`](https://github.com/faytranevozter/vibecode-aio/pkgs/container/vibecode-aio)

| What you get | Port |
| --- | --- |
| OpenChamber UI | `3000` |
| 9router dashboard + OpenAI-compatible API (`/v1`) | `20128` |

---

## Run (recommended)

```bash
cp .env.example .env
# set strong passwords/secrets in .env

docker run --rm --name vibecode-aio \
  --env-file .env \
  -p 3000:3000 \
  -p 20128:20128 \
  -v vibecode-openchamber:/home/bun/.config/openchamber \
  -v vibecode-opencode-config:/home/bun/.config/opencode \
  -v vibecode-opencode-share:/home/bun/.local/share/opencode \
  -v vibecode-opencode-state:/home/bun/.local/state/opencode \
  -v vibecode-9router:/home/bun/.local/share/9router \
  -v vibecode-workspaces:/home/bun/workspaces \
  ghcr.io/faytranevozter/vibecode-aio:latest
```

Then open:

- UI: http://localhost:3000  
- 9router: http://localhost:20128  

Health: `GET /health` (OpenChamber), `GET /api/health` (9router).

### Which tag should I pull?

| Tag | Use when |
| --- | --- |
| `latest` or `alpine` | Everyday use (default, smaller Alpine image) |
| `debian` | You need glibc instead of musl |
| `v0.1.0` | Pin a release (same as that release’s alpine) |
| `v0.1.0-alpine` / `v0.1.0-debian` | Pin a specific variant of a release |

Private package? Log in first:

```bash
echo "$GITHUB_TOKEN" | docker login ghcr.io -u YOUR_GITHUB_USER --password-stdin
```

---

## Required config (`.env`)

| Variable | What it’s for |
| --- | --- |
| `OPENCHAMBER_UI_PASSWORD` | Password for the web UI |
| `JWT_SECRET` | 9router JWT signing secret |
| `INITIAL_PASSWORD` | First 9router dashboard password |
| `API_KEY_SECRET` | 9router API key hashing |
| `MACHINE_ID_SALT` | Stable machine id salt for 9router |

Copy from `.env.example` and change every value before exposing ports beyond localhost.

### Data that persists

| Volume | Stores |
| --- | --- |
| `.../openchamber` | OpenChamber settings |
| `.../opencode` (config/share/state) | OpenCode config, data, state |
| `.../9router` | 9router DB / settings |
| `workspaces` | Projects you work on in the agent |

---

## Using the three apps together

1. Open **OpenChamber** on port `3000` and sign in with `OPENCHAMBER_UI_PASSWORD`.
2. Open **9router** on port `20128`, finish setup with `INITIAL_PASSWORD`, add your LLM providers.
3. In OpenCode / OpenChamber provider settings, point the OpenAI-compatible base URL at:

   `http://127.0.0.1:20128/v1`

   (same container → `127.0.0.1` is correct)

OpenCode is started automatically by OpenChamber.

---

## Build from source

```bash
# Alpine (default)
docker build --target alpine -t vibecode-aio:alpine .

# Debian
docker build --target debian -t vibecode-aio:debian .

# Pin upstream package versions
docker build --target alpine \
  --build-arg NINEROUTER_VERSION=0.5.35 \
  --build-arg OPENCODE_VERSION=1.18.3 \
  --build-arg OPENCHAMBER_VERSION=1.16.2 \
  -t vibecode-aio:alpine .
```

| Variant | Base | Notes |
| --- | --- | --- |
| `alpine` | Bun Alpine + Node LTS | Default, smaller |
| `debian` | Bun Debian + Node LTS | glibc OpenCode binary |

---

## Releases & updates

| File | Meaning |
| --- | --- |
| `VERSION` | vibecode-aio semver (source of truth) |
| `package.json` | Same version, for tooling |
| Dockerfile `ARG`s | Pinned `9router` / `opencode-ai` / `@openchamber/web` |

### Pull published images after a release

Git tag `vX.Y.Z` publishes:

```text
ghcr.io/faytranevozter/vibecode-aio:vX.Y.Z          # alpine
ghcr.io/faytranevozter/vibecode-aio:vX.Y.Z-alpine
ghcr.io/faytranevozter/vibecode-aio:vX.Y.Z-debian
ghcr.io/faytranevozter/vibecode-aio:alpine
ghcr.io/faytranevozter/vibecode-aio:debian
ghcr.io/faytranevozter/vibecode-aio:latest           # alpine
```

### Publish a new version (maintainers)

1. Merge CI-green changes (including any upstream-bump PR).
2. Tag must match `VERSION`:

```bash
git checkout main && git pull
git tag "v$(tr -d '[:space:]' < VERSION)"
git push origin "v$(tr -d '[:space:]' < VERSION)"
```

3. Check **Actions → Release**, then the repo **Packages** tab.

### Automation

| Workflow | When | What |
| --- | --- | --- |
| **CI** | PR/push to image-related files | Build alpine + debian (no push) |
| **Release** | Git tag `v*.*.*` | Push both variants to GHCR |
| **Watch upstream** | Every 3 hours + manual | If npm has newer 9router / OpenCode / OpenChamber → open a PR (no auto-merge, no auto-tag) |

Needs: Actions enabled; Release uses `packages: write`; Watch uses `contents` + `pull-requests` write. No extra secrets for same-repo GHCR.

Local helpers:

```bash
./scripts/check-upstream.sh          # compare Dockerfile ARGs vs npm
./scripts/check-upstream.sh --write  # apply newer ARGs
./scripts/bump-semver.sh patch       # bump VERSION + package.json
```

---

## What’s inside

| App | Role | Upstream |
| --- | --- | --- |
| [9router](https://github.com/decolua/9router) | Model routing / OpenAI-compatible proxy | npm `9router` |
| [OpenCode](https://github.com/anomalyco/opencode) | AI coding agent | npm `opencode-ai` |
| [OpenChamber](https://github.com/openchamber/openchamber) | Web UI for OpenCode | npm `@openchamber/web` |
