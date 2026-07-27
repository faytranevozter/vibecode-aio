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
  -v vibecode-home:/home/vibecoder \
  ghcr.io/faytranevozter/vibecode-aio:debian
```

Then open:

- UI: http://localhost:3000  
- 9router: http://localhost:20128  

Health: `GET /health` (OpenChamber), `GET /api/health` (9router).

The whole home directory is a single named volume so app config, workspaces, shell history, SSH keys, and user-installed toolchains (Go, Rust, etc.) all persist across container recreate.

### Which tag should I pull?

| Tag | Use when |
| --- | --- |
| `debian` | **Recommended** for Go/Rust and most prebuilt toolchains (glibc) |
| `latest` or `alpine` | Smaller Alpine image; fine for Node/agent work, weaker native binary compat |
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

Mount one volume on the full home directory:

| Host volume (example) | Container path | Stores |
| --- | --- | --- |
| `vibecode-home` | `/home/vibecoder` | Everything under home |

That includes:

| Path under home | Stores |
| --- | --- |
| `.config/openchamber` | OpenChamber settings |
| `.config/opencode` | OpenCode config |
| `.local/share/opencode` | OpenCode data |
| `.local/state/opencode` | OpenCode state |
| `.local/share/9router` | 9router DB / settings |
| `workspaces` | Projects for the agent |
| `sdk/go`, `go` | Optional Go toolchain / GOPATH |
| `.cargo`, `.rustup` | Optional Rust toolchain |
| `.deno`, `.bun` | Optional Deno / user-space Bun toolchains |
| `.rbenv`, `.phpenv` | Optional Ruby / PHP toolchains |
| `.local/bin` | Optional user binaries |
| `.ssh`, shell rc, caches | User secrets and preferences |

On first boot with an empty home volume, the entrypoint creates the app layout dirs. Install toolchains into `$HOME` (not `/usr/local`) so they survive image upgrades.

### Migrate from six subpath volumes

Older docs used six named volumes. Docker cannot add mounts to a running container — stop, merge into `vibecode-home`, recreate.

```bash
CONTAINER=vibecode-aio
docker stop "$CONTAINER"
docker rename "$CONTAINER" "${CONTAINER}-old"
docker volume create vibecode-home

copy_vol() {
  src_vol="$1"; dest_sub="$2"
  docker run --rm \
    -v "${src_vol}:/from:ro" \
    -v vibecode-home:/to \
    alpine sh -c "mkdir -p \"/to/${dest_sub}\" && cp -a /from/. \"/to/${dest_sub}/\" && chown -R 1000:1000 \"/to/${dest_sub}\""
}

copy_vol vibecode-openchamber      .config/openchamber
copy_vol vibecode-opencode-config  .config/opencode
copy_vol vibecode-opencode-share   .local/share/opencode
copy_vol vibecode-opencode-state   .local/state/opencode
copy_vol vibecode-9router          .local/share/9router
copy_vol vibecode-workspaces       workspaces

docker run -d --name vibecode-aio \
  --env-file .env \
  -p 3000:3000 \
  -p 20128:20128 \
  -v vibecode-home:/home/vibecoder \
  ghcr.io/faytranevozter/vibecode-aio:debian

# after verifying health and data:
# docker rm vibecode-aio-old
# docker volume rm vibecode-openchamber vibecode-opencode-config \
#   vibecode-opencode-share vibecode-opencode-state \
#   vibecode-9router vibecode-workspaces
```

### Optional toolchains (`INSTALL_TOOLCHAINS`)

Toolchains are **not** baked into image layers. They install into `$HOME` (`vibecode-home`) so they survive recreate. Prefer the **debian** tag.

#### One env for many tools

| Variable | Default | Meaning |
| --- | --- | --- |
| `INSTALL_TOOLCHAINS` | _(empty)_ | Comma-separated list: `go`, `rust`, `python`, `ruby`, `deno`, `bun`, `php` |
| `GO_VERSION` | `1.26.5` | Go pin |
| `RUST_VERSION` | `stable` | rustup toolchain |
| `PYTHON_VERSION` | `3.15` | uv-managed Python |
| `RUBY_VERSION` | `4.0.6` | rbenv Ruby |
| `DENO_VERSION` | `2.9.4` | Deno pin |
| `BUN_TOOLCHAIN_VERSION` | `1.3.14` | user-space Bun pin |
| `PHP_VERSION` | `8.5.8` | phpenv PHP pin |

Aliases: `golang`→go, `cargo`/`rustup`→rust, `py`/`uv`→python, `rb`/`rbenv`→ruby, `composer`→php.  
Legacy `INSTALL_GO=1` / `INSTALL_RUST=1` / `INSTALL_PYTHON=1` / etc. still work and are merged into the list.

**Bake default list at build** (install still runs on first start into home — needs network once):

```bash
docker build --target debian \
  --build-arg INSTALL_TOOLCHAINS=go,rust,python,ruby,deno,bun,php \
  --build-arg GO_VERSION=1.26.5 \
  --build-arg PYTHON_VERSION=3.15 \
  -t vibecode-aio:debian .
```

**Enable at run** (no rebuild):

```bash
docker run -d --name vibecode-aio \
  --env-file .env \
  -e INSTALL_TOOLCHAINS=go,rust,python,deno,bun \
  -e GO_VERSION=1.26.5 \
  -p 3000:3000 -p 20128:20128 \
  -v vibecode-home:/home/vibecoder \
  vibecode-aio:debian
```

Or set `INSTALL_TOOLCHAINS=...` in `.env`. Installs are **idempotent**; failures warn and do not block the apps.

#### Manual install (any time)

```bash
docker exec -u vibecoder -it vibecode-aio install-go
docker exec -u vibecoder -it vibecode-aio install-rust
docker exec -u vibecoder -it vibecode-aio install-python   # uv + Python
docker exec -u vibecoder -it vibecode-aio install-ruby     # rbenv + Ruby
docker exec -u vibecoder -it vibecode-aio install-deno
docker exec -u vibecoder -it vibecode-aio install-bun      # user-space Bun
docker exec -u vibecoder -it vibecode-aio install-php      # phpenv + PHP
```

| Name | How | Home paths | Notes |
| --- | --- | --- | --- |
| `go` | official tarball | `~/sdk/go`, `~/go` | Fast binary install |
| `rust` | rustup | `~/.cargo`, `~/.rustup` | Fast binary install |
| `python` | [uv](https://github.com/astral-sh/uv) | `~/.local`, uv cache | Fast; good default Python |
| `ruby` | rbenv + ruby-build | `~/.rbenv` | **Compiles** from source — needs build deps |
| `deno` | official installer | `~/.deno` | Fast binary install |
| `bun` | official installer | `~/.bun` | Fast binary install; image already includes Bun too |
| `php` | phpenv + php-build | `~/.phpenv` | **Compiles** from source — needs build deps |

Ruby, PHP, and native gems/crates may need OS packages once (ephemeral to the image layer):

```bash
# debian, as root inside container if compile fails:
# apt-get update && apt-get install -y build-essential autoconf bison re2c pkg-config \
#   libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev \
#   libcurl4-openssl-dev libxml2-dev libsqlite3-dev libonig-dev libzip-dev
```

#### Already in the image (no install needed)

Node, npm, pnpm, Bun, `gh`, Chromium, and the agent stack ship in the image. The `bun` toolchain option installs a second user-space Bun under `~/.bun` only when you explicitly ask for it.

#### Suggested extras (DIY under `$HOME`)

Not shipped as `install-*` yet — same pattern: put binaries under home so the volume keeps them.

| Tool | Typical home install |
| --- | --- |
| **Java** | [SDKMAN](https://sdkman.io) → `~/.sdkman` |
| **Zig** | tarball under `~/sdk/zig` + symlink in `~/.local/bin` |
| **Terraform / OpenTofu** | binary in `~/.local/bin` |
| **kubectl / helm** | binaries in `~/.local/bin` |
| **mise** | one version manager for many languages → `~/.local` |

Do not install into `/usr/local` if you want persistence across image pulls.

---

## Using the three apps together

1. Open **OpenChamber** on port `3000` and sign in with `OPENCHAMBER_UI_PASSWORD`.
2. Open **9router** on port `20128`, finish setup with `INITIAL_PASSWORD`, add your LLM providers.
3. In OpenCode / OpenChamber provider settings, point the OpenAI-compatible base URL at:

   `http://127.0.0.1:20128/v1`

   (same container → `127.0.0.1` is correct)

OpenCode is started automatically by OpenChamber.

### Built-in agent tools

The image includes:

- GitHub CLI: `gh`
- Playwright MCP: `playwright-mcp`
- Context7 MCP: `context7-mcp`
- Chrome DevTools MCP: `chrome-devtools-mcp`
- CodeGraph CLI and MCP server: `codegraph`
- RTK command-output optimizer: `rtk`
- System Chromium for headless browser MCP sessions

On first startup, if `/home/vibecoder/.config/opencode/opencode.json` does not exist, the entrypoint seeds a default OpenCode config that enables `playwright`, `context7`, `chrome-devtools`, and `codegraph` MCP servers. If an OpenCode config already exists, the entrypoint updates only the managed MCP entries (`context7`, `codegraph`) and keeps the rest of the file intact.

To authenticate `gh`, either run `gh auth login` in the container or pass `GH_TOKEN`/`GITHUB_TOKEN` in your environment. The default OpenCode permission config keeps `gh *` at `ask` because it can mutate repositories, issues, pull requests, releases, and auth state.

Context7 MCP reads its API key from `CONTEXT7_API_KEY`. Add it to `.env` or pass it with `docker run -e CONTEXT7_API_KEY=...`; the default OpenCode config passes it to `context7-mcp --api-key` without writing the secret into the config file.

CodeGraph ships as a self-contained CLI. Its MCP server is launched with `codegraph serve --mcp`, and projects need a local `.codegraph/` index to expose tools. Run `codegraph init` inside a project after startup to build that index.

`codegraph init` is per workspace. Each project you want CodeGraph to index must be initialized once before the MCP server becomes active for that workspace.

Troubleshooting: if a workspace does not have a `.codegraph/` index yet, the CodeGraph MCP server stays inactive and exposes no tools until you run `codegraph init`.

RTK is initialized for OpenCode automatically on container startup when the `rtk` binary is available. Set `RTK_OPENCODE_INIT=0` to disable that behavior. RTK telemetry is disabled by default with `RTK_TELEMETRY_DISABLED=1`.

RTK is available in Debian images and Alpine x86_64 images. Alpine arm64 skips RTK because upstream does not publish an Alpine-compatible arm64 binary yet; the entrypoint logs a warning and continues startup.

Verify the correct RTK installation with `rtk --version` and `rtk gain`. RTK is the Rust Token Killer from [rtk-ai/rtk](https://github.com/rtk-ai/rtk); do not install the unrelated npm package named `rtk`.

RTK can be used explicitly for compact command output, for example:

```bash
rtk git status
rtk pnpm list
rtk vitest
rtk playwright test
```

After editing `/home/vibecoder/.config/opencode/opencode.json`, restart the container or OpenCode session. OpenCode loads config once at startup.

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

# Default auto-install toolchains into home volume on container start
docker build --target debian \
  --build-arg INSTALL_TOOLCHAINS=go,rust,python,ruby,deno,bun,php \
  -t vibecode-aio:debian .
```

| Variant | Base | Notes |
| --- | --- | --- |
| `alpine` | Bun Alpine + Node LTS | Default, smaller |
| `debian` | Bun Debian + Node LTS | glibc OpenCode binary; better for Go/Rust |

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
| [GitHub CLI](https://github.com/cli/cli) | GitHub command-line workflows | OS package `gh` / `github-cli` |
| [Playwright MCP](https://github.com/microsoft/playwright-mcp) | Browser automation MCP server | npm `@playwright/mcp` |
| [Context7 MCP](https://github.com/upstash/context7) | Documentation context MCP server | npm `@upstash/context7-mcp` |
| [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) | Chrome debugging/performance MCP server | npm `chrome-devtools-mcp` |
| [CodeGraph](https://github.com/colbymchenry/codegraph) | Code intelligence CLI and MCP server | npm `@colbymchenry/codegraph` |
| [RTK](https://github.com/rtk-ai/rtk) | Compact shell output for AI agents | Prebuilt Rust binary `rtk` |
