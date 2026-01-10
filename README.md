# Hetzner Cloud DNS Dynamic Update (multi-zone)

Small shell-based updater for Hetzner DNS (Cloud API), supports multiple zones and multiple hosts per zone.

## Files

- `config/hcloud-zones.txt` (required): one line per zone, space-separated.
- `config/hcloud-dyndns.conf` (required): script settings.
- `.env` (required): contains `API_TOKEN` (not committed).

## zones file format

`config/hcloud-zones.txt`:

```txt
# zone host host host...
example.com example.com www.example.com


cp .env.example .env
docker compose up -d --build



If you need a one-shot run, do it without an extra service:

docker compose run --rm -e MODE=once hcloud-dyndns
(Optionally add -e SCRIPT_FLAGS=--quiet.)
