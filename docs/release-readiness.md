# TurnKeyOps GitHub Actions and Hubbsly Ship release contract

The current production handoff, artifact hashes, deployment IDs, migration
order, support matrix, observation window, and remaining signoffs are recorded
in `docs/releases/turnkeyops-prod-580d9a6-20260907T043500Z.md`.

## Authoritative automation

GitHub Actions is the only active CI/CD system for TurnKeyOps. Hubbsly Ship
discovers, starts, and monitors the production workflow through the GitHub
Actions API. Azure DevOps deployment YAML has been removed; see
`api/.azure-pipelines/README.md` for the retirement record.

The workflow layout follows the shared deployment pattern used by the Bed
Brigade platform:

| Workflow | Trigger | Purpose |
| --- | --- | --- |
| `pull-request.yml` | pull request to `main` | Stable required check over every quality gate |
| `quality-gates.yml` | reusable only | Repository, API, client, legacy-admin, and Playwright gates |
| `deploy.yml` | reusable only | Validate, create immutable API/web artifacts, deploy, smoke, and publish evidence |
| `deploy-staging.yml` | push to `main` or manual from `main` | Automatic staging deployment |
| `deploy-production.yml` | manual dispatch from `main` only | Hubbsly Ship production entry point |

Both deployment wrappers use concurrency groups with cancellation disabled so
a release cannot be silently replaced mid-deployment. The production wrapper
has no push, pull-request, schedule, or tag trigger.

## Required pull-request policy

Create a GitHub ruleset for `main` that:

1. requires a pull request and an up-to-date branch;
2. requires the `Required PR validation` status check from
   `.github/workflows/pull-request.yml`;
3. blocks force pushes and branch deletion;
4. prevents check bypass except through the documented incident process; and
5. requires approval from the designated release owners for workflow changes.

The stable required job fails unless every reusable gate succeeds. Browser
tests have zero retries. A failure remains visible and publishes Playwright
JUnit, HTML, trace, screenshot, and video evidence; a critical journey must not
be ignored with `continue-on-error`.

| Gate | Published evidence | Blocks merge when |
| --- | --- | --- |
| Repository policy | Scanner/migration log | a tracked secret/PII signature, conflict artifact, whitespace error, or unreviewed relational migration exists |
| API | TRX and dependency report | restore, Release build, a test, or dependency audit fails |
| SvelteKit client | audit/check/session/build output | a high advisory, diagnostic, auth-policy test, or build fails |
| Legacy admin | audit/check/build output | a high advisory, diagnostic, or build fails |
| Critical E2E | JUnit, HTML, traces, screenshots, video | either brand intake, attachment, authorization negative path, mobile, or serious accessibility coverage fails |

## GitHub environments and Azure OIDC

Create `staging` and `production` GitHub environments. Each environment must
define these secrets:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

Each environment must define these non-secret variables:

- `AZURE_RESOURCE_GROUP`
- `API_WEBAPP_NAME`
- `WEB_WEBAPP_NAME`
- `API_BASE_URL`
- `WEB_BASE_URL`

> **Architecture guard:** `WEB_WEBAPP_NAME` currently names the SvelteKit Node App Service used by `client/`. The client still contains server-rendered routes and uses `@sveltejs/adapter-node`; it is not an Azure Static Web App deployment target yet. Do not replace this with a Static Web App until the migration sequence in `docs/architecture-migration.md` is complete. The `admin/` application already uses `@sveltejs/adapter-static`, but it is a separate surface and is not deployed by this reusable workflow.

## Static admin release path

`.github/workflows/deploy-admin-swa.yml` follows the Bed Brigade Static Web App
release shape for the static-ready `admin/` surface only:

- a push to `dev` deploys the admin bundle to the `staging` GitHub environment;
- a manual dispatch from `main` deploys to the protected `production`
  environment and requires a Hubbsly Ship release ID, UAT evidence, and rollback
  reference;
- both environments must provide `VITE_API_URL`, `DEPLOYMENT_URL`, and the
  `AZURE_STATIC_WEB_APPS_API_TOKEN` secret;
- the workflow builds the checked static bundle, carries
  `staticwebapp.config.json` into the artifact directory, uploads that prebuilt
  directory to Azure Static Web Apps, and requires a 200 smoke check.

This workflow must not be used for `client/` until the architecture migration is
complete.

| Setting | Meaning |
| --- | --- |
| `AZURE_RESOURCE_GROUP` | Resource group containing that environment's API and web App Services |
| `API_WEBAPP_NAME` | API App Service name |
| `WEB_WEBAPP_NAME` | SvelteKit Node App Service name |
| `API_BASE_URL` | Public API origin, with no trailing slash |
| `WEB_BASE_URL` | Public web origin, with no trailing slash |

The Azure identity must use workload identity federation restricted to this
repository and the corresponding GitHub environment. Do not create a client
secret for CI. Limit its Azure role assignments to the two App Services and
the settings they require.

Create the federated credentials with these exact subjects:

- `repo:MedPACTech/TurnKeyOps:environment:staging`
- `repo:MedPACTech/TurnKeyOps:environment:production`

The repository or environment must not contain Azure publishing profiles or
long-lived service-principal client secrets. Application credentials remain in
App Service settings or Key Vault and are outside the deployment workflow.

Protect the `production` environment with at least one reviewer who did not
author the change, disallow self-approval, and prevent administrators from
bypassing the deployment protection rule. Staging can deploy automatically
after the required quality workflow passes on `main`.

## Hubbsly Ship integration

Connect the `MedPACTech/TurnKeyOps` repository to Hubbsly Ship with GitHub
Actions read/write and repository contents read access. Configure Ship to use
workflow `deploy-production.yml`, ref `main`, and supply all three dispatch
inputs:

- `ship-release-id`: the immutable Hubbsly deployment/release identifier;
- `uat-evidence`: the Hubbsly card, URL, or record containing approved UAT;
- `rollback-reference`: the previous healthy GitHub run, artifact, or commit.

Ship must record the GitHub Actions run ID and final conclusion. The workflow
also writes the Ship ID, commit SHA, run ID/attempt, UAT reference, and rollback
reference to the GitHub run summary. A non-`main` dispatch is skipped before
the reusable deploy workflow can acquire Azure credentials.

Immediately before dispatch, Ship must verify that the current `main` SHA is
the SHA approved in the UAT record. If `main` moved after UAT, stop and repeat
staging/UAT for the new SHA. The production environment reviewer performs the
same SHA check before approval; the run summary is the authoritative record of
the SHA that actually executed.

## UAT signoff template

```text
Commit:
Required PR validation run:
Staging deployment run:
Immutable artifact name and SHA-256:
Hubbsly Ship release id:
Tester and UTC time:

[ ] BDR public quote with attachment is visible only in BDR admin.
[ ] Think Pink public quote with attachment is visible only in Think Pink admin.
[ ] Duplicate retry preserves one request and one attachment.
[ ] BDR and Think Pink OTP login complete with the expected role.
[ ] Anonymous API/admin and wrong-tenant access fail closed.
[ ] Internal admin health and tenant views load live data.
[ ] Accessibility/mobile critical E2E passed with zero retry.
[ ] Secret, dependency, migration/configuration, and artifact scans passed.
[ ] Previous healthy deployment and rollback artifacts are identified.

Business approver:
Technical approver:
Decision: APPROVE / REJECT
Notes:
```

## Production release and rollback

1. Merge the reviewed commit through the required `main` ruleset.
2. Wait for `Deploy TurnKeyOps - Staging` and its smoke checks to succeed.
3. Complete the UAT record and identify the previous healthy artifact/run.
4. Create a Hubbsly Ship deployment for that exact `main` SHA.
5. Ship dispatches `Deploy TurnKeyOps - Production` with the evidence inputs.
6. The GitHub `production` environment reviewer verifies the SHA, UAT, and
   rollback reference before approving.
7. Preserve the SHA/run/attempt-named release bundle, deployment JSON, smoke log, GitHub run ID, and
   Ship record as card evidence.

| Evidence | Location | Retention |
| --- | --- | --- |
| API tests and dependency audit | `api-test-evidence-*` GitHub artifact | 30 days |
| Critical Playwright output | `critical-e2e-evidence-*` GitHub artifact | 30 days |
| API/web ZIPs and SHA-256 manifest | `turnkeyops-release-*` GitHub artifact | 90 days |
| App Service deployment JSON, manifest, and smoke log | `deployment-evidence-*` GitHub artifact | 90 days |
| SHA, GitHub run/attempt, UAT, rollback, and Ship IDs | GitHub run summary and Hubbsly Ship release | Keep with the TKO-0014/release record |

If the smoke job fails, stop the release. Download the previous healthy API and
web artifacts, redeploy each with `api/scripts/rollback-app-service.sh`, and
rerun `api/scripts/post-deploy-smoke.sh`. Record both commits, artifact hashes,
GitHub run IDs, Hubbsly Ship IDs, App Service deployment IDs, UTC start/end,
the failing check, and the rollback smoke output.

Application state currently uses tenant-partitioned Azure Tables and Blob
Storage rather than relational migrations. If a relational store is added, the
required workflow must gain tested forward and rollback migration jobs before
the first schema change merges.
