# RouteTest - Azure Static Web App + Function App Testing Project

This is a minimal test project designed to troubleshoot and verify routing behavior in Azure Static Web Apps with integrated Azure Functions.

## Project Information

- **Azure Subscription:** c3332e69-d44b-4402-9467-ad70a23e02e5
- **Resource Group:** IAM-RA
- **Static Web App:** RouteTest
- **Function App:** RouteTestFA

## Project Structure

```
RouteTest/
├── webapp/                 # Static Web App frontend
│   ├── index.html         # Main page with API tests
│   ├── about.html         # About page
│   └── test.html          # Simple test page
├── server/                # Azure Functions backend
│   ├── hello/            # Simple GET endpoint
│   ├── echo/             # POST endpoint that echoes request
│   ├── query/            # Query parameter test
│   ├── users/            # Route parameter test
│   ├── error/            # Error handling test
│   ├── host.json         # Function App configuration
│   ├── requirements.psd1 # PowerShell dependencies
│   └── profile.ps1       # PowerShell profile
├── staticwebapp.config.json  # SWA routing configuration
├── .gitignore
└── README.md
```

## API Endpoints

### GET /api/hello
Simple GET request that returns a JSON response.

### POST /api/echo
Echoes back the request body along with headers and query parameters.

### GET /api/query
Tests query parameter handling. Try: `/api/query?name=Test&value=123`

### GET /api/users/{id}
Tests route parameter handling. Try: `/api/users/123`

### GET /api/error
Returns a 400 Bad Request error for testing error handling.

## Local Development

### Prerequisites
- Azure Functions Core Tools
- PowerShell 7.4+
- Node.js (for Static Web Apps CLI)

### Running Locally

1. Install Azure Static Web Apps CLI:
```bash
npm install -g @azure/static-web-apps-cli
```

2. Start the development server:
```bash
cd C:\Git\IAM_Tools\RouteTest
swa start webapp --api-location server
```

3. Open browser to `http://localhost:4280`

## Deployment

### Using Azure CLI

```bash
# Login to Azure
az login

# Deploy Static Web App (first time)
az staticwebapp create \
  --name RouteTest \
  --resource-group IAM-RA \
  --subscription c3332e69-d44b-4402-9467-ad70a23e02e5 \
  --location centralus \
  --source https://github.com/YOUR_REPO \
  --branch main \
  --app-location "webapp" \
  --api-location "server" \
  --output-location ""
```

### Using GitHub Actions

The Static Web App will automatically create a GitHub Actions workflow when connected to a repository. The workflow will deploy on every push to the main branch.

### Manual Deployment

You can also deploy using the SWA CLI:
```bash
swa deploy --app-location webapp --api-location server --env production
```

## Testing

Open the deployed Static Web App URL and navigate to the home page. The page includes interactive buttons to test all API endpoints:

1. **Test /api/hello** - Verifies basic GET request
2. **Test /api/echo** - Verifies POST with JSON body
3. **Test /api/query** - Verifies query parameter handling
4. **Test /api/users/123** - Verifies route parameter handling
5. **Test /api/error** - Verifies error response handling

Click "Run All Tests" to execute all tests sequentially.

## Routing Configuration

The `staticwebapp.config.json` file configures:
- API routes with anonymous access
- Navigation fallback to index.html
- 404 redirect handling
- Global security headers
- MIME type configuration

## Troubleshooting

### Common Issues

1. **API returns 404**: Check that the `api-location` in deployment matches the folder structure
2. **CORS errors**: Ensure the SWA and Functions are deployed together
3. **Function not found**: Verify function.json route matches the expected endpoint
4. **Authentication issues**: Check authLevel in function.json (set to "anonymous" for testing)

### Debugging

- Check Application Insights for function execution logs
- Use browser DevTools Network tab to inspect requests/responses
- Review GitHub Actions workflow logs for deployment issues
- Check SWA configuration in Azure Portal

## Next Steps

Once routing is verified to work correctly, compare:
1. The staticwebapp.config.json with the original ID360 project
2. The function.json configurations
3. The route definitions and naming conventions
4. Any authentication/authorization differences

This will help identify what's causing routing issues in the main project.

