#!/usr/bin/env bash
# Recreate the Konstellation-Network org directory on a fresh machine.
#
#   git clone git@github.com:Konstellation-Network/.github.git /path/to/Konstellation-Network/.github
#   /path/to/Konstellation-Network/.github/bootstrap.sh
#
# Result: org root with ENGINEERING.md / STATUS.md / CLAUDE.md / README.md / wt
# symlinked from this repo, and every org repo cloned alongside.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORG="$(dirname "$HERE")"
GH_ORG=Konstellation-Network

for f in ENGINEERING.md STATUS.md CLAUDE.md wt; do ln -sfn ".github/$f" "$ORG/$f"; done
ln -sfn .github/ORG-README.md "$ORG/README.md"

for r in konstellation networks contracts infra explorer docs whitepaper chain-config faucet; do
  [ -d "$ORG/$r/.git" ] || git -C "$ORG" clone "git@github.com:$GH_ORG/$r.git"
done
echo "org ready at $ORG"; "$ORG/wt" status
