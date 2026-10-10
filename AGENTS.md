# Agent Rules

Ask for an explicit yes first, every time (approval doesn't carry over), before:

- **Deleting** anything: files, branches, tags, remotes, commits, stashes, repos, or file content. Includes `reset --hard`, `clean`, force push, history rewrites.
- **Touching anything outside this repo** (dotfiles, system config).
- **Reading or modifying `~/.ssh`**, keys, tokens, credentials.

State exactly what will change, then wait.

# Decisions

- Follow [spec.md](spec.md). If it is silent or ambiguous, ask.
- Log judgment calls (TBD values, layout, pinned versions, ambiguity resolved, reviewer-driven changes) in [agent_adr.md](agent_adr.md): append-only, `## <date> — <title>` with Decision / Decided by / Why / Source / Revisit if, a few lines each, committed with the work. Skip routine changes, spec facts and secrets.
- Decided by: `claude` (me), `reviewer` (change-reviewer), another named agent, or `user`. Only ask the user between iterations, never mid-iteration.
- Suggest spec changes. Don't make them.
