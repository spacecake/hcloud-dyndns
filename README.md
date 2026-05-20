# Hetzner Cloud DNS Dynamic Update (multi-zone)

Small Dockerized shell updater for Hetzner DNS (Cloud API).
Supports **multiple zones** and **multiple hosts** per zone.

## Requirements

- Docker + Docker Compose
- Hetzner Cloud API token with DNS access
- Zones already exist in Hetzner DNS

## Quick start

```bash
git clone https://github.com/spacecake/hcloud-dyndns.git
cd hcloud-dyndns

cp .env.example .env
# edit .env and set API_TOKEN=...

cp config/hcloud-zones.example.txt config/hcloud-zones.txt
# edit config/hcloud-zones.txt with your zones/hosts (local only)

docker compose up -d --build
docker compose logs -f
```

If you need a one-shot run, do it without an extra service:

```bash
docker compose run --rm -e MODE=once hcloud-dyndns
```

Optionally add `-e SCRIPT_FLAGS=--quiet`.

## Notes

Hosts are space-separated.

Use FQDNs (recommended).

If you put only the zone on a line, the script updates the zone apex.

Settings live in `config/hcloud-dyndns.conf`.

## Key settings

Default updates A only.

`IPV6=1` updates AAAA only.

`BOTH=1` updates A + AAAA.

## Environment switches

Set these in `docker-compose.yml` under `environment:` or via `docker compose run -e ...`.

- `AUTO_CREATE=0|1`: if `1`, missing RRsets are created automatically using `add_records`.
- `TTL=3600`: enforces RRset TTL. Default is `3600`; the script changes TTL if different.

## Update interval

Set in `docker-compose.yml`:

```yaml
- INTERVAL=300
```

`300` seconds is the default, which is every 5 minutes.

## Logging

Default behavior logs only when something changes (`[SET]`, `[UPD]`, `[TTL]`) or on errors (`[ERR]`).

Enable verbose logs (`[OK]` too) by adding to `docker-compose.yml`:

```yaml
- SCRIPT_FLAGS=--verbose
```

Errors-only mode:

```yaml
- SCRIPT_FLAGS=--quiet
```

One-shot run:

```bash
docker compose run --rm -e MODE=once hcloud-dyndns
```

Example verbose run with auto-create and TTL:

```bash
docker compose run --rm -e MODE=once -e SCRIPT_FLAGS=--verbose -e AUTO_CREATE=1 -e TTL=3600 hcloud-dyndns
```


## Published image

GitHub Actions publishes Docker images to GitHub Container Registry:

```text
ghcr.io/spacecake/hcloud-dyndns
```

Pushes to `main` publish the `main` tag plus a short SHA tag. Version tags such as `v1.2.3` also publish matching semantic version tags.
The same version tags create GitHub Releases with generated release notes.

Pull the latest image from `main`:

```bash
docker pull ghcr.io/spacecake/hcloud-dyndns:main
```

## Docker networking note

This deployment uses host networking for both runtime and image builds:

```yaml
build:
  context: .
  network: host
network_mode: host
```

This avoids a host-specific Docker bridge networking failure where containers could resolve DNS names but outbound TCP/HTTPS connections timed out. Symptoms looked like this:

```text
curl: (6) Could not resolve host: api.ipify.org
curl: (28) Failed to connect to api.ipify.org port 443
[ERR] Zone not found: example.com
```

The `Zone not found` messages can be a follow-on error from failed or unauthorized Hetzner API calls. Verify network access from inside the container first, then verify that `API_TOKEN` is present and has access to the configured zones.

With `SCRIPT_FLAGS=--quiet`, logs can be empty when records already match the current public IP. Remove that flag or use `--verbose` for diagnostics.

## Update / upgrade

```bash
git pull
docker compose up -d --build
```
