# 1percent — Autoresearch Plugin

Claude Code plugin for automated experiment loops. Port of karpathy/autoresearch.

## Structure

- `/autoresearch <goal>` — command to bootstrap a session
- `skills/autoresearch/` — loop discipline, decision rules, anti-patterns
- `scripts/parse-metrics.sh` — extracts `METRIC name=value` from stdout → JSON (pure awk)

## Testing

```bash
bash tests/test-parse-metrics.sh      # 18 assertions — metric parsing
bash tests/test-experiment-flow.sh     # 21 assertions — git workflow integration
```

## Metric Contract

Benchmarks output `METRIC name=value` on stdout. The parse-metrics script extracts these into a JSON object.

## Key Decisions

- Command bootstraps, skill sustains the loop
- No custom tools — Claude uses built-in Bash/Read/Write/Edit
- Ignored state in `.autoresearch/sessions/<session-id>/` — survives context resets without polluting commits
- Default resume reads only active state + last 20 run lines; old sessions are cold unless asked for or extended
- Extracted learning in `research/learnings/<session-id>.md` — committed without cross-session conflicts
- `awk` over `jq` — POSIX-guaranteed, no external deps
- `${CLAUDE_PLUGIN_ROOT}` for portable script paths
