# Changelog

## 0.1.2 - 2026-05-14

### Changed

- Removed automatic `autoresearch/*` branch creation. Bootstrap command asks user how to isolate work (git worktree, new branch, or current branch).
- Stop hook no longer keys session detection on branch name; relies solely on `.autoresearch/current`.
- `state.md` template `Branch:` field records user's chosen branch instead of forced `autoresearch/{slug}`.

### Fixed

- Portable `touch -t` with BSD/GNU `date` detection in `tests/test-experiment-flow.sh` (previous `touch -d '30 days ago'` failed on macOS).

## 0.1.1 - 2026-04-22

### Changed

- Moved autoresearch runtime state from root `autoresearch.*` files to ignored `.autoresearch/sessions/<session-id>/`.
- Added `.autoresearch/current` as the active-session pointer for resume.
- Kept in-progress research out of commits by ignoring `.autoresearch/`.
- Replaced broad commit/revert guidance with explicit pathspec commits and scoped experiment reverts.
- Added committed learning output at `research/learnings/<session-id>.md` so resumed or extended research does not fight over one file.
- Added retention controls: active session hot, recent sessions warm, old sessions cold/on-demand, default resume reads only active state plus the last 20 run lines.
- Added cold runtime pruning for non-active sessions older than 14 days.
- Updated stop/pre-compact hooks for the new session layout and compact resume behavior.
- Expanded experiment-flow tests to cover ignored runtime, clean learning commits, resume pointer, compact resume, and cold-session pruning.
