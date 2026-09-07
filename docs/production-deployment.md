# TurnKeyOps production deployment

TurnKeyOps uses one multi-tenant SvelteKit Node application and one ASP.NET
Core API. The web application resolves the tenant and surface from the request
hostname; do not create separate BDR and Think Pink builds.

## Production surfaces

| Hostname | Application route | Purpose |
| --- | --- | --- |
| `turnkeyops.ai` | `/turnkeyops/public` | TurnKeyOps public site |
| `www.turnkeyops.ai` | `/turnkeyops/public` | Public-site alias |
| `admin.turnkeyops.ai` | `/turnkeyops/admin` | Platform administration |
| `thinkpinklc.com` | `/thinkpink/public` | Think Pink public site |
| `www.thinkpinklc.com` | `/thinkpink/public` | Public-site alias |
| `admin.thinkpinklc.com` | `/thinkpink/admin` | Think Pink External Admin |
| `bdrconcrete.com` | `/bdr/public` | BDR public site |
| `www.bdrconcrete.com` | `/bdr/public` | Public-site alias |
| `admin.bdrconcrete.com` | `/bdr/admin` | BDR External Admin |

Hostname routing is defined in `client/src/lib/config/domains.ts`. External
Admin tenant configuration is defined in
`client/src/lib/config/external-admin.ts`.

## Azure resources

Create these production resources:

1. A Linux App Service Plan using a production tier that supports custom domains and managed certificates.
2. A Node 22 Linux Web App for the SvelteKit application.
3. A .NET 10 Linux Web App for the TurnKeyOps API.
4. A production Azure Storage account for tables, blobs, and queues.
5. Azure Communication Services resources for OTP email and SMS.
6. Application Insights for both web applications.
7. Azure Key Vault for production secrets.

The API and Node application must not use Azurite or `.svelte-kit` local JSON
stores in production.

## Deployment configuration

GitHub Actions and Hubbsly Ship are authoritative. Azure DevOps deployment
definitions are retired and must remain disabled. Configure the `staging` and
`production` GitHub environments with the OIDC secrets and target variables
listed in `docs/release-readiness.md`.

Azure remains the application runtime; it is no longer the release control
plane. GitHub Actions builds and deploys, and Hubbsly Ship initiates and tracks
production releases. No Azure DevOps pipeline, service connection, variable
group, release tag, or manual-validation group is part of this contract.

The Azure federated identity subject must be restricted to the matching GitHub
environment in `MedPACTech/TurnKeyOps`. API secrets belong in Azure App Service
settings or Key Vault references and must never be copied into a GitHub
workflow, repository variable, client bundle, or deployment artifact. The
identity, communications, billing, rotation, disable, rollback, and smoke
contract is in `api/docs/production-integrations.md`.

## Deployment workflows

- Pull-request gate: `.github/workflows/pull-request.yml`
- Reusable quality gate: `.github/workflows/quality-gates.yml`
- Reusable package/deploy workflow: `.github/workflows/deploy.yml`
- Automatic `main` staging deploy: `.github/workflows/deploy-staging.yml`
- Manual `main` production deploy for Hubbsly Ship: `.github/workflows/deploy-production.yml`

Every deployment rebuilds and validates the commit, creates one immutable
API/web artifact bundle named for the SHA, deploys those exact artifacts, runs
post-deployment smoke checks, and publishes deployment evidence. Production
also requires the GitHub environment approval and explicit Ship/UAT/rollback
dispatch inputs.

Linux App Service ZIP deployment submits asynchronously with Azure CLI startup
tracking disabled. The repository-owned smoke script is the authoritative
readiness check and waits up to five minutes by default for each API and web
surface, with `SMOKE_MAX_ATTEMPTS` available for an explicit override.
This avoids Azure CLI 504 false failures when Kudu finishes a OneDeploy package
after the CLI request has timed out.

## First activation checklist

1. Confirm the legacy Azure DevOps definitions are inactive; if none remain,
   record that result as `not applicable` rather than provisioning Azure
   DevOps solely for this audit.
2. Create the `staging` and `production` GitHub environments and configure the
   secrets, variables, OIDC subjects, and production reviewers in
   `docs/release-readiness.md`.
3. Add the required `main` ruleset and its `Required PR validation` check.
4. Connect the repository to Hubbsly Ship and configure the production
   workflow dispatch contract.
5. Merge through the ruleset and retain the first successful staging workflow,
   deployment evidence artifact, and smoke log.
6. Complete UAT, trigger production through Ship, approve the protected GitHub
   environment, and retain the resulting GitHub and Ship identifiers.

## Custom domains and TLS

Add every hostname in the production-surfaces table to the Node Web App. Azure
will provide the verification records.

For each apex domain:

1. Add Azure's `asuid` TXT verification record.
2. Replace the existing apex A record with the Web App inbound IP.

For each `www` and `admin` hostname:

1. Add the Azure `asuid.<subdomain>` TXT verification record when requested.
2. Add a CNAME to the Node Web App default `azurewebsites.net` hostname.

After Azure validates each hostname, create and bind an App Service managed
certificate. Keep the existing A2 Hosting and Namecheap records in place until
the Azure default hostname and all custom-domain validations pass.

## Release verification

Before changing DNS:

1. Confirm `Required PR validation` passed for the exact merge commit.
2. Confirm the staging deployment and its published smoke artifact passed.
3. Verify the Web App default hostname using explicit `Host` headers for all production domains.
4. Confirm each public hostname returns `200`.
5. Confirm each admin hostname redirects an anonymous browser to `/auth/login` with the correct tenant return path.
6. Submit one test request per tenant and confirm it appears only in that tenant's External Admin.
7. Complete an OTP login for each admin hostname.
8. Verify uploaded files persist after an App Service restart.
9. Complete the UAT template and create the Hubbsly Ship release record.

## DNS cutover

Lower DNS TTLs at least several hours before cutover. Change one public domain
at a time, verify TLS and form submission, and then add its admin subdomain. Do
not remove the previous hosting configuration until the new deployment has
remained healthy through the rollback window.
