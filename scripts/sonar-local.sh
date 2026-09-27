#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
token_file="$repo_root/.sonar-token"

if [[ ! -s "$token_file" ]]; then
  printf 'Missing %s\n' "$token_file" >&2
  printf 'Save your local SonarQube token there, then run this script again.\n' >&2
  exit 1
fi

token="$(<"$token_file")"
cd "$repo_root"

flutter test --coverage
sonar-scanner \
  -Dsonar.projectKey=cashflow \
  -Dsonar.host.url="${SONAR_HOST_URL:-http://localhost:9000}" \
  -Dsonar.token="$token"