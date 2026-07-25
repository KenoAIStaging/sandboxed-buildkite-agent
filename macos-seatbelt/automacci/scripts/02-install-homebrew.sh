#!/bin/bash
# Allow passwordless sudo for julia (idempotent; the Intel Homebrew installer
# sudos to create /usr/local directories)
grep -q '^julia ALL' /etc/sudoers || \
    bash -c "echo julia ALL = NOPASSWD: ALL >> /etc/sudoers"

# Create .bash_profile for juliaup to modify
sudo -i -u julia touch /Users/julia/.bash_profile

# Setup homebrew. NONINTERACTIVE must be set *inside* the sudo — `sudo -i`
# scrubs the environment, so a leading NONINTERACTIVE=1 never reaches the
# installer.
sudo -i -u julia NONINTERACTIVE=1 /bin/bash -c \
    "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | /bin/bash"

# Add homebrew to profile. Prefix differs by architecture: /opt/homebrew on
# Apple Silicon, /usr/local on Intel.
if [ "$(uname -m)" = "arm64" ]; then
    BREW=/opt/homebrew/bin/brew
else
    BREW=/usr/local/bin/brew
fi
grep -q 'brew shellenv' /Users/julia/.bash_profile || \
    (echo; echo "eval \"\$(${BREW} shellenv)\"") >> /Users/julia/.bash_profile
