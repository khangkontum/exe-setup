# exe-setup

First-boot setup for new [exe.dev](https://exe.dev/) VMs.

The exeuntu image already includes most tools. This repo only installs/configures the missing bits: Node.js LTS, pnpm, git defaults, shell helpers, and PATH defaults.

## Files

- `bootstrap.sh` — small exe.dev setup script that fetches this repo and runs `setup.sh`
- `setup.sh` — main installer
- `lib/common.sh` — setup helpers
- `lib/shell.sh` — installed shell helpers

## Set as exe.dev default

```bash
cat bootstrap.sh | ssh exe.dev defaults write dev.exe new.setup-script
```

## Run manually

```bash
git clone https://github.com/khangkontum/exe-setup.git
cd exe-setup
bash setup.sh
source ~/.bashrc
```

## Git defaults

`setup.sh` configures:

- global `user.email = git@nhkhang.com`
- global `user.name = Hoang-Khang Nguyen`
- global `core.hooksPath = ~/.config/git/hooks`
- a `commit-msg` hook that strips `Co-Authored-by:` trailers

## Shell helpers

```bash
update-pi [release-tag]
update-codex [release-tag]
list-models [DB_PATH]
```

`DB_PATH` defaults to `/home/exedev/.config/shelley/shelley.db`.
