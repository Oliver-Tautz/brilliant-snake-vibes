# Agent Rules

## Deletion

- Always ask the user for confirmation before deleting anything. No exceptions.
- This covers files, directories, branches, tags, remotes, commits, stashes, and repos.
- It also covers destructive git operations (`reset --hard`, `clean`, `branch -D`, force push, history rewrites) and removing content from existing files.
- Say exactly what would be deleted, then wait for an explicit yes.
- Earlier approval does not carry over to later deletions.
