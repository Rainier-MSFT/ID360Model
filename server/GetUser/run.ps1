using namespace System.Net
param($Request, $TriggerMetadata)

function Write-Log {
    param([string]$Message)
    try { 
        Write-Information $Message -InformationAction Continue 
    } catch { 
        try { Write-Host $Message } catch {} 
    }
}

function Get-DelegatedTokenFromHeaders {
    param($Request)
    
    # Try to get delegated token from EasyAuth headers (multiple possible header names)
    $token = $Request.Headers['X-MS-TOKEN-AAD-ACCESS-TOKEN']
    if (-not $token) {
        $token = $Request.Headers['x-ms-token-aad-access-token']
    }
    if (-not $token) {
        # SWA can pass token as x-ms-auth-token with "Bearer " prefix
        $authHeader = $Request.Headers['x-ms-auth-token']
        if ($authHeader) {
            $token = $authHeader -replace '^Bearer\s+', ''
        }
    }
    if (-not $token) {
        $authHeader = $Request.Headers['X-MS-AUTH-TOKEN']
        if ($authHeader) {
            $token = $authHeader -replace '^Bearer\s+', ''
        }
    }
    
    if (-not $token) {
        Write-Log "No delegated token found in headers"
        return $null
    }
    
    Write-Log "Found SWA auth token, attempting OBO exchange for Graph token..."
    
    # Exchange SWA token for Microsoft Graph token using On-Behalf-Of flow
    $clientId = $env:AZURE_CLIENT_ID
    $clientSecret = $env:AZURE_CLIENT_SECRET  
    $tenantId = $env:AZURE_TENANT_ID
    
    if (-not $clientId -or -not $clientSecret -or -not $tenantId) {
        Write-Log "Missing OBO credentials (AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, or AZURE_TENANT_ID)"
        return @{
            token = [string]$token
            type = "delegated_noOBO"
            warning = "SWA token found but cannot exchange for Graph token - missing OBO credentials"
        }
    }
    
    try {
        $tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
        $body = @{
            grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer"
            client_id = $clientId
            client_secret = $clientSecret
            assertion = $token
            scope = "https://graph.microsoft.com/.default"
            requested_token_use = "on_behalf_of"
        }
        
        $response = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -Body $body -ContentType "application/x-www-form-urlencoded" -ErrorAction Stop
        
        if ($response.access_token) {
            Write-Log "Successfully exchanged SWA token for Graph token via OBO"
            return @{
                token = $response.access_token
                type = "delegated_OBO"
            }
        }
    } catch {
        $errorDetails = $null
        $statusCode = $null
        
        # Try to extract detailed error from response
        if ($_.ErrorDetails.Message) {
            try {
                $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json
                $statusCode = $_.Exception.Response.StatusCode.value__
            } catch {
                $errorDetails = $_.ErrorDetails.Message
            }
        } else {
            $errorDetails = $_.Exception.Message
        }
        
        Write-Log "OBO token exchange failed: $errorDetails"
        return @{
            token = [string]$token
            type = "delegated_OBOFailed"
            error = $_.Exception.Message
            errorDetails = $errorDetails
            statusCode = $statusCode
        }
    }
    
    return @{
        token = [string]$token
        type = "delegated_noExchange"
    }
}

function Get-ManagedIdentityToken {
    Write-Log "Attempting to get UAMI token..."
    
    try {
        # Method 1: Try using managed identity HTTP endpoint
        $tokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://graph.microsoft.com/"
        if ($env:MANAGED_IDENTITY_CLIENT_ID) {
            $tokenUri += "&client_id=$env:MANAGED_IDENTITY_CLIENT_ID"
        }
        
        $tokenResponse = Invoke-RestMethod `
            -Uri $tokenUri `
            -Headers @{ Metadata = "true" } `
            -Method GET `
            -TimeoutSec 5
        
        Write-Log "Successfully obtained UAMI token via metadata endpoint"
        return @{
            token = $tokenResponse.access_token
            type = "managedIdentity"
        }
    } catch {
        Write-Log "Failed to get UAMI token via metadata: $_"
        
        # Method 2: Try using environment variable (Azure Functions can provide this)
        try {
            if ($env:MSI_ENDPOINT -and $env:MSI_SECRET) {
                Write-Log "Trying MSI_ENDPOINT method..."
                $tokenAuthURI = "$($env:MSI_ENDPOINT)?resource=https://graph.microsoft.com/&api-version=2019-08-01"
                if ($env:MANAGED_IDENTITY_CLIENT_ID) {
                    $tokenAuthURI += "&client_id=$env:MANAGED_IDENTITY_CLIENT_ID"
                }
                
                $tokenResponse = Invoke-RestMethod `
                    -Method Get `
                    -Headers @{"X-IDENTITY-HEADER"=$env:MSI_SECRET} `
                    -Uri $tokenAuthURI
                
                Write-Log "Successfully obtained UAMI token via MSI_ENDPOINT"
                return @{
                    token = $tokenResponse.access_token
                    type = "managedIdentity_MSI"
                }
            }
        } catch {
            Write-Log "Failed MSI_ENDPOINT method: $_"
        }
        
        return $null
    }
}

function Invoke-GraphRequest {
    param(
        [string]$AccessToken,
        [string]$Uri
    )
    
    try {
        $headers = @{
            "Authorization" = "Bearer $AccessToken"
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-RestMethod -Uri $Uri -Headers $headers -Method GET
        return @{
            success = $true
            data = $response
        }
    } catch {
        return @{
            success = $false
            error = $_.Exception.Message
            statusCode = $_.Exception.Response.StatusCode.value__
        }
    }
}

# Main logic
Write-Log "GetUser function triggered"

# Get user principal name from route or query
$userPrincipalName = $Request.Params.userPrincipalName
if (-not $userPrincipalName) {
    $userPrincipalName = $Request.Query.userPrincipalName
}

# Default to "me" if no UPN specified
if (-not $userPrincipalName -or $userPrincipalName -eq "") {
    $userPrincipalName = "me"
}

$diagnostics = @{
    function = "GetUser"
    timestamp = (Get-Date).ToUniversalTime().ToString("o")
    userPrincipalName = $userPrincipalName
    headers = @{}
    allHeaders = @()
}

# Capture ALL headers for full diagnostics
if ($Request.Headers) {
    $Request.Headers.Keys | ForEach-Object {
        $diagnostics.allHeaders += $_
        if ($_ -like "*token*" -or $_ -like "*auth*" -or $_ -like "x-ms-*") {
            $value = $Request.Headers[$_]
            if ($value -and $value.ToString().Length -gt 50) {
                $diagnostics.headers[$_] = $value.ToString().Substring(0, 50) + "..."
            } else {
                $diagnostics.headers[$_] = $value
            }
        }
    }
}

# Decode the x-ms-auth-token to see what's actually in it
$authToken = $Request.Headers['x-ms-auth-token']
if ($authToken) {
    $tokenWithoutBearer = $authToken -replace '^Bearer\s+', ''
    $parts = $tokenWithoutBearer.Split('.')
    if ($parts.Length -ge 2) {
        try {
            # Decode JWT payload (second part)
            $payload = $parts[1]
            # Add padding if needed
            while ($payload.Length % 4 -ne 0) { $payload += '=' }
            $payloadBytes = [Convert]::FromBase64String($payload)
            $payloadJson = [System.Text.Encoding]::UTF8.GetString($payloadBytes)
            $tokenClaims = $payloadJson | ConvertFrom-Json
            $diagnostics.tokenClaims = @{
                aud = $tokenClaims.aud
                iss = $tokenClaims.iss
                appid = $tokenClaims.appid
                azp = $tokenClaims.azp
                idp = $tokenClaims.idp
            }
        } catch {
            $diagnostics.tokenDecodeError = $_.Exception.Message
        }
    }
}

# Try to get token in priority order:
# 1. X-Graph-Token from MSAL (true delegated Graph token)
# 2. x-ms-auth-token from SWA (attempt OBO exchange)
# 3. UAMI fallback (app-only)

$graphTokenFromMSAL = $Request.Headers['X-Graph-Token']
if (-not $graphTokenFromMSAL) {
    $graphTokenFromMSAL = $Request.Headers['x-graph-token']
}

if ($graphTokenFromMSAL) {
    Write-Log "Found Graph token from MSAL in X-Graph-Token header"
    $authInfo = @{
        token = [string]$graphTokenFromMSAL
        type = "delegated_MSAL"
    }
} else {
    # Fall back to OBO or UAMI
    $authInfo = Get-DelegatedTokenFromHeaders -Request $Request
    if (-not $authInfo) {
        $authInfo = Get-ManagedIdentityToken
    }
}

if (-not $authInfo) {
    $diagnostics.authMethod = "none"
    $diagnostics.error = "No authentication method available"
    
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = 401
        Body = $diagnostics | ConvertTo-Json -Depth 10
        Headers = @{ "Content-Type" = "application/json" }
    })
    return
}

$diagnostics.authMethod = $authInfo.type

# Add OBO error/warning if present
if ($authInfo.error) {
    $diagnostics.oboError = $authInfo.error
}
if ($authInfo.errorDetails) {
    $diagnostics.oboErrorDetails = $authInfo.errorDetails
}
if ($authInfo.warning) {
    $diagnostics.oboWarning = $authInfo.warning
}

# Validate: "me" only works with delegated auth
if ($userPrincipalName -eq "me" -and $authInfo.type -notlike "*delegated*") {
    $diagnostics.error = "Cannot use 'me' with app-only authentication (UAMI). Please specify a user UPN like 'user@domain.com'"
    $diagnostics.hint = "App-only auth requires explicit user UPN. Delegated auth would allow 'me'."
    
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = 400
        Body = $diagnostics | ConvertTo-Json -Depth 10
        Headers = @{ "Content-Type" = "application/json" }
    })
    return
}

# Call Microsoft Graph
$graphUri = "https://graph.microsoft.com/v1.0/users/$userPrincipalName"
Write-Log "Calling Graph API: $graphUri"

$result = Invoke-GraphRequest -AccessToken $authInfo.token -Uri $graphUri

if ($result.success) {
    $diagnostics.graphCallSuccess = $true
    $diagnostics.user = @{
        displayName = $result.data.displayName
        userPrincipalName = $result.data.userPrincipalName
        id = $result.data.id
        mail = $result.data.mail
        jobTitle = $result.data.jobTitle
    }
    
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = 200
        Body = $diagnostics | ConvertTo-Json -Depth 10
        Headers = @{ "Content-Type" = "application/json" }
    })
} else {
    $diagnostics.graphCallSuccess = $false
    $diagnostics.graphError = $result.error
    $diagnostics.graphStatusCode = $result.statusCode
    
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = 500
        Body = $diagnostics | ConvertTo-Json -Depth 10
        Headers = @{ "Content-Type" = "application/json" }
    })
}

