#!/usr/bin/env bash
# Recreate the Konstellation-Network org directory on a fresh machine.
#
#   git clone git@github.com:Konstellation-Network/handbook.git /path/to/Konstellation-Network/handbook
#   /path/to/Konstellation-Network/handbook/bootstrap.sh
#
# Result: org root with ENGINEERING.md / STATUS.md / CLAUDE.md / README.md / wt
# symlinked from this repo, and every org repo cloned alongside.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORG="$(dirname "$HERE")"
GH_ORG=Konstellation-Network

for f in ENGINEERING.md STATUS.md CLAUDE.md TOKENOMICS.md wt; do ln -sfn "handbook/$f" "$ORG/$f"; done
ln -sfn handbook/ORG-README.md "$ORG/README.md"

for r in konstellation networks contracts infra explorer docs whitepaper chain-config faucet Scriipture .github; do
  [ -d "$ORG/$r/.git" ] || git -C "$ORG" clone "git@github.com:$GH_ORG/$r.git"
done
echo "org ready at $ORG"; "$ORG/wt" status
