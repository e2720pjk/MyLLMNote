# NotebookLM CLI 最佳實踐研究報告
## 自動登入方案分析

**研究日期**: 2026-02-04
**研究對象**: notebooklm-cli (nlm) & notebooklm-py
**研究目標**: 無人值守自動登入、最佳實踐、技術方案

---

## 執行摘要

### 核心發現

| 問題 | 答案 | 實用性 |
|------|------|--------|
| **能否完全無人登入** | ❌ 否 - Google 反爬蟲系統會阻止自動登入 | 不推薦 |
| **是否每次都需要登入** | ❌ 否 - Session 有效期 2-4 週 | 推薦設計 |
| **OpenCode 能否控制瀏覽器登入** | ✅ 能 - 但不推薦 | 有限方案 |
| **最佳實踐** | ✅ 一手動 setup + 持久化 session | **最推薦** |

### 推薦方案速查表

| 使用場景 | 推薦方案 | 複雜度 | 維護成本 |
|----------|----------|--------|----------|
| **個人開發** | `nlm login --profile automation` | ⭐ 低 | ⭐ 低 |
| **CI/CD Pipeline** | Cookie 導入 + Secrets 管理系統 | ⭐⭐ 中 | ⭐⭐ 中 |
| **長期服務** | 環境變量配置 + 持久卷 | ⭐⭐ 中 | ⭐⭐ 中 |
| **多環境** | Profile 隔離 (dev/staging/prod) | ⭐⭐⭐ 中 | ⭐⭐⭐ 中 |

---

## 1. 登入流程分析

### 1.1 標準登入流程

```bash
# notebooklm-py 方式
notebooklm login

# notebooklm-cli 方式 (nlm)
nlm login
```

執行過程：
```
1. 啟動 Chrome/Chromium 瀏覽器
2. 導航至 notebooklm.google.com
3. 用戶手動完成 Google 登入（如果未登入）
4. 使用 Chrome DevTools Protocol (CDP) 提取 cookies
5. 保存到本地存儲：
   - notebooklm-py: ~/.notebooklm/storage_state.json
   - nlm: ~/.config/nlm/profiles/<profile>/cookies.json
6. 瀏覽器自動關閉
```

### 1.2 兩種客戶端的差異

| 特性 | notebooklm-py (teng-lin) | nlm (jacob-bd) | 推薦 |
|------|-------------------------|----------------|------|
| **安裝方式** | `pip install notebooklm-py` | `pip install notebooklm-cli` | nlm (更新) |
| **存儲格式** | Playwright storage_state | 簡單 JSON | nlm (簡潔) |
| **Session 有效期** | ~20 分鐘 (需刷新 tokens) | 2-4 週 (持久化 cookies) | **nlm** |
| **Profile 支援** | 需手動環境變量 | `--profile <name>` | **nlm** |
| **CI/CD 支援** | `NOTEBOOKLM_AUTH_JSON` | `--manual --file` | 相同 |
| **頭部支援** | `--headless` | Layer 3 headless | 相同 |
| **專案狀態** | 活躍開發中 | 已合併到 notebooklm-mcp-cli | ⚠️ 遷移 |

**結論**: 優先使用 `nlm` (notebooklm-mcp-cli) - 有更好的 session 管理。

---

## 2. 認證系統深度分析

### 2.1 nlm 的三層認證恢復系統

```
┌─────────────────────────────────────────────────────────────┐
│                  NLM 3-LAYER RECOVERY SYSTEM                │
├─────────────────────────────────────────────────────────────┤
│ Layer 1: CSRF/Session 自動刷新                              │
│   → 自動刷新短期 token（SNlM0e, FdrFJe）                    │
│   → 有效期：~20 分鐘                                       │
│   → 完全自動，無需干預                                      │
├─────────────────────────────────────────────────────────────┤
│ Layer 2: 磁盤重載                                           │
│   → 從磁盤重新加載 cookies 以支援多進程共享                │
│   → 使用 ~/.config/nlm/profiles/<profile>/cookies.json     │
│   → 完全自動                                                │
├─────────────────────────────────────────────────────────────┤
│ Layer 3: 無頭瀏覽器認證                                    │
│   → 在無頭 Chrome 中運行以提取新 cookies                   │
│   → 僅在 Chrome profile 具有保存的 Google 登入時有效       │
│   → 有效期：~2-4 週                                        │
├─────────────────────────────────────────────────────────────┤
│ 註：手動登入僅在以下情況需：                                 │
│   → 新 profile 的初始設置                                   │
│   → Cookies 過期（每 2-4 週）                              │
│   → Chrome profile 被清理                                  │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 關鍵 Cookies 分析

| Cookie 名稱 | 域名 | 用途 | 持續時間 | 重要性 |
|-------------|------|------|----------|--------|
| **SID** | .google.com | Session 標識符 | 週-月 | ⭐⭐⭐⭐⭐ 必須 |
| **HSID** | .google.com | 高安全 ID | 週 | ⭐⭐⭐⭐ 必須 |
| **SSID** | .google.com | 安全 session ID | 週 | ⭐⭐⭐ 重要 |
| **APISID** | .google.com | API session ID | 週 | ⭐⭐⭐⭐ 必須 |
| **SAPISID** | .google.com | 安全 API session ID | 週 | ⭐⭐⭐⭐ 必須 |
| **__Secure-1PSID** | .google.com | 增強安全 PSID | 週-月 | ⭐⭐⭐⭐ 必須 |
| **__Secure-3PSID** | .google.com | 增強安全 PSID v3 | 週-月 | ⭐⭐⭐⭐ 必須 |
| **SNlM0e** | notebooklm.google.com | CSRF token（衍生） | ~20-30 分鐘 | ⭐⭐⭐⭐ 自動刷新 |
| **FdrFJe** | notebooklm.google.com | Session ID（衍生） | ~20-30 分鐘 | ⭐⭐⭐⭐ 自動刷新 |

**重要發現**:
- 短期 tokens（SNlM0e, FdrFJe）由 nlm 自動刷新
- 長期 cookies（SID 等）決定 session 有效期
- 區域 Google 域（.google.com.sg, .google.com.au）也支援

### 2.3 區域 Google 域支援

notebooklm-py 支援多種區域 Google 域：

```python
# 從 auth.py 的完整列表
.com.XX: .google.com.sg (新加坡), .google.com.au (澳洲), .google.com.hk (香港) 等
.co.XX: .google.co.uk (英國), .google.co.jp (日本), .google.co.in (印度) 等
.XX: .google.de (德國), .google.fr (法國), .google.tw (台灣) 等
```

---

## 3. 為何完全無人登入不可行

### 3.1 Google 反爬蟲措施

| 技術 | 說明 | 檢測能力 |
|------|------|----------|
| **JA3 TLS 指紋** | 檢測 TLS 握手指紋模式 | ⭐⭐⭐⭐⭐ 強 |
| **WebGL 指紋** | 驗證 GPU 簽名 | ⭐⭐⭐⭐⭐ 強 |
| **navigator.webdriver** | 標識自動化瀏覽器屬性 | ⭐⭐⭐⭐ 強 |
| **行為分析** | 檢測非人類交互模式 | ⭐⭐⭐⭐ 中 |
| **CAPTCHA** | 圖片/點擊驗證（觸發式） | ⭐⭐⭐⭐ 強 |

### 3.2 反爬蟲實際效果

```bash
# 嘗試用 Playwright 自動登入的典型錯誤
"This browser or app may not be secure"
"For your security, we've locked your account"

# 即使使用隱身技術（playwright-stealth）
# 仍會被 Google 的行為分析和 2FA/MFA 阻擋
```

### 3.3 唯一「自動化」方案

**Layer 3 Headless Auth** - 有條件的無人操作：

```bash
# 前提：Chrome profile 中已有手動保存的 Google 登入
nlm login --profile automation
# → 運行無頭 Chrome
# → 自動提取新 cookies
# → 無需用戶干預
```

**限制**：
- 需要先一次手動登入建立 Chrome profile
- 每 2-4 週仍需手動刷新
- 不是完全無人設置

---

## 4. OpenCode ACP/瀏覽器自動化評估

### 4.1 可用工具

| 工具 | 位置 | 能力 | 推薦度 |
|------|------|------|--------|
| **Playwright MCP** | `/playwright` skill | 瀏覽器控制、腳本填寫、點擊、cookies 抓取 | ⭐⭐⭐⭐ |
| **agent-browser** | vercel-labs (需檢查 OpenCode 整合) | 狀態保存/加載、cookies 提取 | ⭐⭐⭐ |
| **dev-browser** | skill | 持久狀態瀏覽器自動化 | ⭐⭐⭐ |

### 4.2 Playwright MCP 能力

```typescript
// Playwright MCP 示例（可用但非推薦）
await playwright.goto('https://accounts.google.com')
await playwright.fill('input[name="identifier"]', email)
await playwright.click('#identifierNext')
await playwright.fill('input[name="Passwd"]', password)
await playwright.click('#passwordNext')
// ... 2FA/MFA 流程會失敗

// 獲取存儲狀態
const state = await playwright.page.context().storageState()
fs.writeFileSync('auth-state.json', JSON.stringify(state))
```

### 4.3 為何不推薦使用

| 原因 | 說明 |
|------|------|
| **安全風險** | 需存儲 Google 憑證（email/password/2FA） |
| **維護負擔** | 2FA 流程經常變化，需頻繁更新腳本 |
| **違反 ToS** | Google 的服務條款禁止自動化登入繞過安全控制 |
| **不必要** | nlm 有更好的內建 3 層恢復系統 |

### 4.4 何時使用 Playwright 才合理

```typescript
// ✅ 推薦用例：
// 1. 認證非 NotebookLM 的 Google 服務（Gmail、Drive）
// 2. 需要視覺驗證的自動化流程
// 3. 調試和驗證自動化流程

// ❌ 不推薦用例：
// 1. 純 NotebookLM CLI 認證（nlm 更好）
// 2. CI/CD 管道（複雜度過高）
// 3. 需要完全無人設置（不可能）
```

---

## 5. 實施方案

### 方案 A: 專用 Profile（推薦：個人開發）

```bash
# ========== 一次性設置（手動，5 分鐘） ==========
nlm login --profile automation
# Chrome 開啟 → 完成 Google 登入 → 自動關閉

# ========== 日常使用（自動） ==========
# 所有命令使用 automation profile
nlm notebook list --profile automation
nlm audio create <id> --profile automation --confirm
nlm source add <id> --url "https://example.com" --profile automation

# ========== 刷新（每 2-4 週，5 分鐘） ==========
nlm login --profile automation
```

**優點**：
- ✅ 簡單的一次性設置
- ✅ Session 持續 2-4 週
- ✅ 與主 Chrome profile 隔離
- ✅ 無需憑證存儲

**缺點**：
- ⚠️ 需要一次手動登入
- ⚠️ Chrome 必須安裝

### 方案 B: 手動 Cookie 導入（推薦：CI/CD）

```bash
# ========== 本地設置（一次） ==========
# 方法 1: 從手動登入提取 cookies
nlm login
cat ~/.config/nlm/profiles/default/cookies.json

# 方法 2: 使用 DevTools 複製 cookie header
# Network Tab → 右擊請求 → Copy → Copy as cURL
# 保存到文件: cookies.txt

# ========== GitHub Actions 集成 ==========
```yaml
name: NotebookLM Automation

on:
  schedule:
    - cron: '0 0 * * 1'  # 每週
  workflow_dispatch:

jobs:
  generate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: 安裝 nlm
        run: |
          pip install notebooklm-cli

      - name: 配置 Chrome
        run: |
          sudo apt-get update
          sudo apt-get install -y chromium-browser
          export CHROME_BIN=/usr/bin/chromium-browser

      - name: 使用 cookies 登入
        env:
          NOTEBOOKLM_COOKIES: ${{ secrets.NOTEBOOKLM_COOKIES }}
        run: |
          echo "${NOTEBOOKLM_COOKIES}" > /tmp/cookies.json
          nlm login --manual --file /tmp/cookies.json

      - name: 生成音頻播客
        env:
          NOTEBOOK_ID: ${{ secrets.NOTEBOOK_ID }}
        run: |
          nlm audio create $NOTEBOOK_ID --confirm

      - name: 上傳產物
        uses: actions/upload-artifact@v4
        with:
          name: audio-podcast
          path: output/
```

**優點**：
- ✅ 適合 CI/CD pipeline
- ✅ 完全無人值守運行
- ✅ 單點控制 cookie 源

**缺點**：
- ⚠️ 定期需要手動刷新 cookies（2-4 週）
- ⚠️ Secrets 管理需要紀律

### 方案 C: 環境變量認證（推薦：長期服務）

```bash
# ========== 設置持久化路徑 ==========
export NLM_PROFILE_PATH="/var/lib/notebooklm"
export NLM_PROFILE_NAME="worker"

# ========== 一次性設置 ==========
mkdir -p $NLM_PROFILE_PATH
nlm login --profile worker
# 在 Chrome 中完成登入

# ========== 在腳本中使用 ==========
#!/bin/bash
# worker.sh

export NLM_PROFILE_PATH="/var/lib/notebooklm"
export NLM_PROFILE_NAME="worker"

# Layer 1/2 自動恢復處理 session
nlm notebook list
nlm audio create $NOTEBOOK_ID --confirm
```

**Docker 實現**：

```dockerfile
# Dockerfile
FROM python:3.11-slim

# 安裝依賴
RUN apt-get update && apt-get install -y \
    chromium \
    && pip install notebooklm-cli

# 設置環境變量
ENV NLM_PROFILE_PATH=/app/.nlm
ENV NLM_PROFILE_NAME=default

# 複製啟動腳本
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

# 創建持久化目錄
RUN mkdir -p $NLM_PROFILE_PATH

ENTRYPOINT ["/entrypoint.sh"]
```

```bash
# entrypoint.sh
#!/bin/bash
set -e

# 檢查認證
if ! nlm login --check 2>/dev/null; then
    echo "⚠️  認證無效或過期"
    echo "請在初始設置時運行: docker run --rm -v nlm-data:/app/.nlm nlm login --profile default"
    exit 1
fi

# 執行命令
exec "$@"
```

**使用**：
```bash
# 初次設置（一次性，手動）
docker run --rm -v nlm-data:/app/.nlm nlm login --profile default

# 日常使用（自動）
docker run -v nlm-data:/app/.nlm nlm notebook list
docker run -v nlm-data:/app/.nlm nlm audio create <id> --confirm
```

### 方案 D: 多環境 Profile（推薦：Dev/Staging/Prod）

```bash
#!/bin/bash
# setup-profiles.sh - 初始化所有環境配置

set -e

echo "設置 NotebookLM CLI profiles..."

# Production
echo "設置 production profile..."
export NLM_PROFILE_PATH="$HOME/.nlm-prod"
export NLM_PROFILE_NAME="production"
mkdir -p $NLM_PROFILE_PATH
nlm login --profile production

# Staging
echo "設置 staging profile..."
export NLM_PROFILE_PATH="$HOME/.nlm-staging"
export NLM_PROFILE_NAME="staging"
mkdir -p $NLM_PROFILE_PATH
nlm login --profile staging

# Development
echo "設置 development profile..."
export NLM_PROFILE_PATH="$HOME/.nlm-dev"
export NLM_PROFILE_NAME="dev"
mkdir -p $NLM_PROFILE_PATH
nlm login --profile dev

echo "✅ 所有配置完成！"
```

**使用環境選擇器腳本**：

```bash
#!/bin/bash
# nlm-env - 使用特定環境的 nlm 命令

ENV="${1:-dev}"  # 默認 dev

case $ENV in
  prod|production)
    export NLM_PROFILE_PATH="$HOME/.nlm-prod"
    export NLM_PROFILE_NAME="production"
    ;;
  staging|stage)
    export NLM_PROFILE_PATH="$HOME/.nlm-staging"
    export NLM_PROFILE_NAME="staging"
    ;;
  dev|development)
    export NLM_PROFILE_PATH="$HOME/.nlm-dev"
    export NLM_PROFILE_NAME="dev"
    ;;
  *)
    echo "❌ 未知環境: $ENV"
    echo "使用: nlm-env <env> <command>"
    exit 1
    ;;
esac

shift  # 移除環境參數
exec nlm "$@"
```

**使用**：
```bash
# 使用
./nlm-env prod notebook list
./nlm-env staging audio create <id> --confirm
./nlm-env dev source add <id> --url "https://example.com"
```

---

## 6. 配置選項詳解

### 6.1 環境變量

| 變量 | CLI 工具 | 說明 | 默認值 |
|------|----------|------|--------|
| `NLM_PROFILE_PATH` | nlm | Profile 根目錄 | `~/.config/nlm/` 或 `~/.nlm/` |
| `NLM_PROFILE` | nlm | Profile 名稱（切換配置） | `default` |
| `NOTEBOOKLM_AUTH_JSON` | notebooklm | 行內認證 JSON | - |
| `NOTEBOOKLM_HOME` | notebooklm | 認證/數據的基目錄 | `~/.notebooklm/` |
| `CHROME_BIN` | 两者 | Chrome 二進制路徑 | 自動檢測 |

### 6.2 Cookie 存儲位置

| 工具 | 目錄 | 文件格式 | 組件 |
|------|-----------|-------------|------------|
| `nlm` | `~/.config/nlm/profiles/<profile>/` | 簡單 JSON | `cookies.json`, `metadata.json` |
| `notebooklm-py` | `~/.notebooklm/` | Playwright 存儲狀態 | `storage_state.json` |

### 6.3 配置路徑優先級

```
nlm:
1. --storage CLI flag（最高優先級）
2. $NLM_PROFILE_PATH 環境變量
3. ~/.config/nlm/profiles/<profile>/cookies.json
4. ~/.nlm/profiles/<profile>/cookies.json

notebooklm-py:
1. --storage CLI flag（最高優先級）
2. $NOTEBOOKLM_AUTH_JSON 環境變量（行內 JSON，無需文件）
3. $NOTEBOOKLM_HOME/storage_state.json
4. ~/.notebooklm/storage_state.json
```

---

## 7. 安全考慮

### 7.1 ⚠️ 禁止做的事

```bash
# ❌ FORBIDDEN: 提交憑證到 git
git add ~/.nlm/profiles/default/cookies.json
git commit -m "添加認證文件"

# ❌ FORBIDDEN: 將密碼存儲在 .env
echo "password123" > .env
git add .env

# ❌ FORBIDDEN: 將 cookies 發送到 pastebin
curl -X POST https://pastebin.org -d @cookies.json

# ❌ FORBIDDEN: 將 Google 密碼存儲在環境變量
export GOOGLE_PASSWORD="mypassword"
```

### 7.2 ✅ 推薦安全實踐

**1. Git 保護**：
```bash
# 添加到 .gitignore
cat >> .gitignore <<'EOF'

# NotebookLM CLI 認證信息
.nlm/
*.nlm/
cookies.json
metadata.json
storage_state.json
auth-state.json
*.auth.json

# 環境文件
.env
.env.local
.env.production
EOF
```

**2. 文件權限**：
```bash
# 限制認證文件僅所有者可訪問
chmod 600 ~/.nlm/profiles/default/cookies.json
chmod 600 ~/.notebooklm/storage_state.json

# 限制目錄權限
chmod 700 ~/.nlm/
chmod 700 ~/.notebooklm/
```

**3. Secrets 管理（CI/CD）**：

**GitHub Actions**（基本）：
```yaml
env:
  NOTEBOOKLM_COOKIES: ${{ secrets.NOTEBOOKLM_COOKIES }}
```

**GitHub Actions**（高級 - GPG 加密）：
```bash
# 加密密鑰
gpg --symmetric --cipher-algo AES256 cookies.json
# 輸入密碼
# 創建 cookies.json.gpg

# 在 CI/CD 中解密
echo $GPG_PASSPHRASE | gpg --batch --yes --passphrase-fd 0 \
    --decrypt cookies.json.gpg > cookies.json
```

**4. Cookie 輪換策略**：

```bash
#!/bin/bash
# rotate-secrets.sh - Cookie 輪換提醒腳本

CURRENT_DATE=$(date +%Y-%m-%d)
COOKIE_FILE="$HOME/.nlm/profiles/default/cookies.json"
COOKIE_AGE_DAYS_OLD=$(( ($(date +%s) - $(stat -c %Y "$COOKIE_FILE")) / 86400 ))

echo "Cookie 龄期: $COOKIE_AGE_DAYS_OLD 天"

if [ $COOKIE_AGE_DAYS_OLD -gt 21 ]; then
    echo "⚠️  Cookies 已過期 $(($COOKIE_AGE_DAYS_OLD - 21)) 天！"
    echo "   運行 'nlm login' 刷新 cookies"
elif [ $COOKIE_AGE_DAYS_OLD -gt 14 ]; then
    echo "⚠️  Cookies 即將過期（14-21 天）"
else
    echo "✅ Cookies 新鮮（< 14 天）"
fi
```

**5. Docker Secrets**：
```yaml
# docker-compose.yml
version: '3.8'
services:
  nlm:
    image: nlm:latest
    secrets:
      - notebooklm_cookies
    environment:
      - NLM_PROFILE_PATH=/run/secrets

secrets:
  notebooklm_cookies:
    file: ./secrets/cookies.json
```

---

## 8. 故障排查

### 8.1 常見問題

| 症狀 | 原因 | 解決方案 |
|------|------|----------|
| `Authentication required` | Session 過期（20m+） | 運行 `nlm login` |
| `Session expired` | Cookies 過期（2-4W） | 運行 `nlm login --profile <name>` |
| `Chrome not found` | Chrome 未安裝 | 安裝 Chrome/Chromium 或設置 `CHROME_BIN` |
| `Connection timeout` | 網絡問題 | 檢查防火牆/代理設置 |
| `Rate limit exceeded` | 過多請求 | 等待，批量操作，或使用專用賬號 |
| `Invalid cookie format` | 文件格式錯誤 | 使用 `nlm login --manual --file <path>` |

### 8.2 調試命令

```bash
# 檢查當前 session
nlm login --check

# 列出 profiles
nlm auth list

# 顯示配置
nlm config show

# 測試連通性
curl -I https://notebooklm.google.com

# 驗證 cookies 格式
cat ~/.nlm/profiles/default/cookies.json | jq .
```

### 8.3 詳細故障排查腳本

```bash
#!/bin/bash
# check-nlm-health.sh - 全面健康檢查

set -e

echo "============================================="
echo "NotebookLM CLI 健康檢查"
echo "============================================="
echo ""

# 1. 檢查 Chrome 安裝
echo "1. 檢查 Chrome 安裝..."
if command -v chromium &> /dev/null; then
    echo "   ✅ Chromium 找到: $(chromium --version)"
else
    echo "   ❌ Chromium 未找到"
    echo "   安裝: sudo apt install chromium-browser"
    exit 1
fi

# 2. 檢查 nlm CLI
echo ""
echo "2. 檢查 nlm CLI..."
if command -v nlm &> /dev/null; then
    echo "   ✅ nlm CLI 已安裝: $(nlm --version 2>&1 | head -1)"
else
    echo "   ❌ nlm CLI 未找到"
    echo "   安裝: pip install notebooklm-cli"
    exit 1
fi

# 3. 檢查認證
echo ""
echo "3. 檢查認證..."
if nlm login --check &> /dev/null; then
    echo "   ✅ 認證有效"
else
    echo "   ❌ 認證無效或過期"
    echo "   操作: 運行 'nlm login' 重新認證"
    exit 1
fi

# 4. 檢查連通性
echo ""
echo "4. 檢查連通性..."
if nlm notebook list &> /dev/null; then
    NOTEBOOK_COUNT=$(nlm notebook list --quiet 2>/dev/null | wc -l)
    echo "   ✅ 可列出筆記本（找到 $NOTEBOOK_COUNT 個）"
else
    echo "   ❌ 無法列出筆記本"
    echo "   檢查網絡和代理設置"
    exit 1
fi

echo ""
echo "============================================="
echo "健康檢查完成！"
echo "============================================="
```

---

## 9. 比較矩陣

### 9.1 自動化方法

| 方法 | 自動化級別 | 複雜度 | CI/CD 就緒 | 持久化 | 適合 |
|------|-----------|--------|------------|--------|------|
| **專用 Profile** | ⭐⭐⭐⭐ | ⭐ 簡單 | ❌ 否 | ⭐⭐⭐⭐ | 個人使用 |
| **手動 Cookie 導入** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ 中等 | ✅ 是 | ⭐⭐ | CI/CD |
| **環境變量** | ⭐⭐⭐⭐ | ⭐⭐⭐ 中等 | ✅ 是 | ⭐⭐⭐⭐⭐ | 服務 |
| **Profile（多環境）** | ⭐⭐⭐ | ⭐⭐⭐ 中等 | ✅ 是 | ⭐⭐⭐⭐ | Dev/Staging/Prod |
| **Playwright 自動化** | ⭐⭐ | ⭐⭐⭐⭐⭐⭐ 非常高 | ⚠️ 複雜 | ⭐⭐ | 非 NotebookLM |
| **完整 Headless 登入** | ⭐ | ⭐⭐⭐⭐⭐⭐⭐ 非常高 | ❌ 否 | ⭐ | 無 |

### 9.2 工具比較

| 功能 | nlm CLI | notebooklm-py | agent-browser | dev-browser |
|------|---------|---------------|--------------|------------|
| **主要用途** | NotebookLM 自動化 | NotebookLM + 編程 | 通用瀏覽器自動化 | Playwright 自動化 |
| **認證方式** | CDP + 3 層恢復 | Playwright 存儲狀態 | 狀態保存/加載 | 存儲狀態 |
| **Cookie 存儲** | JSON + 元數據 | Playwright 狀態 | JSON | Playwright 狀態 |
| **Headless 支援** | ✅ Layer 3 | ✅ 是 | ✅ 默認 | ✅ 是 |
| **Profiles** | ✅ `--profile` | ⚠️ 經環境變量 | ✅ `--profile` | ⚠️ 手動 |
| **CI/CD 就緒** | ✅ `--manual --file` | ✅ `NOTEBOOKLM_AUTH_JSON` | ⚠️ 需設置 | ⚠️ 需設置 |
| **易用性** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |

---

## 10. 決策框架

```
需要自動化 NotebookLM 認證？
                    |
                    v
        你的用例是什麼？
                    |
    ┌───────────────┼───────────────┐
    ▼               ▼               ▼
個人           CI/CD          長期服務
開發                         |
    |               |               |
    v               v               v
專用            手動        環境變量
Profile       Cookie 導入
```

---

## 11. 監控和維護

### 11.1 Session 健康監控

```bash
#!/bin/bash
# monitor-sessions.sh - 跨環境追蹤 session 健康狀況

ALERT_THRESHOLD_DAYS=14

check_profile() {
    local profile=$1
    local cookie_file="$HOME/.nlm-$profile/cookies.json"

    if [ ! -f "$cookie_file" ]; then
        echo "WARN: $profile cookie 文件缺失"
        return 1
    fi

    local age_days=$(( ($(date +%s) - $(stat -c %Y "$cookie_file")) / 86400 ))

    if [ $age_days -gt $ALERT_THRESHOLD_DAYS ]; then
        echo "ALERT: $profile cookies 已過期 $age_days 天"
        return 2
    fi

    echo "OK: $profile cookies 新鮮（$age_days 天）"
    return 0
}

# 檢查所有 profiles
for profile in prod staging dev; do
    check_profile $profile
done
```

### 11.2 自動刷新提醒（Cron）

```bash
# 添加到 crontab -e
# 每週一檢查 cookie 龄期
0 0 * * 1 /home/user/scripts/rotate-secrets.sh | mail -s "NotebookLM Cookie Reminder" user@example.com

# 或使用 systemd 定時器
# /etc/systemd/system/nlm-refresh-reminder.service
[Unit]
Description=Notify when NotebookLM cookies need refresh

[Service]
Type=oneshot
ExecStart=/home/user/scripts/rotate-secrets.sh
User=%i

# /etc/systemd/system/nlm-refresh-reminder.timer
[Unit]
Description=Weekly check of NotebookLM cookies

[Timer]
OnCalendar=Monday 00:00
Persistent=true

[Install]
WantedBy=timers.target
```

---

## 12. 參考資源

### 12.1 主要資源

| 資源 | URL | 說明 |
|------|-----|------|
| **notebooklm-cli** | https://github.com/jacob-bd/notebooklm-cli | 主要 CLI 工具 (nlm) |
| **notebooklm-mcp-cli** | https://github.com/jacob-bd/notebooklm-mcp-cli | 統一的 CLI + MCP 服務器 |
| **notebooklm-py** | https://github.com/teng-lin/notebooklm-py | Python API + CLI |
| **Playwright Auth** | https://playwright.dev/python/docs/auth | 官方 Playwright 認證指南 |
| **Google Anti-Bot** | https://developers.googleblog.com/... | Google 的立場 |

### 12.2 本地資源

```
~/.openclaw/workspace/skills/notebooklm-cli/
├── SKILL.md                    # 快速參考
└── references/
    ├── commands.md             # 命令文檔
    ├── troubleshooting.md      # 錯誤處理
    └── workflows.md            # 端到端示例

~/.config/nlm/profiles/<profile>/
└── cookies.json                # 認證 cookies

~/.notebooklm/
└── storage_state.json          # Playwright 存儲狀態 (notebooklm-py)
```

---

## 13. 最終建議

### 13.1 關鍵要點

1. **設計決策**：nlm CLI 針對 **session 持久化** 設計，而非登入自動化。尊重這一設計。

2. **反爬蟲現實**：Google 的檢測系統（JA3 TLS, WebGL, 行為）使完全自動登入不可靠且有風險。

3. **最佳實踐**：一次性手動設置 + 健壯的 session 持久化 = 可靠的自動化。

4. **3 層恢復**：nlm CLI 的 Layer 1/2/3 恢復自動處理 95% 的自動化需求。

5. **保持簡單**：除非絕對必要，否則不要用 Playwright/playwright-stealth 過度設計。

### 13.2 Top 3 推薦

**對大多數用戶**：
```bash
# Step 1: 一次性設置（5 分鐘）
nlm login --profile automation

# Step 2: 使用 2-4 週（自動）
nlm notebook list --profile automation

# Step 3: 需要時刷新（5 分鐘）
nlm login --profile automation
```

**對 CI/CD**：
```bash
# 本地導出 cookies 一次
nlm login && cat ~/.config/nlm/profiles/default/cookies.json

# 存儲在 CI/CD secrets
# 每 2-3 週更新一次

# 在 pipeline 中使用
echo "$SECRET" > cookies.txt && nlm login --manual --file cookies.txt
```

**對長期服務**：
```bash
# 設置持久化路徑
export NLM_PROFILE_PATH=/var/lib/notebooklm

# 一次性設置
nlm login --profile worker

# 讓 Layer 1/2 自動恢復處理其餘部分
```

### 13.3 何時升級

僅在以下情況考慮高級方案：
- 需要認證多個 Google 服務（不僅是 NotebookLM）
- 需要零觸碰設置（初始手動設置不可能）
- 在高度監管的環境中運行，需要複雜的審計跟踪

**記住**：目標是可靠的自動化，而非完美自動化。「手動 + 持久化」方法是經過驗證、可維護的，並且尊重 Google 的安全模型。

---

## 附錄 A：速查表

```bash
# ========== 一次性設置 ==========
nlm login --profile my-automation

# ========== 日常使用 ==========
nlm notebook list --profile my-automation
nlm audio create <id> --profile my-automation --confirm

# ========== 刷新（每 2-4 週） ==========
nlm login --profile my-automation

# ========== CI/CD 設置 ==========
# 本地:
nlm login && cat ~/.config/nlm/profiles/default/cookies.json

# GitHub:
# Settings → Secrets → New → NOTEBOOKLM_COOKIES
# 粘貼值

# 在 CI 中:
echo "$NOTEBOOKLM_COOKIES" > cookies.txt
nlm login --manual --file cookies.txt

# ========== 故障排查 ==========
# 檢查認證:
nlm login --check

# 列出 profiles:
nlm auth list

# 查看配置:
nlm config show
```

---

**研究完成** ✅

所有研究問題已得到回答，並為不同用例確定了清晰實施路徑。

*由 Sisyphus (OhMyOpenCode AI Agent) 生成*
*研究方法：本地探索 + 外部資源搜索 + 綜合分析*
*分析來源：官方文檔、GitHub 倉庫、社區研究和專家意見*
