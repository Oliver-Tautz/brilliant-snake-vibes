# Agent Rules

Ask for an explicit yes first, every time (approval doesn't carry over), before:

- **Deleting** anything: files, branches, tags, remotes, commits, stashes, repos, or file content. Includes `reset --hard`, `clean`, force push, history rewrites.
- **Touching anything outside this repo** (dotfiles, system config).
- **Reading or modifying `~/.ssh`**, keys, tokens, credentials.

State exactly what will change, then wait.

# Decisions

- Follow [spec.md](spec.md). If it is silent or ambiguous, ask.
- Log judgment calls (TBD values, layout, pinned versions, ambiguity resolved, reviewer-driven changes) in [agent_adr.md](agent_adr.md): append-only, `## <date> — <title>` with Decision / Decided by / Why / Source / Revisit if, a few lines each, committed with the work. Skip routine changes, spec facts and secrets.
- Decided by: `claude` (me), `reviewer` (change-reviewer), `worker` (simple-task-worker), another named agent, or `user`. Only ask the user between iterations, never mid-iteration.
- Suggest spec changes. Don't make them.

# Delegation

## simple-task-worker

- Hand small, well-defined code changes (a single function, a small fix, boilerplate) to `simple-task-worker`. Keep design, refactors, and anything ambiguous for yourself.
- Give it a precise brief: files to touch, expected behavior, and the tests or test command to work against. Write or point to the tests first when possible.
- You stay responsible for its work. Read its diff and rerun the tests before accepting it.
- If it reports `BLOCKED` or `DONE WITH CONCERNS`, resolve the issue yourself or narrow the brief. Don't resend the same task unchanged.
- It must not commit, delete, or touch anything outside its brief. The approval rules above apply to it in full: it can't get approval itself, so anything that needs a yes stays with you.
- Log any judgment call it reports in [agent_adr.md](agent_adr.md) with `Decided by: worker`.
- Commit its changes in their own commits, prefixed `worker:`, never mixed with yours.

## change-reviewer

- Run `change-reviewer` once you have finished a set of edits, before committing. It reviews everything in the set, including `simple-task-worker` changes, which stay uncommitted until it approves; then split them into their own `worker:` commits. Don't run it separately per worker commit.
- Commit only on `APPROVE` or `APPROVE WITH NITS`. Fix the nits too, or log why not in [agent_adr.md](agent_adr.md).
- On `CHANGES REQUESTED`, fix the findings and run the reviewer again. Repeat until it approves.
- If it reports failing tests, follow its recommended next step. Don't retry on your own. If you're still stuck after that, ask the reviewer again before trying something else.
- If you disagree with a finding, don't ignore it quietly. Raise it with the user between iterations and log the outcome.
- Log reviewer-driven changes in [agent_adr.md](agent_adr.md) with `Decided by: reviewer`.
