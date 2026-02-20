#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f tmp.compose.yml ]]; then
  echo "tmp.compose.yml not found, nothing to stop."
  exit 0
fi

echo "Stopping services..."
docker compose -f tmp.compose.yml down

echo "Removing tmp.compose.yml..."
rm tmp.compose.yml
