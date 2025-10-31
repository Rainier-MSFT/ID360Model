# Deploy RouteTest to Azure Static Web App
# This script deploys the RouteTest project to Azure

param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "c3332e69-d44b-4402-9467-ad70a23e02e5",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "IAM-RA",
    
    [Parameter(Mandatory=$false)]
    [string]$StaticWebAppName = "RouteTest",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "centralus"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RouteTest Azure Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Azure CLI is installed
Write-Host "Checking Azure CLI installation..." -ForegroundColor Yellow
$azVersion = az version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Azure CLI is not installed. Please install from https://aka.ms/installazurecliwindows" -ForegroundColor Red
    exit 1
}
Write-Host "Azure CLI is installed" -ForegroundColor Green
Write-Host ""

# Login check
Write-Host "Checking Azure login status..." -ForegroundColor Yellow
$account = az account show 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Not logged in to Azure. Starting login process..." -ForegroundColor Yellow
    az login
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to login to Azure" -ForegroundColor Red
        exit 1
    }
}
Write-Host "Logged in to Azure" -ForegroundColor Green
Write-Host ""

# Set subscription
Write-Host "Setting subscription to: $SubscriptionId" -ForegroundColor Yellow
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to set subscription" -ForegroundColor Red
    exit 1
}
Write-Host "Subscription set successfully" -ForegroundColor Green
Write-Host ""

# Check if resource group exists
Write-Host "Checking if resource group '$ResourceGroup' exists..." -ForegroundColor Yellow
$rgExists = az group exists --name $ResourceGroup
if ($rgExists -eq "false") {
    Write-Host "Resource group does not exist. Creating..." -ForegroundColor Yellow
    az group create --name $ResourceGroup --location $Location
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to create resource group" -ForegroundColor Red
        exit 1
    }
    Write-Host "Resource group created" -ForegroundColor Green
} else {
    Write-Host "Resource group exists" -ForegroundColor Green
}
Write-Host ""

# Check if Static Web App exists
Write-Host "Checking if Static Web App '$StaticWebAppName' exists..." -ForegroundColor Yellow
$swaExists = az staticwebapp show --name $StaticWebAppName --resource-group $ResourceGroup 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Static Web App does not exist. You need to create it first." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To create the Static Web App, run:" -ForegroundColor Cyan
    Write-Host "az staticwebapp create --name $StaticWebAppName --resource-group $ResourceGroup --location $Location" -ForegroundColor White
    Write-Host ""
    Write-Host "After creation, you can deploy using the SWA CLI with the deployment token." -ForegroundColor Yellow
    Write-Host "Get the deployment token with:" -ForegroundColor Cyan
    Write-Host "az staticwebapp secrets list --name $StaticWebAppName --resource-group $ResourceGroup --query properties.apiKey -o tsv" -ForegroundColor White
    exit 1
} else {
    Write-Host "Static Web App exists" -ForegroundColor Green
}
Write-Host ""

# Get deployment token
Write-Host "Retrieving deployment token..." -ForegroundColor Yellow
$deploymentToken = az staticwebapp secrets list --name $StaticWebAppName --resource-group $ResourceGroup --query "properties.apiKey" -o tsv
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to retrieve deployment token" -ForegroundColor Red
    exit 1
}
Write-Host "Deployment token retrieved" -ForegroundColor Green
Write-Host ""

# Check if SWA CLI is installed
Write-Host "Checking SWA CLI installation..." -ForegroundColor Yellow
$swaVersion = swa --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "SWA CLI is not installed. Installing..." -ForegroundColor Yellow
    npm install -g @azure/static-web-apps-cli
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to install SWA CLI" -ForegroundColor Red
        exit 1
    }
    Write-Host "SWA CLI installed" -ForegroundColor Green
} else {
    Write-Host "SWA CLI is installed (version: $swaVersion)" -ForegroundColor Green
}
Write-Host ""

# Deploy
Write-Host "Starting deployment..." -ForegroundColor Yellow
Write-Host "App location: webapp" -ForegroundColor White
Write-Host "API location: server" -ForegroundColor White
Write-Host ""

$env:SWA_CLI_DEPLOYMENT_TOKEN = $deploymentToken
swa deploy --app-location webapp --api-location server --env production --deployment-token $deploymentToken

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Deployment failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Get the Static Web App URL
Write-Host "Retrieving Static Web App URL..." -ForegroundColor Yellow
$swaUrl = az staticwebapp show --name $StaticWebAppName --resource-group $ResourceGroup --query "defaultHostname" -o tsv
if ($LASTEXITCODE -eq 0) {
    Write-Host "Your app is available at: https://$swaUrl" -ForegroundColor Cyan
} else {
    Write-Host "Could not retrieve URL. Check Azure Portal for the URL." -ForegroundColor Yellow
}

