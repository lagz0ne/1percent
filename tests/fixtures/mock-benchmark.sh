#!/usr/bin/env bash
# Mock benchmark that outputs configurable metrics and exit code.
# Usage: mock-benchmark.sh [exit_code] [metric_value]
#   exit_code    — process exit code (default: 0)
#   metric_value — value for METRIC score= (default: 42)

EXIT_CODE="${1:-0}"
METRIC_VALUE="${2:-42}"

echo "Starting benchmark run..."
echo "Loading data..."
echo "METRIC score=${METRIC_VALUE}"
echo "METRIC duration_ms=1234"
echo "Run complete."
exit "$EXIT_CODE"
