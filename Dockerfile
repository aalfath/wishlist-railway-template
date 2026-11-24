# Wishlist (https://github.com/cmintey/wishlist) for Railway.
# Official upstream image, pinned by version and digest. Bump both together.
FROM ghcr.io/cmintey/wishlist:v0.69.0@sha256:a3c0482c5d55155a3aa96c4cbb63d2aa379f02ae3bbeb76909ffed2b15980f36

# Small Railway wrapper: start script, Caddy config on $PORT with /healthz,
# and a first-boot script that creates the admin before the port opens.
COPY railway/Caddyfile /usr/src/app/railway/Caddyfile
COPY railway/start.sh /usr/src/app/railway/start.sh
COPY railway/bootstrap.ts /usr/src/app/prisma/railway-bootstrap.ts

ENV PORT=3280 \
    MALLOC_ARENA_MAX=2

ENTRYPOINT ["sh", "/usr/src/app/railway/start.sh"]
