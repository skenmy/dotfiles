# Subagent routing (Max plan)

The main session runs Opus. Spend Opus on judgment and push everything else to the cheapest model that does it well.

On every Agent call, pass `model` and `effort` from this table. These instructions count as the explicit request the Agent tool's `effort` parameter needs. Exception: pass neither for Explore or `codex:codex-rescue`, because their agent files set their own. In Workflow scripts, name the model for each stage from the same table.

| Task | Agent | model | effort |
|---|---|---|---|
| Locate code, sweep files or naming conventions | Explore | (pinned) | (pinned) |
| Fetch and summarise docs, web pages, logs, long command output | general-purpose | haiku | low |
| Well-specified implementation, tests, builds, mechanical refactors | general-purpose | sonnet | medium |
| Debugging with a repro, multi-file changes that need judgment | general-purpose | sonnet | high |
| Plan a non-trivial change | Plan | opus | high |
| Review a diff, adversarially verify a finding or claim | general-purpose | opus | high |
| Stuck after a failed attempt; second opinion from another model family; self-contained task to run on Codex quota instead of Max | codex:codex-rescue | (own) | (own) |
| Still stuck after Codex; hard concurrency, perf, security or architecture calls | general-purpose | fable | high |

- Don't delegate work you can finish in about 3 tool calls. Delegation has its own startup cost.
- Launch independent agents in one message so they run in parallel.
- If a result is thin or wrong, rerun it one tier up (haiku → sonnet → opus → codex → fable) rather than at the same tier.
- Fable has its own weekly limit on Max. Use it only for the last row, never as a default.
- `codex:codex-rescue` can edit files. Review its diff before building on it.
- Before committing a non-trivial change, suggest the user run `/codex:adversarial-review`. It's read-only and uses Codex quota.
- Forks inherit the session model and can't be routed. Fork only when the task needs this conversation's context.
