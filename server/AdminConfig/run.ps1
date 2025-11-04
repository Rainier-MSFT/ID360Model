using namespace System.Net

param($Request, $TriggerMetadata)

Write-Host "Admin Config function invoked"

# Response object
$responseBody = @{
    function = "AdminConfig"
    timestamp = (Get-Date).ToUniversalTime().ToString("o")
}

try {
    # ================================
    # RBAC: Extract and Validate Roles
    # ================================
    
    # Get client principal from SWA header
    $clientPrincipalHeader = $Request.Headers['x-ms-client-principal']
    
    if (-not $clientPrincipalHeader) {
        Write-Host "❌ No x-ms-client-principal header found - request may not be from SWA"
        $responseBody.error = "Authentication required"
        $responseBody.message = "This endpoint requires authentication via Azure Static Web App"
        
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::Unauthorized
            Body = ($responseBody | ConvertTo-Json -Depth 10)
            Headers = @{ 'Content-Type' = 'application/json' }
        })
        return
    }
    
    # Decode client principal (base64 encoded JSON)
    $clientPrincipalJson = [System.Text.Encoding]::UTF8.GetString(
        [Convert]::FromBase64String($clientPrincipalHeader)
    )
    $clientPrincipal = $clientPrincipalJson | ConvertFrom-Json
    
    # DEBUG: Dump entire client principal structure
    Write-Host "=== CLIENT PRINCIPAL STRUCTURE ==="
    Write-Host "Raw JSON: $clientPrincipalJson"
    Write-Host "Properties: $($clientPrincipal | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)"
    Write-Host "===================================="
    
    # DEBUG: Check for ID token header (might have full claims)
    Write-Host "=== CHECKING FOR ID TOKEN HEADER ==="
    $idTokenHeader = $Request.Headers['x-ms-token-aad-id-token']
    if ($idTokenHeader) {
        Write-Host "✓ Found x-ms-token-aad-id-token header!"
        try {
            # Decode ID token to get claims
            $parts = $idTokenHeader.Split('.')
            if ($parts.Length -ge 2) {
                $payload = $parts[1]
                # Pad if needed
                while ($payload.Length % 4 -ne 0) { $payload += "=" }
                $payload = $payload.Replace('-', '+').Replace('_', '/')
                $jsonBytes = [Convert]::FromBase64String($payload)
                $json = [System.Text.Encoding]::UTF8.GetString($jsonBytes)
                $idTokenClaims = $json | ConvertFrom-Json
                Write-Host "ID Token Claims Properties: $($idTokenClaims | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Out-String)"
            }
        } catch {
            Write-Host "Error decoding ID token: $_"
        }
    } else {
        Write-Host "✗ No x-ms-token-aad-id-token header found"
    }
    Write-Host "====================================="
    
    # Extract roles from userRoles array (default SWA)
    $userRoles = @()
    if ($clientPrincipal.userRoles) {
        Write-Host "DEBUG: userRoles property exists"
        $userRoles = @($clientPrincipal.userRoles)
        Write-Host "DEBUG: userRoles from array: $($userRoles -join ', ')"
    } else {
        Write-Host "DEBUG: NO userRoles property!"
    }
    
    # WORKAROUND: SWA linked backends don't pass full claims array
    # Get roles from frontend via custom header (frontend extracts from /.auth/me)
    $frontendRolesHeader = $Request.Headers['X-User-Roles']
    if ($frontendRolesHeader) {
        Write-Host "DEBUG: Found X-User-Roles header from frontend"
        try {
            $frontendRoles = $frontendRolesHeader | ConvertFrom-Json
            foreach ($role in $frontendRoles) {
                if ($role -and $userRoles -notcontains $role) {
                    $userRoles += $role
                    Write-Host "DEBUG: Added role from frontend header: $role"
                }
            }
        } catch {
            Write-Host "ERROR: Failed to parse X-User-Roles header: $_"
        }
    } else {
        Write-Host "DEBUG: No X-User-Roles header found"
    }
    
    # ALSO extract custom app roles from claims array (where Azure AD puts them)
    Write-Host "DEBUG: Checking for claims array..."
    if ($clientPrincipal.claims) {
        $claimsCount = ($clientPrincipal.claims | Measure-Object).Count
        Write-Host "DEBUG: Found $claimsCount claims"
        
        # Log all claim types for debugging
        Write-Host "DEBUG: All claim types:"
        foreach ($c in $clientPrincipal.claims) {
            if ($c.typ -match 'role') {
                Write-Host "  -> ROLE CLAIM FOUND: typ='$($c.typ)', val='$($c.val)'"
            }
        }
        
        # Extract role claims with multiple strategies
        $roleClaims = @()
        foreach ($claim in $clientPrincipal.claims) {
            $isRoleClaim = $false
            
            # Strategy 1: Exact match
            if ($claim.typ -eq 'roles') {
                Write-Host "DEBUG: Matched 'roles' claim"
                $isRoleClaim = $true
            }
            
            # Strategy 2: Long form exact match
            if ($claim.typ -eq 'http://schemas.microsoft.com/ws/2008/06/identity/claims/role') {
                Write-Host "DEBUG: Matched long-form role claim"
                $isRoleClaim = $true
            }
            
            # Strategy 3: Contains 'role' (case-insensitive)
            if ($claim.typ -match 'role') {
                Write-Host "DEBUG: Matched role pattern: $($claim.typ)"
                $isRoleClaim = $true
            }
            
            if ($isRoleClaim) {
                $roleClaims += $claim
            }
        }
        
        Write-Host "DEBUG: Found $($roleClaims.Count) role claims"
        
        foreach ($claim in $roleClaims) {
            if ($claim.val -and $userRoles -notcontains $claim.val) {
                Write-Host "DEBUG: Adding role: $($claim.val)"
                $userRoles += $claim.val
            }
        }
    } else {
        Write-Host "DEBUG: NO claims array found in clientPrincipal!"
    }
    
    $userIdentity = $clientPrincipal.userDetails
    
    Write-Host "User: $userIdentity"
    Write-Host "Final roles: $($userRoles -join ', ')"
    
    # Store in response for transparency
    $responseBody.user = $userIdentity
    $responseBody.roles = $userRoles
    $responseBody.debug = @{
        clientPrincipalJson = $clientPrincipalJson
        hasClaimsProperty = ($null -ne $clientPrincipal.claims)
        claimsCount = if ($clientPrincipal.claims) { ($clientPrincipal.claims | Measure-Object).Count } else { 0 }
        clientPrincipalProperties = ($clientPrincipal | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)
        hasIdTokenHeader = ($null -ne $Request.Headers['x-ms-token-aad-id-token'])
        availableHeaders = @($Request.Headers.Keys | Where-Object { $_ -like '*token*' -or $_ -like '*principal*' })
    }
    
    # ================================
    # RBAC: Check for Admin Role
    # ================================
    
    if ($userRoles -notcontains "Admin") {
        Write-Host "❌ Access Denied: User does not have Admin role"
        $responseBody.error = "Forbidden"
        $responseBody.message = "This endpoint requires the Admin role"
        $responseBody.requiredRole = "Admin"
        
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::Forbidden
            Body = ($responseBody | ConvertTo-Json -Depth 10)
            Headers = @{ 'Content-Type' = 'application/json' }
        })
        return
    }
    
    Write-Host "✓ User has Admin role - access granted"
    
    # ================================
    # Admin Function Logic
    # ================================
    
    # Return configuration information (admin-only data)
    $responseBody.success = $true
    $responseBody.message = "Admin configuration retrieved successfully"
    $responseBody.config = @{
        environment = "Production"
        version = "1.0.0"
        features = @{
            rbacEnabled = $true
            msalEnabled = $true
            delegatedAuthEnabled = $true
        }
        azure = @{
            subscription = "c3332e69-d44b-4402-9467-ad70a23e02e5"
            resourceGroup = "IAM-RA"
            swa = "ID360Model-SWA"
            functionApp = "ID360Model-FA"
            uami = "ID360-UAMI"
        }
        appRoles = @(
            @{ name = "Admin"; description = "Full admin access" }
            @{ name = "Auditor"; description = "Read-only access" }
            @{ name = "SvcDeskAnalyst"; description = "Service desk operations" }
        )
        statistics = @{
            totalUsers = 42
            activeRoles = 3
            apiVersion = "v1.0"
        }
    }
    
    Write-Host "✓ Admin config returned successfully"
    
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body = ($responseBody | ConvertTo-Json -Depth 10)
        Headers = @{ 'Content-Type' = 'application/json' }
    })
    
} catch {
    Write-Host "❌ Error in Admin Config function: $_"
    $responseBody.error = $_.Exception.Message
    $responseBody.success = $false
    
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::InternalServerError
        Body = ($responseBody | ConvertTo-Json -Depth 10)
        Headers = @{ 'Content-Type' = 'application/json' }
    })
}

