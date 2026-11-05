# Hetzner Cloud DNS Dynamic Update (multi-zone)

Small Dockerized shell updater for Hetzner DNS (Cloud API).
Supports **multiple zones** and **multiple hosts** per zone.

## Features

- Keeps A (and optionally AAAA) records pointed at your current public IP; writes only when a record differs.
- Multi-zone, multi-host, zone apex supported (sent to the API as the literal `@`).
- `AUTO_CREATE=1` creates missing RRsets.
- `TTL` enforcement: when set, the TTL of every managed record is brought to that value, including records whose IP is already correct.
- Resilient API and IP-lookup calls: connect timeout 10 s, total timeout 30 s, up to 3 retries (5 s apart) on transient errors such as DNS or TLS failures. A run that still fails aborts safely and the loop tries again at the next interval.
- Runs as a non-root user on Alpine; the config is mounted read-only.

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
      # - TTL=300
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
docker compose run --rm -e MODE=once -e SCRIPT_FLAGS=--verbose -e AUTO_CREATE=1 -e TTL=300 hcloud-dyndns
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
- `TTL=300`: enforces the RRset TTL. There is no default: if `TTL` is unset, TTLs are left untouched. When set, the script changes the TTL of any managed record that differs, whether or not the IP changed, and applies it to newly created records.
- `INTERVAL=300`: loop interval in seconds. `300` is every 5 minutes.

### Choosing a TTL

After your public IP changes, clients may keep the old address for up to one loop interval plus the TTL. Hetzner's default TTL is 3600 s, so a stale address can live for over an hour. A TTL equal to the loop interval (`300`) keeps that to roughly 10 minutes at worst, at the cost of slightly more DNS queries. Going lower than the interval gains little; going higher mostly lengthens outages after an IP change.

The first run with `TTL` newly set makes one `change_ttl` call per record that differs; later runs make none unless a TTL drifts. With `SCRIPT_FLAGS=--quiet` these changes are not logged, so run one pass with `--verbose` to watch them.

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

### Intermittent `Resolving timed out` errors

An occasional `curl: (28) Resolving timed out` is normally a transient network or resolver problem, and the built-in retries absorb most of them. If they recur, check the resolvers your host actually uses:

```bash
resolvectl status                       # systemd-resolved hosts: list the upstream servers
dig +time=2 +tries=1 @<upstream-ip> api.hetzner.cloud
```

With `network_mode: host` the container shares the host's `/etc/resolv.conf`, which often points at the `127.0.0.53` stub of `systemd-resolved`. If one of its upstream servers does not answer public names, lookups stall until the resolver switches servers. The compose `dns:` option is rejected with host networking; instead, fix the host's resolver configuration, or bind-mount your own `resolv.conf` into the container with a compose override file (keep it out of version control, since it holds your network addresses):

```yaml
# docker-compose.override.yml
services:
  hcloud-dyndns:
    volumes:
      - ./resolv.conf:/etc/resolv.conf:ro
```

```text
# resolv.conf
nameserver <reliable-resolver-ip>
nameserver <second-resolver-ip>
options timeout:2 attempts:2
```

"Connection timed out" errors that arrive in short bursts are outages of the network path itself and cannot be fixed by changing resolvers.

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

## Changelog

- **v0.2.2** – `TTL` is now enforced on records whose IP is already correct (previously only when the IP changed or the record was created); README: features, TTL guidance, resolver troubleshooting.
- **v0.2.1** – Timeouts and retries on all curl calls (`--connect-timeout 10 --max-time 30 --retry 3 --retry-all-errors`).
- **v0.2.0** – Fix 404 on `set_records` for the zone apex: the `@` record name is no longer percent-encoded in action paths.
- **v0.1.0** – Initial release.
