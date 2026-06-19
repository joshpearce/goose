<!-- generated-by: gsd-doc-writer -->
# Configuration

Goose has two independently configurable components: the **iOS app** and the **server stack** (FastAPI + TimescaleDB). Neither component requires the other to be running — you can use the iOS app without a server, or run the server standalone.

---

## iOS App

All iOS configuration is done at runtime through the app UI. There is no build-time configuration file.

### Where to find the settings

**More > Remote Server** (navigates to `MoreRemoteServerView`)

### Configurable fields

| Field | Storage | Key / Service | Description |
|---|---|---|---|
| Server URL | `UserDefaults` | `goose.remote.serverURL` | Base URL of your self-hosted server. Must use `https://` or `http://`. Private-range and loopback IP addresses are accepted over `http://`; public addresses require `https://`. Example: `https://goose.example.com` or `http://192.168.1.10:8770` |
| Bearer token | iOS Keychain | service `goose.remote`, account `apiKey` | The `GOOSE_API_KEY` value configured on the server. Stored with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. |
| Enable Upload | `UserDefaults` | `goose.remote.uploadEnabled` | Toggle that gates all outbound uploads. Upload is only attempted when this is `true`, the URL is non-empty, and a token is present. |

### Validation rules

- The server URL must have an `http` or `https` scheme and a non-empty hostname.
- Private-range IP addresses (RFC 1918: `10.x.x.x`, `172.16–31.x.x`, `192.168.x.x`) and loopback addresses (`127.x.x.x`, RFC 5735) are allowed over `http://`. Public IP addresses and public hostnames require `https://` to satisfy App Transport Security. Local hostnames (`localhost`, `*.local`) are allowed over `http://`.

### Status indicators

When upload is enabled and a URL is configured, the **More > Remote Server** screen shows:

- **Server reachable** — result of a `GET /healthz` check. Runs once automatically per app session when upload is enabled; also runs immediately when the user taps **Save**.
- **Test Connection** — manual button that hits `GET /healthz` then `GET /v1/devices` (auth-gated) and reports inline: connected with device count, auth failure (401/403), or server unreachable.
- **Last sync** — timestamp of the most recent successful batch upload, plus the count of records acknowledged by the server. A **Now** button triggers an immediate manual upload.
- **Pending batches** — count of batches queued but not yet delivered.
- **Sync pendente** — count of `hr_samples` rows not yet marked synced. A **Backfill** button replays `sync.backfill_streams` over decoded frames and then uploads.
- **Import do servidor** — imports raw BLE frames from the server into local SQLite via `capture.import_frame_batch`, rebuilding the trust chain on a fresh install without a BLE reconnection. The iOS app pages through `GET /v1/export/frames/{deviceID}` (5,000 frames per page) and the **Import** button in **More > Remote Server** triggers `importHistoricalDataFromServer()`.

### Upload retry behaviour

Each upload batch is attempted up to **7 times** (1 initial attempt + 6 retries) with exponential backoff capped at 60 s: delays between attempts are 1 s, 2 s, 4 s, 8 s, 16 s, 32 s, 60 s. 4xx client errors abort the retry loop immediately and are not retried. After all attempts fail, `uploadErrorState` is set to a human-readable error string and the pending batch count is decremented. The decoded-streams upload endpoint is `POST /v1/ingest-decoded`. On a successful upload, raw BLE frames are also sent to `POST /v1/ingest-frames` (no additional retry loop — a single attempt).

---

## Server

The server stack is configured entirely through environment variables. All variables use the `GOOSE_` prefix. Configuration is loaded from a `.env` file that you create by copying `.env.example`.

### Setup

```bash
cd server/
cp .env.example .env
# Edit .env and fill in GOOSE_API_KEY and GOOSE_DB_PASSWORD
docker compose up -d
```

### Environment variables

#### `.env` file (host-side, read by Docker Compose)

| Variable | Required | Default | Description |
|---|---|---|---|
| `GOOSE_API_KEY` | **Required** | — | Shared secret used for Bearer authentication on every `/v1/*` endpoint. Must match the token entered in the iOS app. Generate with `openssl rand -hex 32`. |
| `GOOSE_DB_PASSWORD` | **Required** | — | PostgreSQL password for the `goose` database user. |
| `GOOSE_DB_NAME` | Optional | `goose` | PostgreSQL database name created on first init. |
| `GOOSE_DB_USER` | Optional | `goose` | PostgreSQL user name created on first init. |
| `GOOSE_INGEST_PORT` | Optional | `8770` | Host port the ingest API is published on. The container always listens on port `8000`; this maps it to the host. |
| `TZ` | Optional | `UTC` | Timezone for both containers. |

#### Variables injected into the `goose-ingest` container

These are constructed by Docker Compose from the `.env` values above. You do not set them directly.

| Variable | Value (from Compose) | Description |
|---|---|---|
| `GOOSE_DB_DSN` | `postgresql://<user>:<password>@goose-db:5432/<name>` | Full PostgreSQL DSN. Hard-coded to point at the `goose-db` container on the internal Docker network. |
| `GOOSE_RAW_ROOT` | `/data/raw` | Directory inside the container where raw BLE frame archives are stored. Backed by the `goose-raw-data` named volume. |

### Required vs optional

The ingest service (`server/ingest/app/config.py`) raises `RuntimeError` on startup if either of these is absent:

- `GOOSE_API_KEY` — startup fails with `"GOOSE_API_KEY is required"`
- `GOOSE_DB_DSN` — startup fails with `"GOOSE_DB_DSN is required"`

All other variables have defaults and will not prevent startup if omitted.

### Docker Compose services

Defined in `server/docker-compose.yml`:

| Service | Container | Image | Role |
|---|---|---|---|
| `goose-db` | `goose-db` | `timescale/timescaledb:2.17.2-pg16` | TimescaleDB (PostgreSQL 16) datastore |
| `goose-ingest` | `goose-ingest` | Built from `server/ingest/Dockerfile` | FastAPI ingest service; runs as non-root user (`appuser`) |

### Named volumes

| Volume | Mount point | Contents |
|---|---|---|
| `goose-db-data` | `/var/lib/postgresql/data` (goose-db) | PostgreSQL data directory |
| `goose-raw-data` | `/data/raw` (goose-ingest) | Raw BLE frame archives (ZIP files) |

### Database schema bootstrap

The schema is applied in two ways (both are idempotent):

1. `server/db/init.sql` is mounted into the `goose-db` container and runs once on first initialization of an empty data directory.
2. The ingest service calls `db.bootstrap_schema()` on every startup, so schema changes apply even after the data directory already exists.

### Health check

```
GET /healthz
```

Returns `{"status": "ok"}` when the ingest service can reach the database. Returns HTTP 503 if the database is unavailable. This endpoint requires no authentication and is used by the iOS app to verify connectivity.

### Per-environment overrides

The server has no built-in multi-environment mechanism. Use separate `.env` files or your deployment platform's secret manager to supply different values for development and production.

<!-- VERIFY: If you expose the ingest port through a reverse proxy (nginx, Caddy, Traefik), set GOOSE_INGEST_PORT to a non-public port and configure the proxy to terminate TLS before forwarding to the container. -->
