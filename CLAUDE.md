# Instructions for Claude

- `claude-requirements.md` is the **source of truth** for this game. Read it before making any change.
- When a request adds or changes a requirement, decision or backlog item, update `claude-requirements.md` first, then the code, in the same commit.
- Follow the ID rules in that file (R-/D-/B-/C- IDs are permanent; add a Change log line for every change). Only Jim moves items from Proposed to Planned.
- Reference IDs in commit messages, e.g. `R-08: add Controls screen`.
- If code and the requirements file disagree, point it out to Jim rather than silently picking one.
- Engine: Godot 4.5+, GDScript, tab indentation. All UI is built in code (`scripts/main.gd`).
- When a requirement is added or changed, add or update its smoke-test steps in `testing.html` (D-10).
