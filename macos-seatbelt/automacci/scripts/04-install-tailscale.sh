#!/bin/bash
# Install Tailscale (open-source CLI variant — the GUI app is per-user and
# wrong for headless CI) and its system daemon. Enrollment against
# https://headscale.julialang.org needs a per-machine preauth key and is NOT
# done here — see enroll-tailscale.sh, run from the host side over SSH.
if [ "$(uname -m)" = "arm64" ]; then
    BREW=/opt/homebrew/bin/brew
else
    BREW=/usr/local/bin/brew
fi

sudo -i -u julia "$BREW" install tailscale

# Registers and starts the tailscaled launchd system daemon; idempotent.
PREFIX="$("$BREW" --prefix)"
"$PREFIX/bin/tailscaled" install-system-daemon
