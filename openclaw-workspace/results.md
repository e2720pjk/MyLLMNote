# NotebookLM CLI 最佳實踐 - 登入自動化研究結果

## 研究摘要

本報告分析 `notebooklm-cli` (nlm) 的登入流程、自動化可能性，以及最佳實踐方案。

---

## 關鍵發現：三層自動恢復機制

**好消息**：`notebooklm-cli` 已經內建自動登入恢復功能，大部分情況下無需人工干預！

### 自動恢復三層架構

```python
# 程式碼來源：src/notebooklm_tools/core/base.py
def _try_reload_or_headless_auth(self) -> bool:
    """嘗試透過重新載入磁碟令牌或執行 headless auth 來恢復驗證。"""
    # 第 1 層：從磁碟重新載入令牌
    cached = load_cached_tokens()
    if cached and cached.cookies:
        # 重新載入令牌並強制重新提取 CSRF token
        self.cookies = cached.cookies
        self.csrf_token = ""
        self._session_id = ""
        return True

    # 第 2層：如果 Chrome profile 存在，執行 headless auth
    try:
        from notebooklm_tools.utils.cdp import run_headless_auth
        tokens = run_headless_auth()
        if tokens:
            # 更新令牌
            self.cookies = tokens.cookies
            self.csrf_token = tokens.csrf_token
            self._session_id = tokens.session_id
            return True
    except Exception:
        pass

    return False
```

### 運作流程

```
命令執行 → 401 錯誤？
    ↓ 是
┌─────────────────────────────────────┐
│ 第 1 層：自動重新載入磁碟令牌          │
│ - 從 ~/.notebooklm-mcp-cli/ 讀取     │
│ - 重新提取 CSRF token                │
│ - 速度最快 (< 1 秒)                   │
└─────────────────────────────────────┘
    ↓ 失敗
┌─────────────────────────────────────┐
│ 第 2 層：從外部重新載入令牌           │
│ - 檢查其他程序是否更新了令牌           │
│ - 例如：另一個程序執行了 nlm login    │
└─────────────────────────────────────┘
    ↓ 失敗
┌─────────────────────────────────────┐
│ 第 3 層：Headless 自動登入           │
│ - 在 headless 模式下啟動 Chrome       │
│ - 使用已儲存的登入資訊               │
│ - 自動提取新 Cookie                   │
└─────────────────────────────────────┘
    ↓ 失敗
需要手動執行: nlm login
```

---

## 回答關鍵問題

### Q1: 能否無人值守自動登入？

**答：部分可行**

**✅ 不需要人工的情況**：
- 已經登入過一次
- Chrome profile 儲存了 Google 登入狀態
- 第 3 層 `run_headless_auth()` 會自動執行

**❌ 需要人工的情況**：
- 首次登入（必須人工操作瀏覽器）
- Google 登入過期需要重新驗證
- Chrome 沒有儲存登入 session

### Q2: 是否每次都需要登入？

**答：不需要**

```
第 1 層恢復成功 (CSRF/Session refresh):  自動重試，無需登入
第 2 層恢復成功 (磁碟令牌 reload):      自動重試，無需登入
第 3 層恢復成功 (headless auth):        自動重試，無需登入
三層都失敗:                             需要 nlm login
```

**實際情況**：
- Session 有效期約 20 分鐘
- Cookie 實際穩定長達數週（程式碼限制 7 天）
- 大部分 token 過期會被第 1 層自動補救
- 只在完全失效時才需要手動 `nlm login`

### Q3: OpenCode 能否透過 ACP 控制瀏覽器登入？

**答：不能直接控制，但可以間接協助**

ACP (Agent Client Protocol) 是用於控制 OpenCode AGENT 的通訊協議，不是瀏覽器自動化工具。

**可行的間接方式**：

```bash
# 方式 1: 執行 nlm login 命令並等待完成
bash(command: "nlm login", timeout: 300)

# 方式 2: 檢查登入狀態
nlm login --check
```

### Q4: agent-browser (vercel-labs) 是否有相關功能？

**答：在當前 OpenCode 環境中沒有發現 agent-browser 技能**

`notebooklm-cli` 已經內建使用 Chrome DevTools Protocol (CDP) 進行瀏覽器自動化，不需要額外的瀏覽器代理。

---

## 核心實現分析

### Headless Auth 實現

**位置**: `src/notebooklm_tools/utils/cdp.py`

```python
def run_headless_auth(
    port: int = 9223,
    timeout: int = 30,
    profile_name: str = "default",
) -> "AuthTokens | None":
    """在 headless 模式下執行驗證（無用戶交互）。

    僅在 Chrome profile 已儲存 Google 登入時有效。
    提取令牌後 Chrome 會自動終止。

    用於快取令牌過期時的自動令牌刷新。
    """
    # 檢查 profile 是否存在且有登入資訊
    if not has_chrome_profile(profile_name):
        return None

    chrome_process: subprocess.Popen | None = None
    chrome_was_running = False

    try:
        # 嘗試連接到現有 Chrome
        debugger_url = get_debugger_url(port)

        if debugger_url:
            # Chrome 已在運行 - 使用現有實例
            chrome_was_running = True
        else:
            # 沒有 Chrome 運行 - 啟動 headless 模式
            chrome_process = launch_chrome_process(
                port, headless=True, profile_name=profile_name
            )
            # ... 等待 debugger 準備 ...

        # 導向 NotebookLM
        page = find_or_create_notebooklm_page(port)
        ws_url = page.get("webSocketDebuggerUrl")

        # 檢查登入狀態
        current_url = get_current_url(ws_url)
        if not is_logged_in(current_url):
            # 未登入 - headless 無法幫助
            return None

        # 提取 Cookie
        cookies_list = get_page_cookies(ws_url)
        cookies = {c["name"]: c["value"] for c in cookies_list}

        # 提取 CSRF token 和 session ID
        html = get_page_html(ws_url)
        csrf_token = extract_csrf_token(html)
        session_id = extract_session_id(html)

        # 儲存令牌
        tokens = AuthTokens(
            cookies=cookies,
            csrf_token=csrf_token,
            session_id=session_id,
            extracted_at=time.time(),
        )
        save_tokens_to_cache(tokens)

        # 清理快取
        cleanup_chrome_profile_cache(profile_name)

        return tokens

    finally:
        # 只終止我們啟動的 Chrome 實例
        if chrome_process and not chrome_was_running:
            try:
                chrome_process.terminate()
                chrome_process.wait(timeout=5)
            except Exception:
                chrome_process.kill()
```

### Cookie 儲存位置

```
~/.notebooklm-mcp-cli/
├── config.toml                    # CLI 配置
├── aliases.json                   # Notebook 別名
├── profiles/                      # 驗證 profile
│   ├── default/
│   │   └── auth.json              # Cookies, tokens, email
│   ├── work/
│   │   └── auth.json
│   └── personal/
│       └── auth.json
├── chrome-profile/                # Chrome profile (單一 profile 用戶)
└── chrome-profiles/               # Chrome profiles (多 profile 用戶)
    ├── work/
    └── personal/
```

### Profile 登入持久化

**專屬 Chrome Profile 特性**：
- 每個 profile 都有自己的隔離 Chrome session
- 首次登入需要手動操作
- 後續登入由瀏覽器的「記住登入」功能處理
- 不會與主 Chrome profile 衝突

```bash
# 首次登入 - 需要手動
nlm login --profile work
# -> 開啟 Chrome window -> 手動登入 Google -> Cookie 提取

# 後續刷新 - 自動 Headless
# -> 瀏覽器自動使用儲存的登入資訊
# -> Headless Chrome 執行並提取新 Cookie
```

---

## 詳細登入流程

### 首次登入（Auto Mode）

```bash
# 步驟
1. 完全關閉 Chrome
2. nlm login
3. 在開啟的瀏覽器 window 登入 Google
4. 等待 "SUCCESS!" 訊息

# 背後發生的事情
1. 建立專用 Chrome profile
2. 以 remote debugging 模式啟動 Chrome
3. 用戶在瀏覽器登入 NotebookLM
4. 提取 Cookie、CSRF token 和電子郵件
5. 關閉 Chrome
```

### 後續登入（自動）

```bash
# 情況 A: Token 有效
nlm notebook list
# -> 直接使用快取的 Cookie

# 情況 B: 401 錯誤 - 第 1 層恢復 (CSRF refresh)
# -> 自動重新提取 CSRF token
# -> 無需用戶幹預

# 情況 C: 401 錯誤 - 第 2/3 層恢復
# -> 第 2 層: 檢查磁碟令牌是否更新
# -> 第 3 層: Headless Chrome 提取新 Cookie
# -> 無需用戶幹預

# 情況 D: 所有層都失敗
# -> 提示用戶執行 nlm login
```

### Manual Mode (Cookie 檔案)

```bash
# 用於自動模式失敗的情況
nlm login --manual --file /path/to/cookies.txt
```

---

## Multi-Profile 支援

### 管理多個 Google 帳號

```bash
# 建立 profile
nlm login --profile work
nlm login --profile personal

# 列出所有 profile
nlm login profile list
# 輸出:
#   work: jsmith@company.com
#   personal: jsmith@gmail.com

# 切換預設 profile
nlm login switch personal

# 使用特定 profile
nlm notebook list --profile work
nlm audio create <id> --profile work --confirm
```

### 隔離特性

每個 profile 獲得：
- 隔離的憑證：儲存在 `~/.notebooklm-mcp-cli/profiles/<name>/`
- 隔離的 Chrome profile：`~/.notebooklm-mcp-cli/chrome-profiles/<name>/`
- 捕獲的電子郵件：登入時自動提取

---

## 實用範例

### 範例 1: 自動化腳本

```bash
#!/bin/bash
# auto-notebooklm.sh

# 1. 嘗試執行命令（讓自動恢復機制處理）
nlm notebook list

# 2. 檢查是否成功
if [ $? -ne 0 ]; then
    echo "Authentication failed, running login..."
    nlm login
    # 重新嘗試
    nlm notebook list
fi

# 3. 繼續工作流程
nlm notebook create "Auto Research"
# ... 更多命令
```

### 範例 2: cron 定期任務

```cron
# 每天早上 9 點同步 notebook 資料
0 9 * * * /home/user/scripts/sync_notebooklm.sh

# sync_notebooklm.sh:
#!/bin/bash
cd /home/user
nlm notebook list > /dev/null 2>&1 || nlm login
nlm research start "daily news" --notebook-id ${NOTEBOOK_ID}
```

### 範例 3: MCP Server 整合

```json
// Claude Desktop / Cursor 設定
{
  "mcpServers": {
    "notebooklm-mcp": {
      "command": "notebooklm-mcp"
    }
  }
}
```

在 MCP 中驗證工具會自動處理刷新：
```python
# src/notebooklm_tools/mcp/tools/auth.py
@logged_tool()
def refresh_auth() -> dict[str, Any]:
    """從磁碟重新載入驗證令牌或執行 headless 重新驗證。"""
    # 嘗試從磁碟載入令牌
    cached = load_cached_tokens()
    if cached and cached.cookies:
        return {
            "status": "success",
            "message": "Auth tokens reloaded from disk cache.",
        }

    # 嘗試 headless auth（如果 Chrome profile 存在）
    tokens = run_headless_auth()
    if tokens:
        return {
            "status": "success",
            "message": "Headless authentication successful.",
        }

    return {
        "status": "error",
        "error": "No cached tokens found. Run 'nlm login' to authenticate.",
    }
```

---

## 安裝與設定

### 安裝

```bash
# 使用 uv（推薦）
uv tool install notebooklm-mcp-cli

# 或使用 pip
pip install notebooklm-mcp-cli

# 或使用 pipx
pipx install notebooklm-mcp-cli
```

### 驗證安裝

```bash
nlm --version
# 輸出: notebooklm-mcp-cli X.Y.Z

nlm --ai > nlm-ai-docs.md  # 生成 AI 助手文件
```

---

## 疑難排解

### 常見錯誤

| 錯誤 | 原因 | 解決方案 |
|------|------|---------|
| "Cookies have expired" | Session 超時 | 由自動恢復機制處理，或 `nlm login` |
| "Chrome not found" | Chrome 未安裝 | 安裝 Google Chrome |
| "Authentication failed" | Profile 不存在 | `nlm login` 建立新 profile |
| "Profile not found" | 指定的 profile 不存在 | `nlm login profile list` 檢查 |
| "Research already in progress" | 已有待處理的研究任務 | 使用 `--force` 或導入現有任務 |

### Session 過期處理

```python
# 註：Session 實際上穩定長達數週
# 程式碼中的 is_expired() 檢查只是警示，不拒絕使用
tokens = load_cached_tokens()
if tokens.is_expired(max_age_hours=168):  # 7 天
    print("Note: Cached tokens are older than 1 week. They may still work.")
# 仍舊返回 tokens，讓 API 客戶端的功能檢查決定有效性
```

---

## 推薦實施方案

### 方案 A: 自動化腳本（推薦）

**適用場景**：
- 定期批量處理
- CI/CD 流程
- cron 任務

```bash
#!/bin/bash
# smart-nlm.sh - 智能處理登入

# 嘗試命令，讓三層自動恢復機制工作
run_nlm() {
    nlm "$@"
}

# 主流程
run_nlm notebook list
if [ $? -ne 0 ]; then
    echo "Auto-recovery failed, running login..."
    nlm login
    run_nlm notebook list
fi

# ... 繼續你的工作流程
```

**優點**：
- 最少的用戶干預
- 自動處理大部分情況
- 簡單易理解

### 方案 B: 預登入服務

**適用場景**：
- 經常需要使用 notebooklm
- 24/7 服務

```python
# 定期刷新令牌的守護進程
import time
import subprocess

def refresh_periodically(interval_hours=19):
    """每 19 小時（低於 20 分鐘 session 限制）刷新一次"""
    while True:
        try:
            # 執行一個輕量級命令來觸發刷新
            subprocess.run(['nlm', 'notebook', 'list'], check=True)
            print("Token refreshed successfully")
        except subprocess.CalledProcessError:
            print("Refresh failed, user intervention may be needed")
            subprocess.run(['nlm', 'login'])

        time.sleep(interval_hours * 3600)

if __name__ == '__main__':
    refresh_periodically()
```

### 方案 C: MCP Server（最便利）

**適用場景**：
- AI 助手整合（Claude, Gemini 等）
- 需要自然語言介面

```bash
# 安裝並配置 MCP
uv tool install notebooklm-mcp-cli

# 添加到 Claude Code
claude mcp add --scope user notebooklm-mcp notebooklm-mcp

# 在 Claude 中使用
"Create a notebook about quantum computing and generate a podcast"
# -> Claude 會自動處理所有驗證細節
```

**優點**：
- 完全透明給 AI 助手
- 自動處理所有刷新機制
- 支援自然語言介面

---

## 最佳實踐摘要

### ✅ DO（應該做的）

1. **信任自動恢復機制**
   - 三層恢復會處理大多數情況
   - 只在確實需要時才手動執行 `nlm login`

2. **使用 Profile 管理多帳號**
   - `nlm login --profile work`
   - 避免登入衝突

3. **定期檢查狀態**
   - `nlm login --check`
   - 在關鍵操作前驗證

4. **使用自動化腳本包裝**
   - 失敗時自動調用 `nlm login`
   - 減少人工干預

5. **利用 MCP 整合**
   - 給 AI 助手完整的控制權
   - 讓 MCP 處理所有驗證細節

### ❌ DON'T（不應該做的）

1. **不要手動管理 Cookies**
   - 讓 nlm 處理所有 Cookie 提取
   - 不要修改 `~/.notebooklm-mcp-cli/` 內的檔案

2. **不要頻繁手動登入**
   - 自動恢復機制已經足夠
   - 只在三層都失敗時才手動登入

3. **不要忽略 profile 隔離**
   - 混用 profile 可能導致問題
   - 始終明確指定 profile（work vs personal）

4. **不要依賴固定 Session 時間**
   - 20 分鐘是保守估計
   - Cookie 實際穩定長達數週

---

## 結論

### 主要結論

1. **`notebooklm-cli` 已經內建強大的自動化能力**
   - 三層自動恢復機制
   - Headless auth 支援
   - Multi-profile 隔離

2. **不需要額外的瀏覽器代理**
   - 工具已經使用 Chrome DevTools Protocol
   - 不需要 agent-browser 或類似工具

3. **大多數情況下無人值守運行**
   - 首次登入後，後續大部分操作自動
   - 只在完全失效時需要人工干預

4. **OpenCode/ACP 不能直接控制瀏覽器**
   - ACP 用於控制 OpenCode AGENT
   - 可以執行 `nlm login` 命令，但不能控制登入流程

### 強烈推薦的做法

**最佳方案**：使用 MCP Server
```bash
claude mcp add --scope user notebooklm-mcp notebooklm-mcp
```

**為什麼 MCP 是最佳選擇**：
1. 完全透明的驗證處理
2. 自然語言介面
3. 自動刷新機制內建
4. 與 AI 助手深度整合

### 替代方案：智能腳本包裝

如果不需要 AI 助手整合，使用腳本包装：
```bash
#!/bin/bash
nlm notebook list || { nlm login; nlm notebook list; }
# ... 繼續工作流程
```

---

## 最後更新

- **研究日期**: 2026-02-05
- `notebooklm-mcp-cli` 版本: 0.2.14+
- **文件來源**:
  - GitHub: https://github.com/jacob-bd/notebooklm-mcp-cli
  - PyPI: https://pypi.org/project/notebooklm-mcp-cli/
  - OpenCode skill: `~/.openclaw/workspace/skills/notebooklm-cli/`

---

## 參考資料

- [官方 README](https://github.com/jacob-bd/notebooklm-mcp-cli/blob/main/README.md)
- [Authentication Guide](https://github.com/jacob-bd/notebooklm-mcp-cli/blob/main/docs/AUTHENTICATION.md)
- [CLI Guide](https://github.com/jacob-bd/notebooklm-mcp-cli/blob/main/docs/CLI_GUIDE.md)
- [MCP Guide](https://github.com/jacob-bd/notebooklm-mcp-cli/blob/main/docs/MCP_GUIDE.md)

---

**研究員**: Sisyphus (OpenCode AI Agent)
**委託**: NotebookLM CLI 自動化探索任務
