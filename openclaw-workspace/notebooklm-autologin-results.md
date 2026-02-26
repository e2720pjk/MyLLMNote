# NotebookLM CLI 自動登入研究結果

## 研究摘要

本研究探索了 NotebookLM CLI (`nlm`) 的認證機制，以及實現無人值守自動登入的可能性。

---

## 關鍵發現

### 1. 當前認證機制

#### 原版 notebooklm-cli (已棄用)
- **命令:** `nlm login`
- **流程:**
  1. 啟動 Chrome 瀏覽器
  2. 導航至 NotebookLM (`notebooklm.google.com`)
  3. 提取 session cookies
  4. 存儲認證狀態
- **要求:** 需要用戶在瀏覽器中進行登入操作
- **Session 持續時間:** 約 20 分鐘
- **資料來源:** `~/.openclaw/workspace/skills/notebooklm-cli/SKILL.md`

#### 新版 notebooklm-mcp-cli (統一包)
- **狀態:** 舊版 CLI 已併入此包
- **認證文件位置:** `~/.notebooklm-mcp/auth.json`
- **機制:** 使用緩存的 tokens 進行認證
- **安裝:** `pip install notebooklm-mcp-cli`

### 2. 認證相關命令

| 命令 | 說明 |
|------|------|
| `nlm login` | 啟動 Chrome 並提取 cookies 進行認證 |
| `nlm login --check` | 驗證當前憑證 |
| `nlm login --profile <name>` | 登入特定 profile |
| `nlm auth status` | 檢查 session 有效性 |
| `nlm auth list` | 列出所有 profiles |
| `nlm auth delete <profile> --confirm` | 刪除 profile |

---

## 無人值守自動登入分析

### 關鍵問題解答

#### Q1: 能否無人值守自動登入？
**答案:** 不直接支持，但有變通方案

**詳細分析:**
1. **原生不支持:** CLI 工具本身沒有提供純命令行、無瀏覽器的登入選項
2. **認證依賴:** 依賴 Chrome DevTools Protocol 進行 cookie 提取
3. **用戶交互要求:** 初次登入必須在瀏覽器中完成 Google 認證

#### Q2: 是否每次都需要登入？
**答案:** 不是，但 session 有時效性

- **Session 持續時間:** 約 20 分鐘 (視 NotebookLM 的 token 有效期而定)
- **Cookies 持久化:** 新版 (`notebooklm-mcp-cli`) 使用 `~/.notebooklm-mcp/auth.json` 存儲認證
- **續期方式:** 重新運行 `nlm login` 即可刷新 session

#### Q3: OpenCode 能否透過 ACP 控制瀏覽器登入流程？
**答案:** 可以，但需要額外編寫腳本

**可行性分析:**

OpenCode 提供了 `playwright` skill，可以輕鬆實現瀏覽器自動化：

```python
# Playwright 自動登入示例 (概念代碼)
import asyncio
from playwright.async_api import async_playwright

async def auto_login():
    async with async_playwright() as p:
        # 啟動 Chromium
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context()
        page = await context.new_page()

        # 或是加載已有 cookies
        # context = await browser.new_context(storageState="auth.json")

        # 導航並登入
        await page.goto("https://notebooklm.google.com")
        # ... 登入邏輯 ...

        # 提取 cookies
        cookies = await context.cookies()
        await context.storage_state(path="auth.json")

        await browser.close()
```

**工具支持:**
- **Playwright MCP Server:** 完整支持瀏覽器自動化
- **Dev-Browser Skill:** 持久化頁面狀態的瀏覽器自動化
- **Cookie 管理:** `context.cookies()`, `context.add_cookies()`, `storageState()`

#### Q4: Agent-browser (vercel-labs) 是否有相關功能？
**答案:** 有相關功能，但 NotebookLM 有專用的 MCP Server

**相關項目:**
1. **notebooklm-mcp:** 專為 NotebookLM 設計的 MCP Server (`jacob-bd/notebooklm-mcp`)
2. **Persistent Auth:** 支持 persistent authentication
3. **Cookie 依賴:** 仍需手動登入一次獲取 cookies

---

## 推薦實施方案

### 方案 A: 首次手動登入 + Cookies 重用 (推薦)

**優點:**
- 最簡單且穩定
- 配合 `~/.notebooklm-mcp/auth.json` 自動持久化
- 不需要維護複雜的自動化腳本

**步驟:**
```bash
# 1. 首次手動登入
nlm login

# 2. 之後直接使用命令，cookies 會從 auth.json 載入
nlm notebook list
nlm source add ...  # 除非 session 過期，否則不需重新登入
```

**注意事項:**
- Session 約 20 分鐘後過期
- 可以寫一個監控腳本檢查 `nlm auth status`
- 過期後重新運行 `nlm login`

### 方案 B: Playwright 自動化登入 (高級)

**適用場景:** 需要完全自動化解決方案

**實現方式:**

```python
# 使用 Playwright 自動登入並保存 cookies
import asyncio
from playwright.async_api import async_playwright
import json
import os

async def notebooklm_auto_login():
    async with async_playwright() as p:
        # 使用已安裝的 Chromium
        browser = await p.chromium.launch(
            headless=False,  # 設為 True 則為無人值守模式
            channel="chrome",
            executable_path="/usr/bin/chromium"  # 使用系統 Chromium
        )
        context = await browser.new_context()
        page = await context.new_page()

        # 導航到 NotebookLM
        await page.goto("https://notebooklm.google.com")

        # 等待用戶完成登入 (首次需要)
        # 或者如果有 Google Service Account，可以自動登入

        # 檢測登入成功信號
        await page.wait_for_selector("[data-test-id='notebook-list']")

        # 保存認證狀態
        auth_dir = os.path.expanduser("~/.notebooklm-mcp")
        os.makedirs(auth_dir, exist_ok=True)
        await context.storage_state(path=os.path.join(auth_dir, "auth.json"))

        print("✅ 登入成功，cookies 已保存到 ~/.notebooklm-mcp/auth.json")
        await browser.close()

asyncio.run(notebooklm_auto_login())
```

**與 OpenCode 集成:**
```bash
# 使用 playwright skill 自動登入
skill_mcp mcp_name="playwright" tool_name="get_cookies"
# 或使用 dev-browser skill 進行瀏覽器操作
```

### 方案 C: Direct Cookie Injection (進階)

**原理:** 直接構造 `~/.notebooklm-mcp/auth.json` 文件

**檢查 auth.json 格式:**
```json
{
  "cookies": [
    {
      "name": "SID",
      "value": "...",
      "domain": ".google.com",
      "path": "/",
      "expires": 1735689600,
      "httpOnly": true,
      "secure": true,
      "sameSite": "None"
    }
    // ... 其他 cookies
  ],
  "origins": [
    // ... localStorage, sessionStorage
  ]
}
```

**實現方式:**
1. 手動登入一次 NotebookLM
2. 瀏覽器開發者工具 → Application → Cookies → 導出
3. 將 cookies 轉換為 auth.json 格式
4. 直接寫入 `~/.notebooklm-mcp/auth.json`

**風險:**
- Cookie 格式可能變化
- 可能需要額外的 localStorage/IndexedDB 數據
- 需要定期更新 (token 過期)

---

## 最佳實踐評估

### 推薦方案: **方案 A (首次手動登入 + Cookies 重用)**

**理由:**
1. ✅ **簡單可靠:** 不需要維護複雜的自動化代碼
2. ✅ **官方支持:** 利用工具自帶的 `auth.json` 持久化機制
3. ✅ **安全性:** 避免在腳本中硬編碼敏感信息
4. ✅ **靈活性:** 支持多 profile (`--profile`)

**改善建議:**
```bash
# 創建一個 helper 腳本檢查並自動刷新
cat > ~/scripts/refresh_nlm_auth.sh << 'EOF'
#!/bin/bash
if ! nlm auth status &>/dev/null; then
    echo "⚠️  Session 過期，自動登入..."
    nlm login
else
    echo "✅ Session 有效"
fi
EOF

chmod +x ~/scripts/refresh_nlm_auth.sh

# 使用前先刷新
~/scripts/refresh_nlm_auth.sh && nlm notebook list
```

---

## 技術細節: Playwright Cookie 管理

### 核心 API

```javascript
// 1. 獲取 Cookies
const cookies = await context.cookies();

// 2. 設置 Cookies
await context.addCookies([
  {
    name: "SID",
    value: "...",
    url: "https://notebooklm.google.com",
    domain: ".google.com",
    path: "/"
  }
]);

// 3. 保存 Storage State (Cookies + localStorage + sessionStorage)
await context.storageState({ path: "auth.json" });

// 4. 加載 Storage State
const context = await browser.newContext({
  storageState: "auth.json"
});
```

### StorageState 格式

```json
{
  "cookies": [
    {
      "name": "cookie_name",
      "value": "cookie_value",
      "domain": ".google.com",
      "path": "/",
      "expires": 1735689600,
      "httpOnly": true,
      "secure": true,
      "sameSite": "Lax"
    }
  ],
  "origins": [
    {
      "origin": "https://notebooklm.google.com",
      "localStorage": [
        {"name": "key", "value": "value"}
      ]
    }
  ]
}
```

---

## 總結

| 問題 | 答案 | 推薦方案 |
|------|------|----------|
| 能否無人值守自動登入? | 原生不支持，需變通 | 首次手動登入 + 重用 Cookies |
| 是否每次都需要登入? | 否，session 約 20 分鐘 | 監控 session 狀態 |
| OpenCode 能控制登入? | 可以，需 Playwright | 使用 playwright skill |
| Agent-browser 支持如何? | 有 persistent auth，但仍需首次手動登入 | 配合 `~/.notebooklm-mcp/auth.json` |

### 執行建議

**短期 (立即可用):**
1. 手動 `nlm login` 一次性
2. 使用 `nlm auth status` 檢查 session
3. 過期後重新登入

**中期 (優化體驗):**
1. 寫 wrapper 腳本自動檢查並刷新
2. 集成到 cron 定期刷新
3. 使用多 profile 隔離環境

**長期 (完全自動化):**
1. 使用 Playwright 自動化登入流程
2. 配合 Google Service Account (可能)
3. 直接管理 auth.json 文件

---

## 參考資料

- [notebooklm-cli (deprecated)](https://github.com/jacob-bd/notebooklm-cli)
- [notebooklm-mcp-cli](https://github.com/jacob-bd/notebooklm-mcp-cli)
- [Playwright Authentication Docs](https://playwright.dev/docs/auth)
- [NotebookLM MCP Server on LobeHub](https://lobehub.com/mcp/jacob-bd-notebooklm-mcp)

---

*研究完成日期: 2026-02-04*
*研究人員: OpenCode 系統*
