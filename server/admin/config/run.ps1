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
    
    $userRoles = $clientPrincipal.userRoles
    $userIdentity = $clientPrincipal.userDetails
    
    Write-Host "User: $userIdentity"
    Write-Host "Roles: $($userRoles -join ', ')"
    
    # Store in response for transparency
    $responseBody.user = $userIdentity
    $responseBody.roles = $userRoles
    
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

