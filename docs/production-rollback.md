# First-production-release rollback runbook

This runbook is the rollback procedure for TKO-0014's first production release. It
restores the **API and web artifacts from one previously healthy GitHub Actions
release bundle**; it does not rebuild from source and it does not alter data.

## Preconditions and release record

Before dispatching production, the Hubbsly Ship release record must contain:

- the exact production `main` commit SHA and GitHub Actions run ID/attempt;
- the previous healthy run URL and its immutable artifact name;
- API and web ZIP SHA-256 values from that artifact;
- the production resource group, API App Service, web App Service, and smoke URLs;
- the first-release rollback window and the incident owner/on-call contact.

Do not begin a rollback without identifying both ZIPs from the same previous healthy
run. Do not put Azure credentials, tokens, or application secrets in the record.

## Trigger and stop conditions

Trigger rollback when the production smoke checks fail, a critical tenant/auth
journey fails, or the release owner declares a customer-impacting regression.
Stop the release immediately on a failed smoke check; do not retry production
deployment as a substitute for rollback. If either artifact deployment fails,
stop, preserve the command output, and escalate to the Azure/App Service owner.

## Executable procedure

From the repository checkout, with Azure CLI already authenticated through the
approved operator path, download the API and web ZIPs from the referenced GitHub
artifact and verify their recorded hashes. Then run:

```bash
api/scripts/rollback-production.sh \
  "$AZURE_RESOURCE_GROUP" \
  "$API_WEBAPP_NAME" \
  "$WEB_WEBAPP_NAME" \
  /path/to/previous/turnkeyops-api.zip \
  /path/to/previous/turnkeyops-web.zip \
  "$API_BASE_URL" \
  "$WEB_BASE_URL" \
  rollback-evidence-UTC_TIMESTAMP
```

The script submits both ZIPs with `az webapp deploy --clean true --restart true
--async true --track-status false`, captures each App Service deployment JSON, computes the
artifact hashes, and runs `api/scripts/post-deploy-smoke.sh` as the authoritative
readiness gate. Smoke must pass for
both the API and web surfaces, both public tenant routes, anonymous API denial,
and anonymous admin redirects. A failed smoke run leaves evidence and exits
non-zero; keep the environment in incident state and escalate rather than
claiming recovery.

## Evidence to attach to Hubbsly Ship and TKO-0014

Attach the script output directory and record all of the following in UTC:

```text
Rollback trigger and failing check:
Original production commit / GitHub run / attempt:
Previous healthy commit / GitHub run / attempt:
Previous healthy artifact name:
API artifact SHA-256:
Web artifact SHA-256:
API App Service deployment id:
Web App Service deployment id:
Rollback start UTC:
Rollback end UTC:
Rollback smoke result: PASS / FAIL
Rollback smoke log:
Hubbsly Ship release/deployment id:
Incident owner and follow-up:
```

The release owner closes the incident only after the rollback smoke log is PASS,
production URLs and anonymous admin redirects are rechecked, both deployment JSON
files are attached, and Hubbsly Ship records the final outcome. Preserve the
original failed-release evidence alongside the rollback evidence for the release
retention period. This procedure is intentionally operational; it does not
attempt a production deployment itself.
