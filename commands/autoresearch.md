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

Run the gitignore setup script to check if runtime files are excluded:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/setup-gitignore.sh" .
```

## Step 2: Create Branch

```bash
# Slugify the goal
SLUG=$(echo "$ARGUMENTS" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g' | head -c 50)
git checkout -b "autoresearch/${SLUG}"
```

## Step 3: Write Session Files

Create `autoresearch.md` in the project root:

```markdown
# Autoresearch: {goal}

## Config
- **Benchmark**: `{benchmark_command}`
- **Target metric**: `{metric_name}` ({direction})
- **Scope**: {files/modules}
- **Branch**: `autoresearch/{slug}`
- **Started**: {ISO timestamp}

## Rules
1. One change per experiment
2. Run benchmark after every change
3. Keep if metric improves, discard if it regresses
4. Log every run to autoresearch.jsonl
5. Commit kept changes with `Result:` trailer
```

Create `autoresearch.sh` in the project root:

```bash
#!/usr/bin/env bash
set -euo pipefail
# Autoresearch benchmark wrapper
# Runs the benchmark and parses metrics

{benchmark_command} 2>&1 | tee /dev/stderr | bash "${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")}/scripts/parse-metrics.sh"
```

Make it executable: `chmod +x autoresearch.sh`

## Step 4: Run Baseline

```bash
bash autoresearch.sh
```

Parse the output with `${CLAUDE_PLUGIN_ROOT}/scripts/parse-metrics.sh`. Record the baseline:

```bash
# Append to autoresearch.jsonl
echo '{"run":1,"commit":"'$(git rev-parse --short HEAD)'","metrics":{parsed_metrics},"status":"keep","description":"baseline","timestamp":'$(date +%s)'}' >> autoresearch.jsonl
```

## Step 5: Commit Baseline

```bash
git add autoresearch.md autoresearch.sh autoresearch.jsonl
git commit -m "autoresearch: bootstrap session for ${ARGUMENTS}

Result: {baseline_metric_name}={baseline_value}"
```

## Step 6: Start the Loop

Tell the user:
> Baseline recorded. Starting experiment loop. I'll propose changes one at a time, benchmark each, and keep what improves `{metric_name}`.

Now begin the experiment loop. For each iteration:

1. **Hypothesize** — propose a single, targeted change with clear rationale
2. **Implement** — make the change
3. **Benchmark** — run `bash autoresearch.sh` and parse metrics via `${CLAUDE_PLUGIN_ROOT}/scripts/parse-metrics.sh`
4. **Decide**:
   - **Keep**: metric improved → commit with `Result:` trailer, log to JSONL with `"status":"keep"`
   - **Discard**: metric regressed → `git checkout -- .`, log to JSONL with `"status":"discard"`
   - **Crash**: benchmark failed → `git checkout -- .`, log to JSONL with `"status":"crash"`
5. **Report** — show the user: run number, what changed, before/after metric, decision
6. **Repeat** — next hypothesis

Always refer to the autoresearch skill for loop discipline and anti-patterns.
