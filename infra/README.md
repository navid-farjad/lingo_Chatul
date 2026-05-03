# infra/

Hetzner deploy configuration. Will hold:
- `kamal.yml` — Kamal deploy config (target server, image registry, env vars)
- `nginx.conf` — reverse proxy / TLS config
- `systemd/` — service unit files if needed

**Server:** 49.12.247.57 (Hetzner Cloud)
**Domain:** lingochatul.com (Cloudflare DNS)
**Deploy SSH key:** `~/.ssh/lingo_chatul`

To be filled in once api/ and web/ are scaffolded and we're ready to ship a first deploy.
