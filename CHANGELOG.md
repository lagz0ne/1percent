# Changelog

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
