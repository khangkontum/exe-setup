# exe-setup

Tiny first-boot setup for new [exe.dev](https://exe.dev/) VMs.

It only fills gaps in the exeuntu image: Node.js LTS, pnpm, git defaults,
PATH/shell helpers, Shelley models, and Shelley AGENTS additions.

## Use

Set as the exe.dev default setup script:

```bash
cat bootstrap.sh | ssh exe.dev defaults write dev.exe new.setup-script
```

Run manually:

```bash
bash setup.sh
source ~/.bashrc
```

## Files

- `bootstrap.sh`: tiny default setup script; downloads this repo and runs `setup.sh`.
- `setup.sh`: idempotent installer.
- `lib/`: shared setup logic and installed shell helpers.
- `models.json`: Shelley custom models template.
- `AGENTS.append.md`: managed Shelley instruction block.

## Helpers

After setup:

```bash
update-pi [release-tag]
update-codex [release-tag]
list-models [DB_PATH]
install-rust [toolchain]
install-tailscale
join-tailscale [AUTH_KEY] [tailscale up args...]
```

Use `api_key_env` in `models.json`; rerun `setup.sh` after changing local
models or `AGENTS.append.md`.
