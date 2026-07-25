#!/bin/bash
# Create .bash_profile for juliaup to modify
sudo -i -u julia touch /Users/julia/.bash_profile

# Install juliaup. The whole pipeline must run as julia — in the old
#   `sudo -i -u julia curl ... | sh`
# form only curl ran as julia; the installer itself ran as root and put
# juliaup in root's home.
sudo -i -u julia /bin/bash -c \
    "curl -fsSL https://install.julialang.org | sh -s -- -y"

# CI also wants the LTS channel available (PR #57 discussion, maleadt's
# note 3). 'release' stays the default.
sudo -i -u julia /Users/julia/.juliaup/bin/juliaup add lts || true
