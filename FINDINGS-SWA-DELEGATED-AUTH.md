# Azure Static Web Apps - Delegated Authentication Findings

**Date:** 2025-11-01  
**Project:** ID360Model (Test environment for ID360)  
**Issue:** Cannot call Microsoft Graph with delegated (user context) permissions from SWA linked backend

---

## Problem Summary

When Azure Static Web App (SWA) is linked to an Azure Function App (FA) backend, the authentication token passed from SWA to FA cannot be used for On-Behalf-Of (OBO) flow to call Microsoft Graph with delegated permissions.

---

## Investigation Results

### Token Analysis

**What we found in the `x-ms-auth-token` header:**

```json
{
  "iss": "https://happy-ocean-02b2c0403.3.azurestaticapps.net/.auth",
  "aud": "https://id360model-fa.azurewebsites.net",
  "appid": null,
  "idp": null,
  "azp": null
}
```

**Key Facts:**
1. ✅ Token is issued by SWA itself (`.auth` endpoint), NOT Azure AD
2. ✅ Token audience is the Function App backend, NOT Microsoft Graph
3. ✅ Token has no Azure AD claims (no `appid`, no `idp`)
4. ✅ This is NOT an Azure AD access token
5. ✅ Azure AD rejects this token for OBO flow with error `AADSTS50013: Assertion failed signature validation`

### Headers Passed from SWA to Backend

**Complete list of headers:**
- Standard HTTP headers: `accept`, `accept-language`, `cookie`, `host`, `user-agent`, `referer`
- Azure infrastructure: `x-arr-log-id`, `x-site-deployment-id`, `x-forwarded-for`, etc.
- **Authentication**: `x-ms-auth-token` (the SWA-issued token)
- **No Azure AD access token headers found**

### OBO Flow Failure

**Error attempting On-Behalf-Of token exchange:**

```json
{
  "error": "invalid_grant",
  "error_description": "AADSTS50013: Assertion failed signature validation. [Reason - The key was not found.]",
  "error_codes": [50013]
}
```

**Translation:** Azure AD cannot validate the SWA token because Azure AD did not issue it. The signing keys don't match because SWA uses its own signing keys, not Azure AD's.

---

## Research Findings

### Microsoft Documentation
- ✅ Documentation exists for SWA authentication and securing API endpoints
- ✅ Documentation shows how to restrict routes to authenticated users
- ❌ **NO documentation on accessing Azure AD tokens from SWA backends**
- ❌ **NO documentation on calling Microsoft Graph with user context from SWA**
- ❌ **NO configuration options to change what token SWA passes**

### Community Resources
- ✅ [Matt Frear's article](https://mattfrear.com/2024/05/08/authentication-azure-static-web-app-api/) confirms SWA passes its own token to linked backends
- ❌ No Stack Overflow or GitHub examples of Graph + delegated permissions from SWA backends
- ❌ No workarounds or solutions found in community

---

## Technical Explanation

### How SWA Authentication Works

1. User authenticates to SWA using Azure AD (or other provider)
2. SWA creates its own authentication session
3. SWA issues its own JWT token for that session
4. When user calls `/api/*`, SWA proxies to linked backend
5. SWA adds `x-ms-auth-token` header with **SWA's own token** (not Azure AD token)
6. Backend receives SWA token, which proves user is authenticated **to the SWA**

### Why This Fails for Microsoft Graph

1. Microsoft Graph requires Azure AD access tokens
2. To call Graph with user permissions (delegated), you need:
   - An Azure AD access token issued **for Microsoft Graph** (`aud: https://graph.microsoft.com`)
   - Token obtained via user consent to Graph permissions
3. SWA token has `aud: https://id360model-fa.azurewebsites.net` (the Function App)
4. On-Behalf-Of flow requires an Azure AD token as input
5. SWA's token is not an Azure AD token, so OBO fails

### What Works vs What Doesn't

| Scenario | Works? | Explanation |
|----------|--------|-------------|
| User authenticates to SWA | ✅ Yes | SWA built-in auth with Azure AD |
| Backend verifies user is authenticated | ✅ Yes | `x-ms-auth-token` proves authentication |
| Backend knows user identity | ✅ Yes | Token contains user claims |
| Backend calls internal APIs | ✅ Yes | No Azure AD token needed |
| Backend calls Graph (app-only/UAMI) | ✅ Yes | Uses managed identity, no user context |
| Backend calls Graph (delegated/user context) | ❌ **NO** | Requires Azure AD token, not available |
| Backend uses On-Behalf-Of flow | ❌ **NO** | SWA token not valid for OBO |

---

## Current Working Solution (UAMI)

**What we have now:**
- ✅ ID360Model-FA uses User-Assigned Managed Identity (ID360-UAMI)
- ✅ UAMI has Microsoft Graph application permissions
- ✅ Can call Graph with app-only permissions (no user context)
- ✅ Can read any user's data (e.g., `/users/{upn}`)
- ❌ Cannot use `/users/me` (requires user context)
- ❌ Cannot act with user's specific permissions

**Code:** `Get-ManagedIdentityToken` function in `GetUser/run.ps1`

---

## Proposed Solutions

### Option 1: Accept UAMI Limitation (Current)
**Pros:**
- ✅ Already working
- ✅ Simple, no code changes needed
- ✅ Can access all user data with proper Graph permissions

**Cons:**
- ❌ No user context (can't use "me")
- ❌ App acts with full permissions, not user's permissions
- ❌ Audit trails show app, not user

**Best for:** Administrative functions, reporting, bulk operations

---

### Option 2: Unlink SWA and FA
**Description:** Remove the SWA-FA link, implement Azure AD auth directly on Function App, manage CORS manually.

**Pros:**
- ✅ Full control over authentication
- ✅ Can implement OBO flow properly
- ✅ True delegated Graph calls

**Cons:**
- ❌ Lose SWA's automatic proxy and auth injection
- ❌ Must manage CORS configuration
- ❌ More complex authentication setup
- ❌ Frontend calls FA directly (need to handle auth tokens)

**Best for:** Complex scenarios requiring true delegation

---

### Option 3: Frontend Gets Azure AD Token (Recommended Next Step)
**Description:** Use MSAL.js in the frontend to obtain Azure AD access token for Microsoft Graph, pass it to backend explicitly.

**Flow:**
1. User authenticates to SWA (Azure AD) - existing behavior
2. Frontend uses MSAL.js to request Graph access token (user consents)
3. Frontend calls backend API, passing Graph token in custom header (e.g., `X-Graph-Token`)
4. Backend extracts Graph token from header
5. Backend calls Microsoft Graph with user's token (true delegation)

**Pros:**
- ✅ Keep SWA-FA linking (simpler infrastructure)
- ✅ True delegated Graph calls with user context
- ✅ User consents to Graph permissions explicitly
- ✅ Can use `/users/me` and user-scoped permissions
- ✅ Audit trails show actual user

**Cons:**
- ⚠️ Frontend code changes required (add MSAL.js)
- ⚠️ Token management in frontend
- ⚠️ Backend must validate both SWA token (auth) and Graph token (Graph calls)

**Best for:** User-centric operations, delegated permissions, "me" endpoints

---

## Test Environment Details

**Resources Created:**
- SWA: `ID360Model-SWA` (https://happy-ocean-02b2c0403.3.azurestaticapps.net)
- FA: `ID360Model-FA` (https://id360model-fa.azurewebsites.net)
- Storage: `id360modelstorage`
- Linked: ✅ Standard SKU, SWA and FA are linked
- UAMI: ✅ ID360-UAMI assigned to ID360Model-FA
- App Registration: Uses ID360 app (1ba30682-63f3-4b8f-9f8c-b477781bf3df)

**Test Function:**
- `GetUser` at `/api/user/{upn}` or `/api/user/me`
- Tests both delegated (failed) and UAMI (working) authentication
- Returns diagnostics including token claims and headers

---

## Next Steps

**Recommended:** Implement Option 3 (Frontend obtains Graph token)

**Tasks:**
1. ✅ Document findings (this file)
2. ⏳ Create full backup restore point
3. ⏳ Add MSAL.js to frontend
4. ⏳ Configure app registration for Graph permissions
5. ⏳ Update backend to accept Graph token from custom header
6. ⏳ Test delegated Graph calls with user context
7. ⏳ Apply solution to ID360 if successful

---

## References

- [Matt Frear: Add authentication to Azure Static Web App's API](https://mattfrear.com/2024/05/08/authentication-azure-static-web-app-api/)
- [Microsoft Docs: Azure Static Web Apps Authentication](https://learn.microsoft.com/en-us/azure/static-web-apps/authentication-authorization)
- [Microsoft Docs: On-Behalf-Of Flow](https://learn.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-on-behalf-of-flow)
- [AADSTS50013 Error Documentation](https://learn.microsoft.com/en-us/azure/active-directory/develop/reference-aadsts-error-codes)

