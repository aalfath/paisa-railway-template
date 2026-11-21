#!/bin/sh
# Start script for Paisa on Railway.
# - keeps paisa.yaml, the journal, sheets and the database on the volume
# - makes sure the UI has a login (PAISA_USERNAME / PAISA_PASSWORD) before it listens,
#   and puts it back if paisa.yaml loses it while running (Paisa's "load demo" button
#   rewrites paisa.yaml without user accounts)
# - listens on $PORT and caps Go to the service's CPUs and memory
# An unexpected stop exits non-zero, so Railway's ON_FAILURE restart policy applies.
set -eu

DATA_DIR="${PAISA_DATA_DIR:-/root/Documents/paisa}"
export PAISA_CONFIG="${PAISA_CONFIG:-$DATA_DIR/paisa.yaml}"
PORT="${PORT:-7500}"
USER_NAME="${PAISA_USERNAME:-admin}"
PASSWORD="${PAISA_PASSWORD:-}"
CHECK_EVERY="${PAISA_LOGIN_CHECK_SECONDS:-2}"

# Go doesn't read the container's CPU limit; Railway hosts report many CPUs.
export GOMAXPROCS="${GOMAXPROCS:-2}"
export GOMEMLIMIT="${GOMEMLIMIT:-384MiB}"

log() { echo "railway-start: $*"; }
die() { echo "railway-start: $*" >&2; exit 1; }

CONFIG_DIR="$(dirname "$PAISA_CONFIG")"
mkdir -p "$DATA_DIR" "$CONFIG_DIR"

# First start on an empty volume: the same minimal config Paisa writes itself.
if [ ! -s "$PAISA_CONFIG" ]; then
  log "creating $PAISA_CONFIG"
  printf "journal_path: main.ledger\ndb_path: paisa.db\n" > "$PAISA_CONFIG"
  [ -e "$CONFIG_DIR/main.ledger" ] || : > "$CONFIG_DIR/main.ledger"
fi

case "$USER_NAME" in
  ""|*[!A-Za-z0-9._-]*) die "PAISA_USERNAME may only use letters, digits, '.', '_' and '-'" ;;
esac

HASH=""
if [ -n "$PASSWORD" ]; then
  # Paisa stores sha256:<hex sha256 of the hex sha256 of the password>
  # (the browser hashes the password once, the config form once more).
  H1="$(printf '%s' "$PASSWORD" | sha256sum | cut -d' ' -f1)"
  HASH="sha256:$(printf '%s' "$H1" | sha256sum | cut -d' ' -f1)"
fi

accounts() { yq '(.user_accounts // []) | length' "$PAISA_CONFIG" 2>/dev/null || echo error; }

set_login() {
  PU="$USER_NAME" PH="$HASH" yq -i '.user_accounts = (((.user_accounts // []) | map(select(.username != strenv(PU)))) + [{"username": strenv(PU), "password": strenv(PH)}])' "$PAISA_CONFIG"
}

if [ -n "$HASH" ]; then
  set_login || die "could not write the login account to $PAISA_CONFIG"
  log "login account '$USER_NAME' set from PAISA_PASSWORD"
elif [ "$(accounts)" = "0" ]; then
  die "PAISA_PASSWORD is empty and paisa.yaml has no user account; refusing to serve your finances without a login"
else
  log "PAISA_PASSWORD is empty; keeping the user account(s) already in paisa.yaml"
fi

PID=""
STOPPING=0
on_term() {
  STOPPING=1
  [ -n "$PID" ] && kill -TERM "$PID" 2>/dev/null || true
}
trap on_term TERM INT

start_paisa() {
  log "starting Paisa on port $PORT"
  paisa serve --port "$PORT" &
  PID=$!
}

start_paisa
while :; do
  sleep "$CHECK_EVERY" &
  wait $! 2>/dev/null || true
  if [ "$STOPPING" = 1 ]; then
    wait "$PID" 2>/dev/null || true
    exit 0
  fi
  if ! kill -0 "$PID" 2>/dev/null; then
    CODE=0; wait "$PID" || CODE=$?
    [ "$CODE" = 0 ] && CODE=1
    die "Paisa stopped unexpectedly (exit $CODE)"
  fi
  if [ "$(accounts)" = "0" ]; then
    if [ -n "$HASH" ]; then
      set_login || die "could not restore the login account"
      # Paisa's in-memory config has no account either, so its config endpoint is open:
      # hand it the restored config, which applies it at once without a restart.
      if yq -o=json "$PAISA_CONFIG" > /tmp/paisa-config.json \
         && wget -q -O /dev/null -T 30 --header "Content-Type: application/json" \
              --post-file /tmp/paisa-config.json "http://127.0.0.1:$PORT/api/config"; then
        log "paisa.yaml lost its user accounts (demo data or a config edit); restored '$USER_NAME'"
      else
        log "paisa.yaml lost its user accounts; restored '$USER_NAME' and restarting Paisa to apply it"
        kill -TERM "$PID" 2>/dev/null || true
        wait "$PID" 2>/dev/null || true
        start_paisa
      fi
      rm -f /tmp/paisa-config.json
    else
      kill -TERM "$PID" 2>/dev/null || true
      die "paisa.yaml has no user account and PAISA_PASSWORD is empty; stopping so the UI isn't open without a login"
    fi
  fi
done
