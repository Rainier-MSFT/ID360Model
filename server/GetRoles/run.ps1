using namespace System.Net

param($Request, $TriggerMetadata)

Write-Host "GetRoles function invoked"

try {
    # This function is called by SWA to determine user roles
    # It should return a JSON object with a "roles" array
    
    $roles = @()
    
    # Try to get roles from x-ms-client-principal first (if already authenticated)
    $clientPrincipalHeader = $Request.Headers['x-ms-client-principal']
    
    if ($clientPrincipalHeader) {
        Write-Host "Found x-ms-client-principal header"
        try {
            $clientPrincipalJson = [System.Text.Encoding]::UTF8.GetString(
                [Convert]::FromBase64String($clientPrincipalHeader)
            )
            $clientPrincipal = $clientPrincipalJson | ConvertFrom-Json
            
            Write-Host "Client principal parsed successfully"
            
            # Extract roles from claims array (where typ == "roles")
            if ($clientPrincipal.claims) {
                Write-Host "Found claims array with $($clientPrincipal.claims.Count) claims"
                
                $roleClaims = $clientPrincipal.claims | Where-Object { $_.typ -eq "roles" }
                if ($roleClaims) {
                    foreach ($roleClaim in $roleClaims) {
                        $roles += $roleClaim.val
                        Write-Host "Found role claim: $($roleClaim.val)"
                    }
                }
            }
            
            # Also check userRoles array (legacy fallback)
            if ($roles.Count -eq 0 -and $clientPrincipal.userRoles) {
                $roles = $clientPrincipal.userRoles | Where-Object { $_ -ne "authenticated" -and $_ -ne "anonymous" }
                Write-Host "Roles from userRoles array: $($roles -join ', ')"
            }
        } catch {
            Write-Host "Error parsing client principal: $_"
        }
    }
    
    # If no roles yet, try to get from Azure AD ID token
    if ($roles.Count -eq 0) {
        $idToken = $Request.Headers['x-ms-token-aad-id-token']
        
        if (-not $idToken) {
            # Try alternate header name
            $idToken = $Request.Headers['X-MS-TOKEN-AAD-ID-TOKEN']
        }
        
        if ($idToken) {
            Write-Host "Found Azure AD ID token, extracting roles..."
            try {
                # Decode JWT (format: header.payload.signature)
                $parts = $idToken.Split('.')
                if ($parts.Length -ge 2) {
                    $payload = $parts[1]
                    
                    # Add padding if needed
                    while ($payload.Length % 4 -ne 0) {
                        $payload += "="
                    }
                    
                    # Decode base64
                    $jsonBytes = [Convert]::FromBase64String($payload)
                    $json = [System.Text.Encoding]::UTF8.GetString($jsonBytes)
                    $claims = $json | ConvertFrom-Json
                    
                    Write-Host "Token claims: $json"
                    
                    # Extract roles claim (can be "roles" or "http://schemas.microsoft.com/ws/2008/06/identity/claims/role")
                    if ($claims.roles) {
                        $roles = $claims.roles
                        Write-Host "Found roles in 'roles' claim: $($roles -join ', ')"
                    } elseif ($claims.'http://schemas.microsoft.com/ws/2008/06/identity/claims/role') {
                        $roles = $claims.'http://schemas.microsoft.com/ws/2008/06/identity/claims/role'
                        Write-Host "Found roles in legacy claim: $($roles -join ', ')"
                    }
                }
            } catch {
                Write-Host "Error parsing ID token: $_"
            }
        }
    }
    
    # Ensure roles is an array (PowerShell sometimes converts single-item arrays to strings)
    if ($roles -isnot [array]) {
        if ($roles) {
            $roles = @($roles)
        } else {
            $roles = @()
        }
    }
    
    # Always include "authenticated" role if we got here
    if ($roles -notcontains "authenticated") {
        $roles += "authenticated"
    }
    
    Write-Host "Final roles: $($roles -join ', ')"
    
    # Return roles in the format SWA expects
    $response = @{
        roles = $roles
    }
    
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body = ($response | ConvertTo-Json -Depth 10)
        Headers = @{
            'Content-Type' = 'application/json'
        }
    })
    
} catch {
    Write-Host "Error in GetRoles: $_"
    
    # Return authenticated role as fallback
    $response = @{
        roles = @("authenticated")
    }
    
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body = ($response | ConvertTo-Json -Depth 10)
        Headers = @{
            'Content-Type' = 'application/json'
        }
    })
}

