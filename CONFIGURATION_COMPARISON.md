# Configuration Comparison: ID360 vs RouteTest

## Summary

The RouteTest project has been created and configured. While full Azure deployment is pending due to build pipeline issues, we've successfully compared the configurations between ID360 and RouteTest to identify potential routing issues.

## Azure Static Web Apps Found

| Name | URL | Location | SKU | Status |
|------|-----|----------|-----|--------|
| ID360-SWA | https://salmon-grass-059245d03.2.azurestaticapps.net | West Europe | Standard | ✅ Working |
| RouteTest | https://thankful-flower-098363c03.3.azurestaticapps.net | West Europe | Free | ⏳ Deployment Pending |

## Key Configuration Differences

### 1. Authentication & Authorization ⚠️ **CRITICAL DIFFERENCE**

**ID360** (`webapp/staticwebapp.config.json`):
```json
{
  "routes": [
    {
      "route": "/api/*",
      "allowedRoles": ["authenticated"]  // ❌ Requires authentication
    },
    {
      "route": "/*",
      "allowedRoles": ["authenticated"]  // ❌ All routes require auth
    }
  ]
}
```

**RouteTest** (`webapp/staticwebapp.config.json`):
```json
{
  "routes": [
    {
      "route": "/api/*",
      "allowedRoles": ["anonymous"]  // ✅ Public access
    }
  ]
}
```

**Impact**: ID360 requires users to be authenticated for ALL routes including API calls. If authentication fails or isn't configured, all requests will return 401.

---

### 2. IP Restrictions 🔒 **SECURITY**

**ID360** has IP whitelisting:
```json
"networking": {
  "allowedIpRanges": [
    "62.30.200.221/32",
    "193.117.224.186/32",
    "193.117.232.246/32",
    "31.94.66.211/32"
  ]
}
```

**RouteTest**: No IP restrictions

**Impact**: If you're accessing ID360 from an IP not in this list, you'll get blocked even if authenticated.

---

### 3. Authentication Routes

**ID360** includes explicit auth routes:
```json
{
  "route": "/.auth/*",
  "allowedRoles": ["anonymous", "authenticated"]
}
```

**RouteTest**: No auth routes configured

**Impact**: ID360 uses Azure Active Directory authentication. Routes under `/.auth/*` handle login/logout.

---

### 4. Response Overrides

**ID360**:
```json
"responseOverrides": {
  "400": {
    "statusCode": 400,
    "redirect": "/index.html"
  },
  "401": {
    "statusCode": 302,
    "redirect": "/.auth/login/aad"  // Auto-redirect to AAD login
  }
}
```

**RouteTest**:
```json
"responseOverrides": {
  "404": {
    "rewrite": "/index.html",
    "statusCode": 200
  }
}
```

**Impact**: ID360 redirects unauthorized requests to AAD login. RouteTest just shows the homepage for 404s.

---

### 5. Navigation Fallback

**ID360**:
```json
"navigationFallback": {
  "rewrite": "/index.html",
  "exclude": ["/api/*", "/.auth/*"]  // Don't rewrite API/auth routes
}
```

**RouteTest**:
```json
"navigationFallback": {
  "rewrite": "/index.html",
  "exclude": ["/images/*.{png,jpg,gif,ico}", "/css/*", "/js/*"]
}
```

**Impact**: ID360's approach is better - it prevents API routes from falling back to index.html.

---

### 6. Content Security Policy

**ID360** has a comprehensive CSP:
```json
"globalHeaders": {
  "content-security-policy": "default-src 'self'; script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob: https://portal.azure.com; connect-src 'self' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com https://id360-fa.azurewebsites.net https://id360-fa-feature.azurewebsites.net https://login.microsoftonline.com https://login.windows.net https://graph.microsoft.com https://api.github.com"
}
```

**RouteTest** has a minimal CSP:
```json
"globalHeaders": {
  "content-security-policy": "default-src https: 'unsafe-eval' 'unsafe-inline'; object-src 'none'"
}
```

---

## Potential Routing Issues in ID360

Based on the configuration comparison, here are the likely causes of routing issues:

### Issue 1: Authentication Not Configured ⚠️
**Symptom**: API calls return 401 or redirect to login
**Cause**: All routes require `authenticated` role but user isn't logged in
**Solution**: 
- Ensure Azure AD authentication is properly configured in Azure Portal
- Check that users can successfully login via `/.auth/login/aad`
- For testing, temporarily change `allowedRoles` to `["anonymous"]`

### Issue 2: IP Blocking 🔒
**Symptom**: Can't access the site at all, even homepage
**Cause**: Your IP address isn't in the `allowedIpRanges` list
**Solution**:
- Add your current IP to the allowed list
- Or temporarily remove the `networking` section for testing
- Check your current IP: https://whatismyipaddress.com/

### Issue 3: Function App Not Integrated
**Symptom**: API routes return 404
**Cause**: Azure Functions not properly linked to the Static Web App
**Solution**:
- Verify the Function App is linked in Azure Portal > Static Web App > Configuration
- Check Function App is running and accessible
- Verify function.json route definitions match expected URLs

### Issue 4: CORS / CSP Blocking
**Symptom**: API calls blocked by browser
**Cause**: Content Security Policy or CORS restrictions
**Solution**:
- Check browser console for CSP violations
- Ensure Function App URLs are in the CSP `connect-src` list

---

## Testing Checklist for ID360

1. **Authentication Test**:
   ```
   1. Open https://salmon-grass-059245d03.2.azurestaticapps.net
   2. Should redirect to Azure AD login
   3. After login, should show the app
   4. Check browser console for auth errors
   ```

2. **IP Access Test**:
   ```powershell
   # Check your current IP
   Invoke-RestMethod -Uri "https://api.ipify.org"
   
   # Compare with allowed IPs in config
   # If different, you're blocked
   ```

3. **API Routing Test**:
   ```javascript
   // From browser console after logging in:
   fetch('/api/Ping')
     .then(r => r.text())
     .then(console.log)
     .catch(console.error);
   ```

4. **Function App Health Check**:
   ```powershell
   # Check if Function App is running
   Invoke-WebRequest -Uri "https://id360-fa.azurewebsites.net/api/Ping" -UseBasicParsing
   ```

---

## Recommended Next Steps

### Option A: Fix ID360 Routing (Recommended)

1. **Check Authentication Setup**:
   ```powershell
   cd C:\Git\IAM_Tools\ID360
   az staticwebapp show --name ID360-SWA --resource-group IAM-RA --query "{name:name, provider:provider}" -o json
   ```

2. **Verify IP Access**:
   - Get your current IP
   - Add to `allowedIpRanges` if needed
   - Redeploy configuration

3. **Test API Integration**:
   - Check Function App is linked
   - Test direct Function App access
   - Test via Static Web App

### Option B: Deploy RouteTest for Comparison

The RouteTest deployment is stuck in "WaitingForDeployment" due to Azure build pipeline issues. Options:

1. **Wait longer** - Sometimes takes 10-15 minutes
2. **Use GitHub Actions** - More reliable deployment method
3. **Focus on local testing** - Run RouteTest locally to verify it works

To test RouteTest locally:
```powershell
cd C:\Git\IAM_Tools\RouteTest
.\test-local.ps1
# Open http://localhost:4280
```

### Option C: Compare Function Configurations

Check a sample function from each project:

**ID360 Function** (`server/Ping/function.json`):
```powershell
cat C:\Git\IAM_Tools\ID360\server\Ping\function.json
```

**RouteTest Function** (`server/hello/function.json`):
```powershell
cat C:\Git\IAM_Tools\RouteTest\server\hello\function.json
```

Compare:
- `authLevel` settings
- `route` definitions
- HTTP methods
- Binding configurations

---

## Quick Fixes to Try

### Fix 1: Temporarily Disable Authentication (for testing)
Edit `C:\Git\IAM_Tools\ID360\webapp\staticwebapp.config.json`:
```json
{
  "routes": [
    {
      "route": "/api/*",
      "allowedRoles": ["anonymous"]  // Changed from "authenticated"
    },
    {
      "route": "/*",
      "allowedRoles": ["anonymous"]  // Changed from "authenticated"
    }
  ]
}
```

### Fix 2: Remove IP Restrictions (for testing)
Remove the `networking` section entirely from the config file.

### Fix 3: Add Your IP
Get your IP and add it to the `allowedIpRanges` array.

---

## Files Created in RouteTest Project

```
C:\Git\IAM_Tools\RouteTest\
├── webapp/
│   ├── index.html (interactive API test page)
│   ├── about.html
│   ├── test.html
│   └── staticwebapp.config.json ✅
├── server/
│   ├── hello/ (GET test)
│   ├── echo/ (POST test)
│   ├── query/ (query params test)
│   ├── users/ (route params test)
│   ├── error/ (error handling test)
│   └── host.json ✅
├── README.md
├── QUICKSTART.md
├── PROJECT_SUMMARY.md
└── CONFIGURATION_COMPARISON.md (this file)
```

---

## Deployment Status

### RouteTest Deployment Issue

The SWA CLI deployment command completes but the build remains in "WaitingForDeployment" status. This appears to be related to how the Azure build service processes standalone deployments in your subscription.

**Current Status**:
- ✅ Static Web App created: https://thankful-flower-098363c03.3.azurestaticapps.net
- ✅ Deployment token retrieved
- ⏳ Build pending (status: WaitingForDeployment)
- ❌ Content not yet live

**Possible Causes**:
1. Azure build pipeline startup delay (can take 10-15 minutes)
2. SWA CLI compatibility issue with subscription policies
3. Missing build configuration trigger

**Workarounds**:
1. Test locally instead: `cd C:\Git\IAM_Tools\RouteTest && .\test-local.ps1`
2. Use GitHub Actions for deployment
3. Focus on configuration comparison (already completed)

---

## Summary & Conclusion

**Main Finding**: The routing issues in ID360 are most likely caused by:

1. **Authentication Requirements** - All routes require authenticated users
2. **IP Restrictions** - Only specific IPs can access the site
3. **Function App Integration** - May not be properly configured

**Recommendation**: 

Start by checking if you can access ID360-SWA when:
- You're logged in with Azure AD
- You're accessing from an allowed IP address

If not, the configuration needs adjustment based on your requirements.

The RouteTest project serves as a working baseline with minimal restrictions that you can use for comparison and gradual feature addition.

