---
event: PreCompact
---

Before context compaction, ensure autoresearch state is persisted:

1. If `autoresearch.md` exists, verify `autoresearch.jsonl` has the latest run logged
2. If there are uncommitted experiment changes that were decided as "keep", commit them now with the `Result:` trailer
3. If there are uncommitted changes that should be discarded, run `git checkout -- .` to clean up

After compaction, the skill's session resumption protocol will pick up from `autoresearch.md` + `autoresearch.jsonl`.
