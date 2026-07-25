#!/bin/bash
# Julia CI first-boot setup. Delivered by firstboot.pkg and run as root by the
# org.julialang.ci.firstboot LaunchDaemon on the first boot after deployment.
# Logs to /var/log/juliaci-firstboot.log (tail it to watch progress).
BASE=/private/var/juliaci
exec >>/var/log/juliaci-firstboot.log 2>&1
set -x

finish() {
    rm -f /Library/LaunchDaemons/org.julialang.ci.firstboot.plist
}
if [ -e "$BASE/.done" ]; then
    finish
    exit 0
fi

# config provides SERVER_URL and (optionally) XCODE_ASSET
. "$BASE/config"

# Wait for the network (up to 10 minutes). Try the deploy server first, fall
# back to apple.com in case the server is only needed for Xcode.
for _ in $(seq 1 60); do
    curl -fsI --max-time 5 "$SERVER_URL/" >/dev/null 2>&1 && break
    curl -fsI --max-time 5 https://www.apple.com/ >/dev/null 2>&1 && break
    sleep 10
done

# Passwordless sudo for julia (needed by the setup scripts and by Homebrew on
# Intel, where the installer sudos to create /usr/local directories).
grep -q '^julia ALL' /etc/sudoers || echo 'julia ALL = NOPASSWD: ALL' >>/etc/sudoers

# Create the julia user. NOTE (Apple Silicon): a user created here, before any
# Setup Assistant user exists, may not hold a secure token / volume ownership.
# CI doesn't need one; OS *upgrades* on such machines are easiest done by
# redeploying this image.
if ! id julia >/dev/null 2>&1; then
    sysadminctl -addUser julia -fullName "Julia CI" -admin \
        -password "$(cat "$BASE/password")"
    createhomedir -c -u julia
fi
rm -f "$BASE/password"

# SSH on, never sleep, restart after power failure.
systemsetup -setremotelogin on || launchctl load -w /System/Library/LaunchDaemons/ssh.plist
pmset -a sleep 0 displaysleep 0 disksleep 0 autorestart 1 womp 1

# Fetch and unpack Xcode if the image was built with one.
if [ -n "${XCODE_ASSET:-}" ] && [ ! -d /Applications/Xcode.app ]; then
    cd /Applications
    case "$XCODE_ASSET" in
        *.xip)
            curl -fO "$SERVER_URL/$XCODE_ASSET"
            xip --expand "$XCODE_ASSET"   # slow: ~30+ minutes
            rm -f "$XCODE_ASSET"
            # xip may expand to a versioned name; normalize
            [ -d Xcode.app ] || mv Xcode*.app Xcode.app
            ;;
        *.tar)          curl -f "$SERVER_URL/$XCODE_ASSET" | tar -x ;;
        *.tar.gz|*.tgz) curl -f "$SERVER_URL/$XCODE_ASSET" | tar -xz ;;
    esac
    cd /
fi

# Run the setup scripts in order (00-select-xcode, 01-clone, 02-homebrew,
# 03-juliaup). Keep going on failure — a partially set up machine that answers
# SSH beats one that never comes up; failures are visible in the log.
FAILED=""
for s in "$BASE"/scripts/*.sh; do
    bash "$s" || FAILED="$FAILED $s"
done
[ -n "$FAILED" ] && echo "JULIACI SETUP FAILURES:$FAILED"

touch "$BASE/.done"
finish
echo "JULIACI SETUP COMPLETE"
