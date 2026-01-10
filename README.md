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
