using namespace System.Net

param($Request, $TriggerMetadata)

Write-Host "Query function triggered"

$queryParams = @{}
foreach ($key in $Request.Query.Keys) {
    $queryParams[$key] = $Request.Query[$key]
}

$body = @{
    message = "Query parameter test"
    timestamp = (Get-Date).ToUniversalTime().ToString("o")
    queryParameters = $queryParams
    url = $Request.Url
} | ConvertTo-Json -Depth 10

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Headers = @{
        "Content-Type" = "application/json"
    }
    Body = $body
})

