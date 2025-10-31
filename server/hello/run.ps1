using namespace System.Net

param($Request, $TriggerMetadata)

Write-Host "Hello function triggered"

$body = @{
    message = "Hello from Azure Functions!"
    timestamp = (Get-Date).ToUniversalTime().ToString("o")
    function = "hello"
    method = $Request.Method
    url = $Request.Url
} | ConvertTo-Json

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Headers = @{
        "Content-Type" = "application/json"
    }
    Body = $body
})

