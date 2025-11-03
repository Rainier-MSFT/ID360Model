# RBAC Implementation Guide

**Date:** November 3, 2025  
**Status:** ✅ Deployed (awaiting GitHub Actions)

---

## What Was Implemented

### ✅ Phase 1: Frontend RBAC

**Location:** `webapp/index.html`

**RBAC Module Functions:**
```javascript
fetchUserInfo()       // Fetches user roles from /.auth/me
hasRole(role)         // Check if user has specific role
hasAnyRole([roles])   // Check if user has ANY of specified roles  
hasAllRoles([roles])  // Check if user has ALL specified roles
updateUserInfoDisplay() // Show user identity and role badges
applyRoleBasedUI()    // Show/hide UI elements based on roles
```

**UI Features:**
- **Role Badges**: Color-coded visual indicators
  - 🔴 Admin (red)
  - 🟢 Auditor (green)
  - 🟡 SvcDeskAnalyst (yellow)
- **Dynamic Sections**: Use `data-role="Admin,Auditor"` attribute to show/hide
- **Test Sections**: Role-specific test areas for each role

**Test Functions:**
- `testAdminFunction()` - Admin only
- `testAuditLogs()` - Auditor or Admin
- `testSvcDeskFunction()` - SvcDeskAnalyst or Admin
- `testUserInfo()` - All authenticated users

---

### ✅ Phase 2: SWA Route-Level RBAC

**Location:** `webapp/staticwebapp.config.json`

**Route Configuration:**
```json
{
  "routes": [
    {
      "route": "/api/admin/*",
      "allowedRoles": ["Admin"]
    },
    {
      "route": "/api/user/*",
      "allowedRoles": ["Admin", "Auditor", "SvcDeskAnalyst"]
    },
    {
      "route": "/api/*",
      "allowedRoles": ["authenticated"]
    }
  ]
}
```

**Enforcement:**
- SWA checks roles BEFORE proxying to Function App
- Returns `403 Forbidden` if role not present
- First layer of defense

---

### ✅ Phase 3: Backend Function-Level RBAC

**Admin Endpoint:** `server/admin/config/run.ps1`

**Role Validation Logic:**
```powershell
# 1. Extract x-ms-client-principal header (base64 encoded JSON)
$clientPrincipalJson = [System.Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String($clientPrincipalHeader)
)
$clientPrincipal = $clientPrincipalJson | ConvertFrom-Json
$userRoles = $clientPrincipal.userRoles

# 2. Check for required role
if ($userRoles -notcontains "Admin") {
    return 403 Forbidden
}

# 3. Execute admin logic
return $adminData
```

**GetUser Endpoint:** `server/GetUser/run.ps1`

Added same validation but for multiple roles:
```powershell
$allowedRoles = @("Admin", "Auditor", "SvcDeskAnalyst")
if (no matching role) {
    return 403 Forbidden
}
```

**Defense in Depth:**
- SWA routes (Layer 1) ✅
- Backend validation (Layer 2) ✅
- Logging and audit trail ✅

---

## App Roles (Azure AD)

Already configured in Azure AD app registration (ID360):

| Role | Value | Description | Allowed Members |
|------|-------|-------------|-----------------|
| **Admin** | `Admin` | Full admin access for dev and maintenance | User, Application |
| **Auditor** | `Auditor` | Read-only and export permissions | User |
| **SvcDeskAnalyst** | `SvcDeskAnalyst` | Limited access for frontline service desk (TAP management) | User, Application |
| **NotAllowedClaim** | `NotAllowedClaim` | Test/unused role | User, Application |

---

## How to Assign Roles to Users

### Via Azure Portal

1. **Navigate to App Registration:**
   ```
   Azure Portal → Azure Active Directory → App registrations → ID360
   ```

2. **Go to Enterprise Application:**
   - Click "Managed application in local directory"
   - Or: Azure AD → Enterprise applications → ID360

3. **Assign Users:**
   - Click "Users and groups"
   - Click "+ Add user/group"
   - Select user
   - Select role (Admin, Auditor, or SvcDeskAnalyst)
   - Click "Assign"

### Via Azure CLI

```bash
# Get the service principal (Enterprise App) object ID
$spId = az ad sp list --filter "appId eq '1ba30682-63f3-4b8f-9f8c-b477781bf3df'" --query "[0].id" -o tsv

# Get role IDs
# Admin: 98f189fa-6133-4da8-9adf-1a57a20645fa
# Auditor: aa9d4686-4ecb-4871-bb7a-5fcefa3931ad
# SvcDeskAnalyst: e6959088-040c-4915-9374-1c1aaf07ea71

# Assign Admin role to a user
az ad app role assignment create \
  --resource-id $spId \
  --principal-id <user-object-id> \
  --role-id 98f189fa-6133-4da8-9adf-1a57a20645fa

# Assign Auditor role
az ad app role assignment create \
  --resource-id $spId \
  --principal-id <user-object-id> \
  --role-id aa9d4686-4ecb-4871-bb7a-5fcefa3931ad

# Assign SvcDeskAnalyst role
az ad app role assignment create \
  --resource-id $spId \
  --principal-id <user-object-id> \
  --role-id e6959088-040c-4915-9374-1c1aaf07ea71
```

### Get User Object ID

```bash
# By UPN
az ad user show --id user@newday.co.uk --query id -o tsv

# By display name
az ad user list --filter "displayName eq 'Rainier Amara'" --query "[0].id" -o tsv
```

---

## Testing RBAC

### Wait for Deployment

```bash
# Check GitHub Actions status
# Navigate to: https://github.com/Rainier-MSFT/ID360Model/actions

# Or monitor via CLI
gh run list --repo Rainier-MSFT/ID360Model --limit 1
```

### Test Scenarios

#### 1. **No Role Assigned** (Expected: Minimal Access)

**What you'll see:**
- ❌ "Admin Only Section" hidden
- ❌ "Auditor Section" hidden
- ❌ "Service Desk Section" hidden
- ✅ "All Users Section" visible
- ❌ `/api/admin/config` returns `403 Forbidden`
- ❌ `/api/user/...` returns `403 Forbidden`

**Frontend:**
- Role badges: None displayed (or "No roles assigned")
- UI sections hidden via `data-role` attributes

**Backend:**
- Returns detailed `403` response with required roles

---

#### 2. **Admin Role** (Expected: Full Access)

**Assign role:**
```bash
az ad app role assignment create --resource-id $spId --principal-id <your-user-id> --role-id 98f189fa-6133-4da8-9adf-1a57a20645fa
```

**What you'll see:**
- ✅ Badge: 🔴 **Admin**
- ✅ ALL sections visible
- ✅ `/api/admin/config` returns configuration data
- ✅ `/api/user/me` works (delegated auth with MSAL token)
- ✅ Can access all test functions

**Test:**
1. Navigate to https://happy-ocean-02b2c0403.3.azurestaticapps.net/
2. Look for red "Admin" badge
3. Click "Test Admin API (/api/admin/config)" button
4. Should see JSON with system configuration

---

#### 3. **Auditor Role** (Expected: Read-Only)

**Assign role:**
```bash
az ad app role assignment create --resource-id $spId --principal-id <your-user-id> --role-id aa9d4686-4ecb-4871-bb7a-5fcefa3931ad
```

**What you'll see:**
- ✅ Badge: 🟢 **Auditor**
- ❌ "Admin Only Section" hidden
- ✅ "Auditor Section" visible
- ❌ "Service Desk Section" hidden
- ✅ "All Users Section" visible
- ❌ `/api/admin/config` returns `403 Forbidden`
- ✅ `/api/user/...` works
- ✅ "View Audit Logs" button works

**Test:**
1. Verify green "Auditor" badge
2. Admin section should be hidden
3. Click "View Audit Logs" - should show simulated audit data
4. Try "Test Admin API" if visible - should fail with 403

---

#### 4. **SvcDeskAnalyst Role** (Expected: Service Desk Access)

**Assign role:**
```bash
az ad app role assignment create --resource-id $spId --principal-id <your-user-id> --role-id e6959088-040c-4915-9374-1c1aaf07ea71
```

**What you'll see:**
- ✅ Badge: 🟡 **SvcDeskAnalyst**
- ❌ "Admin Only Section" hidden
- ❌ "Auditor Section" hidden
- ✅ "Service Desk Section" visible
- ✅ "All Users Section" visible
- ❌ `/api/admin/config` returns `403 Forbidden`
- ✅ `/api/user/...` works
- ✅ "Issue Temporary Access Pass" works

**Test:**
1. Verify yellow "SvcDeskAnalyst" badge
2. Click "Issue Temporary Access Pass"
3. Should see simulated TAP code

---

#### 5. **Multiple Roles** (Expected: Union of Permissions)

**Assign multiple:**
```bash
# Assign both Auditor AND SvcDeskAnalyst
az ad app role assignment create --resource-id $spId --principal-id <your-user-id> --role-id aa9d4686-4ecb-4871-bb7a-5fcefa3931ad
az ad app role assignment create --resource-id $spId --principal-id <your-user-id> --role-id e6959088-040c-4915-9374-1c1aaf07ea71
```

**What you'll see:**
- ✅ Badges: 🟢 **Auditor** 🟡 **SvcDeskAnalyst**
- ❌ "Admin Only Section" hidden
- ✅ "Auditor Section" visible
- ✅ "Service Desk Section" visible
- ✅ Both role-specific functions work

---

## Troubleshooting

### Issue: "No roles assigned" despite assigning role in Azure AD

**Solution:**
1. **Sign out and sign back in**
   - Roles are cached in the authentication token
   - Navigate to: `https://happy-ocean-02b2c0403.3.azurestaticapps.net/.auth/logout`
   - Sign in again
   
2. **Verify role assignment:**
   ```bash
   # Check if role is actually assigned
   az ad app role assignment list \
     --id <service-principal-id> \
     --filter "principalId eq '<your-user-object-id>'"
   ```

3. **Check claims in browser:**
   - Open: `https://happy-ocean-02b2c0403.3.azurestaticapps.net/.auth/me`
   - Look for `userRoles` array in the response
   - Should contain your assigned role(s)

---

### Issue: Function returns 403 but role IS assigned

**Check:**
1. **Case sensitivity**: Roles are case-sensitive (`Admin` not `admin`)
2. **Role value vs display name**: Use role VALUE not display name
   - ✅ Correct: `"Admin"`
   - ❌ Wrong: `"Full admin access"` (this is the description)
3. **Backend logs**:
   ```bash
   az functionapp logs tail --name ID360Model-FA --resource-group IAM-RA
   ```
   Look for role validation messages

---

### Issue: UI sections not showing/hiding correctly

**Check:**
1. **Browser console**: `fetchUserInfo()` should log roles
2. **Hard refresh**: Ctrl+Shift+R to clear cache
3. **JavaScript errors**: Check for errors in console
4. **Attribute format**:
   ```html
   <!-- ✅ Correct -->
   <div data-role="Admin,Auditor">...</div>
   
   <!-- ❌ Wrong (no spaces) -->
   <div data-role="Admin, Auditor">...</div>
   ```

---

### Issue: Backend validation not working

**Debug:**
1. **Check header presence**:
   ```powershell
   Write-Host "x-ms-client-principal: $($Request.Headers['x-ms-client-principal'])"
   ```

2. **Decode manually**:
   ```powershell
   $decoded = [System.Text.Encoding]::UTF8.GetString(
       [Convert]::FromBase64String($Request.Headers['x-ms-client-principal'])
   )
   Write-Host "Decoded: $decoded"
   ```

3. **Check SWA-FA link**:
   - Only linked Function Apps receive `x-ms-client-principal`
   - Verify: Azure Portal → SWA → APIs → Should show ID360Model-FA

---

## API Response Examples

### Successful Admin Call

**Request:**
```http
GET /api/admin/config HTTP/1.1
Host: happy-ocean-02b2c0403.3.azurestaticapps.net
x-ms-client-principal: <base64-encoded-with-Admin-role>
```

**Response: 200 OK**
```json
{
  "function": "AdminConfig",
  "timestamp": "2025-11-03T20:55:00.000Z",
  "user": "n19931@newday.co.uk",
  "roles": ["Admin"],
  "success": true,
  "message": "Admin configuration retrieved successfully",
  "config": {
    "environment": "Production",
    "version": "1.0.0",
    "features": {
      "rbacEnabled": true,
      "msalEnabled": true,
      "delegatedAuthEnabled": true
    },
    "azure": {
      "subscription": "c3332e69-d44b-4402-9467-ad70a23e02e5",
      "resourceGroup": "IAM-RA",
      "swa": "ID360Model-SWA",
      "functionApp": "ID360Model-FA",
      "uami": "ID360-UAMI"
    },
    "appRoles": [
      { "name": "Admin", "description": "Full admin access" },
      { "name": "Auditor", "description": "Read-only access" },
      { "name": "SvcDeskAnalyst", "description": "Service desk operations" }
    ],
    "statistics": {
      "totalUsers": 42,
      "activeRoles": 3,
      "apiVersion": "v1.0"
    }
  }
}
```

---

### Forbidden (No Role)

**Request:**
```http
GET /api/admin/config HTTP/1.1
Host: happy-ocean-02b2c0403.3.azurestaticapps.net
x-ms-client-principal: <base64-encoded-with-NO-Admin-role>
```

**Response: 403 Forbidden**
```json
{
  "function": "AdminConfig",
  "timestamp": "2025-11-03T20:55:00.000Z",
  "user": "someuser@newday.co.uk",
  "roles": ["Auditor"],
  "error": "Forbidden",
  "message": "This endpoint requires the Admin role",
  "requiredRole": "Admin"
}
```

---

### Unauthorized (No Auth)

**Request:**
```http
GET /api/admin/config HTTP/1.1
Host: happy-ocean-02b2c0403.3.azurestaticapps.net
(no x-ms-client-principal header)
```

**Response: 401 Unauthorized**
```json
{
  "function": "AdminConfig",
  "timestamp": "2025-11-03T20:55:00.000Z",
  "error": "Authentication required",
  "message": "This endpoint requires authentication via Azure Static Web App"
}
```

---

## Security Considerations

### ✅ What's Protected

1. **Route-level** (SWA): Fast rejection before hitting backend
2. **Function-level**: Defense in depth if SWA bypass attempted
3. **Audit logging**: All role checks logged with user identity
4. **HTTP status codes**: Proper 401 vs 403 responses

### ⚠️ What's NOT Protected (Yet)

1. **Content within pages**: All HTML/JS is publicly downloadable
   - Users can view source code
   - Client-side checks are for UX only
   - Backend is the enforcement point
   
2. **Direct Function App calls**: If someone discovers the FA URL
   - Mitigation: Add IP restrictions or Private Link
   - See RISKS-AND-MITIGATIONS.md for details

3. **Role escalation**: Users can't assign roles to themselves
   - Only Azure AD admins can assign roles
   - But verify your AD permissions are locked down

---

## Next Steps

1. **Assign roles to test users** in Azure AD
2. **Test each role** thoroughly
3. **Review audit logs** in Function App logs
4. **Implement additional endpoints** following the same pattern
5. **Add more granular permissions** if needed (e.g., read vs write within a role)
6. **Consider Phase 3 enhancements:**
   - Custom claims for fine-grained permissions
   - Time-based access (temporary elevations)
   - Conditional access policies
   - Approval workflows for sensitive operations

---

## Rollback Instructions

If RBAC causes issues:

```bash
# Restore from pre-RBAC backup
cd C:\Git\IAM_Tools\ID360Model

# Option 1: File restore
Copy-Item -Path "backups\backup-pre-rbac-20251103-204648\*" -Destination "." -Recurse -Force

# Option 2: Git reset
git log --oneline -10  # Find commit before RBAC
git reset --hard <commit-hash>
git push origin main --force

# Then verify backup restore instructions in:
# backups/backup-pre-rbac-20251103-204648/BACKUP-SUMMARY.md
```

---

## References

- Azure AD App Roles: https://learn.microsoft.com/azure/active-directory/develop/howto-add-app-roles-in-apps
- SWA Authentication: https://learn.microsoft.com/azure/static-web-apps/authentication-authorization
- Role-based Routes: https://learn.microsoft.com/azure/static-web-apps/configuration#securing-routes-with-roles

---

**Document Version:** 1.0  
**Last Updated:** November 3, 2025  
**Status:** Ready for testing once GitHub Actions completes deployment

