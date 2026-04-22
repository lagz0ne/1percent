---
event: PreCompact
---

Before context compaction, ensure autoresearch state is persisted:

1. If `.autoresearch/current` exists, read the active session id and verify `.autoresearch/sessions/<session-id>/run.jsonl` has the latest run logged
2. If there are uncommitted experiment changes that were decided as "keep", commit them now with the `Result:` trailer
3. Commit only intended source pathspecs. Never commit `.autoresearch/**`
4. If there are uncommitted experiment changes that should be discarded, revert only the intended experiment pathspecs
5. Compact context: preserve `.autoresearch/current`, active `state.md`, and only the last 20 `run.jsonl` lines in memory. Do not load old sessions unless asked or extending.

After compaction, the skill's session resumption protocol will pick up from `.autoresearch/current` + the active session files.
