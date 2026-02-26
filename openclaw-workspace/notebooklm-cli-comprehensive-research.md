# NotebookLM CLI 自動化登入研究報告

## 研究摘要

本文档汇总了 NotebookLM CLI (`nlm`) 自動化登入的方案分析，包含技術細節、最佳實踐與推薦實施方案。

---

## 1. 專案現狀

### 1.1 官方專案變遷

- **舊專案**: `notebooklm-cli` - 已棄用
- **新專案**: `notebooklm-mcp-cli` - 統一 CLI + MCP Server (推薦使用)
- **GitHub**: https://github.com/jacob-bd/notebooklm-mcp-cli
- **安裝**: `pip install notebooklm-mcp-cli` 或 `uv tool install notebooklm-mcp-cli`

### 1.2 專案特性

- 使用 **Chrome DevTools Protocol (CDP)** 提取 cookies
- **無需 keychain 存取**，透過 WebSocket 協定
- 支援 **多 Profile** (多個 Google 帳號)
- 支援 **Headless 模式**
- Cookie 有效期約 **2-4 週**
- Session ID 有效期約 **20 分鐘**

---

## 2. 登入流程分析

### 2.1 標準登入流程

```bash
# 預設模式：Chrome 自動開啟，使用者登入後自動提取 cookie
nlm login

# 檢查認證狀態
nlm login --check

# 使用指定 profile
nlm login --profile work

# 手動模式：從檔案匯入 cookies
nlm login --manual --file cookies.txt
```

### 2.2 內部運作機制

#### Step 1: 啟動 Chrome
```python
# 來源: src/notebooklm_tools/utils/cdp.py
chrome_args = [
    chrome_path,
    f"--remote-debugging-port={port}",       # 預設 9222
    "--no-first-run",
    "--no-default-browser-check",
    "--disable-extensions",
    f"--user-data-dir={profile_dir}",         # ~/{profile} 存儲使用者資料
    "--remote-allow-origins=*",
]
```

#### Step 2: 連接 CDP
```python
# 透過 WebSocket 連接 Chrome
ws_url = get_debugger_url(port)  # http://localhost:9222/json/version
```

#### Step 3: 提取 Cookies
```python
# 使用 Network.getCookies CDP 命令
cookies = cdp.send_command("Network.getCookies")
```

#### Step 4: 提取 CSRF Token
```python
# 從頁面 HTML 提取 WIZ_global_data.SNlM0e
csrf_token = extract_csrf_from_page_source(html)
```

#### Step 5: 快取到檔案
```python
# 存儲位置: ~/.notebooklm-mcp-cli/auth.json
# 包含: cookies, csrf_token, session_id, extracted_at
```

---

## 3. 自動化方案評估

### 3.1 **方案 A: Chrome Profile 持久化 (推薦)** ⭐

#### 原理
保存 Chrome user-profile，包含已登入的 Google 帳號資訊。下次啟動時 Chrome 自動保持登入狀態，無需重新輸入密碼。

#### 優點
- ✅ **最接近無人值守**: 只需第一次手動登入，之後自動
- ✅ 安全性高: 使用官方 Chrome cookie 管理機制
- ✅ 多帳號支援: 每個 profile 獨立的 Google 帳號
- ✅ 實作簡單: Chrome 原生支援

#### 缺點
- ⚠️ 需要儲存 Chromium profile (~50-200MB)
- ⚠️ Profile 約 2-4 週後仍需重新登入 (Google 限制)
- ⚠️ 仍需啟動瀏覽器程序

#### 實作步驟
```bash
# 1. 初次登入 (手動操作一次)
nlm login --profile default

# 2. Profile 已保存到 ~/.notebooklm-mcp-cli/chrome-profiles/default/
#    包含 Google 登入資訊

# 3. 後續自動登入
nlm login --profile default
#    Chrome 開啟 → 自動登入 → 提取 cookies → 關閉
```

#### 技術細節
```python
# CDP 自動登入流程
def headless_auth_with_saved_profile(profile_name: str = "default"):
    # 1. 啟動 headless Chrome with saved profile
    launch_chrome(
        port=9222,
        headless=True,
        profile_name=profile_name  # 使用已保存的 profile
    )

    # 2. 導航到 NotebookLM
    navigate_to("https://notebooklm.google.com/")

    # 3. 檢查登入狀態 (已自動登入，無需互動)
    if is_logged_in(page_source):
        # 4. 提取 cookies
        cookies = extract_cookies_via_cdp()
        return cookies

    # 如果 profile 過期，需要重新手動登入
    return None
```

---

### 3.2 **方案 B: 直接匯入 Cookies**

#### 原理
預先從已登入的 Chrome 匯出 cookies，直接載入到 notebooklm-cli。

#### 優點
- ✅ 完全無需瀏覽器互動
- ✅ 腳本友好，容易自動化
- ✅ 無需啟動 Chrome 程序

#### 缺點
- ❌ **仍需手動初次登入**: 需要在瀏覽器手動登入 Google 一次
- ❌ Cookie 過期 (2-4 週) 需要重新提取
- ❌ 安全性較低: Cookies 存在檔案中
- ❌ 提取流程需要手動操作

#### 實作步驟
```bash
# 步驟 1: 手動從 Chrome 匯出 cookies
# 方法 A: 使用 DevTools
chrome
# → 打開 https://notebooklm.google.com/
# → F12 > Network > 任一請求 > Copy Cookie header

# 步驟 2: 存入 cookies.txt
echo "Cookie: SID=...; HSID=...; ..." > cookies.txt

# 步驟 3: 自動登入
nlm login --manual --file cookies.txt
```

#### 自動化提取 Cookies (透過 Chrome DevTools MCP)
如果 OpenCode 有 Chrome DevTools MCP，可以自動提取：
```python
# 偽代碼
cookies = chrome_devtools_mcp.get_cookies("https://notebooklm.google.com/")
save_cookies_to_file(cookies, "cookies.txt")
nlm login --manual --file cookies.txt
```

---

### 3.3 **方案 C: Playwright 自動化**

#### 原理
使用 Playwright 完全自動化登入流程，但密碼仍需提供。

#### 優點
- ✅ 完全程式化控制
- ✅ 可整合到 CI/CD
- ✅ 支援複雜 2FA 流程

#### 缺點
- ❌ 需要儲存密碼 (安全風險)
- ❌ 仍需處理 2FA 認證
- ❌ 維護成本高 (UI 變化需要更新腳本)

#### 參考實作
```python
# 來源: DataNath/notebooklm_source_automation/set_login_state.py
async def setup_playwright_auth():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False)
        context = await browser.new_context()

        # 開啟 NotebookLM
        page = await context.new_page()
        await page.goto("https://notebooklm.google.com/")

        # 等待使用者登入 (手動互動)
        input("Login in browser, then press Enter...")

        # 保存 browser state
        await context.storage_state(path="state.json")
        await browser.close()

# 後續使用保存的 state
async def use_saved_state():
    browser = await p.chromium.launch(headless=True)
    context = await browser.new_context(storage_state="state.json")
    page = await context.new_page()
    # ... 繼續操作
```

---

### 3.4 **方案 D: Google Service Account (不可行)** ⛔

#### 原理
使用 Google Cloud Service Account 取得 OAuth token。

#### 結論
❌ **不可行**，原因：
- NotebookLM 使用內部 API，不支援 OAuth 2.0 flow
- 無官方 API，無法使用 Service Account
- 需要第三方 cookies (SID, HSID, SSID, APISID, SAPISID)

---

## 4. 開發中選項

### 4.1 **方案 E: Chrome Headless 自動刷新** (已支援)

#### 原理
結合方案 A + Headless 模式，完全無人值守。

#### 狀態
- ✅ notebooklm-mcp-cli v0.1.9+ 已支援自動刷新 tokens
- ✅ Chrome profile 保存登入狀態
- ⚠️ 仍需 2-4 週重新登入一次

#### 實作
```bash
# 初次設定 (僅需一次)
nlm login --profile default

# 後續自動 (headless + saved profile)
nml login --profile default
# 瀏覽器會以 headless 模式啟動，使用保存的 profile 自動登入
```

---

## 5. OpenCode ACP 整合可行性

### 5.1 現有 OpenCode 能力

#### 查詢結果
- ❌ OpenCode 未內建 `playwright` 或 `dev-browser` skill
- ❌ 未發現 MCP browser automation 配置

#### 替代方案
1. **安裝 Chrome DevTools MCP**:
   ```bash
   # 參考: https://github.com/ChromeDevTools/chrome-devtools-mcp
   claude mcp add chrome-devtools-mcp --scope user
   ```

2. **安裝 Playwright MCP**:
   ```bash
   # 需自行整合
   # 參考: https://modelcontextprotocol.io/guides/clients/
   ```

### 5.2 推薦整合方式

#### 方式 1: 直接呼叫 CLI (最簡單)
```python
# OpenCode agent 直接呼叫
import subprocess

def authenticate():
    # 檢查是否已有有效認證
    result = subprocess.run(["nlm", "login", "--check"], capture_output=True)
    if result.returncode == 0:
        return True

    # 執行登入 (使用 saved profile)
    result = subprocess.run(["nlm", "login", "--profile", "default"])
    return result.returncode == 0
```

#### 方式 2: 使用 notebooklm-mcp (推薦)
```bash
# 安裝 MCP
uv tool install notebooklm-mcp-cli

# 配置到 OpenCode (如果支援)
claude mcp add --scope user notebooklm-mcp notebooklm-mcp

# 則 agent 可直接呼叫 MCP tools
```

---

## 6. 推薦最佳實踐

### 6.1 生產環境推薦方案

#### **方案 A (Chrome Profile 持久化) ➡ 方案 D (定時檢查腳本)**

1. **初次設定**
   ```bash
   nlm login --profile production
   # 手動登入 Google 一次
   ```

2. **日常自動使用**
   ```bash
   nlm login --profile production
   # 自動從 saved profile 提取 cookies
   nlm notebook list
   nlm audio create <id> --confirm
   ```

3. **定期刷新** (每 2-3 週)
   ```bash
   # 當自動登入失敗時
   rm -rf ~/.notebooklm-mcp-cli/chrome-profiles/production/
   nlm login --profile production
   # 重新手動登入
   ```

#### 定時任務檢查 (cron)
```bash
#!/bin/bash
# check-credentials.sh
if ! nlm login --check; then
    echo "Credentials expired, triggering refresh..."
    # 發送通知 (Slack/Email)
    python3 notify-credentials-expired.py
    exit 1
fi

exit 0
```

```crontab
# 每日檢查一次
0 9 * * * /path/to/check-credentials.sh
```

---

### 6.2 CI/CD 環境推薦方案

#### **方案 B (Cookies 檔案)** + GitHub Secrets

1. **本地匯出 cookies**
   ```bash
   nlm login
   # 從 ~/.notebooklm-mcp-cli/auth.json 讀取 cookies
   cat ~/.notebooklm-mcp-cli/auth.json | jq -r '.cookies | to_entries[] | "\(.key)=\(.value)"' | tr '\n' ';' | sed 's/;$//' > cookies.txt
   ```

2. **加密並上傳到 GitHub Secrets**
   ```bash
   gpg --symmetric --cipher-algo AES256 cookies.txt
   # 加密 -> cookies.txt.gpg
   # 上傳到 CI/CD secrets
   ```

3. **CI/CD 中使用**
   ```yaml
   # .github/workflows.yml
   - name: Decrypt cookies
     env:
       GPG_PASSPHRASE: ${{ secrets.NLM_COOKIE_PASSPHRASE }}
     run: |
       echo "${{ secrets.NLM_COOKIES }}" > cookies.txt.gpg
       gpg --passphrase "$GPG_PASSPHRASE" --decrypt cookies.txt.gpg > cookies.txt

   - name: Authenticate with NotebookLM
     run: |
       nlm login --manual --file cookies.txt
       nlm notebook list
   ```

---

## 7. 技術細節

### 7.1 Cookie 存儲位置

```
~/.notebooklm-mcp-cli/
├── auth.json              # AuthTokens 快取 (cookies, csrf_token, session_id)
├── chrome-profiles/       # Chrome profiles
│   ├── default/          # 預設 profile
│   ├── work/             # 工作帳號 profile
│   └── personal/         # 個人帳號 profile
└── profiles/             # AuthManager profiles (配置檔)
    ├── default.json
    └── work.json
```

### 7.2 AuthTokens 結構
```json
{
  "cookies": {
    "SID": "...",
    "HSID": "...",
    "SSID": "...",
    "APISID": "...",
    "SAPISID": "...",
    "LSID": "...",
    "__Secure-1PSID": "..."
  },
  "csrf_token": "WIZ_global_data.SNlM0e value",
  "session_id": "extracted from page",
  "extracted_at": 1736700000.0
}
```

### 7.3 CDP 命令序列

```javascript
// 1. 連接到 CDP
const ws = new WebSocket("ws://localhost:9222/devtools/page/...");

// 2. 啟用 Network domain
ws.send(JSON.stringify({
  "id": 1,
  "method": "Network.enable",
  "params": {}
}));

// 3. 導航到 NotebookLM
ws.send(JSON.stringify({
  "id": 2,
  "method": "Page.navigate",
  "params": { "url": "https://notebooklm.google.com/" }
}));

// 4. 獲取 cookies
ws.send(JSON.stringify({
  "id": 3,
  "method": "Network.getCookies",
  "params": { "urls": ["https://notebooklm.google.com/"] }
}));

// 響應
{
  "id": 3,
  "result": {
    "cookies": [
      { "name": "SID", "value": "...", "domain": ".google.com" },
      ...
    ]
  }
}
```

---

## 8. 常見問題

### Q1: 為什麼無法完全無人值守？
A: NotebookLM 使用內部 API，無官方 OAuth。需要從第三方 cookies (Google 登入)，這無法程式生成。

### Q2: 如何減少手動登入頻率？
A: 使用 Chrome Profile 持久化，只需每 2-4 週重新登入一次。

### Q3: 為什麼不能使用 Google Service Account？
A: NotebookLM API 未公開，不支援標準 OAuth 2.0 flow。

### Q4: 能否使用 SSH 隧道遠程登入？
A: 可以，先 SSH 連接遠程機器，再在遠端運行 `nlm login`。

### Q5: 如果登入失敗怎麼辦？
A:
```bash
# 1. 檢查現有認證
nlm login --check

# 2. 刪除過期 profile
rm -rf ~/.notebooklm-mcp-cli/chrome-profiles/default/

# 3. 重新登入
nlm login
```

---

## 9. 安全考量

### 9.1 Cookie 儲存安全
- ✅ 使用系統預設目錄 (`~/.notebooklm-mcp-cli/`)
- ✅ 檔案權限已適當設定 (預設 600)
- ⚠️ 不要分享 `chrome-profiles/` 目錄給他人
- ⚠️ 不要將 `auth.json` 提交到版本控制

### 9.2 2FA 處理
- Chrome Profile 方案：第一次登入時處理 2FA，之後自動使用
- 手動匯入 Cookies：需要每次手動登入 (包括 2FA)

### 9.3 密碼儲存
- ❌ **不要儲存密碼明文**
- ❌ **不要使用 Playwright 自動填入密碼** (除非你確定是安全環境)

---

## 10. 總結與推薦

| 場景 | 推薦方案 | 優先級 |
|------|----------|--------|
| **個人開發** | 方案 A (Chrome Profile) | ⭐⭐⭐⭐⭐ |
| **生產環境** | 方案 A + 定期檢查 | ⭐⭐⭐⭐⭐ |
| **CI/CD** | 方案 B + GitHub Secrets | ⭐⭐⭐⭐ |
| **多帳號** | 方案 A 多 Profile | ⭐⭐⭐⭐ |
| **完全自動化** | 不可行 (除非接受每 2-3 週手動刷新) | ⭐ |

### 最佳實踐流程

```bash
#!/bin/bash
# 完整的認證工作流

# 1. 檢查現有認證
if nlm login --check 2>/dev/null; then
    echo "✓ 認證有效，繼續..."
else
    echo "⚠ 需要重新登入"

    # 2. 使用 saved profile 自動登入
    if nlm login --profile production; then
        echo "✓ 使用 saved profile 登入成功"
    else
        echo "❌ 登入失敗，profile 可能已過期"
        echo "請手動運行: nlm login --profile production"
        exit 1
    fi
fi

# 3. 執行 NotebookLM 操作
nml notebook list
nlm audio create <notebook-id> --confirm
```

---

## 11. 參考資源

### 官方文檔
- [notebooklm-mcp-cli Repository](https://github.com/jacob-bd/notebooklm-mcp-cli)
- [Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/)
- [Playwright 文檔](https://playwright.dev/python/)

### 相關專案
- [DataNath/notebooklm_source_automation](https://github.com/DataNath/notebooklm_source_automation) - Playwright 自動化範例
- [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) - OpenCode 可整合

### 社群討論
- [AutoGen MCP](https://github.com/PromptEngineer48/auto-gen-mcp) - NotebookLM 自動化參考
- [MCP Registry](https://mcp.so/) - 可用的 MCP servers 列表

---

## 附錄 A: 快速開始指南

```bash
# 1. 安裝 notebooklm-mcp-cli
uv tool install notebooklm-mcp-cli

# 2. 初次登入 (手動一次)
nml login --profile work

# 3. 在螢幕上登入你的 Google 帳號

# 4. 等待 cookies 提取完成

# 5. 開始使用
nml notebook list
nml audio create <notebook-id> --confirm

# 6. 後續登入 (自動)
nml login --profile work
```

---

## 附錄 B: 故障排除

```bash
# 檢查 Chrome 是否已安裝
which google-chrome chromium

# 檢查 profile 是否存在
ls ~/.notebooklm-mcp-cli/chrome-profiles/

# 查看詳細日誌
nml login --profile work --verbose

# 完全重置認證
rm -rf ~/.notebooklm-mcp-cli/
nml login --profile work
```

---

**報告生成時間**: 2026-02-05
**研究範圍**: NotebookLM CLI 自動化登入最佳實踐
**作者**: Sisyphus (OpenCode Agent)
