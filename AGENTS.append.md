# exe-setup additions

These instructions are appended to `/home/exedev/.config/shelley/AGENTS.md` during first-boot setup.

## Sub-agents

Always spin sub-agents to handle complex task that you think worth separate instead of trying to do all yourself, you will run out of context limit.
When spawning subagents or schedule shelley tasks, always use the model "{{subAgentsModel}}".

## Custom models

Custom Shelley models may be seeded from `~/.config/exe-setup/models.json` during setup. If you edit that file later, rerun `setup.sh` to sync the changes and restart Shelley.
