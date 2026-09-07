#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: rollback-production.sh <resource-group> <api-app> <web-app> <api-zip> <web-zip> <api-base-url> <web-base-url> [evidence-dir]" >&2
  exit 2
}

[[ $# -ge 7 && $# -le 8 ]] || usage

resource_group="$1"
api_app="$2"
web_app="$3"
api_zip="$4"
web_zip="$5"
api_base_url="$6"
web_base_url="$7"
evidence_dir="${8:-rollback-evidence-$(date -u +%Y%m%dT%H%M%SZ)}"

[[ -f "$api_zip" && -f "$web_zip" ]] || { echo 'Both rollback ZIP artifacts must exist.' >&2; exit 2; }
[[ -n "$resource_group" && -n "$api_app" && -n "$web_app" && -n "$api_base_url" && -n "$web_base_url" ]] || usage

mkdir -p "$evidence_dir"
api_zip_sha256="$(shasum -a 256 "$api_zip" | cut -d ' ' -f 1)"
web_zip_sha256="$(shasum -a 256 "$web_zip" | cut -d ' ' -f 1)"
start_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

{
  echo "Rollback started UTC: $start_utc"
  echo "Resource group: $resource_group"
  echo "API app: $api_app"
  echo "Web app: $web_app"
  echo "API artifact: $api_zip"
  echo "API artifact SHA-256: $api_zip_sha256"
  echo "Web artifact: $web_zip"
  echo "Web artifact SHA-256: $web_zip_sha256"
} | tee "$evidence_dir/rollback-record.txt"

# Deploy both artifacts from the same previously healthy release before smoke testing.
az webapp deploy \
  --resource-group "$resource_group" \
  --name "$api_app" \
  --src-path "$api_zip" \
  --type zip \
  --clean true \
  --restart true \
  --async true \
  --track-status false \
  --output json | tee "$evidence_dir/api-deployment.json"

az webapp deploy \
  --resource-group "$resource_group" \
  --name "$web_app" \
  --src-path "$web_zip" \
  --type zip \
  --clean true \
  --restart true \
  --async true \
  --track-status false \
  --output json | tee "$evidence_dir/web-deployment.json"

SMOKE_API_BASE_URL="$api_base_url" \
SMOKE_WEB_BASE_URL="$web_base_url" \
  "$(dirname "$0")/post-deploy-smoke.sh" | tee "$evidence_dir/rollback-smoke.log"

end_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'Rollback completed UTC: %s\nRollback smoke: PASS\n' "$end_utc" | tee -a "$evidence_dir/rollback-record.txt"
