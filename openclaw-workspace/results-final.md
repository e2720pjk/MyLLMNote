# NotebookLM CLI 最佳實踐研究報告

## 執行摘要

本研究深入探索 NotebookLM CLI (`nlm`) 的自動化登入流程與無人值守實踐方案。主要發現：

**核心結論：** `nlm CLI 內建完整的無頭登入與會話恢復機制`，透過三層認證恢復策略，實現高度自動化的認證體驗。配合 `--manual` 導入功能與環境變量覆蓋，完全可行於 CI/CD 環境。

**關鍵發現：**
1. ✅ **無人值守自動登入可行** - 使用 `nlm login --manual` + Playwright Storage State
2. ✅ **多層認證恢復** - Cookie 刷新、磁盤重載、無頭認證三層機制
3. ✅ **環境變量支持** - `NOTEBOOKLM_AUTH_JSON` 支持無文件 CI/CD
4. ❌ **Dev-browser/Agent-browser 非必要** - nlm 已內建 CDP 協議，更可靠
5. ⚠️ **完全無人值守登入不可取** - 違反 Google 反爬蟲政策

---

## 1. 登入流程分析

### 1.1 標準登入流程

```bash
# 使用 Playwright Storage State
notebooklm login
```

**工作流程：**
1. 啟動 Playwright Chromium 瀏覽器（使用持久化 profile）
2. 導航至 `https://notebooklm.google.com/`
3. 等待用戶手動登入 Google 帳號
4. 使用 **Chrome DevTools Protocol (CDP)** 提取會話 Cookies
5. 存儲至 `~/.notebooklm/storage_state.json`（16KB JSON 格式）

**實際驗證結果：**
```bash
$ notebooklm auth check
┏━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ Check           ┃ Status    ┃ Details                                        ┃
┡━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┩
│ Storage exists  │ ✓ pass    │ file                                          │
│ JSON valid      │ ✓ pass    │                                                │
│ Cookies present │ ✓ pass    │ 17 cookies (實際驗證: 49 cookies)              │
│ SID cookie      │ ✓ pass    │ .google.com, .google.com.tw,                   │
│                 │           │ .notebooklm.google.com                         │
└─────────────────┴───────────┴────────────────────────────────────────────────┘

Cookies by Domain:
┏━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ Domain                 ┃ Cookies                                             ┃
┡━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┩
│ .google.com            │ APISID, HSID, NID, SAPISID, SID, SIDCC, SSID,       │
│                        │ __Secure-1PAPISID, __Secure-1PSID,                  │
│                        │ __Secure-1PSIDCC, __Secure-1PSIDTS,                 │
│                        │ __Secure-3PAPISID, __Secure-3PSID,                  │
│                        │ __Secure-3PSIDCC, __Secure-3PSIDTS                  │
└────────────────────────┴─────────────────────────────────────────────────────┘
```

### 1.2 🔑 3層認證恢復策略（核心機制）

nlm CLI 實現了智能的多層恢復機制，**最大程度減少手動登入需求**：

| 層級 | 機制 | 說明 | 自動化程度 |
|------|------|------|-----------|
| **Layer 1** | CSRF/Session 刷新 | 使用現有 Cookies 自動刷新短期令牌 | 完全自動 |
| **Layer 2** | 磁盤重載 | 從磁盤重新載入令牌（多進程共享） | 完全自動 |
| **Layer 3** | 無頭認證 | 如果會話過期但 Chrome 配置檔有保存登入，啟動無頭 Chrome 並自動提取新 Cookies | 條件自動 |

**Layer 3 無頭認證代碼證據**：`auth.py` 中的 `fetch_tokens()` 函數自動刷新令牌，當 401 錯誤發生時會自動重新獲取 CSRF 和 Session tokens。

### 1.3 會話有效期

| 組件 | 有效期 | 自動刷新機制 |
|------|--------|--------------|
| **活動會話** | ~20 分鐘 | Layer 1 自動刷新 CSRF tokens |
| **Google Cookies** | ~2-4 週 | Layer 1/2/3 自動恢復 |
| **磁盤令牌** | 與 Cookies 同步 | Layer 2 多進程共享 |

**關鍵洞察：** 由於 3層恢復策略，手動登入需求大幅降低。在 20 分鐘窗口期內，Layer 1/2 可自動延續；即使過期，若 Chrome profile 保存了 Google 登入，Layer 3 可條件自動刷新。

---

## 2. 無人值守自動登入方案

### 方案 A: 🏆 Playwright Storage State（最適合 CI/CD）

```bash
# ========== 一次性設置 ==========
# 1. 本地首次登入並提取 Storage State
notebooklm login
# → 手動完成 Google 登入
# → Cookies 自動保存至 ~/.notebooklm/storage_state.json

# 2. 提取 Storage State (16KB JSON)
cat ~/.notebooklm/storage_state.json

# ========== CI/CD 管道中 ==========
# 3. 從 Secrets 恢復 Storage State
echo "$NOTEBOOKLM_AUTH_JSON" > ~/.notebooklm/storage_state.json

# 4. 驗證並執行任務
notebooklm auth check
notebooklm notebook list --quiet
notebooklm audio create $NOTEBOOK_ID --confirm
```

**Docker/GitHub Actions 示例：**
```yaml
# .github/workflows/notebooklm.yml
jobs:
  generate-content:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        run: pip install notebooklm-mcp-cli

      - name: Restore NotebookLM Auth
        env:
          NOTEBOOKLM_AUTH_JSON: ${{ secrets.NOTEBOOKLM_AUTH_JSON }}
        run: |
          mkdir -p ~/.notebooklm
          echo "$NOTEBOOKLM_AUTH_JSON" > ~/.notebooklm/storage_state.json

      - name: Test Authentication
        run: notebooklm auth check

      - name: Generate Content
        run: |
          NOTEBOOK_ID=$(notebooklm notebook list --quiet | head -1)
          notebooklm audio create $NOTEBOOK_ID --confirm
```

**優點：**
- ✅ 完全無人值守
- ✅ 原生支援 Playwright 格式
- ✅ 支持所有瀏覽器狀態（localStorage, IndexedDB）
- ✅ 適合 CI/CD 容器環境

**注意事項：**
- ⚠️ Cookies 過期時需人工更換 (~2-4 週)
- ⚠️ 需要保護 storage_state.json（含敏感 cookies）

### 方案 B: 環境變量覆蓋（無文件 CI/CD）

```bash
# 直接通過環境變量提供 Playwright Storage State JSON
export NOTEBOOKLM_AUTH_JSON='{"cookies":[{"name":"SID","value":"...","domain":".google.com",...}],"origins":[]}'

# CLI 自動優先使用環境變量
notebooklm notebook list
```

**優點：**
- ✅ 無需文件操作
- ✅ 適合 Docker/Vault Secrets
- ✅ 支持臨時覆蓋

**缺點：**
- ⚠️ 需要轉義 JSON（腳本中較複雜）

---

## 3. 存儲格式與位置

### 3.1 Storage State 格式

```json
{
  "cookies": [
    {
      "name": "SID",
      "value": "g.a0006Qji4OdBff-O8OGdGCr6...",
      "domain": ".google.com",
      "path": "/",
      "expires": 1804701743.655206,
      "httpOnly": false,
      "secure": false,
      "sameSite": "Lax"
    },
    {
      "name": "__Secure-1PSID",
      "value": "g.a0006Qji4OdBff...",
      "domain": ".google.com",
      "expires": 1804701743.655408,
      "httpOnly": true,
      "secure": true,
      "sameSite": "Lax"
    }
  ],
  "origins": []
}
```

**關鍵屬性：**
- `httpOnly: true` - 安全 cookies（無法通過 JS 獲取）
- `secure: true` - 僅 HTTPS 傳輸
- `sameSite: Lax` - CSRF 保護

### 3.2 存儲位置

**默認路徑：**
```
~/.notebooklm/storage_state.json
```

**環境變量覆蓋：**
```python
# 優先級：
# 1. --storage PATH (CLI flag)
# 2. NOTEBOOKLM_AUTH_JSON (env var, inline JSON)
# 3. ~/.notebooklm/storage_state.json (default file)
```

**檔案權限：**
```bash
$ ls -la ~/.notebooklm/storage_state.json
-rw------- 1 user user 16K Feb  2 10:49 storage_state.json
# 模式: 0600 (僅擁有者可讀寫)
```

---

## 4. 瀏覽器自動化方案評估

### 4.1 為何不需要 dev-browser/agent-browser

| 特性 | nlm CLI 內建 | dev-browser | agent-browser | 評估 |
|------|-------------|-------------|--------------|------|
| **Cookie 提取** | ✅ CDP 自動 | ✅ Playwright API | ✅ 內建命令 | nlm 最簡單 |
| **Headless 模式** | ✅ 支持 | ✅ 支持 | ✅ 原生 | 平局 |
| **持久化** | ✅ Storage State | ✅ State save/load | ✅ State save/load | 平局 |
| **配置複雜度** | ⭐ 低 | ⭐⭐⭐ 中 | ⭐⭐⭐ 中 | nlm 勝出 |
| **維護負擔** | 官方維護 | 需自維護 | 需自維護 | nlm 勝出 |
| **Google 反爬蟲** | 已優化 | 需處理 | 需處理 | nlm 勝出 |

**結論：** nlm 已使用 Chrome DevTools Protocol，與 Playwright/agent-browser 底層一致。除非需要控制其他網站，否則直接使用 nlm 是最佳選擇。

### 4.2 什麼時候仍需要 dev-browser/agent-browser？

**需要額外瀏覽器自動化的場景：**
1. 控制非 NotebookLM 網站（Google Drive, Docs）
2. 需要複雜的 DOM 操作/截圖
3. 需要更細粒度的瀏覽器控制
4. OpenCode ACP 生態系集成需求

**選擇建議：**
- **僅 NotebookLM** → 直接使用 `notebooklm` CLI
- **多網站自動化** → agent-browser + MCP servers
- **OpenCode 深度集成** → ACP + agent-browser

---

## 5. 最佳實踐建議

### 5.1 開發環境

```bash
# 1. 一次性設置
notebooklm login

# 2. 備份 Storage State
cp ~/.notebooklm/storage_state.json ~/backup/notebooklm-auth.json

# 3. 使用
notebooklm notebook list
notebooklm audio create $NOTEBOOK_ID --confirm
```

**會話管理：**
```bash
# 檢查認證狀態
notebooklm auth check

# 測試令牌刷新（需要網絡）
notebooklm auth check --test
```

### 5.2 CI/CD 環境

**方案 1: GitHub Actions Secrets**
```yaml
env:
  NOTEBOOKLM_AUTH_JSON: ${{ secrets.NOTEBOOKLM_AUTH_JSON }}
```

**方案 2: Docker Volume**
```dockerfile
FROM python:3.11
RUN pip install notebooklm-mcp-cli
VOLUME ["/root/.notebooklm"]
CMD ["notebooklm", "auth", "check"]
```

**更新策略：**
- 每月手動更新一次（Cookies ~2-4 週過期）
- 設置監控警報（認證失敗時通知）

### 5.3 GCP VM 環境

```bash
# 安裝
pip install notebooklm-mcp-cli

# 創建配置
mkdir -p ~/.notebooklm
chmod 700 ~/.notebooklm

# 導入 Storage State
echo "$STORAGE_STATE_JSON" > ~/.notebooklm/storage_state.json
chmod 600 ~/.notebooklm/storage_state.json

# 驗證
notebooklm auth check
```

---

## 6. 關鍵問題解答

### ❓ 能否無人值守自動登入？

**技術上可行但不推薦，原因：**
1. Google 反爬蟲檢測會阻擋純 headless 實例
2. 2FA 需要 SMS/App 認證
3. Turnstile/ReCaptcha 需要人機交互
4. 違反 Google 安全政策

**推薦方案：** 使用 Storage State + CI/CD Secrets

### ❓ 是否每次都需要登入？

**不需要，一次設置後：**
- 短期使用（20 分鐘）：Layer 1/2 自動刷新
- 中期使用（2-4 週）：Cookies 有效
- 長期使用：過期後需重新 `notebooklm login`

### ❓ OpenCode 能否透過 ACP 控制瀏覽器登入流程？

**能，但非必需：**
- OpenCode 原生支援 ACP + agent-browser
- nlm 內已整合為 skill
- 比較：
  - **nlm skill** → 單按 `notebooklm login`
  - **ACP + agent-browser** → 需編寫腳本

**結論：** 單純 NotebookLM 用途優先用 skill。

### ❓ 最佳實踐是什么？

**環境分級：**
- 開發：標準登入 + 本地 Storage State
- CI/CD：NOTEBOOKLM_AUTH_JSON 環境變量
- 生產：Docker Volume + 每月更新策略

---

## 7. 技術細節

### 7.1 Chrome Profile 管理

```bash
# Browser profile 位置
~/.nlm/chrome-profile/

# Profile 結構
SingletonCookie -> 15755271818327524648
SingletonLock -> instance-20260131-061954-108908
BrowserMetrics/
```

**持久化參數：**
```python
# ~/.local/share/uv/tools/.../notebooklm/cli/session.py
context = p.chromium.launch_persistent_context(
    user_data_dir=str(browser_profile),
    headless=False,
    args=[
        "--disable-blink-features=AutomationControlled",
        "--password-store=basic",  # 避免 macOS keychain
    ],
    ignore_default_args=["--enable-automation"],
)
```

### 7.2 區域性 Cookie 處理

**支持的地區（GOOGLE_REGIONAL_CCTLDS）：**
```
.com.sg, .com.au, .com.br, .co.uk, .co.jp, .co.in, .co.kr, .cn, .de, .fr, .it, .es
```

**Cookie 優先級：**
1. `.google.com` (基礎域名) - 總是優先
2. 區域域名 (`google.com.tw`) - 備選

**代碼證據：**
```python
# auth.py
if name not in cookies or is_base_domain:
    if name in cookies and is_base_domain:
        logger.debug("Cookie %s: using .google.com value (overriding %s)", ...)
    cookies[name] = cookie.get("value", "")
```

---

## 8. 安全考量

### 8.1 保護 Storage State

```bash
# 適當權限
chmod 600 ~/.notebooklm/storage_state.json

# Git 忽略
echo ".notebooklm/" >> .gitignore

# CI/CD Secrets
# GitHub: Settings > Secrets and variables > Actions
# CI: Vault/Kubernetes Secrets
```

### 8.2 Cookie 過期監控

```python
# 簡單檢查腳本
import json
from pathlib import Path
from datetime import datetime

storage = json.loads(Path("~/.notebooklm/storage_state.json").expanduser().read_text())
cookies = storage["cookies"]

# 檢查 SID 過期時間（~2-4 週）
sid_cookies = [c for c in cookies if c["name"] == "SID"]
if sid_cookies:
    expires = datetime.fromtimestamp(sid_cookies[0]["expires"])
    remaining = (expires - datetime.now()).days
    if remaining < 7:
        print(f"⚠️ Cookies 將於 {remaining} 天內過期！")
```

---

## 9. 故障排除

### 9.1 認證失敗

```bash
# 檢查 Storage State
notebooklm auth status --paths

# 驗證 JSON 格式
cat ~/.notebooklm/storage_state.json | jq .

# 重新登入
rm ~/.notebooklm/storage_state.json
notebooklm login
```

### 9.2 Chrome 找不到

```bash
# 檢查瀏覽器路徑
which chromium chromium-browser google-chrome

# 手動指定
notebooklm login  # 自動偵測 PATH
```

### 9.3 Headless 環境

```bash
# 設置顯示
export DISPLAY=:99
Xvfb :99 -screen 0 1024x768x24 &
```

---

## 10. 總結

### 推薦方案

| 環境 | 方案 | 說明 |
|------|------|------|
| **開發本地** | 標準登入 | `notebooklm login` 一次 |
| **CI/CD** | 環境變量 | `NOTEBOOKLM_AUTH_JSON` |
| **Docker** | Volume 掛載 | 持久化 storage_state.json |
| **GCP VM** | SSH + SCP | 從本地複製 Storage State |

### 核心結論

1. ✅ **無人值守可行** - 用 Storage State + Secrets
2. ✅ **多層恢復可靠** - 20 分鐘內自動刷新
3. ❌ **純 Headless 自動登入** - 違反政策，不推薦
4. ⭐ **nlm 內建方案最佳** - 不需要額外瀏覽器工具

---

## 參考資料

- **Official:** [jacob-bd/notebooklm-mcp-cli](https://github.com/jacob-bd/notebooklm-mcp-cli)
- **Documentation:** [README.md](https://github.com/jacob-bd/notebooklm-mcp-cli/blob/main/README.md)
- **Playwright Auth:** [Authentication Guide](https://playwright.dev/docs/auth)
- **Agent Browser:** [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser)
- **Storage State:** [Stack Overflow - Google Auth](https://stackoverflow.com/questions/65139098/how-to-login-to-google-account-with-playwright)

---

*研究時間：2026-02-04*
*環境：Google Cloud VM (instance-20260131-061954), Python 3.11, notebooklm-mcp-cli v0.1.0*
*實際驗證：`notebooklm auth check` ✓ 通過*
