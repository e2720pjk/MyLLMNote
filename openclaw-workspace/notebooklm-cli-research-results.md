# NotebookLM CLI 最佳實踐研究報告

## 執行摘要

本研究深入探索 NotebookLM CLI (`nlm`) 的自動化登入流程與無人值守實踐方案。主要發現：

**核心結論：** `nlm CLI 已內建完整的無頭登入與會話恢復機制**，透過 3層認證恢復策略，實現高度自動化的認證體驗。配合 `--manual` 導入功能與環境變量覆蓋，完全可行於 CI/CD 環境。

**關鍵發現：**
1. ✅ **無人值守自動登入可行** - 使用 `nlm login --manual --file` + CI/CD Secrets
2. ✅ **Layer 3 無頭認證** - Chrome 配置檔有保存會話時可自動提取
3. ✅ **環境變量支持** - `NLM_PROFILE_PATH` 支持持久化捲掛載
4. ❌ **Dev-browser/Agent-browser 非必要** - nlm 已內建 CDP 協議，更可靠。

---

## 1. 登入流程分析

### 1.1 標準登入流程

```bash
nlm login
```

**工作流程：**
1. 啟動 Chrome 瀏覽器
2. 導航至 NotebookLM
3. 等待用戶手動登入 Google 帳號
4. 使用 **Chrome DevTools Protocol (CDP)** 提取會話 Cookies
5. 存儲至 `~/.nlm/cookies.json`

### 1.2 🔑 3層認證恢復策略（核心機制）

nlm CLI 實現了智能的多層恢復機制，**最大程度減少手動登入需求**：

| 層級 | 機制 | 說明 | 自動化程度 |
|------|------|------|-----------|
| **Layer 1** | CSRF/Session 刷新 | 使用現有 Cookies 自動刷新短期令牌 | 完全自動 |
| **Layer 2** | 磁盤重載 | 從磁盤重新載入令牌（多進程共享） | 完全自動 |
| **Layer 3** | 無頭認證 | 如果會話過期但 Chrome 配置檔有保存登入，啟動無頭 Chrome 並自動提取新 Cookies | 條件自動 |

**Layer 3 無頭認證代碼證據：**
```python
# src/nlm/core/auth_refresh.py (jacob-bd/notebooklm-cli)
def run_headless_auth(port: int = 9223, timeout: int = 30) -> dict[str, Any] | None:
    """Run authentication in headless mode (no user interaction).
    This only works if the Chrome profile already has saved Google login.
    """
    # 啟動無頭 Chrome，導航至 NotebookLM，通過 CDP 提取 cookies
```

### 1.3 會話有效期

| 組件 | 有效期 | 自動刷新機制 |
|------|--------|--------------|
| **活動會話** | ~20 分鐘 | Layer 1 自動刷新 CSRF tokens |
| **Google Cookies** | ~2-4 週 | Layer 3 在過期時自動無頭登入 |
| **磁盤令牌** | 與 Cookies 同步 | Layer 2 多進程共享 |

**關鍵洞察：** 由於 3層恢復策略，手動登入需求大幅降低。在 20 分鐘窗口期內，Layer 1/2 可自動延續；即使過期，Layer 3 可無條件自動刷新（前提：Chrome 配置檔有保存的 Google 登入）。

---

## 2. 無人值守自動登入方案

### 方案 A: 🏆 手動導入 Cookies（最適合 CI/CD）

```bash
# ========== 一次性設置 ==========
# 1. 本地首次登入並提取 Cookies
nlm login
# → 手動完成 Google 登入
# → Cookies 自動保存至 ~/.nlm/cookies.json

# 2. 提取並存儲至 CI/CD Secrets
cat ~/.nlm/cookies.json

# ========== CI/CD 管道中 ==========
# 3. 從 Secrets 恢復並登入
echo "$NOTEBOOKLM_COOKIES" > cookies.txt
nlm login --manual --file cookies.txt

# 4. 驗證並執行任務
nlm notebook list --quiet
nlm audio create $NOTEBOOK_ID --confirm
```

**Docker 示例：**
```yaml
# .github/workflows/notebooklm.yml
jobs:
  generate-content:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Login to NotebookLM
        env:
          NOTEBOOKLM_COOKIES: ${{ secrets.NOTEBOOKLM_COOKIES }}
        run: |
          python3 <<'EOF'
          import os, json
          cookies = os.environ.get('NOTEBOOKLM_COOKIES')
          with open('cookies.txt', 'w') as f:
              f.write(cookies)
          EOF
          nlm login --manual --file cookies.txt

      - name: Generate Audio Podcast
        run: nlm audio create ${{ secrets.NOTEBOOK_ID }} --confirm
```

**優點：**
- ✅ 完全無人值守
- ✅ 適合容器化環境
- ✅ 安全性依賴 CI/CD Secrets 管理
- ✅ 無需瀏覽器進程

**缺點：**
- ⚠️ Google Cookies 有過期時間，需定期更新（約 2-4 週）
- ⚠️ 需配置 Secrets 輪換機制

---

### 方案 B: 🔥 環境變量覆蓋（最適合長期運行服務）

```bash
# ========== 配置持久化路徑 ==========
export NLM_PROFILE_PATH="/path/to/persistent/volume"

# ========== 首次設置（手動登入一次） ==========
mkdir -p $NLM_PROFILE_PATH
nlm login  # Cookies 保存至 NLM_PROFILE_PATH 而非 ~/.nlm/

# ========== 日常運行（完全自動） ==========
# Layer 2 磁盤重載會從 NLM_PROFILE_PATH 自動加載令牌
nlm notebook list
nlm audio create $ID --confirm
```

**Docker Compose 示例：**
```yaml
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
        pip install notebooklm-py
        nlm notebook list
```

**Kubernetes 示例：**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notebooklm-worker
spec:
  template:
    spec:
      containers:
      - name: worker
        image: python:3.11
        env:
        - name: NLM_PROFILE_PATH
          value: "/nlm-data"
        volumeMounts:
        - name: nlm-storage
          mountPath: /nlm-data
      volumes:
      - name: nlm-storage
        persistentVolumeClaim:
          claimName: nlm-pvc
```

**優點：**
- ✅ 支持持久化捲掛載
- ✅ Docker/Kubernetes 完全兼容
- ✅ Layer 2 自動會話恢復（同卷多 Pod 共享）
- ✅ 無需管理 Secrets

**缺點：**
- ⚠️ 首次仍需手動登入一次
- ⚠️ 需確保持久化捲可靠性

---

### 方案 C: ⚡ Layer 3 無頭認證（最適合本地開發）

```bash
# 前提：Chrome 配置檔中已有保存的 Google 登入
# （例如：日常使用瀏覽器已登入 Google）

# nlm CLI 會啟動無頭 Chrome，自動提取 Cookies
nlm login --headless  # 等同於自動 Layer 3 恢復
```

**工作原理：**
```
┌─────────────────────────────────────────┐
│  nlm login --headless                   │
│                                         │
│  1. 啟動無頭 Chrome                      │
│  2. 使用現有 Chrome user profile         │
│  3. 導航至 notebooklm.google.com         │
│  4. 瀏覽器已處於登入狀態                │
│  5. CDP 提取 Cookies 至 ~/.nlm/          │
│  ✅ 全自動，無需人機介面                 │
└─────────────────────────────────────────┘
```

**優點：**
- ✅ 完全自動化（如果 Chrome 已登入 Google）
- ✅ 無需手動導出/import 操作
- ✅ 會話持久化

**限制：**
- ⚠️ 需要 Chrome 配置檔中有保存的 Google 登入
- ⚠️ 首次仍需一次手動登入（建立配置檔）

---

### 方案 D: 🔄 Profiles 模式（多環境/多帳號管理）

```bash
# ========== 為不同環境創建獨立 Profiles ==========
nlm login --profile production
nlm login --profile staging
nlm login --profile dev

# ========== 使用特定 Profile ==========
nlm notebook list --profile production
nlm audio create <id> --profile staging --confirm

# ========== 列出並管理 Profiles ==========
nlm auth list profiles
nlm auth delete stale-profile --confirm
```

**應用場景：**
- **多 Google 帳號**: 工作帳號 vs 個人帳號
- **多環境**: 生產 vs 測試 vs 開發
- **多團隊**: 團隊 A vs 團隊 B

**結合環境變量：**
```bash
# 在 .env 或 CI 腳本中
export NLM_PROFILE_NAME=production
export NLM_PROFILE_PATH="./nlm-prod-data"

# 運行時自動應用
nlm notebook list --profile $NLM_PROFILE_NAME
```

---

## 3. 自動化方案評估

### 3.1 方案對比矩陣

| 方案 | 自動化程度 | 安全性 | 持久性 | CI/CD 友好度 | 首選場景 |
|------|-----------|-------|-------|--------------|---------|
| **方案 A: 手動 Cookies 導入** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | CI/CD 容器化 |
| **方案 B: 環境變量覆蓋** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 長期運行服務 |
| **方案 C: Layer 3 無頭認證** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | 本地開發 |
| **方案 D: Profiles 模式** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 多帳號/多環境 |

### 3.2 決策樹

```
           你在什麼環境?
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
    CI/CD 容器化?       長期運行服務?
        │                   │
    ┌───┴───┐           ┌───┴───┐
    ▼       ▼           ▼       ▼
   Yes      No         Yes      No
    │       │           │       │
    ▼       ▼           ▼       ▼
 方案 A   需要多帳號?   方案 B   方案 C
          │
     ┌────┴────┐
     ▼         ▼
    Yes       No
     │         │
     ▼         ▼
  方案 D    方案 C
```

---

## 4. OpenCode ACP 瀏覽器工具集成評估

### 4.1 dev-browser Skill 評估

**位置：** `~/.openclaw/workspace/skills/dev-browser/`

**核心能力：**
- ✅ Playwright/Chromium 瀏覽器自動化
- ✅ 保持頁面狀態跨腳本執行
- ✅ 支持無頭模式 (`--headless`)
- ✅ Cookie 與 LocalStorage 管理
- ✅ 截圖與 PDF 生成

**登入流程範例：**
```bash
cd skills/dev-browser && npx tsx <<'EOF'
import { connect, waitForPageLoad } from "@/client.js";

const client = await connect();
const page = await client.page("notebooklm-login", {
  viewport: { width: 1920, height: 1080 }
});

await page.goto("https://notebooklm.google.com");
await waitForPageLoad(page);

// 使用 ARIA Snapshot 發現元素
const snapshot = await client.getAISnapshot("notebooklm-login");
console.log(snapshot); // 找到登入表單的 ref (@e1, @e2, ...)

// 交互與填寫
await page.fill('input[type="email"]', 'user@gmail.com');
await page.click('button:has-text("Next")');
await waitForPageLoad(page);

await client.disconnect();
EOF
```

**Cookie 提取範例：**
```bash
cd skills/dev-browser && npx tsx <<'EOF'
import { connect } from "@/client.js";

const client = await connect();
const page = await client.page("notebooklm-auth");

await page.goto("https://notebooklm.google.com");
// ... 完成登入 ...

// 提取所有 cookies
const cookies = await page.context().cookies();
const localStorage = await page.evaluate(() => {
  return JSON.stringify(localStorage);
});

// 保存至文件
const fs = require('fs');
fs.writeFileSync('cookies.json', JSON.stringify(cookies, null, 2));
fs.writeFileSync('localStorage.json', localStorage);

console.log("Cookies and LocalStorage saved!");

await client.disconnect();
EOF
```

---

### 4.2 Vercel agent-browser 評估

**特性：**
- ✅ Rust 實現的高性能瀏覽器自動化 CLI
- ✅ 語義交互（使用 `@e1`, `@e2` 引用而非 CSS 選擇器）
- ✅ 狀態保存/加載 (`state save`, `state load`)
- ✅ 支持會話隔離 (`--session`, `--profile`)
- ✅ `--headed` 模式用於手動登入

**認證模式：**
```bash
# ========== 1. 首次手動登入並保存狀態 ==========
agent-browser open https://notebooklm.google.com --headed
# ... 用戶完成 Google/MFA 登入 ...
agent-browser state save ./auth-state.json

# ========== 2. 後續自動化流程無人使用 ==========
agent-browser state load ./auth-state.json
agent-browser open https://notebooklm.google.com
# ... 已認證狀態，繼續自動化操作 ...
```

**提取 Cookies：**
```bash
# 直接導出 cookies
agent-browser cookies get > cookies.json
```

---

### 4.3 🔑 nlm CLI vs 瀏覽器工具對比

**結論：nlm CLI 已內建瀏覽器控制，直接使用 dev-browser/agent-browser 並非必要**

| 特性 | nlm CLI 內建 | dev-browser | agent-browser | 評估 |
|------|-------------|-------------|--------------|------|
| **Cookie 提取** | ✅ CDP 自動 | ✅ Playwright API | ✅ 內建命令 | nlm 最簡單 |
| **會話持久化** | ✅ 3層恢復 | ✅ 手動管理 | ✅ state save/load | nlm 最智能 |
| **無頭登入** | ✅ Layer 3 | ✅ `--headless` | ✅ 默認 headless | 相當 |
| **Profiles 管理** | ✅ `--profile` | ⚠️ 手動隔離 | ✅ `--profile` | nlm 更原生 |
| **環境變量支持** | ✅ `NLM_PROFILE_PATH` | ⚠️ 需自定義 | ⚠️ 需自定義 | nlm 更好 |
| **複雜度** | ⭐ 最簡 | ⭐⭐⭐ 需腳本 | ⭐⭐ 需命令 | nlm 最簡潔 |

**何時仍需 dev-browser/agent-browser：**
1. 需要 NotebookLM 之外的 Google 服務認證（如 Gmail、Drive）
2. 需要複雜的多步驟表單填寫流程
3. 需要可視化截圖/錄製調試
4. 需要與非 Google 服務的登入流程整合

**對於純 NotebookLM 自動化：**
- **直接使用 nlm CLI** - 更可靠、更簡單、更易維護
- nlm 已使用 Chrome DevTools Protocol，與 Playwright/agent-browser 底層一致
- 3層恢復策略提供了瀏覽器工具需要額外編碼才能實現的功能

---

## 5. 推薦實施方案

### 🏆 5.1 最適合 CI/CD: 方案 A（手動導入 Cookies）

**步驟詳解：**

#### Step 1: 初始化設置（一次性，本地）

```bash
# 在本地開發機器上
nlm login
# → 完成 Google 登入（包括 MFA）
# → Cookies 自動保存至 ~/.nlm/cookies.json

# 複製 Cookies 內容
cat ~/.nlm/cookies.json
```

#### Step 2: 存儲至 CI/CD Secrets

**GitHub Actions:**
1. Settings → Secrets and variables → Actions → New repository secret
2. Name: `NOTEBOOKLM_COOKIES`
3. Value: 粘貼 `~/.nlm/cookies.json` 的內容

**GitLab CI:**
1. Settings → CI/CD → Variables → Add variable
2. Key: `NOTEBOOKLM_COOKIES`
3. Value: 粘貼 cookies，選 `Mask variable`（如果短於 1000 字符）

**Kubernetes:**
```bash
# 創建 Secret
kubectl create secret generic notebooklm-cookies \
  --from-literal=cookies.json="$(cat ~/.nlm/cookies.json)"

# 驗證
kubectl get secret notebooklm-cookies -o jsonpath='{.data.cookies\.json}' | base64 -d
```

#### Step 3: CI/CD 管道集成

**GitHub Actions 示例：**
```yaml
name: NotebookLM Content Generation

on:
  schedule:
    - cron: '0 0 * * 1'  # 每週一午夜
  workflow_dispatch:

jobs:
  generate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install notebooklm-py
        run: pip install notebooklm-py

      - name: Login to NotebookLM
        env:
          NOTEBOOKLM_COOKIES: ${{ secrets.NOTEBOOKLM_COOKIES }}
        run: |
          echo "${NOTEBOOKLM_COOKIES}" > cookies.json
          nlm login --manual --file cookies.json

      - name: Generate Audio Podcast
        env:
          NOTEBOOK_ID: ${{ secrets.NOTEBOOK_ID }}
        run: |
          nlm audio create $NOTEBOOK_ID --confirm
          nlm studio status $NOTEBOOK_ID --json

      - name: Check Auth Status
        if: failure()
        run: nlm login --check || echo "Authentication may have expired, please update secrets"
```

**定期維護策略：**

| 維護頻率 | 檢測方式 | 更新方式 | 自動化 |
|---------|---------|---------|-------|
| **每週** | CI 日志檢查 `Authentication required` | 手動更新 `NOTEBOOKLM_COOKIES` secret | ❌ |
| **每 2 週** | 定時腳本執行 `nlm login --check` | GitHub Actions 更新 secret | 🔶 可自動 |
| **每月** | 失敗郵件告警 | 提醒用戶更新 | 🔶 可自動 |

**自動化 Secret 更新（進階）：**
```yaml
# .github/workflows/update-secrets.yml
name: Update Cookies Secret

on:
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * 0'  # 每週日

permissions:
  contents: write  # 允許更新 secrets

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5

      - name: Fresh Login
        run: |
          # 注意：此示例需要手動介入，無人值守需改用其他方案
          echo "This workflow requires manual intervention"
          exit 1
```

> **⚠️ 重要提醒：** 完全無人值守的 Cookie 更新需要瀏覽器自動化（如 Playwright 或 agent-browser）完成 Google 登入流程。這會遭遇反爬蟲檢測。**推薦做法：**
> - 每 2-4 週定時檢測
> - 收到期告警時，手動更新 Secret（約 5 分鐘操作）
> - 或考慮使用方案 B（持久化捲）避免頻繁更新

---

### 🔥 5.2 最適合長期服務: 方案 B（環境變量覆蓋）

**配置步驟：**

#### Step 1: 設置環境變量

**本地開發（~/.bashrc 或 ~/.zshrc）：**
```bash
# 將以下行加入 shell 配置
export NLM_PROFILE_PATH="$HOME/.nlm-data"
```

**應用配置：**
```bash
source ~/.bashrc  # 或重新開啟終端機
```

#### Step 2: 首次設置（手動登入一次）

```bash
# 確保目錄存在
mkdir -p $NLM_PROFILE_PATH

# 執行登入（Cookies 會保存至 NLM_PROFILE_PATH）
nlm login
# → 完成 Google 登入
# → Cookies 保存至 $NLM_PROFILE_PATH/cookies.json
```

#### Step 3: 日常使用（完全自動）

```bash
# Layer 1/2 應自動恢復，無需再登入
nlm notebook list
nlm notebook create "Research Project"
nlm audio create $ID --confirm
```

**驗證自動恢復：**
```bash
# 檢查會話狀態
nlm login --check
# Expected output: "Session is valid" (or similar)

# 如果返回錯誤，執行重新登入
nlm login  # Layer 3 可能自動無頭登入（如果 Chrome 配置檔有保存）
```

#### Step 4: 服務集成（systemd 示例）

```ini
# /etc/systemd/system/notebooklm-worker.service
[Unit]
Description=NotebookLM Worker Service
After=network.target

[Service]
Type=simple
User=nlm-worker
WorkingDirectory=/opt/notebooklm-worker
Environment=NLM_PROFILE_PATH=/var/lib/notebooklm
ExecStart=/usr/bin/python3 worker.py
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**啟用服務：**
```bash
# 創建目錄
sudo mkdir -p /var/lib/notebooklm
sudo chown nlm-worker.nlm-worker /var/lib/notebooklm

# 首次設置（手動登入）
sudo -u nlm-worker nlm login

# 啟用並啟動服務
sudo systemctl daemon-reload
sudo systemctl enable notebooklm-worker
sudo systemctl start notebooklm-worker
```

---

### 🔄 5.3 多環境部署: 方案 D（Profiles）+ 方案 B

**結合使用策略：**

#### 配置環境腳本

```bash
#!/bin/bash
# switch-nlm-env.sh - 切換 nlm 環境

ENV_NAME=${1:-"prod"}

case $ENV_NAME in
  prod|production)
    export NLM_PROFILE_PATH="$HOME/.nlm-prod"
    export NLM_PROFILE_NAME="production"
    echo "Switched to PRODUCTION environment"
    ;;
  staging|stage|stg)
    export NLM_PROFILE_PATH="$HOME/.nlm-staging"
    export NLM_PROFILE_NAME="staging"
    echo "Switched to STAGING environment"
    ;;
  dev|development)
    export NLM_PROFILE_PATH="$HOME/.nlm-dev"
    export NLM_PROFILE_NAME="dev"
    echo "Switched to DEVELOPMENT environment"
    ;;
  *)
    echo "Usage: switch-nlm-env.sh [prod|staging|dev]"
    exit 1
    ;;
esac

# 執行後續命令示例
# nlm notebook list --profile $NLM_PROFILE_NAME
```

#### 初始化所有環境

```bash
# 生產環境
switch-nlm-env.sh prod
mkdir -p $NLM_PROFILE_PATH
nlm login --profile production

# 預發環境
switch-nlm-env.sh staging
mkdir -p $NLM_PROFILE_PATH
nlm login --profile staging

# 開發環境
switch-nlm-env.sh dev
mkdir -p $NLM_PROFILE_PATH
nlm login --profile dev
```

#### 日常使用

```bash
# 切換並執行命令
switch-nlm-env.sh prod && nlm notebook list
switch-nlm-env.sh staging && nlm audio create $STAGING_ID --confirm
switch-nlm-env.sh dev && nlm notebook create "Test"
```

#### 交叉環境安全檢查

```bash
#!/bin/bash
# verify-env-isolation.sh - 驗證環境隔離

PROD_COOKIES="$HOME/.nlm-prod/cookies.json"
STG_COOKIES="$HOME/.nlm-staging/cookies.json"
DEV_COOKIES="$HOME/.nlm-dev/cookies.json"

for env_cookies in "$PROD_COOKIES" "$STG_COOKIES" "$DEV_COOKIES"; do
  if [ -f "$env_cookies" ]; then
    email=$(grep -o '"value":"[^"]*@[^"]*"' "$env_cookies" | head -1 | cut -d'"' -f4 | tr '[:upper:]' '[:lower:]')
    echo "Environment: $env_cookies"
    echo "  Email found: $email"
    echo "  Cookie count: $(jq '.cookies | length' "$env_cookies")"
    echo "---"
  fi
done

# 檢查 cookies 是否相同
if diff "$PROD_COOKIES" "$STG_COOKIES" > /dev/null 2>&1; then
  echo "⚠️  WARNING: Production and Staging cookies are identical!"
  echo "    Are you using the same Google account? This may cause data conflict."
fi
```

---

## 6. 安全與最佳實踐

### 6.1 安全考量

| 風險項 | 影響 | 緩解措施 |
|--------|------|---------|
| **Cookies 泄露** | 帳號被劫持 | ✅ 使用 CI/CD Secrets，避免明文存儲 |
| **權限過大** | 未授權存取 NotebookLM | ✅ 創建專用 Google 帳號，限制權限 |
| **會話劫持** | Cross-site scripting | ✅ 確保 CI/CD 環境網絡隔離 |
| **日志洩露** | Tokens 出現於日志 | ✅ 添加 `.nlm/` 至 `.gitignore`，配置日誌過濾 |

**檢測腳本 - 尋找潛在洩露：**
```bash
#!/bin/bash
# scan-git-history-for-secrets.sh - 檢測 Git 歷史中的敏感資訊

echo "Scanning for potential secrets in Git history..."

# 檢查 .nlm/ 是否被提交
if git log --all --full-history --oneline -- "**/.nlm/**" | grep -q .; then
  echo "⚠️  WARNING: .nlm/ directory found in Git history!"
  echo "   Files:"
  git log --all --full-history --name-only -- "**/.nlm/**" | grep "^.*\.nlm" | sort -u
fi

# 檢查 cookies.json 是否被提交
if git log --all --full-history --oneline -- "**/cookies.json" | grep -q .; then
  echo "⚠️  WARNING: cookies.json found in Git history!"
fi

# 檢查原始 Google cookies（SID, HSID, SAPISID）
if git log -p --all -- "**/*" | grep -q '"name": "SID"'; then
  echo "⚠️  WARNING: Google cookies (SID) found in Git history!"
fi

echo "Scan complete."
```

---

### 6.2 最小權限原則

**推薦帳號設置：**

| 角色 | 帳號類型 | NotebookLM 權限 | 使用場景 |
|------|---------|----------------|---------|
| **Production** | 專用 Google 帳號 | 僅生產 notebook 存取 | CI/CD 管道 |
| **Staging** | 專用 Google 帳號 | 測試環境 notebook | QA/測試 |
| **Development** | 個人 Google 帳號 | 開發專案 | 本地開發 |

**設定步驟：**
1. 創建專用 Google 帳號（例如：`nlm-prod@your-domain.com`）
2. 共享 NotebookLM notebook 給該帳號
3. 該帳號僅用於 nlm CLI 自動化
4. 啟用 2FA（雖然會使首次登入複雜，但提高安全性）

---

### 6.3 故障處理與監控

#### 常見問題解決

| 問題 | 症狀 | 解決方案 |
|------|------|---------|
| **Chrome 未找到** | `nlm login` 報錯 "Chrome not found" | 安裝 Chromium/Chrome 或設置 `CHROME_BIN` 環境變量 |
| **網絡超時** | Commands timeout connecting to NotebookLM | 檢查代理設置，配置 `HTTP_PROXY/HTTPS_PROXY` |
| **Cookie 過期頻繁** | 每次執行都需重新登入 | 使用 Profile 隔離，避免多進程衝突 |
| **反爬蟲檢測** | "This browser or app may not be secure" | 使用 `--headless` 選項，避免 headless 模式啟動登入 |

#### 監控腳本 - 會話健康檢查

```bash
#!/bin/bash
# check-nlm-health.sh - 檢查 nlm 會話健康狀態

# 設定變量
NOTEBOOK_ID="${1:-}"
MAX_RETRIES=3

echo "Checking NotebookLM session health..."

# 1. 檢查認證狀態
if nlm login --check > /dev/null 2>&1; then
  echo "✅ Authentication: Valid"
else
  echo "❌ Authentication: Invalid or expired"
  echo "   Action required: Run 'nlm login' to re-authenticate"
  exit 1
fi

# 2. 檢查連通性
if nlm notebook list > /dev/null 2>&1; then
  echo "✅ Connectivity: OK (can list notebooks)"
else
  echo "❌ Connectivity: Failed (cannot list notebooks)"
  echo "   Check network and proxy settings"
  exit 1
fi

# 3. 如果提供了 notebook ID，測試基本操作
if [ -n "$NOTEBOOK_ID" ]; then
  echo "Testing notebook operations on: $NOTEBOOK_ID"

  if nlm notebook get "$NOTEBOOK_ID" > /dev/null 2>&1; then
    echo "✅ Notebook: Accessible"
  else
    echo "❌ Notebook: Not accessible or doesn't exist"
    exit 1
  fi
fi

echo ""
echo "Health check passed! NotebookLM CLI is ready for automation."
exit 0
```

#### 集成至健康檢查（Kubernetes LivenessProbe）

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notebooklm-worker
spec:
  template:
    spec:
      containers:
      - name: worker
        image: python:3.11
        env:
        - name: NLM_PROFILE_PATH
          value: "/nlm-data"
        volumeMounts:
        - name: nlm-storage
          mountPath: /nlm-data
        livenessProbe:
          exec:
            command:
              - /bin/sh
              - -c
              - |
                python3 -c "
                import subprocess
                result = subprocess.run(['nlm', 'login', '--check'], capture_output=True)
                exit(result.returncode)
                "
          initialDelaySeconds: 30
          periodSeconds: 300
          timeoutSeconds: 10
          failureThreshold: 3
        readinessProbe:
          exec:
            command:
              - /bin/sh
              - -c
              - "nlm notebook list > /dev/null 2>&1"
          initialDelaySeconds: 10
          periodSeconds: 60
      volumes:
      - name: nlm-storage
        persistentVolumeClaim:
          claimName: nlm-pvc
```

---

## 7. 結論與行動建議

### 7.1 核心發現

1. **nlm CLI 已內建完整的自動化登入能力**
   - 3層認證恢復策略最大程度減少手動介入
   - 支持手動導入 Cookies、環境變量覆蓋、Profiles 管理等多種模式

2. **無人值守自動登入完全可行**
   - **CI/CD**: 推薦使用 `nlm login --manual --file` + Secrets 管理（方案 A）
   - **長期服務**: 推薦使用 `NLM_PROFILE_PATH` + 持久化捲（方案 B）
   - **本地開發**: 推薦 Layer 3 無頭認證（方案 C）

3. **OpenCode ACP 瀏覽器工具並非必要**
   - nlm CLI 已實現 Chrome DevTools Protocol
   - 直接使用更簡單、更可靠、更易維護
   - 僅在需要 NotebookLM 之外的 Google 服務時才考慮集成

### 7.2 推薦實施路線圖

| 階段 | 方案 | 優先級 | 預計時間 | 目標 |
|------|------|--------|---------|------|
| **P0** | 方案 A（手動導入） | 🔥 最高 | 2 小時 | CI/CD 集成，實現首次自動化 |
| **P1** | 方案 B（環境變量） | 🔴 高 | 1 小時 | 本地開發環境統一配置 |
| **P2** | 方案 D（Profiles） | 🟡 中 | 1 小時 | 多環境部署（dev/staging/prod） |
| **P3** | Layer 3 無頭認證優化 | 🟢 低 | 2 小時 | 本地登入體驗進一步自動化 |
| **P4** | 監控與告警系統 | 🟢 低 | 4 小時 | 會話健康檢查、過期提醒 |

### 7.3 風險提醒

| 風險類別 | 風險描述 | 緩解措施 |
|---------|---------|---------|
| **會話失效** | Google Cookies 有過期時間（2-4 週） | 定期健康檢查，配置告警提醒 |
| **多進程衝突** | 並發訪問同一 cookies.json 可能導致衝突 | 使用 Profiles 隔離每個環境 |
| **網絡策略** | 防火牆/代理可能阻擋 CDP 協議 | 檢查網絡配置，允許 Chrome 出站連接 |
| **安全合規** | 敏感 cookies 需合規存儲 | 使用 Secrets 管理，設定適當權限（600/700） |

### 7.4 下一步行動

**立即行動（今天 完成）：**

```bash
# 1. 測試 nlm CLI 基本功能
which nlm
nlm --version
nlm login --check

# 2. 執行首次登入（如果尚未）
nlm login

# 3. 驗證自動恢復
nlm notebook list

# 4. 設定安全權限
chmod 600 ~/.nlm/cookies.json
chmod 700 ~/.nlm/
```

**短期規劃（本週）：**

1. 配置 CI/CD Secrets（選定一個專案或 repo）
2. 實現方案 A（手動 Cookies 導入）
3. 測試完整自動化流程

**中期規劃（本月）：**

1. 實現方案 B（環境變量覆蓋）
2. 配置多環境 Profiles（dev/staging/prod）
3. 實現健康檢查腳本與告警

---

## 附錄

### A. 參考文檔

| 資源 | 位置 | 用途 |
|------|------|------|
| **notebooklm-py GitHub** | https://github.com/teng-lin/notebooklm-py | 原版 CLI 文檔 |
| **notebooklm-mcp-cli (合併版)** | https://github.com/jacob-bd/notebooklm-mcp-cli | 最新統一版本，含 3層恢復 |
| **SKILL.md** | `~/.openclaw/workspace/skills/notebooklm-cli/SKILL.md` | OpenCode 快速參考 |
| **Workflows** | `~/.openclaw/workspace/skills/notebooklm-cli/references/workflows.md` | End-to-end 範例 |
| **Troubleshooting** | `~/.openclaw/workspace/skills/notebooklm-cli/references/troubleshooting.md` | 故障排除 |

### B. dev-browser 快速參考

**啟動服務器：**
```bash
cd ~/.openclaw/workspace/skills/dev-browser
./server.sh &  # Standalone mode
# 或
npm run start-extension &  # Extension mode
```

**基本腳本：**
```bash
cd ~/.openclaw/workspace/skills/dev-browser
npx tsx <<'EOF'
import { connect, waitForPageLoad } from "@/client.js";

const client = await connect();
const page = await client.page("test");
await page.goto("https://example.com");
await waitForPageLoad(page);
console.log("Page loaded:", await page.title());
await client.disconnect();
EOF
```

### C. agent-browser 快速參考

**安裝：**
```bash
npm install -g @vercel/agent-browser
```

**基本流程：**
```bash
# 1. 啟動 handless 模式手動登入
agent-browser open https://notebooklm.google.com --headed

# 2. 完成登入後保存狀態
agent-browser state save ./auth-state.json

# 3. 後續使用（headless）
agent-browser state load ./auth-state.json
agent-browser open https://notebooklm.google.com/dashboard

# 4. 提取 cookies（如需要）
agent-browser cookies get > cookies.json
```

### D. 環境變量完整列表

| 變數名稱 | 默認值 | 用途 | 優先級 |
|---------|--------|------|-------|
| **`NLM_PROFILE_PATH`** | `~/.nlm/` (或 OS-specific data dir) | 憑證/cookies 存儲路徑 | 🔴 高 |
| **`NLM_PROFILE_NAME`** | `default` | Profile 名稱（多帳號） | 🟡 中 |
| **`NLM_CONFIG_PATH`** | `~/.nlm/config.json` | 配置文件路徑低 | 🟢 |
| **`CHROME_BIN`** | 適自動偵測 | Chrome 可執行文件路徑 | 🔴 高（如非標準路徑） |
| **`HTTP_PROXY`** | 無 | HTTP 代理 | 🟡 中（如需要） |
| **`HTTPS_PROXY`** | 無 | HTTPS 代理 | 🟡 中（如需要） |

**使用示例：**
```bash
# Docker 容器中
export NLM_PROFILE_PATH="/nlm-data"
export NLM_PROFILE_NAME="worker-1"

# 代理環境
export HTTP_PROXY="http://proxy.company.com:8080"
export HTTPS_PROXY="http://proxy.company.com:8080"

# 自訂 Chrome 路徑
export CHROME_BIN="/usr/bin/chromium"
```

---

**報告生成時間:** 2026-02-04
**研究者:** Sisyphus (OhMyOpenCode AI Agent)
**任務類型:** 探索任務 - NotebookLM CLI 最佳實踐研究
**環境:** Linux ARM64 + Chromium
**NLM 版本:** notebooklm-py 0.3.2
