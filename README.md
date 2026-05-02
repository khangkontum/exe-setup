# exe-setup

First-boot setup for new [exe.dev](https://exe.dev/) VMs.

The exeuntu image already includes most tools. This repo only installs/configures the missing bits: Node.js LTS, pnpm, git defaults, shell helpers, PATH defaults, and on-demand helpers for Rust/Tailscale.

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
install-rust [toolchain]
install-tailscale
join-tailscale [AUTH_KEY] [tailscale up args...]
```

`DB_PATH` defaults to `/home/exedev/.config/shelley/shelley.db`.

`install-rust` installs/updates Rust via rustup, makes cargo available on PATH,
sets the default toolchain (default: `stable`), and adds `rustfmt`, `clippy`,
`rust-src`, and `rust-analyzer`. Set `RUST_COMPONENTS="..."` to override the
component list.

`join-tailscale` installs Tailscale if needed, prompts for a reusable auth key
when `AUTH_KEY` is omitted, and joins with the VM hostname. Set
`TAILSCALE_HOSTNAME=my-name` to override the hostname.
