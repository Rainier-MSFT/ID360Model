using namespace System.Net

param($Request, $TriggerMetadata)

$userId = $Request.Params.id

Write-Host "Users function triggered for user ID: $userId"

$body = @{
    message = "User route parameter test"
    timestamp = (Get-Date).ToUniversalTime().ToString("o")
    userId = $userId
    url = $Request.Url
} | ConvertTo-Json

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Headers = @{
        "Content-Type" = "application/json"
    }
    Body = $body
})

