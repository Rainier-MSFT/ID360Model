# ID360Model - Azure Static Web App with RBAC & Delegated Authentication

A proof-of-concept project demonstrating advanced authentication patterns in Azure Static Web Apps, including:
- **Role-Based Access Control (RBAC)** with Azure AD app roles
- **Delegated Microsoft Graph API calls** using MSAL.js
- **Hybrid authentication** (delegated + managed identity fallback)
- **Secure token passing** patterns for SWA linked backends

## Quick Start

### Live Demo
🌐 **URL:** https://happy-ocean-02b2c0403.3.azurestaticapps.net

Sign in with your Azure AD account to test:
- Role-based UI sections (Admin, Auditor, SvcDeskAnalyst)
- MSAL.js token acquisition via dedicated redirect page
- Microsoft Graph user lookups with delegated permissions

### Azure Resources
- **Subscription:** c3332e69-d44b-4402-9467-ad70a23e02e5
- **Resource Group:** IAM-RA
- **Static Web App:** ID360Model-SWA
- **Function App:** ID360Model-FA
- **App Registration:** ID360 (1ba30682-63f3-4b8f-9f8c-b477781bf3df)

## Project Structure

```
ID360Model/
├── webapp/
│   ├── index.html                   # Main app with MSAL + RBAC
│   ├── redirect.html                # MSAL redirect handler (CRITICAL!)
│   └── staticwebapp.config.json     # SWA configuration & routes
├── server/
│   ├── GetUser/                     # GET /api/user/{upn} - Graph lookup
│   ├── AdminConfig/                 # GET /api/config/admin - Admin only
│   ├── host.json
│   ├── profile.ps1
│   └── requirements.psd1
├── DOCUMENTATION-DELEGATED-AUTH-SOLUTION.md  # 1,491 lines
├── RBAC-IMPLEMENTATION-COMPLETE.md           # 2,101 lines
├── RISKS-AND-MITIGATIONS.md
└── README.md
```

## Key Features

| Feature | Implementation | Documentation |
|---------|---------------|---------------|
| **RBAC** | Custom `X-User-Roles` header workaround | [RBAC-IMPLEMENTATION-COMPLETE.md](RBAC-IMPLEMENTATION-COMPLETE.md) |
| **Delegated Auth** | MSAL.js + dedicated redirect page | [DOCUMENTATION-DELEGATED-AUTH-SOLUTION.md](DOCUMENTATION-DELEGATED-AUTH-SOLUTION.md) |
| **Hybrid Auth** | Delegated → UAMI fallback | Both documents |
| **Security** | Threat modeling & mitigations | [RISKS-AND-MITIGATIONS.md](RISKS-AND-MITIGATIONS.md) |

## Architecture

### Authentication Flow
```
User → SWA EasyAuth → MSAL.js Token → Role Extraction
                          ↓
    API Request (X-Graph-Token + X-User-Roles headers)
                          ↓
              Backend RBAC Validation
                          ↓
        Microsoft Graph (delegated or UAMI)
```

### RBAC Roles
| Role | Access | Endpoint |
|------|--------|----------|
| **Admin** | Full access | All endpoints |
| **Auditor** | Read-only | `/api/user/*` only |
| **SvcDeskAnalyst** | Service desk | `/api/user/*` only |

💡 **System supports unlimited roles** - see [RBAC guide](RBAC-IMPLEMENTATION-COMPLETE.md#appendix-b-adding-new-roles) for adding more.

### Critical Design Patterns

1. **Dedicated Redirect Page** (`/redirect.html`)
   - **Why:** SWA strips URL fragments, breaking MSAL OAuth flow
   - **Solution:** Dedicated page excluded from navigation fallback
   - **Details:** [URL Stripping Discovery](DOCUMENTATION-DELEGATED-AUTH-SOLUTION.md#phase-5-url-stripping-discovery)

2. **Custom Headers**
   - `X-Graph-Token` - Passes MSAL token to backend
   - `X-User-Roles` - Workaround for missing claims array in linked backends
   - **Details:** [Token Passing](DOCUMENTATION-DELEGATED-AUTH-SOLUTION.md#6-token-passing-strategy)

3. **Client-Side Role Extraction**
   - **Why:** SWA linked backends don't receive full claims array
   - **Solution:** Frontend extracts from `/.auth/me`, passes via header
   - **Details:** [Platform Limitation](RBAC-IMPLEMENTATION-COMPLETE.md#the-platform-limitation)

## API Endpoints

### `GET /api/user/{upn}`
Microsoft Graph user lookup with delegated permissions

**RBAC:** Admin | Auditor | SvcDeskAnalyst  
**Special:** `upn=me` returns signed-in user

```bash
GET /api/user/john.doe@example.com
X-Graph-Token: eyJ0eXAiOiJKV1Qi...
X-User-Roles: ["authenticated","Admin"]
```

### `GET /api/config/admin`
Admin configuration endpoint

**RBAC:** Admin only  
**Returns:** System config, feature flags, statistics

```bash
GET /api/config/admin
X-User-Roles: ["authenticated","Admin"]
```

## Local Development

```bash
# Install prerequisites
npm install -g @azure/static-web-apps-cli

# Start dev server
cd C:\Git\IAM_Tools\ID360Model
swa start webapp --api-location server

# Open http://localhost:4280
```

⚠️ **Note:** Local dev uses emulated auth. For full MSAL/RBAC testing, deploy to Azure.

## Deployment

### Quick Deploy (Azure CLI)
```bash
az staticwebapp create \
  --name ID360Model-SWA \
  --resource-group IAM-RA \
  --subscription c3332e69-d44b-4402-9467-ad70a23e02e5 \
  --sku Standard \
  --location centralus \
  --app-location "webapp" \
  --api-location "server"
```

### GitHub Actions
Auto-deploys on push to `main` branch (workflow created by SWA).

**Configuration:**
- App location: `webapp`
- API location: `server`
- Output location: (empty)

## Configuration Quick Reference

### Required Azure AD Setup
1. **Redirect URI:** `https://{your-swa}.azurestaticapps.net/redirect.html` ⚠️
2. **Token claims:** Include `roles` in ID token
3. **App roles:** Define Admin, Auditor, SvcDeskAnalyst
4. **API permissions:** `User.Read` (delegated), `User.Read.All` (application)

### Required Function App Settings
- `AZURE_CLIENT_ID` - App registration client ID
- `AZURE_CLIENT_SECRET` - Client secret
- `AZURE_TENANT_ID` - Tenant ID
- **UAMI:** ID360-UAMI with Graph `User.Read.All` permission

### Key staticwebapp.config.json Rules
```json
{
  "routes": [
    { "route": "/redirect.html", "allowedRoles": ["anonymous", "authenticated"] },
    { "route": "/api/*", "allowedRoles": ["authenticated"] }
  ],
  "navigationFallback": {
    "exclude": ["/redirect.html"]  // CRITICAL!
  }
}
```

📘 **Full configuration details:** See [Configuration sections](RBAC-IMPLEMENTATION-COMPLETE.md#configuration-files) in documentation.

## Testing

### Test the Live App
1. Sign in at https://happy-ocean-02b2c0403.3.azurestaticapps.net
2. Check browser console for role extraction logs
3. Test based on your assigned role:
   - **Admin:** All sections visible, all endpoints accessible
   - **Auditor:** User lookup only
   - **No roles:** 403 on all endpoints

### Verification Checklist
- [ ] User info displays with correct roles
- [ ] MSAL token acquisition succeeds (check console)
- [ ] `X-User-Roles` header present in Network tab
- [ ] `X-Graph-Token` header present for Graph calls
- [ ] Backend logs show role extraction

📘 **Detailed testing procedures:** See [Testing & Validation](DOCUMENTATION-DELEGATED-AUTH-SOLUTION.md#testing--validation) and [Manual Testing](RBAC-IMPLEMENTATION-COMPLETE.md#manual-testing-procedure).

## Common Gotchas 🚨

| Issue | Impact | Fix |
|-------|--------|-----|
| **Missing `/redirect.html` exclusion** | MSAL infinite loop | Add to `navigationFallback.exclude` |
| **Function authLevel != anonymous** | 401 errors | Set to `"anonymous"` (SWA handles auth) |
| **Route-level RBAC with custom roles** | Always 403 | Use backend validation only |
| **Wrong token audience** | Graph API 403 | Token must be for `https://graph.microsoft.com` |

## Troubleshooting

### Quick Diagnostics

**Roles not appearing?**
1. Check Azure AD role assignment (Enterprise Apps → ID360 → Users)
2. Sign out/in (roles cached in 1-hour token)
3. Verify `X-User-Roles` header in Network tab

**MSAL redirect loop?**
1. Verify `/redirect.html` exists and is deployed
2. Check Azure AD redirect URI matches exactly
3. Clear browser cache + sessionStorage

**Graph API 403?**
1. Decode token at https://jwt.ms - check `aud` and `scp`
2. Verify user has delegated permissions
3. Check admin consent granted

📘 **Detailed troubleshooting:** See [Troubleshooting](RBAC-IMPLEMENTATION-COMPLETE.md#troubleshooting) section (covers 15+ scenarios).

## Documentation

### 📘 [DOCUMENTATION-DELEGATED-AUTH-SOLUTION.md](DOCUMENTATION-DELEGATED-AUTH-SOLUTION.md)
**1,491 lines** - Complete delegated Microsoft Graph authentication guide

**Key sections:**
- [Root Cause Analysis](DOCUMENTATION-DELEGATED-AUTH-SOLUTION.md#root-cause-analysis) - Why SWA's auth doesn't work for Graph
- [URL Stripping Discovery](DOCUMENTATION-DELEGATED-AUTH-SOLUTION.md#phase-5-url-stripping-discovery) - The redirect.html solution
- [Implementation Details](DOCUMENTATION-DELEGATED-AUTH-SOLUTION.md#implementation-details) - Complete code examples
- [Key Learnings](DOCUMENTATION-DELEGATED-AUTH-SOLUTION.md#key-learnings) - 8 critical lessons learned

**TL;DR:** SWA's EasyAuth protects routes but can't acquire delegated tokens. Use MSAL.js + dedicated redirect page.

### 📘 [RBAC-IMPLEMENTATION-COMPLETE.md](RBAC-IMPLEMENTATION-COMPLETE.md)
**2,101 lines** - Complete RBAC implementation for SWA linked backends

**Key sections:**
- [RBAC vs MSAL](RBAC-IMPLEMENTATION-COMPLETE.md#rbac-vs-msal-understanding-dependencies) - They're independent!
- [The Platform Limitation](RBAC-IMPLEMENTATION-COMPLETE.md#the-platform-limitation) - Why custom header is needed
- [Security Analysis](RBAC-IMPLEMENTATION-COMPLETE.md#security-analysis) - Threat modeling
- [Adding New Roles](RBAC-IMPLEMENTATION-COMPLETE.md#appendix-b-adding-new-roles) - Step-by-step guide

**TL;DR:** SWA linked backends don't get full claims array. Frontend extracts roles from `/.auth/me` → passes via `X-User-Roles` header.

### 📘 [RISKS-AND-MITIGATIONS.md](RISKS-AND-MITIGATIONS.md)
Comprehensive security risk analysis

**Covers:**
- Token leakage scenarios
- Session hijacking mitigations
- RBAC bypass attempts
- Monitoring requirements

## Related Projects

This POC project feeds into:
- **ID360** - Production identity management tool

Patterns proven here are being applied to production systems.

## Contributing

This is an internal testing/documentation project.

**For questions:**
1. Check the [comprehensive documentation](#documentation) first
2. Review Function App logs in Azure Portal
3. Compare code patterns between this POC and production

## License

Internal NewDay use only.
