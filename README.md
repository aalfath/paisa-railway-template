[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/paisa-1?utm_medium=integration&utm_source=button&utm_campaign=paisa)

# Deploy and Host Paisa on Railway

Paisa is an open-source personal finance manager (AGPL-3.0) built on plain-text accounting. You keep your transactions in ledger, hledger or beancount journal files, and Paisa turns them into dashboards for net worth, income and expenses, budgets, investments, goals, credit cards and capital gains. This template deploys Paisa v0.8.0 behind a login.

## About Hosting Paisa

Paisa is a single Go binary that serves its web UI and reads your journal with the ledger, hledger or beancount command-line tools. Everything it needs lives in one folder: `paisa.yaml` (configuration), your journal files, spreadsheets and a SQLite cache (`paisa.db`). This template runs one service built from the official image, keeps that folder on a Railway volume, and serves it on a Railway domain with a health check. Upstream Paisa has no login until you add one, so the template creates the `admin` account from a generated password before the UI starts, and the service exits (and Railway restarts it) if Paisa stops.

## Common Use Cases

* Track spending, income and net worth from a ledger, hledger or beancount journal you write by hand or import from bank statements
* Follow budgets, savings and retirement goals, recurring payments and credit cards in one dashboard
* Review investments, asset allocation and capital gains (including Indian tax reports such as Schedule AL)

## Dependencies for Paisa Hosting

* Paisa (one service, data on a Railway volume)

### Deployment Dependencies

* [Paisa documentation](https://paisa.fyi/)
* [Paisa v0.8.0 release](https://github.com/ananthakumaran/paisa/releases/tag/v0.8.0)
* [Official Docker image](https://hub.docker.com/r/ananthakumaran/paisa)
* [Template source](https://github.com/aalfath/paisa-railway-template)

### Implementation Details

**After you deploy:** open the Paisa service's Variables tab and copy `PAISA_PASSWORD` (generated at deploy). Open the public URL and sign in as `admin` with that password. Your data starts empty: write transactions in the Editor, import a bank CSV from the Import page, or click "Load Demo" on the empty dashboard to explore with sample data. Then open Config to set your `default_currency` and `locale` (Paisa defaults to INR and en-IN).

**Login:** to change the password or the username, change `PAISA_PASSWORD` or `PAISA_USERNAME` on the service and redeploy. On every start the template writes that account into `paisa.yaml` (stored as Paisa's own SHA-256 hash), and it puts it back if Paisa's "Load Demo" or a config edit removes all user accounts. Other accounts you add in Config stay.

**Data:** the volume at `/root/Documents/paisa` holds `paisa.yaml`, `main.ledger`, sheets and `paisa.db`, so it survives redeploys and restarts. Back up that folder (or keep your journal in git) if your finances matter to you.

**Ledger tools:** the image includes ledger, hledger and beancount. Pick one with `ledger_cli` in Config.

**Resources:** it runs within 0.5 GB of RAM and 1 vCPU, so it works on Railway's Free and Trial plans. Large journals with many years of prices sync faster with more memory.

**Updates:** the service builds from this GitHub repo, which pins the official image by version and digest. When we bump the version, Railway shows an update in your project; read the changelog in the repo first, then apply it.

## Why Deploy Paisa on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Paisa on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->

## Template details

| Service | Built from | Volume |
|---|---|---|
| Paisa | [`Dockerfile`](Dockerfile): `ananthakumaran/paisa:v0.8.0-all@sha256:32d69218d0822076a694df48c1b21a442c05adb36364830b6a9c1ccd21ade627` plus [`railway-start.sh`](railway-start.sh) and `yq` 4.54.3 | `/root/Documents/paisa` |

Health check: `/` (Paisa's web page, which answers without a login). Port: `PORT` (7500).

### Variables

| Variable | Value |
|---|---|
| `PAISA_PASSWORD` | generated, 24 characters: the password for the login below |
| `PAISA_USERNAME` | `admin` (letters, digits, `.`, `_`, `-`) |
| `PORT` | `7500` |

Optional, not in the template: `GOMAXPROCS` (default 2) and `GOMEMLIMIT` (default `384MiB`) cap the Go runtime for small plans; raise `GOMEMLIMIT` if you give the service more memory.

### What the wrapper does

`railway-start.sh` creates a minimal `paisa.yaml` and an empty `main.ledger` on a new volume, validates `PAISA_USERNAME`, writes the login account into `paisa.yaml`, refuses to start if there is neither a password nor an existing account, and starts `paisa serve --port $PORT`. Every few seconds it checks that `paisa.yaml` still has a user account and that Paisa is running; if Paisa stops, the container exits non-zero so Railway restarts it.

### Updating this template

Bump the tag and digest in the Dockerfile, test on a scratch Railway project, add a `CHANGELOG.md` entry (breaking changes first) and merge to `main`. Deployers then see the update in Railway.
