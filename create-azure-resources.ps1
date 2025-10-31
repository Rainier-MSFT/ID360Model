# Create Azure resources for RouteTest
# This script creates the Static Web App and associated resources in Azure

param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "c3332e69-d44b-4402-9467-ad70a23e02e5",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "IAM-RA",
    
    [Parameter(Mandatory=$false)]
    [string]$StaticWebAppName = "RouteTest",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "centralus",
    
    [Parameter(Mandatory=$false)]
    [string]$Sku = "Free"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Create Azure Resources for RouteTest" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Subscription: $SubscriptionId" -ForegroundColor White
Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor White
Write-Host "  Static Web App: $StaticWebAppName" -ForegroundColor White
Write-Host "  Location: $Location" -ForegroundColor White
Write-Host "  SKU: $Sku" -ForegroundColor White
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
    Write-Host "Resource group created successfully" -ForegroundColor Green
} else {
    Write-Host "Resource group already exists" -ForegroundColor Green
}
Write-Host ""

# Check if Static Web App exists
Write-Host "Checking if Static Web App '$StaticWebAppName' exists..." -ForegroundColor Yellow
$swaExists = az staticwebapp show --name $StaticWebAppName --resource-group $ResourceGroup 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Static Web App does not exist. Creating..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Creating Static Web App with standalone configuration (no GitHub)..." -ForegroundColor Yellow
    
    az staticwebapp create `
        --name $StaticWebAppName `
        --resource-group $ResourceGroup `
        --location $Location `
        --sku $Sku
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to create Static Web App" -ForegroundColor Red
        exit 1
    }
    Write-Host "Static Web App created successfully" -ForegroundColor Green
} else {
    Write-Host "Static Web App already exists" -ForegroundColor Green
}
Write-Host ""

# Get Static Web App details
Write-Host "Retrieving Static Web App details..." -ForegroundColor Yellow
$swaDetails = az staticwebapp show --name $StaticWebAppName --resource-group $ResourceGroup --output json | ConvertFrom-Json

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Azure Resources Created Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Static Web App Details:" -ForegroundColor Yellow
Write-Host "  Name: $($swaDetails.name)" -ForegroundColor White
Write-Host "  Resource Group: $($swaDetails.resourceGroup)" -ForegroundColor White
Write-Host "  Location: $($swaDetails.location)" -ForegroundColor White
Write-Host "  Default Hostname: $($swaDetails.defaultHostname)" -ForegroundColor White
Write-Host "  SKU: $($swaDetails.sku.name)" -ForegroundColor White
Write-Host ""
Write-Host "Your app will be available at: https://$($swaDetails.defaultHostname)" -ForegroundColor Cyan
Write-Host ""

# Get deployment token
Write-Host "Retrieving deployment token..." -ForegroundColor Yellow
$deploymentToken = az staticwebapp secrets list --name $StaticWebAppName --resource-group $ResourceGroup --query "properties.apiKey" -o tsv

if ($LASTEXITCODE -eq 0) {
    Write-Host "Deployment token retrieved successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "To deploy your app, run:" -ForegroundColor Yellow
    Write-Host "  .\deploy-azure.ps1" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Or use the SWA CLI directly:" -ForegroundColor Yellow
    Write-Host "  swa deploy --app-location webapp --api-location server --deployment-token `"$deploymentToken`"" -ForegroundColor Cyan
} else {
    Write-Host "WARNING: Could not retrieve deployment token" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run .\deploy-azure.ps1 to deploy your application" -ForegroundColor White
Write-Host "  2. Visit https://$($swaDetails.defaultHostname) to view your app" -ForegroundColor White
Write-Host "  3. Test the API endpoints from the home page" -ForegroundColor White

