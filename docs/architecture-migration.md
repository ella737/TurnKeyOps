# TurnKeyOps architecture migration

## Target

```text
SvelteKit + Tailwind static applications
                ↓ HTTPS / JSON
          .NET 10 REST API
                ↓
     Services → Mappers → Repositories
                ↓
      Azure Tables / Blobs / Queues
```

The browser applications own presentation and REST calls. Controllers own HTTP concerns only. Business rules live in services, mapping lives in mappers, and persistence lives in repositories.

## Current migration state

### Completed

- Added a browser-safe API client with bearer-token, envelope, error, and API-base handling.
- Synchronized the existing authenticated admin session into the browser token store used by static TurnKeyOps clients.
- Moved BDR estimate-default reads and writes to `GET/PUT /api/admin/estimate-defaults`.
- Removed the `.svelte-kit/local-bdr-estimate-defaults.json` persistence implementation.
- Connected Admin Settings and estimate calculation surfaces to the API-backed defaults.
- Added service-layer validation and tests for estimate defaults.
- Made API CORS origins configuration-driven and included the known local and production client domains.

### Remaining server-owned persistence

- Quote requests and attachments
- Estimate drafts and workflow actions
- Billing settings and invoice workflow state
- Job scheduling and execution state
- Website content
- Contact access overrides
- Bob conversations and operational actions
- Think Pink settings and tenant workflow pages

## Migration baseline

The branded `client/` application currently contains **33** server route
modules, **16** server-only libraries, and **17** modules that expose SvelteKit
form actions. Those are the blockers to `@sveltejs/adapter-static`; an adapter
change before they are removed would make the affected routes fail at runtime.

The first implementation increments are deliberately ordered by blast radius:

1. **Public intake:** move the BDR and Think Pink public quote forms and
   attachment uploads to the existing anonymous API endpoints. Keep validation,
   idempotency IDs, attachment limits, and user-visible retry states in the
   browser.
2. **Public content:** load public tenant content through the existing public
   tenant-settings API, with a bundled safe fallback for initial render.
3. **Authenticated reads and commands:** replace each admin page load/action
   with browser API calls using the existing browser token store. Start with
   isolated tenant settings and contact access, then move estimates, invoices,
   jobs, and Bob.
4. **Authentication:** replace the cookie/session hook and server OTP actions
   with API-issued access and refresh tokens held by the browser client.

Every increment must delete its corresponding `+page.server.ts`,
`+layout.server.ts`, or `+server.ts` module, retain API authorization checks,
and add browser-level coverage before the route is counted as migrated.

## Migration sequence

1. Migrate quote requests and attachments to API services/repositories.
2. Migrate estimate drafts, revisions, sending, and approval workflows.
3. Migrate invoices, payment events, reminders, and job-release rules.
4. Migrate jobs, scheduling, materials, notes, and status workflows.
5. Migrate customers/contact access, calendars, website content, and tenant settings.
6. Migrate Bob conversations/actions and all Think Pink pages to the shared tenant-aware APIs.
7. Replace the server action-based OTP bridge with browser auth using API-issued bearer/refresh tokens.
8. Remove all remaining `+page.server.ts`, `+layout.server.ts`, and local filesystem stores from client applications.
9. Switch the client to `@sveltejs/adapter-static`, add the Static Web Apps fallback configuration, and update the deployment pipeline.

The adapter switch is deliberately last: changing it while server routes and actions remain would produce an application that builds incompletely or loses workflows at runtime.
