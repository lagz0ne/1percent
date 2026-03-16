#!/usr/bin/env bash
set -euo pipefail
# Bump version, update plugin.json + marketplace.json, commit, tag.
# Usage: bash scripts/version.sh <major|minor|patch>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_JSON="${ROOT}/.claude-plugin/plugin.json"
MARKETPLACE_JSON="${ROOT}/.claude-plugin/marketplace.json"

BUMP="${1:-}"
if [[ ! "$BUMP" =~ ^(major|minor|patch)$ ]]; then
  echo "Usage: bash scripts/version.sh <major|minor|patch>"
  exit 1
fi

# Read current version from plugin.json
CURRENT=$(grep -oP '"version"\s*:\s*"\K[0-9]+\.[0-9]+\.[0-9]+' "$PLUGIN_JSON" | head -1)
if [ -z "$CURRENT" ]; then
  echo "Error: could not read version from $PLUGIN_JSON"
  exit 1
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

case "$BUMP" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
esac

NEW="${MAJOR}.${MINOR}.${PATCH}"

# Update plugin.json
sed -i "s/\"version\": \"${CURRENT}\"/\"version\": \"${NEW}\"/" "$PLUGIN_JSON"

# Update marketplace.json — same version for the autoresearch plugin entry
sed -i "s/\"version\": \"${CURRENT}\"/\"version\": \"${NEW}\"/" "$MARKETPLACE_JSON"

# Verify both files have the new version
PLUGIN_V=$(grep -oP '"version"\s*:\s*"\K[0-9]+\.[0-9]+\.[0-9]+' "$PLUGIN_JSON" | head -1)
MARKET_V=$(grep -oP '"version"\s*:\s*"\K[0-9]+\.[0-9]+\.[0-9]+' "$MARKETPLACE_JSON" | head -1)

if [ "$PLUGIN_V" != "$NEW" ] || [ "$MARKET_V" != "$NEW" ]; then
  echo "Error: version mismatch after update"
  echo "  plugin.json:      ${PLUGIN_V}"
  echo "  marketplace.json: ${MARKET_V}"
  echo "  expected:         ${NEW}"
  exit 1
fi

echo "${CURRENT} → ${NEW}"
echo "  plugin.json:      ${PLUGIN_V} ✓"
echo "  marketplace.json: ${MARKET_V} ✓"
echo ""
echo "To release:"
echo "  git add -A && git commit -m \"release: v${NEW}\" && git tag v${NEW} && git push && git push --tags"
