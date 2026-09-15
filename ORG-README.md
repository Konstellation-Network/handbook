# Konstellation-Network

This folder is the **organisation**. Every top-level folder inside it is an independent git
repo with its own history, branches and remote — exactly like repos under a GitHub org.

```
Konstellation-Network/        the org (NOT a git repo itself)
├── CLAUDE.md                 instructions auto-loaded by coding agents
├── ENGINEERING.md            what we are building, hard constraints, repo map
├── TOKENOMICS.md             every economic parameter: issuance, burn, staking, gov
├── wt                        helper script
├── konstellation/            repo — the chain, produces konstellationd
├── networks/                 repo — genesis, peers, upgrades
├── contracts/                repo — preinstall Solidity
├── infra/                    repo — terraform, ansible, runbooks (private)
├── explorer/ docs/ whitepaper/ chain-config/ faucet/ .github/
└── .worktrees/               extra checkouts, one per <repo>/<branch>
    └── konstellation/hotfix/ worktree of konstellation on branch hotfix
```

See `ENGINEERING.md §5` for what each repo is responsible for and how they relate.

## Working on repos independently

Each repo is already independent — open a terminal per repo and use git as normal:

```sh
cd konstellation && git checkout -b feature-x   # terminal 1
cd contracts && git checkout -b wkons          # terminal 2
```

## Worktrees: several branches of the *same* repo at once

```sh
./wt new konstellation feature-x    # konstellation @ feature-x, in its own directory
./wt new konstellation hotfix       # konstellation @ hotfix, at the same time
cd "$(./wt path konstellation hotfix)"
./wt ls                             # all worktrees, all repos
./wt rm konstellation hotfix -b     # remove worktree + branch when merged
```

## Org-wide commands

```sh
./wt init  faucet                   # create a new repo
./wt clone git@github.com:org/x.git # bring an existing repo in
./wt status                         # every repo: current branch, clean/dirty
./wt each pull                      # run `git pull` in every repo
./wt each log --oneline -1          # last commit of every repo
```
