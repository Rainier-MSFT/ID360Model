# RouteTest Project Summary

## ✅ Project Created Successfully

The RouteTest project has been created at `C:\Git\IAM_Tools\RouteTest` to help troubleshoot routing issues with the ID360 project.

## 📁 Project Structure

```
RouteTest/
├── 📄 README.md                    # Detailed project documentation
├── 📄 QUICKSTART.md                # Step-by-step setup guide
├── 📄 PROJECT_SUMMARY.md           # This file
├── 📄 package.json                 # npm configuration
├── 📄 staticwebapp.config.json     # SWA routing configuration
├── 📄 .gitignore                   # Git ignore rules
│
├── 🔧 PowerShell Scripts:
│   ├── create-azure-resources.ps1  # Creates Azure SWA & resources
│   ├── deploy-azure.ps1            # Deploys to existing Azure SWA
│   └── test-local.ps1              # Starts local dev server
│
├── 🌐 webapp/                      # Static web app frontend
│   ├── index.html                  # Main page with interactive API tests
│   ├── about.html                  # About page
│   └── test.html                   # Simple test page
│
└── ⚡ server/                      # Azure Functions backend
    ├── host.json                   # Function App configuration
    ├── local.settings.json         # Local settings
    ├── profile.ps1                 # PowerShell profile
    ├── requirements.psd1           # PowerShell dependencies
    │
    ├── hello/                      # GET /api/hello
    │   ├── function.json
    │   └── run.ps1
    │
    ├── echo/                       # POST /api/echo
    │   ├── function.json
    │   └── run.ps1
    │
    ├── query/                      # GET /api/query
    │   ├── function.json
    │   └── run.ps1
    │
    ├── users/                      # GET /api/users/{id}
    │   ├── function.json
    │   └── run.ps1
    │
    └── error/                      # GET /api/error
        ├── function.json
        └── run.ps1
```

## 🎯 Purpose

This test project is designed to:

1. **Isolate routing issues** - Create a minimal reproducible environment
2. **Test API routing** - Verify different route patterns work correctly
3. **Compare configurations** - Identify differences with ID360 project
4. **Validate deployment** - Ensure Azure SWA + Functions integration works

## 🧪 API Endpoints for Testing

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/hello` | GET | Simple GET request test |
| `/api/echo` | POST | Request body echo test |
| `/api/query` | GET | Query parameter handling |
| `/api/users/{id}` | GET | Route parameter test |
| `/api/error` | GET | Error handling test |

## 🚀 Quick Start (3 Steps)

### Step 1: Test Locally (Recommended)

```powershell
cd C:\Git\IAM_Tools\RouteTest
.\test-local.ps1
```

Then open `http://localhost:4280` and click the test buttons.

### Step 2: Create Azure Resources

```powershell
.\create-azure-resources.ps1
```

This creates:
- Resource Group: `IAM-RA` (if doesn't exist)
- Static Web App: `RouteTest`
- Retrieves deployment token

### Step 3: Deploy to Azure

```powershell
.\deploy-azure.ps1
```

Then test at your Azure URL (shown in script output).

## 📋 Azure Configuration

- **Subscription ID:** `c3332e69-d44b-4402-9467-ad70a23e02e5`
- **Resource Group:** `IAM-RA`
- **Static Web App:** `RouteTest`
- **Function App:** `RouteTestFA` (integrated with SWA)
- **Location:** `centralus`
- **SKU:** `Free`

## 🔍 What to Test

### Frontend Tests (via UI)
1. Navigate between pages (Home, About, Test)
2. Verify URLs work correctly
3. Test all API endpoints using the buttons
4. Check browser console for errors

### API Tests (automated via UI)
- ✅ Simple GET request
- ✅ POST with JSON body
- ✅ Query parameters
- ✅ Route parameters
- ✅ Error responses

### Routing Tests
- Static HTML file routing
- API endpoint routing
- 404 handling
- Navigation fallback

## 🔧 Troubleshooting Workflow

1. **Verify local works first**
   - If local fails, it's a code/config issue
   - If local works, it's a deployment issue

2. **Check Azure deployment**
   - Verify files deployed correctly
   - Check Application Insights logs
   - Compare configurations

3. **Compare with ID360**
   - Use working RouteTest as reference
   - Document differences
   - Apply fixes incrementally

## 📊 Comparison Checklist

When comparing with ID360, check:

### Configuration Files
- [ ] `staticwebapp.config.json` routing rules
- [ ] `server/host.json` settings
- [ ] Function `function.json` routes
- [ ] Function `authLevel` settings

### Directory Structure
- [ ] Folder naming (case sensitivity)
- [ ] Relative paths
- [ ] File locations

### Code Differences
- [ ] PowerShell version requirements
- [ ] Response formats
- [ ] Error handling patterns
- [ ] Authentication/authorization

### Deployment Settings
- [ ] App location path
- [ ] API location path
- [ ] Build commands
- [ ] Output location

## 📚 Documentation Files

- **README.md** - Comprehensive project documentation
- **QUICKSTART.md** - Step-by-step setup and troubleshooting
- **PROJECT_SUMMARY.md** - This overview document

## 🛠️ Prerequisites

Required software (check QUICKSTART.md for installation links):
- Node.js (v16+)
- Azure CLI
- Azure Functions Core Tools (v4)
- PowerShell 7.4+
- npm

## 💡 Tips

1. **Start simple** - Test locally before Azure deployment
2. **Incremental changes** - Add ID360 features one at a time
3. **Compare logs** - Use Application Insights to compare behavior
4. **Document findings** - Note what works vs. what doesn't
5. **Keep this working** - Don't modify RouteTest until you understand ID360's issue

## 🎓 Learning from RouteTest

Once you identify the routing issue:

1. Document the root cause
2. Create a fix for ID360
3. Test the fix in RouteTest first
4. Apply to ID360 with confidence
5. Keep RouteTest as a reference/test project

## 📞 Next Actions

1. ✅ Project created ← **YOU ARE HERE**
2. ⏭️ Test locally: `.\test-local.ps1`
3. ⏭️ Verify all endpoints work
4. ⏭️ Deploy to Azure: `.\create-azure-resources.ps1`
5. ⏭️ Deploy application: `.\deploy-azure.ps1`
6. ⏭️ Compare with ID360 routing configuration
7. ⏭️ Identify and fix the routing issue

## 🔗 Useful Links

- [Azure Static Web Apps Docs](https://aka.ms/swa-docs)
- [Azure Functions PowerShell Docs](https://aka.ms/functions-powershell)
- [SWA CLI Documentation](https://azure.github.io/static-web-apps-cli/)
- [Routing Configuration Reference](https://aka.ms/swa-routes)

---

**Created:** October 31, 2025  
**Purpose:** Troubleshooting routing issues in ID360 project  
**Status:** Ready for testing ✅

