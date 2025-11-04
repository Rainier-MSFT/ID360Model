# ID360Model - Azure Static Web App with RBAC & Delegated Authentication

A proof-of-concept project demonstrating advanced authentication patterns in Azure Static Web Apps, including:
- **Role-Based Access Control (RBAC)** with Azure AD app roles
- **Delegated Microsoft Graph API calls** using MSAL.js
- **Hybrid authentication** (delegated + managed identity fallback)
- **Secure token passing** patterns for SWA linked backends

## Project Information

- **Azure Subscription:** c3332e69-d44b-4402-9467-ad70a23e02e5
- **Resource Group:** IAM-RA
- **Static Web App:** ID360Model-SWA
- **Function App:** ID360Model-FA
- **App Registration:** ID360 (1ba30682-63f3-4b8f-9f8c-b477781bf3df)
- **SWA URL:** https://happy-ocean-02b2c0403.3.azurestaticapps.net

## Key Features

✅ **RBAC Implementation** - Role-based access control using Azure AD app roles  
✅ **Delegated Auth** - Microsoft Graph calls on behalf of signed-in user  
✅ **MSAL.js Integration** - Client-side token acquisition with dedicated redirect page  
✅ **Hybrid Authentication** - Graceful fallback from delegated to managed identity  
✅ **Secure Architecture** - Custom header pattern for SWA linked backends  
✅ **Production Ready** - Comprehensive error handling and logging  

## Project Structure

```
ID360Model/
├── webapp/                           # Static Web App frontend
│   ├── index.html                   # Main app with MSAL + RBAC
│   ├── redirect.html                # MSAL redirect handler (CRITICAL!)
│   └── staticwebapp.config.json    # SWA configuration & routes
├── server/                          # Azure Functions backend (PowerShell 7.4)
│   ├── GetUser/                    # Microsoft Graph user lookup
│   │   ├── function.json           # Route: GET /api/user/{upn}
│   │   └── run.ps1                 # RBAC + delegated/UAMI Graph calls
│   ├── AdminConfig/                # Admin-only configuration endpoint
│   │   ├── function.json           # Route: GET /api/config/admin
│   │   └── run.ps1                 # RBAC: Admin role required
│   ├── host.json                   # Function App configuration
│   ├── requirements.psd1           # PowerShell dependencies
│   └── profile.ps1                 # PowerShell profile & helpers
├── DOCUMENTATION-DELEGATED-AUTH-SOLUTION.md  # Delegated auth guide (1,491 lines)
├── RBAC-IMPLEMENTATION-COMPLETE.md           # RBAC implementation (2,101 lines)
├── RISKS-AND-MITIGATIONS.md                  # Security analysis
├── .gitignore
└── README.md
```

## API Endpoints

### GET /api/user/{upn}
**Description:** Looks up a user in Microsoft Graph  
**Authentication:** Delegated (with managed identity fallback)  
**RBAC:** Requires Admin, Auditor, or SvcDeskAnalyst role  
**Special Cases:**
- `upn=me` - Returns current signed-in user's profile
- Uses `X-Graph-Token` header for delegated calls
- Falls back to UAMI if no delegated token provided

**Example:**
```bash
GET /api/user/john.doe@example.com
X-Graph-Token: eyJ0eXAiOiJKV1QiLCJub25jZSI6...
X-User-Roles: ["authenticated","Admin"]
```

### GET /api/config/admin
**Description:** Returns admin configuration data  
**Authentication:** Required via SWA EasyAuth  
**RBAC:** Requires Admin role only  
**Returns:** System configuration, feature flags, statistics

**Example:**
```bash
GET /api/config/admin
X-User-Roles: ["authenticated","Admin"]
```

## Architecture Overview

### Authentication Flow

```
User Browser
    ↓
1. SWA EasyAuth (Azure AD)
    ↓
2. MSAL.js acquires Graph token
    ↓
3. Frontend extracts roles from /.auth/me
    ↓
4. API call with custom headers:
   - X-Graph-Token (for delegated Graph calls)
   - X-User-Roles (for RBAC)
    ↓
5. Backend validates authentication & roles
    ↓
6. Call Microsoft Graph (delegated or UAMI)
```

### RBAC Roles

The system supports three Azure AD app roles:

| Role | Description | Access Level |
|------|-------------|--------------|
| **Admin** | Full administrative access | All endpoints |
| **Auditor** | Read-only audit access | User lookup only |
| **SvcDeskAnalyst** | Service desk operations | User lookup only |

**Note:** The system supports unlimited custom roles. See `RBAC-IMPLEMENTATION-COMPLETE.md` for how to add more.

### Key Design Patterns

1. **Dedicated Redirect Page** - `/redirect.html` handles MSAL OAuth callback without SWA URL stripping
2. **Custom Headers** - `X-Graph-Token` and `X-User-Roles` pass data to linked backend
3. **Hybrid Authentication** - Graceful fallback from delegated to managed identity
4. **Client-Side Role Extraction** - Workaround for SWA linked backend limitation

## Local Development

### Prerequisites
- Azure Functions Core Tools
- PowerShell 7.4+
- Node.js (for Static Web Apps CLI)
- Azure AD tenant with ID360 app registration
- Assigned app roles in Azure AD

### Running Locally

1. Install Azure Static Web Apps CLI:
```bash
npm install -g @azure/static-web-apps-cli
```

2. Start the development server:
```bash
cd C:\Git\IAM_Tools\ID360Model
swa start webapp --api-location server
```

3. Open browser to `http://localhost:4280`

**Note:** Local development uses emulated authentication. For full MSAL/RBAC testing, deploy to Azure.

## Deployment

### Using Azure CLI

```bash
# Login to Azure
az login

# Deploy Static Web App (first time)
az staticwebapp create \
  --name ID360Model-SWA \
  --resource-group IAM-RA \
  --subscription c3332e69-d44b-4402-9467-ad70a23e02e5 \
  --location centralus \
  --sku Standard \
  --source https://github.com/YOUR_REPO \
  --branch main \
  --app-location "webapp" \
  --api-location "server" \
  --output-location ""

# Link existing Function App (if needed)
az staticwebapp backends link \
  --name ID360Model-SWA \
  --resource-group IAM-RA \
  --backend-resource-id /subscriptions/c3332e69-d44b-4402-9467-ad70a23e02e5/resourceGroups/IAM-RA/providers/Microsoft.Web/sites/ID360Model-FA \
  --backend-region ukwest
```

### Using GitHub Actions

The Static Web App automatically creates a GitHub Actions workflow when connected to a repository. The workflow deploys on every push to the main branch.

**Important Configuration:**
- App location: `webapp`
- API location: `server` (if deploying integrated)
- Output location: (empty)

### Manual Deployment

Deploy using the SWA CLI:
```bash
swa deploy --app-location webapp --api-location server --env production
```

## Testing

Open the deployed Static Web App URL: https://happy-ocean-02b2c0403.3.azurestaticapps.net

The home page includes comprehensive interactive tests:

### Authentication Tests
1. **User Info** - Displays signed-in user and extracted roles
2. **Acquire Graph Token** - Tests MSAL.js token acquisition via redirect.html

### RBAC Tests
3. **Admin API** - Tests Admin-only endpoint (requires Admin role)
4. **Graph User Lookup** - Tests multi-role endpoint (Admin, Auditor, or SvcDeskAnalyst)

### Test Scenarios
- **Test 1:** Sign in as Admin → Should see all sections
- **Test 2:** Sign in as Auditor → Should see user lookup only
- **Test 3:** Sign in as user with no roles → Should get 403 on all endpoints

### Verification
- Check browser console for role extraction logs
- Check Network tab for `X-User-Roles` and `X-Graph-Token` headers
- Verify backend logs in Azure Portal (Function App → Log stream)

## Configuration

### Static Web App Configuration (`webapp/staticwebapp.config.json`)

Key configurations:
- **Authentication:** Azure AD custom identity provider with ID360 app registration
- **Routes:** All routes require authentication except `/redirect.html` and `/.auth/*`
- **Navigation Fallback:** Excludes `/redirect.html` (CRITICAL for MSAL)
- **CSP Headers:** Allows MSAL.js CDN and Azure AD login endpoints
- **401 Redirect:** Automatically redirects to `/.auth/login/aad`

**Important:** Route-level RBAC is NOT used. All API routes allow `authenticated` role, and actual role checking happens in backend functions.

### Azure AD App Registration

Required configuration:
- **Redirect URIs:** `https://happy-ocean-02b2c0403.3.azurestaticapps.net/redirect.html`
- **Token Configuration:** Include `roles` claim in ID token
- **API Permissions:** `User.Read` (delegated), `User.Read.All` (application)
- **App Roles:** Admin, Auditor, SvcDeskAnalyst defined
- **Expose API:** Optional scope for custom scenarios

### Function App Settings

Required app settings:
- `AZURE_CLIENT_ID` - ID360 app registration client ID
- `AZURE_CLIENT_SECRET` - Client secret for OBO flows
- `AZURE_TENANT_ID` - Tenant ID

Managed identity:
- **User-Assigned Managed Identity (UAMI):** ID360-UAMI
- **Permissions:** `User.Read.All` (application permission on Microsoft Graph)

## Troubleshooting

### Issue: Roles Not Appearing

**Symptoms:**
- User has Admin role in Azure AD but gets 403
- Console shows only `['authenticated', 'anonymous']`

**Solutions:**
1. Check role assignment in Azure Portal: Enterprise Applications → ID360 → Users and groups
2. Sign out and back in (roles are in token, which has 1-hour expiration)
3. Check `X-User-Roles` header in Network tab
4. Verify backend logs show "Found X-User-Roles header from frontend"

### Issue: MSAL Redirect Loop

**Symptoms:**
- Infinite redirect between app and Azure AD
- URL fragment with `#code=...` gets stripped

**Solutions:**
1. Verify `/redirect.html` exists and is deployed
2. Check `navigationFallback.exclude` includes `/redirect.html`
3. Ensure redirect URI in Azure AD matches exactly: `https://{your-swa}/redirect.html`
4. Clear browser cache and sessionStorage

### Issue: Graph API 403 Forbidden

**Symptoms:**
- Graph API returns 403 even with valid token
- Works with UAMI but fails with delegated

**Solutions:**
1. Check token audience: Should be `https://graph.microsoft.com`
2. Verify user has required Graph permissions (e.g., `User.Read`)
3. Check admin consent for delegated permissions
4. Decode token at https://jwt.ms to verify scopes

### Issue: Function Returns 401/403

**Symptoms:**
- All API calls fail with 401 or 403
- User is authenticated

**Solutions:**
1. Check `x-ms-client-principal` header exists (view backend logs)
2. Verify function.json has `"authLevel": "anonymous"` (SWA handles auth)
3. Check staticwebapp.config.json routes allow `["authenticated"]`
4. Ensure Function App is properly linked to SWA

### Debugging Tips

**Frontend:**
- Open browser console (F12) to see role extraction logs
- Check Network tab for custom headers: `X-User-Roles`, `X-Graph-Token`
- Visit `/.auth/me` directly to see full claims

**Backend:**
- Enable Log stream in Azure Portal (Function App → Log stream)
- Check Application Insights for detailed traces
- Add verbose logging: `Write-Host "DEBUG: $($variableName)"`

**Common Gotchas:**
- 🚨 **redirect.html MUST be excluded from navigation fallback**
- 🚨 **Function authLevel MUST be anonymous for SWA linked backends**
- 🚨 **Route-level RBAC doesn't work with custom app roles in linked backends**
- 🚨 **Token must have correct audience for target API**

## Documentation

Comprehensive documentation is available in the project root:

### 📘 [DOCUMENTATION-DELEGATED-AUTH-SOLUTION.md](DOCUMENTATION-DELEGATED-AUTH-SOLUTION.md)
**1,491 lines** | Complete guide to delegated Microsoft Graph authentication in SWA

**Covers:**
- Why SWA's built-in auth doesn't work for delegated Graph calls
- MSAL.js implementation with dedicated redirect page pattern
- URL fragment stripping issues and solutions
- Complete code examples and testing procedures
- Token passing strategy (`X-Graph-Token` header)
- On-Behalf-Of (OBO) flow attempts and why they failed

**Key Learning:** SWA's EasyAuth is for protecting routes, not for downstream API authentication.

### 📘 [RBAC-IMPLEMENTATION-COMPLETE.md](RBAC-IMPLEMENTATION-COMPLETE.md)
**2,101 lines** | Complete guide to role-based access control in SWA linked backends

**Covers:**
- Azure platform limitation: SWA linked backends don't receive full claims array
- Workaround solution: Frontend extracts roles from `/.auth/me` → custom header
- Security analysis and threat modeling
- Complete frontend and backend implementation
- RBAC vs MSAL dependencies (they're independent!)
- How to add new roles and functions
- Testing procedures and troubleshooting

**Key Learning:** Custom header workaround is secure because SWA validates all requests.

### 📘 [RISKS-AND-MITIGATIONS.md](RISKS-AND-MITIGATIONS.md)
Comprehensive security risk analysis

**Covers:**
- Token leakage risks
- Session security
- RBAC bypass attempts
- Monitoring and compliance requirements

## Related Projects

This is a **proof-of-concept** project. Lessons learned are being applied to:
- **ID360** - Production identity management tool

## Contributing

This is an internal testing/documentation project. For questions or issues:
1. Review the comprehensive documentation first
2. Check Function App logs in Azure Portal
3. Compare working patterns here with production implementations

## License

Internal NewDay use only.

