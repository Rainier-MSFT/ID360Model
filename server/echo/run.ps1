using namespace System.Net

param($Request, $TriggerMetadata)

Write-Host "Echo function triggered with method: $($Request.Method)"

$requestBody = $null
if ($Request.Body) {
    $requestBody = $Request.Body
}

$body = @{
    message = "Echo endpoint"
    timestamp = (Get-Date).ToUniversalTime().ToString("o")
    method = $Request.Method
    receivedBody = $requestBody
    headers = $Request.Headers
    query = $Request.Query
} | ConvertTo-Json -Depth 10

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Headers = @{
        "Content-Type" = "application/json"
    }
    Body = $body
})

