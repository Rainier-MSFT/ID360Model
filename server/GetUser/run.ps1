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
    
    # Try to get delegated token from EasyAuth headers
    $token = $Request.Headers['X-MS-TOKEN-AAD-ACCESS-TOKEN']
    if (-not $token) {
        $token = $Request.Headers['x-ms-token-aad-access-token']
    }
    
    if ($token) {
        Write-Log "Found delegated token in headers"
        return @{
            token = [string]$token
            type = "delegated"
        }
    }
    
    Write-Log "No delegated token found in headers"
    return $null
}

function Get-ManagedIdentityToken {
    Write-Log "Attempting to get UAMI token..."
    
    try {
        # Get token using managed identity
        $tokenResponse = Invoke-RestMethod `
            -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://graph.microsoft.com/&client_id=$env:MANAGED_IDENTITY_CLIENT_ID" `
            -Headers @{ Metadata = "true" } `
            -Method GET
        
        Write-Log "Successfully obtained UAMI token"
        return @{
            token = $tokenResponse.access_token
            type = "managedIdentity"
        }
    } catch {
        Write-Log "Failed to get UAMI token: $_"
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

if (-not $userPrincipalName) {
    $userPrincipalName = "me"  # Default to current user if no UPN specified
}

$diagnostics = @{
    function = "GetUser"
    timestamp = (Get-Date).ToUniversalTime().ToString("o")
    userPrincipalName = $userPrincipalName
    headers = @{}
}

# Capture relevant headers for diagnostics
if ($Request.Headers) {
    $Request.Headers.Keys | ForEach-Object {
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

# Try to get token (delegated first, then UAMI fallback)
$authInfo = Get-DelegatedTokenFromHeaders -Request $Request
if (-not $authInfo) {
    $authInfo = Get-ManagedIdentityToken
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

