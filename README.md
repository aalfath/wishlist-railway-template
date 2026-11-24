[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/wishlist?utm_medium=integration&utm_source=button&utm_campaign=wishlist)

# Wishlist on Railway

One-click Railway template for [Wishlist](https://github.com/cmintey/wishlist) (MIT), a self-hosted wishlist you share with friends and family: they see what you want, claim gifts, and the claims stay hidden from you so the surprise holds.

**Deploys:** Wishlist **v0.69.0**, from the official image `ghcr.io/cmintey/wishlist:v0.69.0` pinned by digest in the [`Dockerfile`](Dockerfile).

## What you get

One service, `Wishlist`, built from this repo:

- The SvelteKit app and its bundled Caddy proxy on Railway's `PORT`, with a public Railway domain and a `/healthz` health check.
- SQLite database and uploaded images on one Railway volume at `/usr/src/app/data`, so data survives redeploys and restarts.
- On the first boot, before the public port opens, an **admin account is created** from generated variables and **public sign-up is switched off** (upstream would make the first visitor the admin). If that step fails, the service stops instead of starting with open sign-up.
- Fits Railway's Free plan: tested with 0.5 GB RAM / 1 vCPU (about 120 MB in use after adding items with images). Threads and the Node heap are sized from the container's limits.

## Variables

| Variable | Default | What it is |
|---|---|---|
| `WISHLIST_ADMIN_USERNAME` | `admin` | Username of the admin created on the first boot. |
| `WISHLIST_ADMIN_PASSWORD` | `${{secret(24)}}` | Generated admin password. Read it in the service's Variables tab. Used only on the first boot; change it later in the app. |
| `ORIGIN` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | The URL people open. Change it if you add a custom domain. |
| `DEFAULT_CURRENCY` | `USD` | ISO code of the default currency for item prices. |
| `PORT` | `3280` | Port Railway routes to. |

Nothing to fill in at deploy time.

## After deploying

1. Open the service's Variables tab and copy `WISHLIST_ADMIN_PASSWORD`.
2. Open the public URL and sign in as `admin` with that password.
3. In **Account**, set your real name, email and a new password.
4. Invite people from **Admin > Users** (an invite link is shown if SMTP isn't set up), or turn public sign-up back on in **Admin > Settings**.
5. Optional: SMTP (email invites and password resets) and OpenID Connect login are set in **Admin > Settings**.

## Updates

When a new Wishlist release comes out, this repo bumps the pinned version and digest in the `Dockerfile` and adds an entry to [`CHANGELOG.md`](CHANGELOG.md). Railway then shows deployers of this template an "update available" notice, and you choose when to apply it. Database migrations run on start. Read the changelog first: breaking changes are listed at the top of each entry.

## Files

- `Dockerfile`: official image pinned by version and digest, plus the wrapper below.
- `railway/start.sh`: sets `ORIGIN`, sizes threads and heap, runs migrations, creates the admin on the first boot, runs the app and Caddy, and exits non-zero if either stops so Railway restarts the service.
- `railway/bootstrap.ts`: the first-boot admin step.
- `railway/Caddyfile`: upstream's Caddy config on `$PORT`, plus `/healthz` and Railway's proxy ranges as trusted proxies.
