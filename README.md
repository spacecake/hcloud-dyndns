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
```
docker compose run --rm -e MODE=once hcloud-dyndns
```
(Optionally add -e SCRIPT_FLAGS=--quiet.)


## Notes:

Hosts are space-separated.

Use FQDNs (recommended).

If you put only the zone on a line, the script updates the zone apex.

`config/hcloud-dyndns.conf`

## Key settings:

Default updates A only

IPV6=1 updates AAAA only

BOTH=1 updates A + AAAA

# Environment switches

Set these in `docker-compose.yml` under `environment:` (or via `docker compose run -e ...`).

* `AUTO_CREATE=0|1`
If 1, missing RRsets will be created automatically (uses add_records).

* `TTL=3600`
Enforces RRset TTL (default: 3600). Script will change TTL if different.

# Update interval

Set in `docker-compose.yml`:

* `INTERVAL=300` (default) = every 5 minutes

# Logging

Default behavior: logs only when something changes ([SET] / [UPD] / [TTL]) or on errors ([ERR]).

Enable verbose logs ([OK] too) by adding to docker-compose.yml:

```
- SCRIPT_FLAGS=--verbose
```

# Errors-only:
```
- SCRIPT_FLAGS=--quiet
```

One-shot run (no extra service)
```
docker compose run --rm -e MODE=once hcloud-dyndns
```

Example (verbose + auto-create + TTL):
```
docker compose run --rm -e MODE=once -e SCRIPT_FLAGS=--verbose -e AUTO_CREATE=1 -e TTL=3600 hcloud-dyndns
```

# Update / upgrade
```
git pull
docker compose up -d --build
```
