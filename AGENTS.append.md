# Shelley sessions and sub-agents
When spawning a new Shelley session or scheduling Shelley tasks, always use the model "{{mainAgent}}".
Always spin sub-agents to handle complex tasks that are worth separating instead of trying to do everything yourself.
When spawning subagents, always use the model "{{subAgentsModel}}".
