#!/bin/bash
# Enroll a deployed CI mac into https://headscale.julialang.org.
# Run from YOUR machine (host side) — per-machine preauth keys must not be
# baked into the deployment image.
#
# usage: ./enroll-tailscale.sh <machine-ip> <tailnet-hostname> [-- extra
#        tailscale-up flags]
#        The preauth key is read from $TS_AUTHKEY or prompted for.
#
# Get a preauth key from whoever admins headscale.julialang.org
# (on the server: `headscale preauthkeys create --user <user> --expiration 1h`).
#
# Self-healing: if the machine predates 04-install-tailscale.sh in the image,
# tailscale is installed first.
set -euo pipefail

[ $# -ge 2 ] || { sed -n '2,12p' "$0"; exit 1; }
IP="$1"; NAME="$2"; shift 2
[ "${1:-}" = "--" ] && shift
EXTRA_FLAGS=("$@")

LOGIN_SERVER=https://headscale.julialang.org

if [ -z "${TS_AUTHKEY:-}" ]; then
    printf "Preauth key for %s: " "$NAME"
    read -rs TS_AUTHKEY
    echo
fi

# Self-heal: install the formula if missing (machines imaged before
# 04-install-tailscale.sh existed) and register the system daemon if missing
# (machines hit by the 04 $HOME-under-root bug). tailscaled is linked next to
# brew — do not use `brew --prefix` under sudo, root has no $HOME for brew.
ssh "julia@$IP" '
    set -e
    BREW=$([ "$(uname -m)" = arm64 ] && echo /opt/homebrew/bin/brew || echo /usr/local/bin/brew)
    "$BREW" list tailscale >/dev/null 2>&1 || "$BREW" install tailscale
    if [ ! -f /Library/LaunchDaemons/com.tailscale.tailscaled.plist ]; then
        sudo "$(dirname "$BREW")/tailscaled" install-system-daemon
    fi
'

# Ship the key via stdin into a root-only file and use --auth-key file: so the
# key never appears in argv/ps on either end; the file is removed after.
printf '%s' "$TS_AUTHKEY" | ssh "julia@$IP" '
    set -e
    BREW=$([ "$(uname -m)" = arm64 ] && echo /opt/homebrew/bin/brew || echo /usr/local/bin/brew)
    PREFIX="$(dirname "$(dirname "$BREW")")"
    sudo sh -c "umask 077; cat > /private/var/root/ts.authkey"
    sudo "$PREFIX/bin/tailscale" up \
        --login-server '"$LOGIN_SERVER"' \
        --auth-key file:/private/var/root/ts.authkey \
        --hostname '"$NAME"' '"${EXTRA_FLAGS[*]:-}"'
    sudo rm -f /private/var/root/ts.authkey
    sudo "$PREFIX/bin/tailscale" status | head -5
'
echo "Enrolled $IP as $NAME on $LOGIN_SERVER"
