---
event: Stop
---

Before stopping, check if there is an active autoresearch session:

1. Check if `autoresearch.md` exists in the working directory
2. Check if the current git branch starts with `autoresearch/`

If both are true, this is an active autoresearch session. **Do not stop.** Instead:

1. Read the last line of `autoresearch.jsonl` to get the current run number and last status
2. If the last 3 consecutive entries have `"status":"discard"`, stop and report to the user (anti-pattern: unbounded exploration)
3. Otherwise, continue the experiment loop — propose the next hypothesis, implement, benchmark, decide

If the user explicitly asked you to stop (e.g., "stop", "pause", "that's enough"), respect that and stop.
