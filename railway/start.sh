#!/bin/sh
# Railway start script for Wishlist. Runs migrations, creates the admin on the
# first boot (before the public port opens), then runs the app and Caddy and
# exits non-zero if either of them stops, so Railway restarts the service.
set -eu
cd /usr/src/app

log() { echo "[railway] $*"; }

# --- Persistent data: one Railway volume at /usr/src/app/data ---------------
DATA_DIR=/usr/src/app/data
mkdir -p "$DATA_DIR/uploads"
export DATABASE_URL="file:$DATA_DIR/prod.db"
# The app writes images to ./uploads: point it at the volume.
if [ -L uploads ]; then
  :
elif mountpoint -q uploads 2>/dev/null || grep -q " /usr/src/app/uploads " /proc/mounts; then
  log "warning: /usr/src/app/uploads is a separate mount; images are stored there, not on the data volume"
else
  if [ -d uploads ] && [ -n "$(ls -A uploads 2>/dev/null)" ]; then cp -a uploads/. "$DATA_DIR/uploads/"; fi
  rm -r uploads 2>/dev/null || true
  ln -s "$DATA_DIR/uploads" uploads
fi

# --- Public URL -------------------------------------------------------------
# ORIGIN must be the URL people open. Ignore an empty or half-resolved value
# ("https://") and fall back to Railway's generated domain.
case "${ORIGIN:-}" in
  http://?*|https://?*) ;;
  *)
    if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
      ORIGIN="https://${RAILWAY_PUBLIC_DOMAIN}"
    else
      ORIGIN="http://localhost:${PORT:-3280}"
    fi
    ;;
esac
export ORIGIN="${ORIGIN%/}"
export PROTOCOL_HEADER=x-forwarded-proto
export HOST_HEADER=x-forwarded-host
log "public URL: $ORIGIN"

export DEFAULT_CURRENCY="${DEFAULT_CURRENCY:-USD}"
export PUBLIC_DEFAULT_CURRENCY="$DEFAULT_CURRENCY"
export TOKEN_TIME="${TOKEN_TIME:-72}"
export BODY_SIZE_LIMIT="${MAX_IMAGE_SIZE:-5000000}"
export PRISMA_HIDE_UPDATE_MESSAGE=1

# --- Size threads and heap from the container's limits ----------------------
# Railway shows the host's CPUs (32+) inside a 1 vCPU service.
CPUS=1
if [ -r /sys/fs/cgroup/cpu.max ]; then
  read -r quota period < /sys/fs/cgroup/cpu.max || true
  if [ "${quota:-max}" != "max" ] && [ -n "${period:-}" ]; then
    CPUS=$(( (quota + period - 1) / period ))
  else
    CPUS=$(nproc 2>/dev/null || echo 2)
  fi
fi
[ "$CPUS" -lt 1 ] && CPUS=1
[ "$CPUS" -gt 4 ] && CPUS=4
MEM_MB=1024
if [ -r /sys/fs/cgroup/memory.max ]; then
  m=$(cat /sys/fs/cgroup/memory.max)
  [ "$m" != "max" ] && MEM_MB=$(( m / 1048576 ))
fi
HEAP_MB=$(( MEM_MB * 45 / 100 ))
[ "$HEAP_MB" -gt 1024 ] && HEAP_MB=1024
[ "$HEAP_MB" -lt 96 ] && HEAP_MB=96
export GOMAXPROCS="${GOMAXPROCS:-$CPUS}"
export VIPS_CONCURRENCY="${VIPS_CONCURRENCY:-1}"
export UV_THREADPOOL_SIZE="${UV_THREADPOOL_SIZE:-$(( CPUS < 2 ? 2 : CPUS ))}"
export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=$HEAP_MB}"
log "limits: ${CPUS} CPU, ${MEM_MB} MB, Node heap ${HEAP_MB} MB"

# --- Database migrations and seed (same steps as upstream's entrypoint) ------
log "running migrations"
pnpm prisma migrate deploy
pnpm prisma db seed
pnpm db:patch

# --- First boot: create the admin before the public port opens --------------
# Exits non-zero if it can't, so sign-up never stays open to the first visitor.
log "checking admin account"
pnpm exec tsx prisma/railway-bootstrap.ts

# --- Run the app (loopback only) and Caddy (public, $PORT) -------------------
PORT=3000 HOST=127.0.0.1 node build &
APP=$!
caddy run --config /usr/src/app/railway/Caddyfile --adapter caddyfile &
PROXY=$!

stop() { kill -TERM "$APP" "$PROXY" 2>/dev/null || true; wait 2>/dev/null || true; exit 0; }
trap stop TERM INT

# BusyBox/dash have no reliable `wait -n`: poll both children.
while kill -0 "$APP" 2>/dev/null && kill -0 "$PROXY" 2>/dev/null; do
  sleep 2
done
log "a process stopped unexpectedly; exiting so Railway restarts the service"
kill -TERM "$APP" "$PROXY" 2>/dev/null || true
exit 1
