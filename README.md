# TurnKeyOps

Unified TurnKeyOps monorepo for the API, admin, and client applications.

Production deployment and custom-domain setup are documented in
[`docs/production-deployment.md`](docs/production-deployment.md).
The current immutable production handoff is recorded in
[`docs/releases/turnkeyops-prod-580d9a6-20260907T043500Z.md`](docs/releases/turnkeyops-prod-580d9a6-20260907T043500Z.md).

## Structure

```
TurnKeyOps/
├── api/    # ASP.NET Core backend
├── admin/  # Legacy standalone internal-admin client
├── client/ # Multi-tenant public, External Admin, and platform-admin Node app
└── docs/   # Production and architecture documentation
```

## Quick Start

### API
```bash
cd api
dotnet run
# → http://localhost:5178 (Swagger at /swagger)
```

### Admin
```bash
cd admin
npm install
npm run dev
# → http://localhost:5173
```

### Client
```bash
cd client
npm install
npm run dev
```

### Local Storage (Azurite)
```bash
npm install -g azurite
azurite --silent --location .azurite --debug .azurite/debug.log
```

## Notes

- `api/` was consolidated from the previous `turnkeyops-api` repository.
- `admin/` was consolidated from the previous `turnkeyops-client` repository and renamed from `frontend/`.
- `client/` was added from the older `turnkeyops-client` app that contains the public-facing site foundation.
- I did not find a separate local `platform` repository in the workspace during consolidation.
