# 1percent

Claude Code plugin for automated experiment loops. Each iteration targets a 1% improvement — small, measurable, compounding.

Inspired by [karpathy/autoresearch](https://github.com/karpathy/autoresearch) and [davebcn87/pi-autoresearch](https://github.com/davebcn87/pi-autoresearch), ported to work as a native Claude Code plugin using only commands, skills, and shell scripts — no custom tools or extensions required.

## Install

```bash
claude plugin add lagz0ne/1percent
```

## Usage

```
/autoresearch "optimize inference speed"
```

Claude will:
1. Ask for your benchmark command, target metric, and direction
2. Create an `autoresearch/*` branch
3. Run a baseline, log it
4. Loop: hypothesize → implement → benchmark → keep or discard → repeat

The loop runs until you say stop or 3 consecutive experiments are discarded.

## How it works

Your benchmark outputs `METRIC name=value` lines on stdout:

```
METRIC accuracy=0.95
METRIC duration_ms=1234
```

The plugin extracts these into JSON, compares against the previous run, and decides: keep (commit) or discard (revert). Every run is logged to ignored runtime state under `.autoresearch/sessions/<session-id>/run.jsonl`.

In-progress state lives under ignored `.autoresearch/` files so the session survives context resets without polluting commits. Default resume reads only the active session and the last 20 run lines; older sessions are cold storage unless asked for or explicitly extended. Reusable learning is committed separately under `research/learnings/<session-id>.md`.

## Git and State

- Runtime state: `.autoresearch/sessions/<session-id>/` (ignored, never committed)
- Active session: `.autoresearch/current`
- Durable learning: `research/learnings/<session-id>.md` (committed)
- Kept experiments: commit only intended source paths with a `Result:` trailer
- Rejected experiments: revert only the experiment paths
- Retention: active session is hot, sessions touched in the last 14 days are warm, older sessions are cold/on-demand

This keeps active research resumable without filling git history with session trash or forcing every resume to load old logs.

## Components

| Component | File | Role |
|-----------|------|------|
| Command | `commands/autoresearch.md` | `/autoresearch` — bootstrap a session |
| Skill | `skills/autoresearch/SKILL.md` | Loop discipline, decision rules, anti-patterns |
| Reference | `skills/autoresearch/references/experiment-protocol.md` | Templates, JSONL schema, examples |
| Script | `scripts/parse-metrics.sh` | `METRIC name=value` → JSON (pure awk) |
| Hooks | `hooks/stop.md`, `hooks/pre-compact.md` | Keep the loop alive across turns and compaction |

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Tests

```bash
bash tests/test-parse-metrics.sh      # 18 assertions
bash tests/test-experiment-flow.sh     # 21 assertions
```

## Versioning

```bash
bash scripts/version.sh patch   # 0.1.0 → 0.1.1
bash scripts/version.sh minor   # 0.1.0 → 0.2.0
bash scripts/version.sh major   # 0.1.0 → 1.0.0
```

## License

MIT
