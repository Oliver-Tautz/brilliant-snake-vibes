# Agent Rules

Ask and get an explicit yes first, every time (approval doesn't carry over), before:

- **Deleting** anything: files, branches, tags, remotes, commits, stashes, repos, or content in existing files. Includes `reset --hard`, `clean`, force push, history rewrites.
- **Touching anything outside this repo**, e.g. `~/.gitconfig`, other dotfiles, system config.
- **Reading or modifying `~/.ssh`**, keys, tokens, or credentials.

State exactly what will change, then wait.

# Decisions

Consult [spec.md](spec.md) before making design or implementation decisions, and follow it. If the spec is silent or ambiguous, ask instead of guessing.
