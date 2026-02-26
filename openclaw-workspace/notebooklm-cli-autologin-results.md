# NotebookLM CLI Auto-Login Research Results

## Executive Summary

After thorough exploration of NotebookLM CLI authentication mechanisms, this report provides analysis of automation options and recommendations for unattended authentication.

## Current Authentication Flow

### How `nlm login` Works

1. **Auto Mode** (default):
   - Launches Chrome with remote debugging enabled
   - Uses a dedicated Chrome profile stored in `~/.notebooklm-mcp-cli/chrome-profiles/<profile>/`
   - Navigates users to NotebookLM to log in
   - Extracts session cookies via Chrome DevTools Protocol
   - Stores cookies in `~/.notebooklm-mcp-cli/profiles/<profile>/auth.json`

2. **File Mode** (`--manual`):
   - Users manually extract cookies from Chrome DevTools
   - Cookies are provided as a text file
   - Tool parses and imports the cookie string

### Token Storage

**Location**: `~/.notebooklm-mcp-cli/profiles/<profile>/auth.json`

**Contains**:
```json
{
  "cookies": {
    "SID": "...",
    "HSID": "...",
    "SSID": "...",
    "__Secure-1PSID": "...",
    ...
  },
  "csrf_token": "...",
  "session_id": "...",
  "extracted_at": <timestamp>
}
```

### Token Lifetime

| Component | Duration | Refresh Method |
|-----------|----------|----------------|
| Cookies | ~2-4 weeks | Auto-refresh via headless Chrome (if profile exists) |
| CSRF Token | Minutes | Auto-refreshed on request failure |
| Session ID | Per session | Auto-extracted on MCP start |

## Automation Options Assessment

### Option 1: Dedicated Headless Chrome Profile ⭐ RECOMMENDED

**How it works:**
- First authentication: Run `nlm login --profile automation` manually once
- Future runs: Chrome remembers the login in the dedicated profile
- Can run in headless mode for cookie refresh

**Pros:**
- ✅ **Best Practice**: Designed by the tool author
- ✅ **Secure**: Isolated profile from your main Chrome
- ✅ **Simple**: One-time manual setup, then automatic
- ✅ **Persistent**: Chrome stays logged in for weeks
- ✅ **Compliant**: Doesn't violate Google's ToS

**Cons:**
- ⚠️ Requires one-time manual login
- ⚠️ Chrome must be installed on the server

**Implementation:**
```bash
# One-time setup (manual):
nlm login --profile automation

# All future runs (automatic):
# The tool will use the cached cookies from the dedicated profile
```

### Option 2: Playwright MCP Automated Login

**How it works:**
- Use Playwright MCP to control the login flow
- Navigate to NotebookLM
- Fill in credentials (email/password/2FA)
- Extract cookies after successful login
- Save to `~/.notebooklm-mcp-cli/profiles/<profile>/auth.json`

**Pros:**
- ✅ Fully automated
- ✅ Can handle 2FA with proper integration
- ✅ Playwright MCP is already available

**Cons:**
- ❌ **Complex**: Requires username/password storage
- ❌ **Security Risk**: Storing credentials defeats purpose of cookie auth
- ❌ **Fragile**: 2FA flows change frequently
- ❌ **Violates Best Practices**: Not recommended by tool author

**Feasibility: VERIFIED** - Playwright MCP can automate login flows
**Recommendation: AVOID** - Security and maintenance concerns outweigh benefits

### Option 3: Manual Cookie Import with Scheduled Refresh

**How it works:**
- Extract cookies once using Chrome DevTools
- Copy to server
- Tool uses cached cookies
- Refresh manually every 2-4 weeks

**Pros:**
- ✅ Simple
- ✅ No external dependencies

**Cons:**
- ❌ Not automated
- ❌ Requires manual intervention for refresh

### Option 4: Environment Variable / File-based Authentication

**How it works:**
- Pre-populate `~/.notebooklm-mcp-cli/profiles/<profile>/auth.json`
- Tool reads from file
- No browser interaction needed

**Pros:**
- ✅ Works if cookies are pre-populated
- ✅ No Chrome needed in production

**Cons:**
- ❌ Doesn't solve the initial cookie extraction problem
- ❌ Cookies still expire

## Security Considerations

### Google Account Security
- Google has implemented device-bound cookies (Chrome 136+) to prevent cookie theft
- This makes cookie persistence more reliable but harder to extract from other browsers

### Recommended Security Practices
1. **Never commit** `auth.json` files to version control
2. **Never share** auth tokens or `auth.json` files
3. **Use isolated profiles** (`--profile automation`) instead of your main Chrome
4. **Keep credentials secret** - don't store Google passwords

### Why Browser Automation of Login is Problematic

Browser automation for the entire login flow (email/password/2FA) raises concerns:

1. **Credential Storage**: Requires storing Google login credentials somewhere
2. **2FA Complexity**: 2FA mechanisms change, requiring maintenance
3. **ToS Violation Risk**: Automating the login to bypass auth controls may violate Google's ToS
4. **Security Risk**: If credentials are exposed, they provide full account access

The tool author designed it specifically to extract **existing session cookies**, not to automate the login process itself.

## Browser MCP Capabilities

### Available Tools

1. **Playwright MCP** (microsoft/playwright-mcp):
   - ✅ Can navigate to pages
   - ✅ Can fill forms and submit
   - ✅ Can extract cookies via `storageState`
   - ✅ Supports headless mode
   - ❌ Requires credential management

2. **Chrome DevTools MCP** (ChromeDevTools/chrome-devtools-mcp):
   - ✅ Native Chrome integration
   - ✅ Can extract cookies from running Chrome
   - ✅ Connects to existing Chrome instance
   - ❌ Requires Chrome to be running with remote debugging

### Cookie Extraction with Playwright

```python
# Example of extracting cookies with Playwright
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()

    # Navigate to NotebookLM (user logs in)
    page.goto("https://notebooklm.google.com")

    # Save cookies for reuse
    cookies = context.cookies()
    with open("cookies.json", "w") as f:
        json.dump(cookies, f)

    # Save full state (including localStorage)
    storage_state = context.storage_state()
    with open("state.json", "w") as f:
        json.dump(storage_state, f)

    browser.close()
```

## Recommended Solution

### Best Practice: Dedicated Profile with Manual First Login

```bash
# Step 1: One-time manual authentication
nlm login --profile automation

# Step 2: Use automation profile in scripts
nlm notebook list --profile automation
nlm audio create <id> --confirm --profile automation

# Step 3: Refresh when cookies expire (every ~2-4 weeks)
nlm login --profile automation
```

### Why This is the Best Approach

1. **Designed by Author**: This is exactly what the tool author intended
2. **Secure**: No credential storage needed
3. **Simple**: First-time manual setup, then pure automation
4. **Reliable**: Chrome handles session persistence
5. **Compliant**: Doesn't violate Google's ToS
6. **Persistent**: The dedicated Chrome profile remembers login for weeks/months

### For CI/CD Environments

For continuous integration, consider:

1. **Pre-generated Cookies**: Generate cookies locally, store encrypted, decrypt in CI
2. **Scheduled Refresh**: Use a cron job to refresh cookies before they expire
3. **Headless Chrome**: Run `nlm login --profile automation` in headless mode

```yaml
# Example: GitHub Actions workflow
- name: Refresh NotebookLM auth
  run: |
    # Decrypt stored auth if needed
    # Or run headless login with pre-seeded Chrome profile
    nlm login --profile automation

- name: Use NotebookLM
  run: |
    nlm notebook list --profile automation
    npm run script-uses-notebooklm
```

## Alternative: Manual Cookie File

If you cannot run Chrome in your environment:

1. **Generate cookies locally**:
   ```bash
   nlm login --manual --file cookies.txt
   ```

2. **Copy `auth.json` to your server**:
   ```bash
   ~/.notebooklm-mcp-cli/profiles/default/auth.json
   ```

3. **Refresh manually every 2-4 weeks**

## Conclusion

### Key Findings

1. **The tool is designed for cookie extraction, not login automation**
2. **Dedicated Chrome profiles are the intended solution for "automation"**
3. **Browser automation of the login flow is possible but not recommended**
4. **Cookies naturally persist for 2-4 weeks**

### Recommendations

✅ **DO:**
- Use `nlm login --profile automation` for one-time setup
- Create dedicated profiles for automated workflows
- Schedule periodic refresh (every 2-3 weeks)
- Use Playwright MCP only if you must automate the entire flow

❌ **DON'T:**
- Store Google credentials to automate login
- Try to extract cookies from other tools/services
- Commit `auth.json` to version control
- Over-engineer when simpler solutions exist

### Implementation Decision

**Use dedicated Chrome profiles with one-time manual setup.**

This aligns with the tool's design, provides the best security model, and offers reliable long-term operation without the complexity and risks of full login automation.

## Additional Resources

- **Tool Documentation**: https://github.com/jacob-bd/notebooklm-mcp-cli
- **Auth Guide**: https://github.com/jacob-bd/notebooklm-mcp-cli/blob/main/docs/AUTHENTICATION.md
- **Playwright MCP**: https://github.com/microsoft/playwright-mcp
- **Chrome DevTools MCP**: https://github.com/ChromeDevTools/chrome-devtools-mcp

---

*Research completed on 2025-02-04*
*Tool version: notebooklm-mcp-cli v0.2.14*
