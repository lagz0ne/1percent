#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PARSE_METRICS="${SCRIPT_DIR}/../scripts/parse-metrics.sh"
FIXTURES="${SCRIPT_DIR}/fixtures"

PASS=0
FAIL=0

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

echo "=== test-parse-metrics ==="

# Test 1: single metric
echo "--- single metric ---"
result=$(echo 'METRIC score=42' | bash "$PARSE_METRICS")
assert_eq "single metric" '{"score":42}' "$result"

# Test 2: multiple metrics
echo "--- multiple metrics ---"
result=$(printf 'METRIC a=1\nMETRIC b=2\nMETRIC c=3\n' | bash "$PARSE_METRICS")
assert_contains "has a" '"a":1' "$result"
assert_contains "has b" '"b":2' "$result"
assert_contains "has c" '"c":3' "$result"

# Test 3: decimal values
echo "--- decimals ---"
result=$(echo 'METRIC accuracy=0.95' | bash "$PARSE_METRICS")
assert_eq "decimal" '{"accuracy":0.95}' "$result"

# Test 4: negative values
echo "--- negatives ---"
result=$(echo 'METRIC delta=-0.03' | bash "$PARSE_METRICS")
assert_eq "negative" '{"delta":-0.03}' "$result"

# Test 5: scientific notation
echo "--- scientific notation ---"
result=$(echo 'METRIC lr=1.5e-4' | bash "$PARSE_METRICS")
assert_eq "sci notation" '{"lr":1.5e-4}' "$result"

# Test 6: no metrics → empty object
echo "--- no metrics ---"
result=$(echo 'just some log output' | bash "$PARSE_METRICS")
assert_eq "empty" '{}' "$result"

# Test 7: malformed lines ignored
echo "--- malformed lines ---"
result=$(printf 'METRIC =noname\nMETRIC bad format\nMETRIC 123invalid=456\nMETRIC valid=99\n' | bash "$PARSE_METRICS")
assert_eq "malformed ignored" '{"valid":99}' "$result"

# Test 8: mixed output from fixture
echo "--- sample-output.txt ---"
result=$(bash "$PARSE_METRICS" < "$FIXTURES/sample-output.txt")
assert_contains "fixture accuracy" '"accuracy":0.95' "$result"
assert_contains "fixture duration_ms" '"duration_ms":1234' "$result"
assert_contains "fixture loss" '"loss":0.281' "$result"
assert_contains "fixture throughput" '"throughput":1500.5' "$result"
assert_contains "fixture negative" '"negative_delta":-0.03' "$result"
assert_contains "fixture sci" '"sci_notation":1.5e-4' "$result"
assert_contains "fixture underscore" '"valid_underscore_name":99' "$result"

# Test 9: metric from mock-benchmark
echo "--- mock-benchmark ---"
result=$(bash "$FIXTURES/mock-benchmark.sh" 0 77 | bash "$PARSE_METRICS")
assert_contains "mock score" '"score":77' "$result"
assert_contains "mock duration" '"duration_ms":1234' "$result"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
