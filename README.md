# exe-setup

First-boot setup for new [exe.dev](https://exe.dev/) VMs.

The default exeuntu image already includes most tools used here (`uv`, `nvm`, `claude`, `pi`, `codex`, `docker`, `jq`, `git`, etc.). This repo installs only the missing/default-unconfigured pieces and adds update helpers.

## What it does

`setup.sh`:

- enables safer Bash execution with `set -euo pipefail`
- logs each run to `~/.cache/exe-setup/` and updates `latest.log`
- installs Node.js LTS via the pre-installed `nvm`
- sets the default Node version to `lts/*`
- installs/activates `pnpm` via Corepack, with an npm fallback
- installs managed shell helpers into `~/.config/exe-setup/shell.sh`
- keeps a single managed source block in `~/.bashrc`
- prepends `~/.local/bin` and `~/.local/pi` to `PATH`
- provides `update-pi [release-tag]`
- provides `update-codex [release-tag]`
- provides `shelley_models [DB_PATH]`

## Files

```text
bootstrap.sh      # tiny exe.dev setup-script; fetches this repo tarball and runs setup.sh
setup.sh          # main setup entrypoint
lib/common.sh     # setup-time helper functions
lib/shell.sh      # installed shell defaults and update helper functions
```

## Install as exe.dev default setup script

From a machine authenticated to exe.dev:

```bash
cat bootstrap.sh | ssh exe.dev defaults write dev.exe new.setup-script
```

New VMs created with `ssh exe.dev new` will then run `bootstrap.sh` on first boot.

## Run manually on a VM

```bash
git clone https://github.com/khangkontum/exe-setup.git
cd exe-setup
bash setup.sh
```

Then open a new shell or run:

```bash
source ~/.bashrc
```

## Update helpers

Latest versions:

```bash
update-pi
update-codex
```

Pinned versions:

```bash
update-pi <release-tag>
update-codex <release-tag>
```

`update-pi` extracts and verifies the new full Pi app directory before replacing `~/.local/pi`, because Pi is a Bun app and is not a standalone binary.

`update-codex` installs the single static Codex binary to `/usr/local/bin/codex` via `sudo install`.

## Querying models on a VM

The shell helper `shelley_models` runs the Shelley models query against a local DB.

```bash
shelley_models
shelley_models /path/to/shelley.db   # optional custom path
```

Default DB path: `/home/exedev/.config/shelley/shelley.db`

The SQL executed is:

```sql
SELECT model_id, display_name, provider_type, model_name, max_tokens, tags, reasoning_effort
FROM models
ORDER BY model_id;
```
