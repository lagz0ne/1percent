# 1percent — Autoresearch Plugin

Claude Code plugin for automated experiment loops. Port of karpathy/autoresearch.

## Structure

- `/autoresearch <goal>` — command to bootstrap a session
- `skills/autoresearch/` — loop discipline, decision rules, anti-patterns
- `scripts/parse-metrics.sh` — extracts `METRIC name=value` from stdout → JSON (pure awk)

## Testing

```bash
bash tests/test-parse-metrics.sh      # 18 assertions — metric parsing
bash tests/test-experiment-flow.sh     # 10 assertions — git workflow integration
```

## Metric Contract

Benchmarks output `METRIC name=value` on stdout. The parse-metrics script extracts these into a JSON object.

## Key Decisions

- Command bootstraps, skill sustains the loop
- No custom tools — Claude uses built-in Bash/Read/Write/Edit
- State in files (`autoresearch.md`, `autoresearch.jsonl`) — survives context resets
- `awk` over `jq` — POSIX-guaranteed, no external deps
- `${CLAUDE_PLUGIN_ROOT}` for portable script paths
