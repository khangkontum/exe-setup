DO NOT add document / commit when I ask to scout the source to find out insight.
Perform new task that edit codebase in another worktree. Then cherry-pick them back to original source. Prune the worktree and delete it after conflict resolved.

# Shelley sessions and sub-agents
Spin sub-agents to handle complex task that you think worth separate like exploring or finding exact piece of code / logic.
When spawning a new Shelley session or scheduling Shelley tasks, always use the model "{{mainAgent}}".
When spawning subagents, always use the model "{{subAgentsModel}}".
