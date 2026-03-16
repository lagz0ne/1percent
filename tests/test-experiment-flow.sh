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

setup_temp_repo() {
  TMPDIR_BASE=$(mktemp -d)
  cd "$TMPDIR_BASE"
  git init -q
  git commit --allow-empty -m "init" -q
  # Copy scripts
  cp "$PARSE_METRICS" ./parse-metrics.sh
  cp "$MOCK_BENCHMARK" ./benchmark.sh
  chmod +x ./benchmark.sh ./parse-metrics.sh
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

# Test 2: baseline run + JSONL logging
echo "--- baseline + JSONL ---"
METRICS=$(bash ./benchmark.sh 0 85 | bash ./parse-metrics.sh)
COMMIT=$(git rev-parse --short HEAD)
TIMESTAMP=$(date +%s)
# Write JSONL entry
echo "{\"run\":1,\"commit\":\"${COMMIT}\",\"metrics\":${METRICS},\"status\":\"keep\",\"description\":\"baseline\",\"timestamp\":${TIMESTAMP}}" > autoresearch.jsonl
assert_file_exists "jsonl created" "./autoresearch.jsonl"

# Validate JSONL content
JSONL_LINE=$(head -1 autoresearch.jsonl)
assert_contains "jsonl has run" '"run":1' "$JSONL_LINE"
assert_contains "jsonl has commit" "\"commit\":\"${COMMIT}\"" "$JSONL_LINE"
assert_contains "jsonl has status" '"status":"keep"' "$JSONL_LINE"
assert_contains "jsonl has description" '"description":"baseline"' "$JSONL_LINE"
assert_contains "jsonl has score metric" '"score":85' "$JSONL_LINE"

# Test 3: commit with Result trailer
echo "--- commit with trailer ---"
echo "# experiment" > experiment.txt
git add experiment.txt
git commit -q -m "$(cat <<'EOF'
experiment: try batch size 64

Result: score=85, duration_ms=1234
EOF
)"
COMMIT_MSG=$(git log -1 --format=%B)
assert_contains "has Result trailer" "Result:" "$COMMIT_MSG"

# Test 4: revert on discard
echo "--- revert on discard ---"
BEFORE_COMMIT=$(git rev-parse HEAD~1)
echo "bad change" > bad.txt
git add bad.txt
git commit -q -m "experiment: bad idea

Result: score=10, duration_ms=9999"
# Simulate discard by reverting
git revert --no-edit HEAD
# bad.txt should be gone
if [ ! -f bad.txt ]; then
  echo "  PASS: revert removes bad file"
  PASS=$((PASS + 1))
else
  echo "  FAIL: revert did not remove bad file"
  FAIL=$((FAIL + 1))
fi

# Test 5: benchmark failure (non-zero exit)
echo "--- benchmark failure ---"
bash ./benchmark.sh 1 50 > /dev/null 2>&1 || EXIT_CODE=$?
assert_eq "non-zero exit" "1" "${EXIT_CODE:-0}"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
