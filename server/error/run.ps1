using namespace System.Net

param($Request, $TriggerMetadata)

Write-Host "Error function triggered"

$body = @{
    error = "This is a test error"
    message = "Testing error handling"
    timestamp = (Get-Date).ToUniversalTime().ToString("o")
} | ConvertTo-Json

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::BadRequest
    Headers = @{
        "Content-Type" = "application/json"
    }
    Body = $body
})

