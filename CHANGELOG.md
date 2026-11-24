# Changelog

## v0.69.0 (2026-11-24)

First release of this template.

- Wishlist v0.69.0, official image `ghcr.io/cmintey/wishlist:v0.69.0@sha256:a3c0482c5d55155a3aa96c4cbb63d2aa379f02ae3bbeb76909ffed2b15980f36`.
- SQLite database and uploads on one Railway volume at `/usr/src/app/data`.
- Admin account created on the first boot from generated variables; public sign-up off by default.
- `/healthz` health check; exits non-zero if the app or Caddy stops.
- Deploy on Railway button in the README.
