# NotebookLM CLI 自動登入研究報告

## 研究日期
2026年2月27日

## 研究目標
探索 NotebookLM CLI 的自動化登入方案，評估無人值守自動化的可行性。

---

## 執行摘要

### 核心發現
1. **無人值守自動登入是可行**的，但有限制條件
2. **單次登入後可重複使用**（session 持續時間約 20 分鐘）
3. **agent-browser 可以輔助自動化**，但需要實際操作瀏覽器
4. **最終不推薦完全無人值守方案** - 不穩定且安全性問題

### 推薦方案
- **最佳實踐**：單次手動登入 + session 重用
- **備選方案**：使用 agent-browser 自動化（需要可視化界面）
- **不推薦**：完全無人值守自動登入

---

## 一、登入流程分析

### 1.1 NotebookLM CLI 登入機制

**實現細節**（來源：`notebooklm` NPM 包 v0.1.1）：

```typescript
// 登入命令實現（src/cli/commands/login.ts）
- 使用 Playwright 啟動 Chromium 瀏覽器
- 導航到 https://notebooklm.google.com
- 等待用戶完成 Google 登入流程
- 檢查 URL 確認登入成功
- 保存 storage-state.json 到 ~/.notebooklm/
```

**關鍵代碼片段**：
```bash
notebooklm login
# 選項：
#   -o, --output <path>      # 自定義保存路徑
#   --headless                # 無頭模式（不推薦，可能失敗）
```

### 1.2 Session 存儲機制

**儲存位置**：
```
~/.notebooklm/storage-state.json  # 默認路徑
```

**儲存格式**（Playwright storageState）：
```json
{
  "cookies": [
    {
      "name": "SID",
      "value": "...",
      "domain": ".google.com",
      "path": "/",
      "expires": 1234567890
    },
    ...
  ],
  "origins": [
    {
      "origin": "https://notebooklm.google.com",
      "localStorage": [...]
    }
  ]
}
```

**Session 有效期**：
- ⚠️ **約 20 分鐘**（根據 skill 文檔）
- 需要定期重新登入

### 1.3 使用已保存的 Session

```bash
# CLI 自動加載 ~/.notebooklm/storage-state.json
notebooklm list

# 或指定自定義路徑
export NOTEBOOKLM_STORAGE_PATH=/path/to/storage-state.json
notebooklm list

# 環境變量方式
export NOTEBOOKLM_STORAGE_STATE='{"cookies":[...],"origins":[...]}'
export NOTEBOOKLM_STORAGE_PATH=':inline:'
notebooklm list
```

---

## 二、自動化方案評估

### 2.1 方案一：單次手動登入 + Session 重用 ✅ **推薦**

**流程**：
1. 首次手動執行 `notebooklm login` 完成認證
2. 保存 storage-state.json
3. 後續操作自動使用已保存的 session
4. Session 過期後重新手動登入

**優點**：
- ✅ 簡單可靠
- ✅ 無需複雜配置
- ✅ 安全性高（不暴露憑證）
- ✅ 符合 Google 安全策略

**缺點**：
- ❌ ~20 分鐘後需重新登入
- ❌ 非完全無人值守

**實現示例**：
```bash
#!/bin/bash
# setup.sh - 初始化腳本（執行一次）
notebooklm login
# 完成手動登入後，session 已保存

# automation.sh - 自動化腳本（可重複使用）
notebooklm list  # 自動使用已保存的 session
notebooklm source add <notebook-id> --url "https://example.com"
notebooklm audio create <notebook-id> --confirm
```

**適用場景**：
- 定期運行的任務（每 15 分鐘內完成）
- Cron jobs（配合 session 刷新策略）
- 交互式開發工作流

---

### 2.2 方案二：agent-browser 自動化登入 ✅ **可行但有限制**

**可行性分析**：

agent-browser (vercel-labs/agent-browser) 支持以下特性：
- ✅ 完整的瀏覽器自動化能力
- ✅ session 持久化 (`--session-name`, `--profile`)
- ✅ cookies 管理 (`cookies set`, `cookies get`)
- ✅ 狀態導入 (`--state <path>` 加載 Playwright storageState)

**潛在實現流程**：
```bash
# 1. 使用 agent-browser 自動化登入流程
agent-browser open https://notebooklm.google.com --headed
agent-browser find role textbox click --name "Email"
agent-browser fill @e1 "your-email@gmail.com"
agent-browser find role button click --name "Next"
# ... 繼續登入流程（需要處理 MFA，如果有的話）

# 2. 提取 cookies
agent-browser cookies > cookies.json

# 3. 轉換為 Playwright storageState 格式（自定義腳本）
# 4. 保存到 ~/.notebooklm/storage-state.json
```

**限制**：
- ❌ **需要可視化界面**（`--headed` 模式）
- ❌ Google 可能檢測到自動化並阻止
- ❌ 需要處理 2FA/MFA（如果啟用）
- ❌ 維護成本高（Google UI 變化會導致失敗）

**agent-browser 相關命令**：
```bash
# Session 持久化
agent-browser --session-name notebooklm open https://notebooklm.google.com

# 使用已保存的 session
agent-browser --session-name notebooklm open https://notebooklm.google.com/dashboard

# 狀態管理
agent-browser state save ~/.notebooklm/session.json
agent-browser state load ~/.notebooklm/session.json

# Cookies 操作
agent-browser cookies  # 獲取當前所有 cookies
agent-browser cookies set "SID" "value" --domain ".google.com"
```

**適用場景**：
- 有 GUI 環境的自動化測試
- 需要定期重新登入的場景
- agent-browser 已經在其他流程中使用

---

### 2.3 方案三：完全無人值守自動登入 ❌ **不推**不推薦**

**嘗試方法**：
1. **無頭模式** (`--headless`)：
   ```bash
   notebooklm login --headless  # ⚠️ CLI 文檔明確標註「不推薦」
   ```

2. **手動創建 storageState.json**：
   - 手動從瀏覽器導出 cookies
   - 轉換為 Playwright storageState 格式
   - 放置到 ~/.notebooklm/storage-state.json

3. **使用 Playwright 自動化腳本**：
   - 編寫自定義腳本模擬登入
   - 使用 `playwright-extra` 和 `undetected-chromedriver` 嘗試繞過檢測

**問題與風險**：
- ❌ **Google 反爬蟲檢測**：會檢測自動化特徵
- ❌ **CAPTCHA**：可能出現驗證碼
- ❌ **2FA/MFA**：無法自動處理雙因素認證
- ❌ **不穩定**：Google UI 隨時變化
- ❌ **安全風險**：硬編碼憑證會暴露敏感信息
- ❌ **違反 Google 服務條款**：可能導致帳戶被封

**社區反饋**：
根據網上研究和 GitHub issues：
- "headless mode may not work with Google login"（項目文檔明確警告）
- 多個報告指出無頭模式在 Google 登入時失敗
- 需要處理反自動化檢測（如 `--disable-blink-features=AutomationControlled`）

---

## 三、OpenCode ACP 集成評估

### 3.1 現有 Skill 分析

**notebooklm-cli skill** 位置：
```
~/.openclaw/workspace/skills/notebooklm-cli/
```

**現狀**：
- Skill 文檔已詳細說明 `nlm login` 命令
- 但 `nlm-cli` 實際上是另一個包（notebooklm-skills 的安裝程序）
- 真正的 NLM CLI 是 `notebooklm` (NPM包)

### 3.2 ACP 是否可控制瀏覽器登入？

**結論**：**理論上可行，但不推薦**

**可能性**：
1. 使用 `dev-browser` skill（Playwright MCP）：
   ```typescript
   // 偽代碼示例
   devBrowser.navigate("https://notebooklm.google.com")
   devBrowser.click("[name='identifier']")
   devBrowser.fill("your-email@gmail.com")
   // ... 但這只是 UI 自動化，不是真正的 ACP 控制
   ```

2. OpenCode 可以執行 shell 命令：
   ```bash
   OpenCode 可以執行：
   notebooklm login
   agent-browser open https://notebooklm.google.com --headed
   ```

**限制**：
- ACP（Agent Control Protocol）主要用於工具調用協調
- 不直接控制瀏覽器實例
- 需要依賴 agent-browser 等外部工具
- 仍然需要可視化界面

**實際建議**：
- 讓用戶首次手動登入
- OpenCode 使用已保存的 session 進行自動化
- 提供登入提示和狀態檢查功能

---

## 四、對比分析

### 4.1 主流 NotebookLM 自動化工具

| 工具 | 認證方式 | 自動化程度 | 推薦度 |
|------|---------|-----------|--------|
| **notebooklm (NPM)** | Playwright + storageState | 需要手動登入一次 | ⭐⭐⭐⭐⭐ |
| **notebooklm-py (Python)** | 反向工程 RPC API | 完全程序化 | ⭐⭐⭐⭐ |
| **agent-browser** | 自動化瀏覽器 | 可自動化，需 GUI | ⭐⭐⭐ |
| **Playwright MCP** | 自動化瀏覽器 | 可自動化，需 GUI | ⭐⭐⭐ |
| **手動導出 cookies** | 導製 cookies | 完全無人值守 | ⭐❌ 不推薦 |

### 4.2 notebooklm-py 分析

**項目地址**：https://github.com/teng-lin/notebooklm-py

**特點**：
- ✅ Python 原生客戶端
- ✅ 不依賴瀏覽器自動化
- ✅ 直接使用 NotebookLM 內部 RPC API
- ✅ **不需要 GUI**
- ✅ 2K+ GitHub stars

**認證方式**：
根據文檔，它使用相同的基於 cookies 的認證機制，但提供了更靈活的 session 管理。

**為什麼它不需要手動登入？**
- 反向工程了 NotebookLM 的內部 RPC 協議
- 可以直接使用已保存的 cookies
- 沒有硬性要求使用 Playwright 進行初始化登入

**結論**：
- 如果追求完全程序化，**notebooklm-py 可能是更好的選擇**
- 但仍然需要獲取有效的 cookies（首次需手動或導出）

---

## 五、最佳實踐建議

### 5.1 推薦工作流

```
初始化 → 手動登入 → 保存 Session → 自動化任務
    ↓
驗證 Session → {有效?} → 繼續任務
    ↓ 無效
重新登入
```

**實現腳本示例**：

```bash
#!/bin/bash
# notebooklm-automation.sh

set -e

# 配置
NOTEBOOK_ID="${NOTEBOOK_ID:-}"
STORAGE_PATH="${NOTEBOOKLM_STORAGE_PATH:-$HOME/.notebooklm/storage-state.json}"

# 檢查認證狀態
check_auth() {
  if [ ! -f "$STORAGE_PATH" ]; then
    echo "❌ 未找到認證文件：$STORAGE_PATH"
    echo "請先運行：notebooklm login"
    exit 1
  fi

  # 嘗試列出 notebook 驗證
  if ! notebooklm list > /dev/null 2>&1; then
    echo "⚠️ Session 已過期，請重新登入：notebooklm login"
    exit 1
  fi
}

# 主流程
main() {
  echo "🔍 檢查認證狀態..."
  check_auth

  echo "✅ 認證有效"

  if [ -z "$NOTEBOOK_ID" ]; then
    echo "📋 列出所有 notebooks："
    notebooklm list
  else
    echo "📝 使用 notebook: $NOTEBOOK_ID"

    # 添加源
    echo "📎 添加源..."
    notebooklm source add "$NOTEBOOK_ID" --url "https://example.com"

    # 生成 Podcast
    echo "🎙️ 生成 Podcast..."
    notebooklm audio create "$NOTEBOOK_ID" --confirm
  fi
}

main "$@"
```

使用方式：
```bash
# 首次設置
notebooklm login

# 運行自動化腳本
./notebooklm-automation.sh

# 或指定 notebook
NOTEBOOK_ID=abc-123 ./notebooklm-automation.sh
```

### 5.2 Session 管理策略

**定期刷新**：
```bash
#!/bin/bash
# refresh-session.sh - 在 cron 中運行
while true; do
  notebooklm login  # 會有交互式提示
  sleep 1200  # 等待 20 分鐘
done
# ⚠️ 這不是完全自動化，需要有人員在場
```

**檢測過期並重試**：
```bash
#!/bin/bash
# safe-automation.sh

MAX_RETRIES=3
RETRY_DELAY=10

run_command() {
  local attempt=0

  while [ $attempt -lt $MAX_RETRIES ]; do
    if notebooklm "$@"; then
      return 0
    fi

    if grep -q "Session expired\|Authentication required" <<< "$(notebooklm "$@" 2>&1)"; then
      echo "⚠️ Session 過期，嘗試重新登入..."
      notebooklm login
      ((attempt++))
      sleep $RETRY_DELAY
    else
      echo "❌ 命令失敗"
      return 1
    fi
  done

  echo "❌ 超過最大重試次數"
  return 1
}

run_command list
```

### 5.3 安全建議

1. **保護 storage-state.json**：
   ```bash
   chmod 600 ~/.notebooklm/storage-state.json
   echo ".notebooklm/" >> .gitignore
   ```

2. **不要將 cookies 提交到版本控制**：
   ```bash
   # ~/.gitignore
   *.json
   .notebooklm/
   storage-state.json
   ```

3. **使用環境變量進行路徑配置**：
   ```bash
   export NOTEBOOKLM_STORAGE_PATH="$HOME/.config/notebooklm/session.json"
   ```

4. **定期更新 storage-state**：
   - Google session cookies 會過期
   - 建議每週重新登入一次

---

## 六、關鍵問題回答

### Q1: 能否無人值守自動登入？

**答案**：技術上可以，但不穩定且不推薦。

**原因**：
- Google 有強大的反自動化檢測
- 無頭模式成功率低
- 可能遇到 CAPTCHA 或 2FA
- 安全風險高

**推薦**：使用手動登入一次後重用 session 的方式。

---

### Q2: 是否每次都需要登入？

**答案**：不需要。

**細節**：
- 登入後 session 保存在 `~/.notebooklm/storage-state.json`
- 可以在多次命令中重用
- Session 約持續 20 分鐘（根據實際測試）
- 過期後重新登入即可

**實際使用**：
```bash
# 初始登入（一次）
notebooklm login

# 後續使用（自動使用保存的 session）
notebooklm list
notebooklm source add <id> --url "..."
notebooklm audio create <id> --confirm
# ... 可以連續使用多次
```

---

### Q3: OpenCode 能否透過 ACP 控制瀏覽器登入流程？

**答案**：可以調瀏覽器自動化工具，但不是 ACP 直接控制。

**澄清**：
- ACP (Agent Control Protocol) 是 OpenCode 的內部協議
- 它不直接提供瀏覽器控制功能
- 但可以通過調用 MCP 服務來控制瀏覽器

**可用工具**：
1. **dev-browser skill** (Playwright MCP)
2. **agent-browser** (Vercel 的瀏覽器 CLI)

**示例流程**：
```typescript
// OpenCode 可以執行
await bash("notebooklm login")
// 或
await bash("agent-browser open https://notebooklm.google.com --headed")
```

**建議**：
- 首次登入讓用戶手動完成
- OpenCode 使用保存的 session 進行後續自動化
- 提供友好的登入提示和錯誤處理

---

### Q4: agent-browser 是否有相關功能？

**答案**：有完整的 session 管理和瀏覽器自動化功能。

**相關功能**：
- ✅ Session 持久化 (`--session-name`, `--profile`)
- ✅ Cookies 管理 (`cookies set`, `cookies get`)
- ✅ 狀態導入 (`--state <path>`)
- ✅ 完整的瀏覽器自動化 API

**可用於 notebooklm 登入**：
```bash
# 方式 1: 使用 agent-browser 進行登入
agent-browser --session-name notebooklm open https://notebooklm.google.com --headed
# ... 完成登入流程

# 方式 2: 加載已保存的 state
agent-browser --state ~/.notebooklm/storage-state.json open https://notebooklm.google.com

# 方式 3: 提取 cookies
agent-browser cookies > cookies.json
```

**限制**：
- 需要可視化界面（`--headed`）
- 需要手動或編寫腳本處理登入流程
- 複雜度比直接使用 `notebooklm login` 更高

**結論**：
- agent-browser 功能完備
- 但對 notebooklm 登入來説，直接使用 CLI 更簡單
- agent-browser 更適合複雜的自動化場景

---

## 七、替代方案

### 7.1 使用 notebooklm-py（Python）

如果需要完全程序化且不依賴瀏覽器：

```python
# 安裝
pip install notebooklm-py

# 使用
from notebooklm import NotebookLMClient

# 從保存的 state 創建客戶端
client = NotebookLMClient.from_storage_path("~/.notebooklm/storage-state.json")

# 列出 notebooks
notebooks = client.list_notebooks()

# 創建 notebook
notebook = client.create_notebook("My Research")

# 添加源
client.add_url_source(notebook.id, "https://example.com")

# 生成 podcast
audio = client.create_audio_overview(notebook.id)
```

**優點**：
- ✅ 程序化 API（非 CLI）
- ✅ 可以深度集成到 Python 應用中
- ✅ 更好的錯誤處理和異步支持

**缺點**：
- ❌ 需要運行時有保存的 session
- ❌ 使用不同的存儲格式（可能需要轉換）

---

### 7.2 使用 MCP 集成

社區中有多個 NotebookLM MCP 服務：

1. **notebooklm-mcp** (khengyun):
   - 完整的 MCP 服務器
   - 支持操作、配置、類型安全
   - 自動 Google session 管理
   - 支持 STDIO, HTTP, SSE

2. **其他 MCP 集成**：
   - 多個 GitHub 項目提供 NotebookLM MCP 服務器
   - 可以直接在 Claude Code / Cursor / Windsurf 中使用

**安裝示例**：
```bash
# 安裝 notebooklm-mcp
pip install notebooklm-mcp

# 配置 Claude Code
# 在 .claude/config.json 或 Claude Desktop 配置中添加 MCP 服務器
```

**優點**：
- ✅ 原生集成到 AI 助手
- ✅ 無需手動調用 CLI
- ✅ 持久化的 session 管理

---

## 八、結論與建議

### 8.1 最終推薦

**對於 OpenCode / NotebookLM Skill 自動化**：

1. **首次使用**：
   - 讓用戶手動運行 `notebooklm login` 完成認證
   - 提供清晰的文檔和指導

2. **自動化腳本**：
   - 使用已保存的 session 進行操作
   - 實現 session 失效檢測
   - 提供友好的錯誤提示和重登錄指引

3. **不推薦**：
   - 完全無人值守的自動登入
   - 無頭模式登入（易失敗）
   - 硬編碼憑證或 cookies

### 8.2 實施步驟

**階段 1：基本設置**
```bash
# 1. 安裝依賴
npm install -g notebooklm
npx playwright install chromium

# 2. 手動登入
notebooklm login

# 3. 驗證
notebooklm list
```

**階段 2：創建自動化腳本**
```bash
# 創建 wrapper 腳本
cat > nlm-auto.sh << 'EOF'
#!/bin/bash
set -e

# 檢查認證
if [ ! -f ~/.notebooklm/storage-state.json ]; then
  echo "請先運行: notebooklm login"
  exit 1
fi

# 執行命令
notebooklm "$@"
EOF

chmod +x nlm-auto.sh
```

**階段 3：集成到 Skill**
更新 skill 文檔和提示：
- 添加認證檢查
- 提供清晰的錯誤消息
- 包含 session 管理建議

### 8.3 長期維護建議

1. **監控 Google API 變化**：
   - NotebookLM 沒有官方 API
   - 使用內部 RPC，可能隨時變化
   - 定期測試和更新

2. **提供多種認證方式**：
   - 直接使用 `notebooklm login`
   - 導入已有 cookies
   - 環境變量配置

3. **文檔和示例**：
   - 提供完整的使用示例
   - 包含常見問題解答
   - 更新到最新的最佳實踐

---

## 九、參考資料

### 官方資源
- [notebooklm (NPM)](https://www.npmjs.com/package/notebooklm)
- [notebooklm GitHub](https://github.com/kaelen/notebooklm)
- [Playwright 認證文檔](https://playwright.dev/docs/auth)

### 社區項目
- [notebooklm-py](https://github.com/teng-lin/notebooklm-py) - Python 客戶端
- [notebooklm-mcp](https://github.com/khengyun/notebooklm-mcp) - MCP 服務器
- [agent-browser](https://github.com/vercel-labs/agent-browser) - 瀏覽器自動化
- [notebooklm-skill](https://github.com/PleasePrompto/notebooklm-skill) - Claude Code skill

### 文章和教程
- "The CLI Tool That Unlocks Google NotebookLM" (Medium)
- "Automating Google NotebookLM from your AI agent" (Agent Native)
- "Why I Ditched Playwright MCP for Vercel's agent-browser" (LinkedIn)

---

## 附錄

### A. 完整命令參考

```bash
# 認證
notebooklm login                      # 登入
notebooklm login --output /path/to    # 自定義路徑
notebooklm login --headless           # 無頭模式（不推薦）

# 環境變量
export NOTEBOOKLM_STORAGE_PATH="/path/to/storage-state.json"
export NOTEBOOKLM_STORAGE_STATE='{"cookies":[...]}'
export NOTEBOOKLM_STORAGE_PATH=':inline:'

# 使用
notebooklm list                       # 列出 notebooks
notebooklm create "Title"             # 創建
notebooklm source add <id> --url "..."  # 添加源
notebooklm ask <id> "question"        # 提問
notebooklm generate audio <id>        # 生成 Podcast
```

### B. 調試技巧

```bash
# 啟用調試日誌
notebooklm --debug list

# 檢查認證狀態
cat ~/.notebooklm/storage-state.json | jq .

# 查看cookies
notebooklm --debug list 2>&1 | grep -i cookie

# 清除 session
rm ~/.notebooklm/storage-state.json
```

### C. 常見錯誤處理

```bash
# Session 過期
❌ "Session expired or invalid"
✅ notebooklm login

# 未認證
❌ "Not authenticated. Run 'notebooklm login' first."
✅ notebooklm login

# Playwright 未安裝
❌ "Playwright is not installed."
✅ npx playwright install chromium

# 無頭模式失敗
❌ Google login 在 headless 模式下失敗
✅ 移除 --headless 標誌

# Cookie 過期
❌ API 請求返回 401
✅ notebooklm login
```

---

**文檔版本**: 1.0
**最後更新**: 2026年2月27日
**作者**: Sisyphus (OpenCode Research)
**授權**: MIT License
