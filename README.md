# Hetzner Cloud DNS Dynamic Update (multi-zone)

Small Dockerized shell updater for Hetzner DNS (Cloud API).
Supports **multiple zones** and **multiple hosts** per zone.

## Requirements

- Docker, or Docker + Docker Compose
- Hetzner Cloud API token with DNS access
- Zones already exist in Hetzner DNS

## Published image

GitHub Actions publishes Docker images to GitHub Container Registry:

```text
ghcr.io/spacecake/hcloud-dyndns
```

Recommended stable install target:

```text
ghcr.io/spacecake/hcloud-dyndns:main
```

Pushes to `main` publish the `main` tag plus a short SHA tag. Version tags such as `v1.2.3` also publish matching semantic version tags.
The same version tags create GitHub Releases with generated release notes.

## Install with Docker

Create a local config directory:

```bash
mkdir -p config
```

Create `.env` with your Hetzner Cloud API token:

```bash
cat > .env <<EOF
API_TOKEN=your_hetzner_cloud_api_token
EOF
```

Create `config/hcloud-dyndns.conf`:

```bash
cat > config/hcloud-dyndns.conf <<EOF
API_BASE="https://api.hetzner.cloud/v1"
ZONES_FILE="/config/hcloud-zones.txt"
COMMENT="dyndns"
IPV6=0
BOTH=0
IPV4_URL="https://api.ipify.org"
IPV6_URL="https://api64.ipify.org"
EOF
```

Create `config/hcloud-zones.txt`:

```bash
cat > config/hcloud-zones.txt <<EOF
example.com example.com www.example.com api.example.com
example.net www.example.net
EOF
```

Run the updater loop:

```bash
docker run -d \
  --name hcloud-dyndns \
  --restart unless-stopped \
  --network host \
  --env-file .env \
  -e CONFIG=/config/hcloud-dyndns.conf \
  -e INTERVAL=300 \
  -e MODE=loop \
  -e AUTO_CREATE=1 \
  -e SCRIPT_FLAGS=--quiet \
  -v "$PWD/config:/config:ro" \
  ghcr.io/spacecake/hcloud-dyndns:main
```

Check logs:

```bash
docker logs -f hcloud-dyndns
```

Run one update pass instead of a loop:

```bash
docker run --rm \
  --network host \
  --env-file .env \
  -e CONFIG=/config/hcloud-dyndns.conf \
  -e MODE=once \
  -e AUTO_CREATE=1 \
  -v "$PWD/config:/config:ro" \
  ghcr.io/spacecake/hcloud-dyndns:main
```

## Install with Docker Compose

Example `docker-compose.yml`:

```yaml
services:
  hcloud-dyndns:
    image: ghcr.io/spacecake/hcloud-dyndns:main
    container_name: hcloud-dyndns
    restart: unless-stopped
    network_mode: host
    env_file:
      - .env
    environment:
      - CONFIG=/config/hcloud-dyndns.conf
      - INTERVAL=300
      - MODE=loop
      - AUTO_CREATE=1
      # optional:
      # - TTL=3600
      # - SCRIPT_FLAGS=--verbose
      - SCRIPT_FLAGS=--quiet
    volumes:
      - ./config:/config:ro
```

Start it:

```bash
docker compose up -d
```

Check logs:

```bash
docker compose logs -f
```

Run one update pass:

```bash
docker compose run --rm -e MODE=once hcloud-dyndns
```

Example verbose run with auto-create and TTL:

```bash
docker compose run --rm -e MODE=once -e SCRIPT_FLAGS=--verbose -e AUTO_CREATE=1 -e TTL=3600 hcloud-dyndns
```

## Zone file format

Hosts are space-separated. Use FQDNs where possible. If you put only the zone on a line, the script updates the zone apex.

```txt
# zone host host host...
example.com example.com www.example.com api.example.com
example.net www.example.net
```

## Key settings

Settings live in `config/hcloud-dyndns.conf`.

Default updates A only.

`IPV6=1` updates AAAA only.

`BOTH=1` updates A + AAAA.

## Environment switches

Set these in `docker-compose.yml` under `environment:` or via `docker run -e ...` / `docker compose run -e ...`.

- `AUTO_CREATE=0|1`: if `1`, missing RRsets are created automatically using `add_records`.
- `TTL=3600`: enforces RRset TTL. Default is `3600`; the script changes TTL if different.
- `INTERVAL=300`: loop interval in seconds. `300` is every 5 minutes.

## Logging

Default behavior logs only when something changes (`[SET]`, `[UPD]`, `[TTL]`) or on errors (`[ERR]`).

Enable verbose logs (`[OK]` too):

```yaml
- SCRIPT_FLAGS=--verbose
```

Errors-only mode:

```yaml
- SCRIPT_FLAGS=--quiet
```

With `SCRIPT_FLAGS=--quiet`, logs can be empty when records already match the current public IP. Remove that flag or use `--verbose` for diagnostics.

## Docker networking note

This deployment uses host networking for runtime:

```yaml
network_mode: host
```

This avoids a host-specific Docker bridge networking failure where containers could resolve DNS names but outbound TCP/HTTPS connections timed out. Symptoms looked like this:

```text
curl: (6) Could not resolve host: api.ipify.org
curl: (28) Failed to connect to api.ipify.org port 443
[ERR] Zone not found: example.com
```

The `Zone not found` messages can be a follow-on error from failed or unauthorized Hetzner API calls. Verify network access from inside the container first, then verify that `API_TOKEN` is present and has access to the configured zones.

## Update / upgrade

Docker:

```bash
docker pull ghcr.io/spacecake/hcloud-dyndns:main
docker rm -f hcloud-dyndns
# rerun the docker run command from the install section
```

Docker Compose:

```bash
docker compose pull
docker compose up -d
```
