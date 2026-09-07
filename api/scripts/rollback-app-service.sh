#!/usr/bin/env bash
set -euo pipefail

resource_group="${1:-}"
app_name="${2:-}"
artifact_path="${3:-}"

if [[ -z "$resource_group" || -z "$app_name" || -z "$artifact_path" || ! -f "$artifact_path" ]]; then
  echo 'Usage: rollback-app-service.sh <resource-group> <app-name> <previous-release.zip>' >&2
  exit 2
fi

az webapp deploy \
  --resource-group "$resource_group" \
  --name "$app_name" \
  --src-path "$artifact_path" \
  --type zip \
  --clean true \
  --restart true \
  --async true \
  --track-status false \
  --output json

echo "Rollback artifact deployed to $resource_group/$app_name. Run post-deploy-smoke.sh before closing the incident."
