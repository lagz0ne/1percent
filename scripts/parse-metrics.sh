#!/usr/bin/env bash
# Extract METRIC name=value lines from stdin → JSON object on stdout.
# Valid: METRIC <identifier>=<number> where identifier starts with [a-zA-Z_]
# Usage: some_command | bash parse-metrics.sh

awk '
BEGIN { n = 0 }
/^METRIC [a-zA-Z_][a-zA-Z0-9_]*=-?[0-9]*\.?[0-9]+([eE][+-]?[0-9]+)?$/ {
  split($2, kv, "=")
  names[n] = kv[1]
  values[n] = kv[2]
  n++
}
END {
  printf "{"
  for (i = 0; i < n; i++) {
    if (i > 0) printf ","
    printf "\"%s\":%s", names[i], values[i]
  }
  printf "}"
}
'
