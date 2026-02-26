# NotebookLM CLI 最佳實踐研究報告

## 探索任務摘要

**研究日期**: 2026-02-05
**研究者**: Sisyphus (OhMyOpenCode AI Agent)
**目標**: 找到 NotebookLM CLI 的最佳自動化實踐，特別關注自動登入方案

---

## 執行摘要

### 核心結論

| 關鍵問題 | 答案 | 實用性評估 |
|---------|------|----------|
| **能否無人值守自動登入** | ⚠️ 有限 - Google 反爬蟲系統阻擋純 headless 自動登入 | **不推薦**完全自動首次登入 |
| **是否每次都需要登入** | ❌ 否 - Session 有效期 2-4 週 | **優秀設計** |
| **OpenCode 能否控制瀏覽器登入** | ✅ 能 - 但不推薦 | 有限方案 |
| **最佳實踐** | ✅ 一手動設置 + 持久化 session (nlm 內建) | **最推薦** |

### 最新的 nlm CLI v0.2.15 (2026-02-04)

**重要更新**:
- 統一 CLI (`nlm`) 和 MCP Server (`notebooklm-mcp`) 到單一包
- 內建三層認證恢復系統 (v0.1.9+)
- 自動 token 刷新機制
- 支持多 profile (多 Google 帳號)

---

## 1. 登入流程分析

### 1.1 標準登入流程

```bash
# 安裝 (推薦使用 uv)
uv tool install notebooklm-mcp-cli

# 或使用 pip
pip install notebooklm-mcp-cli

# 自動模式 (推薦)
nlm login
```

**工作流程**:
```
1. 啟動 Chrome/Chromium 瀏覽器 (使用獨立 profile)
2. 導航至 notebooklm.google.com
3. 用戶手動完成 Google 登入
4. 使用 Chrome DevTools Protocol (CDP) 提取 cookies
5. 保存到 ~/.notebooklm-mcp-cli/profiles/<profile>/cookies.json
6. 瀏覽器自動關閉
```

### 1.2 認證命令

| 命令 | 說明 |
|------|------|
| `nlm login` | 自動模式 (啟動 Chrome，完成登入後自動提取) |
| `nlm login --check` | 檢查現有認證狀態 |
| `nlm login --profile <name>` | 使用特定 profile (多帳號支持) |
| `nlm login --manual --file cookies.txt` | 手動模式 (從文件導入 cookies) |
| `nlm login profile list` | 列出所有 profiles |

### 1.3 🔑 三層認證恢復策略 (v0.1.9+)

nlm CLI 實現了智能的多層恢復機制，最大程度減少手動登入需求：

```
┌─────────────────────────────────────────────────────────────┐
│                  NLM 3-LAYER RECOVERY SYSTEM                 │
├─────────────────────────────────────────────────────────────┤
│ Layer 1: CSRF/Session 自動刷新                              │
│   → 自動刷新短期 token (SNlM0e, FdrFJe)                     │
│   → 有效期：~20 分鐘                                       │
│   → 完全自動，無需干預                                      │
├─────────────────────────────────────────────────────────────┤
│ Layer 2: 磁盤重載                                           │
│   → 從磁盤重新加載 cookies 以支援多進程共享                │
│   → 使用 ~/.notebooklm-mcp-cli/profiles/<profile>/cookies.json │
│   → 完全自動                                                │
├─────────────────────────────────────────────────────────────┤
│ Layer 3: 無頭瀏覽器認證                                    │
│   → 在無頭 Chrome 中運行以提取新 cookies                   │
│   → 僅在 Chrome profile 具有保存的 Google 登入時有效       │
│   → 有效期：~2-4 週                                        │
└─────────────────────────────────────────────────────────────┘

手動登入僅需在以下情況：
  → 新 profile 的初始設置
  → Cookies 過期 (每 2-4 週)
  → Chrome profile 被清理
```

### 1.4 會話有效期

| 組件 | 有效期 | 自動刷新機制 |
|------|--------|--------------|
| **活動會話** | ~20 分鐘 | Layer 1 自動刷新 CSRF tokens |
| **Google Cookies** | ~2-4 週 | Layer 3 自動無頭認證 (如果 profile 有保存登入) |
| **磁盤令牌** | 與 Cookies 同步 | Layer 2 多進程共享 |

---

## 2. 無人值守自動登入方案評估

### 方案 A: ❌ 完全無人值守的首次自動登入 (不推薦)

**原理**: 使用 Playwright/puppeteer 等瀏覽器自動化工具填寫 Google 登入表單

**為何不推薦**:
- Google 的反爬蟲系統會阻擋純 headless 自動登入
- JA3 TLS 指紋檢測會識別自動化瀏覽器
- WebGL 指紋一致性檢查
- `navigator.webdriver` 標誌檢測
- 2FA/MFA 無法繞過
- 會觸發 "This browser or app may not be secure" 錯誤

**結論**: **完全無人值守的首次登入不可行，也不推薦嘗試**

---

### 方案 B: ✅ 一手動設置 + nlm 內建自動恢復 (最推薦)

**原理**: 使用 nlm CLI 內建的三層認證恢復系統

**實施步驟**:

```bash
# ========== 一次性設置 (第一次) ==========
# 1. 安裝 nlm CLI
uv tool install notebooklm-mcp-cli

# 2. 首次登入 (手動操作一次)
nlm login --profile automation
# → Chrome 開啟
# → 手動完成 Google 登入
# → Cookies 自動提取並保存
# → Chrome 關閉

# 3. 驗證
nlm login --check
```

**後續使用**:
```bash
# ========== 日常使用 (完全自動) ==========
# Layer 2 會自動從磁盤加載 cookies
# Layer 1 會自動刷新短期 tokens
# Layer 3 會在 cookies 過期時自動無頭認證 (如果 profile 有保存登入)

nlm notebook list
nlm source add <notebook-id> --url "https://example.com"
nlm audio create <notebook-id> --confirm
```

**優點**:
- ✅ 最簡單、最可靠
- ✅ nlm 內建完整機制，無需額外開發
- ✅ 支持三層自動恢復
- ✅ 多 profile 支持 (dev/staging/prod)
- ✅ 無需瀏覽器自動化工具

**缺點**:
- ⚠️ 首次仍需手動登入一次
- ⚠️ Cookies 每 2-4 週過期，需重新登入一次

**適用場景**: 個人開發、腳本自動化、定期任務

---

### 方案 C: 🏆 手動 Cookie 導入 + CI/CD Secrets (CI/CD 最佳)

**原理**: 一次性提取 cookies，存入 CI/CD Secrets，每次運行時導入

**實施步驟**:

```bash
# ========== 本地設置 ==========
# 1. 首次登入
nlm login

# 2. 提取 cookies JSON
cat ~/.notebooklm-mcp-cli/profiles/default/cookies.json

# 3. 存入 CI/CD Secrets
# GitHub Actions: Settings → Secrets and variables → New repository secret
# 名稱: NOTEBOOKLM_COOKIES
# 值: 复制上面的 JSON 內容
```

**GitHub Actions 示例**:
```yaml
# .github/workflows/notebooklm.yml
name: Generate NotebookLM Content

on:
  schedule:
    - cron: '0 9 * * *'  # 每天 9:00

jobs:
  generate:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install dependencies
        run: |
          apt-get update
          apt-get install -y chromium-browser
          pip install notebooklm-mcp-cli

      - name: Restore NotebookLM auth
        env:
          NOTEBOOKLM_COOKIES: ${{ secrets.NOTEBOOKLM_COOKIES }}
        run: |
          mkdir -p ~/.notebooklm-mcp-cli/profiles/default
          echo "$NOTEBOOKLM_COOKIES" > ~/.notebooklm-mcp-cli/profiles/default/cookies.json

      - name: Check authentication
        run: nlm login --check

      - name: Generate podcast
        run: |
          NOTEBOOK_ID=$(nlm notebook list --quiet | head -1)
          nlm audio create "$NOTEBOOK_ID" --confirm
```

**優點**:
- ✅ 完全無人值守
- ✅ 適合容器化環境
- ✅ 安全性依賴 CI/CD Secrets 管理

**缺點**:
- ⚠️ Cookies 過期時需人工更新 (約 2-4 週)
- ⚠️ 需配置 Secrets 輪換機制

**適用場景**: CI/CD Pipeline、Docker 容器、Kubernetes

---

### 方案 D: 🔥 環境變量覆蓋 (長期服務最佳)

**原理**: 使用環境變量或持久化儲存來保存認證狀態

**實施步驟**:

```bash
# ========== 使用持久化路徑 ==========
export NLM_PROFILE_PATH="/path/to/persistent/volume"

# ========== 首次設置 (手動登入一次) ==========
mkdir -p $NLM_PROFILE_PATH
nlm login
# Cookies 保存至 NLM_PROFILE_PATH 而非 ~/.notebooklm-mcp-cli/

# ========== 日常運行 (完全自動) ==========
nlm notebook list
```

**Docker Compose 示例**:
```yaml
version: '3.8'

services:
  notebooklm-worker:
    image: python:3.11
    volumes:
      - ./nlm-data:/nlm-data  # 持久化捲
    environment:
      - NLM_PROFILE_PATH=/nlm-data
    command:
      - /bin/bash
      - -c
      - |
        pip install notebooklm-mcp-cli
        nlm notebook list
        nlm audio create $NOTEBOOK_ID --confirm
```

**優點**:
- ✅ 支持持久化捲掛載
- ✅ Docker/Kubernetes 完全兼容
- ✅ Layer 2 自動會話恢復 (同捲多 Pod 共享)

**缺點**:
- ⚠️ 首次仍需手動登入一次
- ⚠️ 需確保持久化捲可靠性

**適用場景**: 長期運行服務、Docker/Kubernetes 部署

---

### 方案 E: 多環境 Profile (Dev/Staging/Prod)

**原理**: 使用不同的 profile 來隔離不同環境的認證

**實施步驟**:

```bash
# ========== 創建不同 environment 的 profiles ==========
nlm login --profile dev
nlm login --profile staging
nlm login --profile prod

# ========== 使用不同 profile ==========
nlm notebook list --profile dev
nlm notebook list --profile staging
nlm notebook list --profile prod

# ========== 列出所有 profiles ==========
nlm login profile list
```

**優點**:
- ✅ 完全隔離不同環境
- ✅ 每個 profile 獨立的 Google 帳號支持
- ✅ 適合多團隊/多項目場景

**適用場景**: 多環境部署、多帳號管理

---

## 3. OpenCode 瀏覽器自動化能力評估

### 3.1 Playwright MCP (可用但非推薦)

**OpenCode 已內建 Playwright skill**，提供完整的瀏覽器自動化能力：

**可用工具**:
- `browser_navigate` - 導航到 URL
- `browser_click` - 點擊元素
- `browser_type` - 輸入文字
- `browser_fill_form` - 填寫表單
- `browser_snapshot` - 獲取當前頁面快照
- `browser_take_screenshot` - 截圖
- `browser_wait_for` - 等待元素出現
- `browser_navigate_back` - 返回上一頁
- `browser_evaluate` - 執行 JavaScript
- 以及更多...

**理論上可能的實現**:
```javascript
// 使用 Playwright MCP 嘗試自動登入 (不推薦)
async (page) => {
  await page.goto('https://accounts.google.com')
  await page.fill('input[name="identifier"]', email)
  await page.click('#identifierNext')
  await page.fill('input[name="Passwd"]', password)
  await page.click('#passwordNext')
  await page.waitForNavigation()
  const cookies = await page.context().cookies()
  return cookies
}
```

**為何不推薦使用**:

1. **Google 反爬蟲**: 會被檢測並阻擋，觸發 "此瀏覽器或應用程式可能不安全" 警告
2. **nlm 已更好**: nlm CLI 已內建更可靠的 CDP 協議實現
3. **維護成本**: 需要處理 Google 登入 UI 變化、2FA、驗證碼等
4. **不需要**: nlm 的三層恢復機制已足夠滿足自動化需求

**何時可使用 Playwright MCP**:
- ✅ **非認證相關的瀏覽器自動化** (測試、爬蟲、數據采集)
- ✅ **登入之後的操作** (點擊導航、填寫表單)
- ✅ **其他網站的自動化** (非 Google 認證)
- ❌ **Google 自動登入** (不推薦，會被阻擋)

---

### 3.2 agent-browser / dev-browser (非必要)

**結論**: 不需要使用 agent-browser 或 dev-browser 來處理 NotebookLM 認證。

**原因**:
1. nlm CLI 已內建完整的瀏覽器自動化和認證機制
2. 使用 Chrome DevTools Protocol (CDP) 直接控制 Chrome
3. 比第三方瀏覽器自動化工具更可靠
4. 無需額外的複雜性和依賴

---

## 4. 推薦方案速查表

| 使用場景 | 推薦方案 | 複雜度 | 維護成本 | 推薦度 |
|---------|---------|--------|----------|--------|
| **個人開發** | 方案 B: 一手動設置 + nlm 內建 | ⭐ 低 | ⭐ 低 | ⭐⭐⭐⭐⭐ |
| **腳本自動化** | 方案 B: 一手動設置 + nlm 內建 | ⭐ 低 | ⭐ 低 | ⭐⭐⭐⭐⭐ |
| **CI/CD Pipeline** | 方案 C: Cookie 導入 + Secrets | ⭐⭐ 中 | ⭐⭐ 中 | ⭐⭐⭐⭐ |
| **長期服務** | 方案 D: 環境變量覆蓋 | ⭐⭐ 中 | ⭐⭐ 中 | ⭐⭐⭐⭐ |
| **多環境部署** | 方案 E: Profile 隔離 | ⭐⭐⭐ 中 | ⭐⭐⭐ 中 | ⭐⭐⭐⭐ |
| **容器化 (Docker)** | 方案 D: 持久化捲 | ⭐⭐ 中 | ⭐⭐ 中 | ⭐⭐⭐⭐ |
| **Kubernetes** | 方案 D: PersistentVolume | ⭐⭐⭐ 中高 | ⭐⭐⭐ 中 | ⭐⭐⭐ |

---

## 5. 最佳實踐建議

### 5.1 ✅ 首選方案: nlm CLI 內建機制

**為何優先使用 nlm CLI 而非 Playwright**:

1. **專為 NotebookLM 設計**: nlm CLI 針對 NotebookLM API 優化
2. **三層恢復機制**: 自動處理 token 刷新和多種場景
3. **不需要額外依賴**: 無需 Playwright 或其他瀏覽器工具
4. **更可靠**: 使用 CDP 直接控制 Chrome，避免反爬蟲檢測
5. **持續維護**: 活躍開發中，快速響應 Google API 變化 (v0.2.15 於 2026-02-04 發布)

### 5.2 ⚠️ 避免的做法

| 不推薦做法 | 原因 |
|----------|------|
| 完全無人值守的首次自動登入 | Google 反爬蟲會阻擋 |
| 使用 Playwright 嘗試 Google 認證 | 會被檢測，觸發安全警告 |
| 使用 playwright-stealth 隱匿 | 過度設計，不可靠 |
| 直接 hardcode cookies | 安全風險，難以維護 |

### 5.3 🔧 故障排除

**問題 1: "401 Unauthorized" 或認證錯誤**

```bash
# 解決方案: 重新登入
nlm login
```

**問題 2: Chrome 未找到**

```bash
# Linux
sudo apt-get install chromium-browser

# macOS
# Chrome 應該已安裝

# 檢查 Chromium 路徑
which chromium chrome google-chrome
```

**問題 3: 多 profile 混亂**

```bash
# 列出所有 profiles
nlm login profile list

# 切換 profile
nlm login switch <profile>

# 刪除不需要的 profile
nlm login profile delete <profile>
```

---

## 6. 關鍵問題解答

### Q1: 能否無人值守自動登入？

**A: ❌ 不能 (完全無人值守首次登入)**

**原因**:
- Google 的反爬蟲系統會阻擋純 headless 自動登入
- 檢測 JA3 TLS 指紋、WebGL 指紋、`navigator.webdriver` 標誌
- 2FA/MFA 無法繞過

**可行替代方案**:
1. **一手動設置 + nlm 內建自動恢復** (最推薦)
2. **Cookie 導入 + CI/CD Secrets** (適合 CI/CD)

---

### Q2: 是否每次都需要登入？

**A: ❌ 不需要**

**nlm CLI 的三層恢復機制**:
- Layer 1: 自動刷新 ~20 分鐘的短期 tokens
- Layer 2: 自動從磁盤加載 cookies
- Layer 3: 無頭 Chrome 自動認證 (如果 profile 有保存登入)

**實際體驗**:
- 首次登入後，通常可以使用 2-4 週無需重新認證
- Layer 1/2 在 20 分鐘窗口期內完全自動
- Layer 3 在 cookies 過期時條件自動 (如果 Chrome profile 有保存登入)

---

### Q3: OpenCode 能否透過 ACP 控制瀏覽器登入流程？

**A: ✅ 理論上可以，但❌ 不推薦**

**OpenCode 的能力**:
- ✅ 有 Playwright MCP skill，可以完全控制瀏覽器
- ✅ 可以填寫表單、點擊按鈕、提取 cookies

**為何不推薦**:
1. **Google 反爬蟲會阻擋**: 觸發 "此瀏覽器或應用程式可能不安全"
2. **nlm 已更好**: nlm CLI 已內建更可靠的 CDP 實現
3. **維護成本高**: 需要處理 UI 變化、2FA、驗證碼等
4. **不需要**: nlm 的三層恢復機制已足夠

**何時可用 OpenCode 的 Playwright**:
- ✅ 非認證相關的瀏覽器自動化
- ✅ 登入之後的操作
- ❌ Google 自動登入 (不推薦)

---

### Q4: agent-browser (vercel-labs) 是否有相關功能？

**A: ❌ 不需要，非必要**

**原因**:
- nlm CLI 已內建完整的瀏覽器自動化和認證機制
- 使用 Chrome DevTools Protocol (CDP) 直接控制 Chrome
- 比第三方瀏覽器自動化工具更可靠
- 無需額外的複雜性和依賴

**結論**: 使用 nlm CLI 的內建機制即可，無需 agent-browser

---

## 7. 技術細節

### 7.1 nlm CLI 內部運作機制

#### Step 1: 啟動 Chrome

```python
# 來源: notebooklm-mcp-cli/src/notebooklm_tools/utils/cdp.py
chrome_args = [
    chrome_path,
    f"--remote-debugging-port={port}",       # 預設 9222
    "--no-first-run",
    "--no-default-browser-check",
    "--disable-extensions",
    f"--user-data-dir={profile_dir}",         # ~/{profile} 存儲使用者資料
    "--remote-allow-origins=*",              # WebSocket 連接 (Chrome 136+)
]

if headless:
    args.append("--headless=new")            # Headless 模式
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

#### Step 5: 保存到文件

```python
# 存儲位置: ~/.notebooklm-mcp-cli/profiles/<profile>/cookies.json
# 包含: cookies, csrf_token, session_id, extracted_at
```

### 7.2 Chrome Profile 管理

**啟動 Chrome 的關鍵參數**:

```python
def launch_chrome_process(port: int = CDP_DEFAULT_PORT,
                         headless: bool = False,
                         profile_name: str = "default") -> subprocess.Popen:
    """啟動 Chrome 並返回進程句柄"""
    chrome_path = get_chrome_path()
    profile_dir = get_chrome_profile_dir(profile_name)

    args = [
        chrome_path,
        f"--remote-debugging-port={port}",      # 啟用 CDP
        f"--user-data-dir={profile_dir}",        # 獨立 profile (保存登入狀態)
        "--no-first-run",
        "--no-default-browser-check",
        "--disable-extensions",
        "--remote-allow-origins=*",              # WebSocket 連接
    ]

    if headless:
        args.append("--headless=new")           # Headless 模式

    return subprocess.Popen(args)
```

---

## 8. 安全考量

### 8.1 敏感資料處理

**重要**:
- ❌ 不要分享 `cookies.json` 或 `auth.json` 文件
- ❌ 不要提交到版本控制系統
- ✅ 使用 CI/CD Secrets 管理認證資料

### 8.2 權限設置

```bash
# 設置嚴格的權限
chmod 700 ~/.notebooklm-mcp-cli/profiles/
chmod 600 ~/.notebooklm-mcp-cli/profiles/*/cookies.json
```

### 8.3 環境變量認證 (CI/CD)

nlm CLI 支持通過環境變量提供認證資料：

```bash
# 支持內聯 JSON，無需文件寫入
export NOTEBOOKLM_AUTH_JSON='{"cookies":[{"name":"SID","value":"..."}]}'
```

---

## 9. 推薦資源

### 官方文檔

- [notebooklm-mcp-cli GitHub](https://github.com/jacob-bd/notebooklm-mcp-cli) - 最新版本 v0.2.15
- [CLI Guide](https://github.com/jacob-bd/notebooklm-mcp-cli/blob/main/docs/CLI_GUIDE.md)
- [Authentication Guide](https://github.com/jacob-bd/notebooklm-mcp-cli/blob/main/docs/AUTHENTICATION.md)
- `nlm --ai` - 運行 `nlm --ai` 獲取 AI 助手專用文檔

### OpenCode MCP

- Playwright MCP skill - OpenCode 內建瀏覽器自動化
- 瀏覽器控制、表單填寫、點擊、cookies 抓取等功能

### 社區資源

- [Playwright Auth Guide](https://playwright.dev/python/docs/auth) - 官方 Playwright 認證指南

---

## 10. 總結與推薦

### 🏆 最佳實踐: 使用 nlm CLI 內建機制

**推薦方案**:
1. **個人開發/腳本自動化**: 方案 B - 一手動設置 + nlm 內建
2. **CI/CD Pipeline**: 方案 C - Cookie 導入 + Secrets
3. **長期服務/容器化**: 方案 D - 環境變量覆蓋

**核心原則**:
- ✅ 一次性手動設置
- ✅ nlm CLI 內建三層恢復機制自動處理
- ✅ 2-4 週後重新手動登入一次
- ❌ 完全無人值守的首次登入 (不可行)
- ❌ 使用 Playwright 嘗試 Google 認證 (不推薦)

### 📊 方案選擇流程圖

```
開始
  ↓
使用場景是什麼？
  ├─ 個人開發/腳本 → 方案 B: 一手動設置 + nlm 內建 ⭐
  ├─ CI/CD Pipeline → 方案 C: Cookie 導入 + Secrets ⭐
  ├─ 長期服務/容器 → 方案 D: 環境變量覆蓋 ⭐
  └─ 多環境部署 → 方案 E: Profile 隔離 ⭐

  ↓
首次: 手動登入一次 (nlm login)
  ↓
後續: nlm 內建機制自動處理 (三層恢復)
  ↓
2-4 週後: 重新手動登入一次
  ↓
完成
```

### 📝 快速開始指南

```bash
# 1. 安裝
uv tool install notebooklm-mcp-cli

# 2. 首次登入 (手動)
nlm login

# 3. 驗證
nlm login --check

# 4. 使用
nlm notebook list
```

---

## 附錄: 現有研究文件

本研究參考了以下現有研究文件：

1. `notebooklm-cli-best-practices-results.md` - 2026-02-04 主要研究
2. `notebooklm-auto-login-research.md` - 自動登入研究
3. `notebooklm-cli-comprehensive-research.md` - 綜合研究
4. `results-final.md` - 最終結果
5. `notebooklm-research-results.md` - 研究結果
6. `notebooklm-cli skill SKILL.md` - 本地 skill 文檔
7. GitHub [notebooklm-mcp-cli](https://github.com/jacob-bd/notebooklm-mcp-cli) - 最新版本 v0.2.15 (2026-02-04)

---

**研究完成日期**: 2026-02-05
**研究者**: Sisyphus (OhMyOpenCode AI Agent)
**研究方法**: 探索本地代碼 + 分析現有研究 + GitHub 官方資訊 + OpenCode MCP 技能文檔
