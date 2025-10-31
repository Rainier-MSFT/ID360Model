# QuickStart Guide - RouteTest

This guide will help you get the RouteTest project up and running quickly for troubleshooting routing issues.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Node.js** (v16 or later) - [Download](https://nodejs.org/)
- **Azure CLI** - [Download](https://aka.ms/installazurecliwindows)
- **Azure Functions Core Tools** (v4) - [Download](https://aka.ms/azfunc-install)
- **PowerShell 7.4+** - [Download](https://aka.ms/powershell)

## Option 1: Quick Local Testing (Recommended First Step)

Test the project locally before deploying to Azure:

### Step 1: Install Dependencies

```powershell
cd C:\Git\IAM_Tools\RouteTest
npm install
```

### Step 2: Start Local Development Server

```powershell
.\test-local.ps1
```

Or manually:

```powershell
npm start
```

### Step 3: Test the Application

1. Open your browser to `http://localhost:4280`
2. Click the test buttons on the home page
3. Verify all API endpoints respond correctly
4. Check the browser console and terminal for any errors

## Option 2: Deploy to Azure

### Step 1: Create Azure Resources

Run the resource creation script:

```powershell
cd C:\Git\IAM_Tools\RouteTest
.\create-azure-resources.ps1
```

This script will:
- Verify Azure CLI installation
- Login to Azure (if not already logged in)
- Set the correct subscription
- Create the resource group (if it doesn't exist)
- Create the Static Web App

### Step 2: Deploy the Application

```powershell
.\deploy-azure.ps1
```

This script will:
- Verify all prerequisites
- Retrieve the deployment token
- Deploy the application using SWA CLI

### Step 3: Test the Deployed Application

1. Get your Static Web App URL from the script output
2. Open the URL in your browser
3. Run all the API tests from the home page
4. Compare behavior with local testing

## Manual Deployment Steps

If you prefer to do it manually:

### Create the Static Web App

```powershell
az login
az account set --subscription c3332e69-d44b-4402-9467-ad70a23e02e5

az staticwebapp create `
  --name RouteTest `
  --resource-group IAM-RA `
  --location centralus `
  --sku Free
```

### Get Deployment Token

```powershell
$token = az staticwebapp secrets list `
  --name RouteTest `
  --resource-group IAM-RA `
  --query "properties.apiKey" `
  --output tsv
```

### Deploy

```powershell
swa deploy `
  --app-location webapp `
  --api-location server `
  --deployment-token $token `
  --env production
```

## Troubleshooting Local Development

### SWA CLI Not Starting

If the SWA CLI fails to start:

1. Check that Azure Functions Core Tools is installed:
   ```powershell
   func --version
   ```

2. Verify the paths are correct:
   - `webapp` folder exists
   - `server` folder exists with function folders

3. Check for port conflicts (default is 4280)

### Functions Not Working

If API endpoints return 404:

1. Verify PowerShell version:
   ```powershell
   $PSVersionTable.PSVersion
   ```
   Should be 7.4 or later

2. Check function.json files are valid JSON

3. Verify the `server/host.json` exists

4. Look for errors in the terminal where SWA CLI is running

### CORS Errors

CORS should not be an issue when using SWA CLI locally or when deployed to Azure SWA, as the API and app are served from the same domain.

If you see CORS errors:
- Ensure you're accessing via the SWA CLI URL (localhost:4280), not directly opening the HTML file
- Check that staticwebapp.config.json is in the root directory

## Troubleshooting Azure Deployment

### Deployment Token Issues

If deployment fails with authentication errors:

```powershell
# Re-login to Azure
az logout
az login

# Get fresh deployment token
az staticwebapp secrets list `
  --name RouteTest `
  --resource-group IAM-RA `
  --query "properties.apiKey" `
  --output tsv
```

### Functions Not Working in Azure

If API endpoints work locally but not in Azure:

1. Check Application Insights logs in Azure Portal
2. Verify the API location in Azure Portal > Static Web App > Configuration
3. Check that all function.json files were deployed
4. Verify PowerShell runtime version in Function App settings

### 404 Errors on Routes

If you get 404 on certain routes:

1. Check `staticwebapp.config.json` routing rules
2. Verify API routes match function.json route definitions
3. Check that files are in the correct directories

## Comparing with ID360 Project

Once RouteTest is working, compare these aspects with your ID360 project:

### Configuration Files

Compare:
- `staticwebapp.config.json` - routing rules, fallbacks
- `server/host.json` - runtime settings, extensions
- Function `function.json` files - routes, auth levels

### Directory Structure

Verify:
- Relative paths match
- Folder names are consistent
- No case sensitivity issues

### Function Implementation

Check:
- PowerShell version consistency
- Binding patterns
- Route parameter syntax
- Response format

### Authentication

Compare:
- Auth levels in function.json
- staticwebapp.config.json route rules
- Any authentication middleware

## Next Steps

After verifying RouteTest works:

1. Document the differences between RouteTest and ID360
2. Incrementally apply ID360 features to RouteTest
3. Test after each change to identify what breaks routing
4. Apply the fix back to ID360

## Getting Help

If you encounter issues:

1. Check the terminal output for error messages
2. Review browser console for client-side errors
3. Check Application Insights in Azure Portal
4. Compare with working RouteTest configuration
5. Review Azure Static Web Apps documentation: https://aka.ms/swa-docs

## Useful Commands

```powershell
# View SWA CLI version
swa --version

# View Azure Functions version
func --version

# Check Azure login
az account show

# List Static Web Apps in resource group
az staticwebapp list --resource-group IAM-RA --output table

# View logs (if functions deployed separately)
az functionapp logs tail --name RouteTestFA --resource-group IAM-RA

# Delete resources when done testing
az staticwebapp delete --name RouteTest --resource-group IAM-RA
```

