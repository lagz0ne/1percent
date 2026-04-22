---
description: "Bootstrap an autoresearch session — automated experiment loop for continuous improvement"
argument-hint: "<goal>"
---

# /autoresearch — Bootstrap an Experiment Loop

You are starting an autoresearch session. Your job is to set up the scaffolding, run a baseline, and hand off to the experiment loop.

## Step 1: Gather Context

The user's goal: `$ARGUMENTS`

Ask the user (if not already clear):
1. **Benchmark command** — what script/command measures success? (e.g., `python benchmark.py`, `bash run_tests.sh`)
2. **Target metric** — which `METRIC name=value` line matters most? (e.g., `score`, `accuracy`, `duration_ms`)
3. **Direction** — higher is better, or lower is better?
4. **Scope** — which files/modules are in play?

## Step 1.5: Gitignore Check

Run the gitignore setup script to check if runtime state is excluded:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/setup-gitignore.sh" .
```

## Step 2: Create Branch

```bash
# Slugify the goal
SLUG=$(echo "$ARGUMENTS" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g' | head -c 50)
git checkout -b "autoresearch/${SLUG}"
```

## Step 3: Write Ignored Session Files

Create a unique session directory. Runtime state is never committed. Keep only the active session hot.

```bash
SESSION_ID="$(date -u +%Y%m%dT%H%M%SZ)-${SLUG}"
SESSION_DIR=".autoresearch/sessions/${SESSION_ID}"
mkdir -p "$SESSION_DIR" research/learnings
printf '%s\n' "$SESSION_ID" > .autoresearch/current
```

Create `${SESSION_DIR}/state.md`:

```markdown
# Autoresearch: {goal}

## Config
- **Session**: `{session_id}`
- **Extends**: `{prior_session_id|none}`
- **Benchmark**: `{benchmark_command}`
- **Target metric**: `{metric_name}` ({direction})
- **Scope**: {files/modules}
- **Branch**: `autoresearch/{slug}`
- **Base commit**: `{git rev-parse --short HEAD}`
- **Started**: {ISO timestamp}

## Rules
1. One change per experiment
2. Run benchmark after every change
3. Keep if metric improves, discard if it regresses
4. Log every run to `${SESSION_DIR}/run.jsonl`
5. Never commit `.autoresearch/**`
6. Commit kept source changes with explicit pathspecs and `Result:` trailer
7. Commit extracted learning to `research/learnings/{session_id}.md`
8. Default resume reads only `.autoresearch/current`, `state.md`, and the last 20 `run.jsonl` lines
9. Older sessions are cold storage; inspect them only when asked or when extending
```

Create `${SESSION_DIR}/benchmark.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
# Autoresearch benchmark wrapper
# Runs the benchmark and parses metrics

{benchmark_command} 2>&1 | tee /dev/stderr | bash "${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")}/scripts/parse-metrics.sh"
```

Make it executable: `chmod +x "${SESSION_DIR}/benchmark.sh"`

## Step 4: Run Baseline

```bash
bash "${SESSION_DIR}/benchmark.sh"
```

Parse the output with `${CLAUDE_PLUGIN_ROOT}/scripts/parse-metrics.sh`. Record the baseline:

```bash
# Append to ${SESSION_DIR}/run.jsonl
echo '{"run":1,"commit":"'$(git rev-parse --short HEAD)'","metrics":{parsed_metrics},"status":"keep","description":"baseline","timestamp":'$(date +%s)'}' >> "${SESSION_DIR}/run.jsonl"
```

## Step 5: Keep Runtime Uncommitted

```bash
git check-ignore -q .autoresearch/
git status --short --ignored .autoresearch/
```

Do not commit baseline runtime state. It is local progress state.

Run compact retention before starting, resuming, and stopping:

```bash
find .autoresearch/sessions -mindepth 1 -maxdepth 1 -type d ! -name "$SESSION_ID" -mtime +14 -exec rm -rf {} +
```

Keep only active/recent sessions by default. Do not scan historical session logs unless the user asks or the new session has `Extends:`.

## Step 6: Start the Loop

Tell the user:
> Baseline recorded. Starting experiment loop. I'll propose changes one at a time, benchmark each, and keep what improves `{metric_name}`.

Now begin the experiment loop. For each iteration:

1. **Hypothesize** — propose a single, targeted change with clear rationale
2. **Implement** — make the change
3. **Benchmark** — run `bash "${SESSION_DIR}/benchmark.sh"` and parse metrics via `${CLAUDE_PLUGIN_ROOT}/scripts/parse-metrics.sh`
4. **Decide**:
   - **Keep**: metric improved → commit only intended source pathspecs with `Result:` trailer, append run JSONL with `"status":"keep"`
   - **Discard**: metric regressed → revert only intended experiment pathspecs, append run JSONL with `"status":"discard"`
   - **Crash**: benchmark failed → revert only intended experiment pathspecs, append run JSONL with `"status":"crash"`
5. **Report** — show the user: run number, what changed, before/after metric, decision
6. **Repeat** — next hypothesis

When a reusable lesson is found, write or update `research/learnings/${SESSION_ID}.md` and commit that file separately from experiment runtime.

Always refer to the autoresearch skill for loop discipline and anti-patterns.
