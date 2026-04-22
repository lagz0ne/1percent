#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PARSE_METRICS="${PROJECT_ROOT}/scripts/parse-metrics.sh"
MOCK_BENCHMARK="${SCRIPT_DIR}/fixtures/mock-benchmark.sh"

PASS=0
FAIL=0
TMPDIR_BASE=""

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local name="$1" path="$2"
  if [ -f "$path" ]; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name — file not found: $path"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_not_exists() {
  local name="$1" path="$2"
  if [ ! -f "$path" ]; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name — unexpected file: $path"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local name="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name"
    echo "    expected to contain: $needle"
    echo "    actual: $haystack"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local name="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo "  FAIL: $name"
    echo "    did not expect: $needle"
    echo "    actual: $haystack"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  fi
}

setup_temp_repo() {
  TMPDIR_BASE=$(mktemp -d)
  cd "$TMPDIR_BASE"
  git init -q
  git commit --allow-empty -m "init" -q
  # Copy scripts
  cp "$PARSE_METRICS" ./parse-metrics.sh
  cp "$MOCK_BENCHMARK" ./benchmark.sh
  chmod +x ./benchmark.sh ./parse-metrics.sh
  printf '%s\n' '.autoresearch/' > .gitignore
  git add .gitignore
  git commit -q -m "test: ignore autoresearch runtime"
}

cleanup() {
  if [ -n "$TMPDIR_BASE" ] && [ -d "$TMPDIR_BASE" ]; then
    rm -rf "$TMPDIR_BASE"
  fi
}
trap cleanup EXIT

echo "=== test-experiment-flow ==="

# Test 1: branch creation
echo "--- branch creation ---"
setup_temp_repo
SLUG="optimize-speed"
git checkout -b "autoresearch/${SLUG}" -q
BRANCH=$(git branch --show-current)
assert_eq "branch name" "autoresearch/${SLUG}" "$BRANCH"

# Test 2: baseline run + ignored session logging
echo "--- baseline + JSONL ---"
SESSION_ID="20260422T000000Z-${SLUG}"
SESSION_DIR=".autoresearch/sessions/${SESSION_ID}"
mkdir -p "$SESSION_DIR" .autoresearch research/learnings
printf '%s\n' "$SESSION_ID" > .autoresearch/current
METRICS=$(bash ./benchmark.sh 0 85 | bash ./parse-metrics.sh)
COMMIT=$(git rev-parse --short HEAD)
TIMESTAMP=$(date +%s)
# Write JSONL entry
echo "# state" > "${SESSION_DIR}/state.md"
echo "#!/usr/bin/env bash" > "${SESSION_DIR}/benchmark.sh"
echo "{\"run\":1,\"commit\":\"${COMMIT}\",\"metrics\":${METRICS},\"status\":\"keep\",\"description\":\"baseline\",\"timestamp\":${TIMESTAMP}}" > "${SESSION_DIR}/run.jsonl"
assert_file_exists "jsonl created" "${SESSION_DIR}/run.jsonl"
if git status --short --ignored .autoresearch/ | grep -q '^!! .autoresearch/'; then
  echo "  PASS: runtime ignored"
  PASS=$((PASS + 1))
else
  echo "  FAIL: runtime not ignored"
  git status --short --ignored .autoresearch/
  FAIL=$((FAIL + 1))
fi

# Validate JSONL content
JSONL_LINE=$(head -1 "${SESSION_DIR}/run.jsonl")
assert_contains "jsonl has run" '"run":1' "$JSONL_LINE"
assert_contains "jsonl has commit" "\"commit\":\"${COMMIT}\"" "$JSONL_LINE"
assert_contains "jsonl has status" '"status":"keep"' "$JSONL_LINE"
assert_contains "jsonl has description" '"description":"baseline"' "$JSONL_LINE"
assert_contains "jsonl has score metric" '"score":85' "$JSONL_LINE"

# Test 3: commit with explicit pathspec excludes runtime
echo "--- commit with trailer ---"
echo "# experiment" > experiment.txt
echo "runtime noise" >> "${SESSION_DIR}/run.jsonl"
git add experiment.txt
git commit -q -m "$(cat <<'EOF'
experiment: try batch size 64

Result: score=85, duration_ms=1234
EOF
)"
COMMIT_MSG=$(git log -1 --format=%B)
assert_contains "has Result trailer" "Result:" "$COMMIT_MSG"
COMMITTED_FILES=$(git show --name-only --format= HEAD)
assert_eq "only experiment committed" "experiment.txt" "$COMMITTED_FILES"

# Test 4: discard only experiment pathspec
echo "--- pathspec discard ---"
echo "user work" > user-notes.txt
echo "bad change" > bad.txt
rm -- bad.txt
assert_file_not_exists "discard removes experiment file" bad.txt
assert_file_exists "discard preserves user work" user-notes.txt

# Test 5: extracted learning commits without runtime
echo "--- learning commit ---"
LEARNING="research/learnings/${SESSION_ID}.md"
echo "# Learning" > "$LEARNING"
git add "$LEARNING"
git commit -q -m "research: extract learning for ${SESSION_ID}"
assert_contains "learning committed" "$LEARNING" "$(git show --name-only --format= HEAD)"
if git show --name-only --format= HEAD | grep -q '^.autoresearch/'; then
  echo "  FAIL: runtime committed with learning"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: learning excludes runtime"
  PASS=$((PASS + 1))
fi

# Test 6: resume pointer locates active session
echo "--- resume pointer ---"
RESUME_ID=$(cat .autoresearch/current)
assert_eq "current session id" "$SESSION_ID" "$RESUME_ID"
assert_file_exists "resume state" ".autoresearch/sessions/${RESUME_ID}/state.md"
assert_file_exists "resume run log" ".autoresearch/sessions/${RESUME_ID}/run.jsonl"

# Test 7: compact resume reads only recent active state by default
echo "--- compact resume ---"
for run in $(seq 2 30); do
  echo "{\"run\":${run},\"commit\":\"${COMMIT}\",\"metrics\":{\"score\":$((85 + run))},\"status\":\"keep\",\"description\":\"run ${run}\",\"timestamp\":${TIMESTAMP}}" >> "${SESSION_DIR}/run.jsonl"
done
RECENT_RUNS=$(tail -n 20 "${SESSION_DIR}/run.jsonl")
assert_not_contains "old run skipped by default" '"description":"baseline"' "$RECENT_RUNS"
assert_contains "recent run loaded" '"run":30' "$RECENT_RUNS"
OLD_SESSION=".autoresearch/sessions/20200101T000000Z-old"
mkdir -p "$OLD_SESSION"
echo "# old" > "$OLD_SESSION/state.md"
touch -d '30 days ago' "$OLD_SESSION" "$OLD_SESSION/state.md"
find .autoresearch/sessions -mindepth 1 -maxdepth 1 -type d ! -name "$SESSION_ID" -mtime +14 -exec rm -rf {} +
assert_file_not_exists "cold session pruned" "$OLD_SESSION/state.md"

# Test 8: benchmark failure (non-zero exit)
echo "--- benchmark failure ---"
bash ./benchmark.sh 1 50 > /dev/null 2>&1 || EXIT_CODE=$?
assert_eq "non-zero exit" "1" "${EXIT_CODE:-0}"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
