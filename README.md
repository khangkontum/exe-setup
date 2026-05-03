# exe-setup

First-boot setup for new [exe.dev](https://exe.dev/) VMs.

The exeuntu image already includes most tools. This repo only installs/configures the missing bits: Node.js LTS, pnpm, git defaults, shell helpers, PATH defaults, Shelley custom models, and on-demand helpers for Rust/Tailscale.

## Files

- `bootstrap.sh` — small exe.dev setup script that fetches this repo and runs `setup.sh`
- `setup.sh` — main installer
- `lib/common.sh` — setup helpers
- `lib/shell.sh` — installed shell helpers
- `lib/shelley-models.sh` — startup-only Shelley custom model sync
- `models.json` — editable Shelley custom model list, copied to `~/.config/exe-setup/models.json`

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


## Shelley custom models

`setup.sh` copies `models.json` to `~/.config/exe-setup/models.json` when the
local file does not exist yet, then tries to sync it into Shelley via the local
custom-models API. If any models are created or updated, setup restarts
`shelley.service` so Shelley loads the changes. The file is safe to keep empty
by default:

```json
{
  "models": []
}
```

Add models like this:

```json
{
  "models": [
    {
      "display_name": "GPT 5.1 Codex",
      "provider_type": "openai-responses",
      "endpoint": "https://api.openai.com/v1/responses",
      "api_key_env": "OPENAI_API_KEY",
      "model_name": "gpt-5.1-codex",
      "max_tokens": 200000,
      "tags": "",
      "reasoning_effort": "medium"
    }
  ]
}
```

Use `api_key_env` to read the key from the environment, or `api_key` to store a
key directly in the local file. Existing models are matched by `model_id` when
present, otherwise by `display_name`. Re-run `setup.sh` after editing the local
file to sync changes.

Supported `provider_type` values are `anthropic`, `openai`,
`openai-responses`, and `gemini`.

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
