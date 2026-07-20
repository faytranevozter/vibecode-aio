# vibecode-aio

One container with **9router** (model gateway), **OpenCode** (AI coding agent), and **OpenChamber** (web UI).

Runs as user **`vibecoder`** (`uid 1000`) with home `/home/vibecoder`.

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
  -v vibecode-openchamber:/home/vibecoder/.config/openchamber \
  -v vibecode-opencode-config:/home/vibecoder/.config/opencode \
  -v vibecode-opencode-share:/home/vibecoder/.local/share/opencode \
  -v vibecode-opencode-state:/home/vibecoder/.local/state/opencode \
  -v vibecode-9router:/home/vibecoder/.local/share/9router \
  -v vibecode-workspaces:/home/vibecoder/workspaces \
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
| `v0.1.1` | Pin a release (same as that release’s alpine) |
| `v0.1.1-alpine` / `v0.1.1-debian` | Pin a specific variant of a release |

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

| Container path | Stores |
| --- | --- |
| `/home/vibecoder/.config/openchamber` | OpenChamber settings |
| `/home/vibecoder/.config/opencode` | OpenCode config |
| `/home/vibecoder/.local/share/opencode` | OpenCode data |
| `/home/vibecoder/.local/state/opencode` | OpenCode state |
| `/home/vibecoder/.local/share/9router` | 9router DB / settings |
| `/home/vibecoder/workspaces` | Projects for the agent |

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

## How to bump / release a version

Two different “versions” exist:

| Kind | Where | Meaning |
| --- | --- | --- |
| **vibecode-aio** | `VERSION` (+ `package.json`) | Your image release (`0.1.0` → tag `v0.1.0`) |
| **Upstream packages** | Dockerfile `ARG`s | Pinned `9router` / `opencode-ai` / `@openchamber/web` |

### A) Automatic (upstream packages)

Every **3 hours**, **Watch upstream** checks npm. If anything is newer, it opens a PR that:

1. Updates Dockerfile `ARG`s  
2. Bumps **patch** in `VERSION` + `package.json`  

You still:

1. Review & merge the PR  
2. Wait for **CI** green  
3. Publish (section C)

### B) Manual bump

```bash
# Upstream package pins only (compare / write Dockerfile ARGs)
./scripts/check-upstream.sh
./scripts/check-upstream.sh --write

# vibecode-aio semver only
./scripts/bump-semver.sh patch   # 0.1.0 → 0.1.1
./scripts/bump-semver.sh minor   # 0.1.0 → 0.2.0
./scripts/bump-semver.sh major   # 0.1.0 → 1.0.0
```

Commit the result, push to `main`, then publish.

### C) Publish to GHCR

Tag **must equal** `VERSION` with a `v` prefix:

```bash
git checkout main && git pull
# ensure VERSION is what you want to release
git tag "v$(tr -d '[:space:]' < VERSION)"
git push origin "v$(tr -d '[:space:]' < VERSION)"
```

**Release** builds alpine + debian and pushes:

```text
ghcr.io/faytranevozter/vibecode-aio:vX.Y.Z          # alpine (default)
ghcr.io/faytranevozter/vibecode-aio:vX.Y.Z-alpine
ghcr.io/faytranevozter/vibecode-aio:vX.Y.Z-debian
ghcr.io/faytranevozter/vibecode-aio:alpine
ghcr.io/faytranevozter/vibecode-aio:debian
ghcr.io/faytranevozter/vibecode-aio:latest           # alpine
```

### Automation overview

| Workflow | When | What |
| --- | --- | --- |
| **CI** | PR/push to image-related files | Build alpine + debian (no push) |
| **Release** | Git tag `v*.*.*` | Push both variants to GHCR |
| **Watch upstream** | Every 3 hours + manual | Open PR for newer npm packages |

Needs:

- Actions enabled
- Release: workflow `packages: write`
- Watch: workflow `contents` + `pull-requests` write
- **Repo setting (required for Watch PRs):**  
  **Settings → Actions → General → Workflow permissions**  
  - “Read and write permissions”  
  - Enable **“Allow GitHub Actions to create and approve pull requests”**

Without that last checkbox, Watch upstream fails with:  
`GitHub Actions is not permitted to create or approve pull requests`.

No extra secrets for same-repo GHCR (`GITHUB_TOKEN` is enough).

---

## What’s inside

| App | Role | Upstream |
| --- | --- | --- |
| [9router](https://github.com/decolua/9router) | Model routing / OpenAI-compatible proxy | npm `9router` |
| [OpenCode](https://github.com/anomalyco/opencode) | AI coding agent | npm `opencode-ai` |
| [OpenChamber](https://github.com/openchamber/openchamber) | Web UI for OpenCode | npm `@openchamber/web` |
