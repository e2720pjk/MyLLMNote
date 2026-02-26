# NotebookLM CLI 最佳實踐研究報告

## 執行摘要

本研究深入分析了 NotebookLM CLI (nlm) 的認證機制、自動化登入方法，以及相關的瀏覽器自動化技術。研究發現如下：

### 關鍵發現

1. **專案已合併**：原 `notebooklm-cli` 專案已併入 `notebooklm-mcp-cli`，提供統一的 CLI 和 MCP 伺服器
2. **支持無人值守自動登入**：v0.1.9+ 版本包含 headless Chrome 自動認證功能
3. **三層認證恢復機制**：CSRF 刷新 → 磁碟重載 → Headless Chrome 認證
4. **多帳號支持**：透過獨立的 Chrome profile 支持多個 Google 帳號
5. **Cookie 有效期**：約 2-4 週，可自動刷新

---

## 一、認證機制概述

### 1.1 NoteBookLM CLI 認證原理

NotebookLM 使用瀏覽器 cookies 進行認證（無官方 API）。CLI/MCP 透過 Chrome DevTools Protocol (CDP) 自動提取這些 cookies。

**認證流程：**
1. 啟動專屬 Chrome profile（與用戶主 Chrome 隔離）
2. 啟用遠程調試端口 (remote debugging port)
3. 瀏覽器開啟 NotebookLM，用戶登入 Google
4. 透過 CDP WebSocket 連接提取 cookies、CSRF token、session ID
5. 將 tokens 快取到本地

**存儲位置：**
```
~/.notebooklm-mcp-cli/
├── config.toml                    # CLI 配置
├── aliases.json                   # Notebook 別名
├── profiles/                      # 認證 profile
│   ├── default/
│   │   └── auth.json              # Cookies, tokens, email
│   ├── work/
│   └── personal/
└── chrome-profiles/               # Chrome profiles
    ├── work/
    └── personal/
```

### 1.2 認證組件

每個 profile 的 `auth.json` 包含：
- Parsed cookies (字典格式)
- CSRF token (自動提取)
- Session ID (自動提取)
- Account email (自動提取)
- Extraction timestamp (提取時間戳)

**必需的 Cookies：**
```python
REQUIRED_COOKIES = ["SID", "HSID", "SSID", "APISID", "SAPISID"]
MINIMUM_REQUIRED_COOKIES = {"SID"}
```

---

## 二、無人值守自動登入方案

### 2.1 v0.1.9+ 的自動認證恢復機制

從 notebooklm-mcp-cli v0.1.9 開始，伺服器自動處理 token 過期：

#### 三層恢復策略

**Layer 1: 刷新 CSRF tokens** (快速，~1秒)
```python
# 從 NotebookLM 主頁提取新的 CSRF token/session ID
fetch_tokens(cookies) -> (csrf_token, session_id)
```

**Layer 2: 從磁碟重載**
```python
# 檢查 auth.json 是否有更新的 tokens (<5 分鐘前)
if has_fresher_tokens_on_disk():
    reload_from_disk()
```

**Layer 3: Headless Chrome 認證**
```python
# 如果 profile 有保存的登入，在 headless 模式運行 Chrome
if has_chrome_profile_saved_login():
    run_headless_auth()  # 提取後自動終止 Chrome
```

### 2.2 Headless Auth 實現

**核心函數：** `run_headless_auth()`

**工作原理：**

```python
def run_headless_auth(
    port: int = 9223,
    timeout: int = 30,
    profile_name: str = "default",
) -> AuthTokens | None:
    """
    在無頭模式下運行認證（無需用戶交互）
    
    前提：Chrome profile 已經保存了 Google 登入
    Chrome 進程會在 token 提取後自動終止
    """
    # 1. 檢查 profile 是否存在並且有保存的登入
    if not has_chrome_profile(profile_name):
        return None

    chrome_process = None
    chrome_was_running = False

    try:
        # 2. 嘗試連接到現有 Chrome
        debugger_url = get_debugger_url(port)

        if debugger_url:
            # Chrome 已經在運行 - 使用現有實例
            chrome_was_running = True
        else:
            # 3. 沒有 Chrome 運行 - 在 headless 模式啟動
            chrome_process = launch_chrome_process(
                port,
                headless=True,  # 關鍵：headless 模式
                profile_name=profile_name
            )

            # 等待 Chrome debugger 準備就緒
            for _ in range(5):
                debugger_url = get_debugger_url(port)
                if debugger_url:
                    break
                time.sleep(1)

        # 4. 提取 cookies 和 tokens
        cookies_list = get_page_cookies(ws_url)
        cookies = {c["name"]: c["value"] for c in cookies_list}

        html = get_page_html(ws_url)
        csrf_token = extract_csrf_token(html)
        session_id = extract_session_id(html)

        # 5. 保存 tokens
        tokens = AuthTokens(
            cookies=cookies,
            csrf_token=csrf_token,
            session_id=session_id,
            extracted_at=time.time(),
        )
        save_tokens_to_cache(tokens)

        # 6. 清理快取以減小 profile 大小
        cleanup_chrome_profile_cache(profile_name)

        return tokens

    finally:
        # 關鍵：只終止我們啟動的 Chrome
        if chrome_process and not chrome_was_running:
            chrome_process.terminate()
            chrome_process.wait(timeout=5)
```

**檢查 Chrome Profile 是否已登入：**
```python
def has_chrome_profile(profile_name: str = "default") -> bool:
    """檢查 Chrome profile 是否有保存的登入"""
    profile_dir = get_chrome_profile_dir(profile_name)
    cookies_file = profile_dir / "Default" / "Cookies"
    return cookies_file.exists()
```

### 2.3 完整的認證生命週期

| 組件 | 持續時間 | 刷新方式 |
|-------|----------|---------|
| Cookies | ~2-4 週 | 自動刷新 via headless Chrome (如果保存了 profile) |
| CSRF Token | ~分鐘 | 每次調用失敗時自動刷新 |
| Session ID | 每次 MPC 會話 | MPC 啟動時自動提取 |

**重要：** 重新認證只需運行 `nlm login`

---

## 三、瀏覽器自動化能力

### 3.1 Chrome DevTools Protocol (CDP)

NotebookLM CLI 使用 CDP 進行 cookie 提取，無需鑰匙串訪問。

**CDP 工具：** `src/notebooklm_tools/utils/cdp.py`

**關鍵功能：**

```python
def extract_cookies_via_cdp(
    port: int = 9222,
    auto_launch: bool = True,
    wait_for_login: bool = True,
    login_timeout: int = 300,
    profile_name: str = "default",
) -> dict[str, Any]:
    """
    透過 CDP 從 Chrome 提取 cookies 和 tokens
    
    參數：
        port: Chrome DevTools 端口
        auto_launch: 如為 true，自動啟動 Chrome
        wait_for_login: 如為 true，等待用戶登入
        login_timeout: 登入超時時間（秒）
        profile_name: NLM profile 名稱（每個都有獨立的 Chrome user-data-dir）
    """
    # 1. 檢查 Chrome 是否運行
    existing_port = find_existing_nlm_chrome()
    if existing_port:
        port = existing_port
    
    # 2. 啟動 Chrome（如果需要）
    if not debugger_url and auto_launch:
        port = find_available_port()
        launch_chrome(port, headless=False, profile_name=profile_name)
        debugger_url = get_debugger_url(port)
    
    # 3. 打開 NotebookLM 頁面
    page = find_or_create_notebooklm_page(port)
    ws_url = page.get("webSocketDebuggerUrl"]
    
    # 4. 導航到 NotebookLM
    navigate_to_url(ws_url, NOTEBOOKLM_URL)
    
    # 5. 檢查登入狀態
    current_url = get_current_url(ws_url)
    if not is_logged_in(current_url) and wait_for_login:
        # 等待用戶登入
        wait_for_login_completion(ws_url, login_timeout)
    
    # 6. 提取 cookies
    cookies = get_page_cookies(ws_url)
    
    # 7. 提取 CSRF 和 session ID
    html = get_page_html(ws_url)
    csrf_token = extract_csrf_token(html)
    session_id = extract_session_id(html)
    email = extract_email(html)
    
    return {
        "cookies": cookies,
        "csrf_token": csrf_token,
        "session_id": session_id,
        "email": email,
    }
```

### 3.2 Chrome Profile 管理

**啟動 Chrome 的關鍵參數：**

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
        "--no-first-run",
        "--no-default-browser-check",
        "--disable-extensions",
        f"--user-data-dir={profile_dir}",        # 獨立 profile
        "--remote-allow-origins=*",              # WebSocket 連接 (Chrome 136+)
    ]
    
    if headless:
        args.append("--headless=new")            # Headless 模式
    
    return subprocess.Popen(args)
```

**可用端口掃描：**
```python
def find_available_port(starting_from: int = 9222, max_attempts: int = 10) -> int:
    """查找可用的 Chrome 調試端口"""
    import socket
    for offset in range(max_attempts):
        port = starting_from + offset
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(('localhost', port))
                return port
        except OSError:
            continue
    raise RuntimeError(f"無可用端口")
```

### 3.3 多帳號支持

**Profile 管理系統：**

```bash
# 創建不同 profile
nlm login --profile work       # 用工作帳號登入
nlm login --profile personal   # 用個人帳號登入

# 列出所有 profiles
nlm login profile list
# 輸出：
#   work: jsmith@company.com
#   personal: jsmith@gmail.com

# 切換默認 profile
nlm login switch personal

# 使用指定 profile
nlm notebook list -profile work
```

**實現細節：**
每個 profile 獲得：
- **獨立的 credentials**：存儲在 `~/.notebooklm-mcp-cli/profiles/<name>/`
- **獨立的 Chrome profile**：`~/.notebooklm-mcp-cli/chrome-profiles/<name>/`
- **捕獲的 email**：登入時自動提取

這樣可以同時登入多個 Google帳號而不會衝突。

---

## 四、OpenCode 瀏覽器控制集成

### 4.1 agent-browser (vercel-labs) 評估

經過研究，發現：

1. **agent-browser** 主要是一個瀏覽器自動化工具（類似 Playwright）
2. 具有基本的瀏覽器控制能力（導航、點擊、填寫表單等）
3. **不支持直接與 Chrome DevTools Protocol 集成**
4. **沒有內建的 cookie 持久化機制**用於無人值守認證

### 4.2 ACP (Agent Control Protocol) 集成

OpenCode 的 ACP 沒有直接的瀏覽器控制功能。對於 NotebookLM CLI 的認證：

**推薦方式：** 使用 `nlm login` CLI 命令
- 該命令已經內建了完整的瀏覽器自動化邏輯
- 使用 CDP 進行 cookie 提取
- 支持多 profile 管理
- 支持手動和自動模式

### 4.3 Playwright vs agent-browser

| 功能 | Playwright | agent-browser | NotebookLM CLI |
|------|----------|--------------|----------------|
| CDP 集成 | ✅ 支持 | ❌ 不支持 | ✅ 原生支持 |
| Headless 模式 | ✅ 支持 | ✅ 支持 | ✅ 支持 |
| Cookie 持久化 | ✅ 支持 | ❌ 原生支持 | ✅ 支持 |
| Profile 隔離 | ✅ 支持 | ✅ 支持 | ✅ 支持 |
| 瀏覽器生命周期管理 | 手動 | 手動 | 自動終止 |

---

## 五、方案評估與推薦

### 5.1 方案比較

| 方案 | 自動化程度 | 初期設置 | 維護成本 | 適用場景 |
|------|----------|---------|---------|---------|
| **Headless Auth (v0.1.9+)** | ⭐⭐⭐⭐ | 一次性登入 | 低 | CI/CD、定期任務 |
| **手動 File Mode** | ⭐⭐⭐ | 手動提取 cookies | 中 | 開發環境、調試 |
| **Auto Mode (交互式)** | ⭐⭐ | 無 | 低 | 交互式使用 |
| **agent-browser** | ⭐⭐ | 需要實現 | 高 | 不推薦 |
| **Playwright 自動化** | ⭐⭐⭐ | 需要編寫腳本 | 中 | 自定義場景 |

### 5.2 推薦實施方案

#### 方案 A：使用 NotebookLM CLI 內建的 Headless Auth（推薦）

**優點：**
- ✅ 原生支持，無需額外開發
- ✅ 自動處理 token 過期
- ✅ Profile 隔離，支持多帳號
- ✅ 自動清理快取，節省空間

**實施步驟：**

1. **初始設置（一次性）**
   ```bash
   # 安裝 notebooklm-mcp-cli
   pipx install notebooklm-mcp-cli
   
   # 交互式登入（首次需要）
   nlm login --profile production
   # 在打開的 Chrome 窗口中登入你的 Google 帳號
   ```

2. **自動化使用（無人值守）**
   ```bash
   # 只需調用 CLI 命令
   nlm notebook list
   nlm source add <notebook-id> --url "https://example.com"
   nlm audio create <notebook-id> --confirm
   ```

3. **Token 自動刷新**
   - v0.1.9+ 自動處理三層恢復
   - 如果 Google 登入完全過期，只需重新運行 `nlm login`

**CI/CD 集成示例：**

```yaml
# .github/workflows/notebooklm.yml
name: Generate Podcast

on:
  schedule:
    - cron: '0 9 * * *'  # 每天 9:00

jobs:
  generate:
    runs-on: ubuntu-latest
    container:
      image: python:3.11
      # 需要安裝 Chromium
    
    steps:
      - name: Install dependencies
        run: |
          apt-get update
          apt-get install -y chromium-browser
          pipx install notebooklm-mcp-cli
      
      # 複製預先認證的 profile（推薦）
      - name: Load auth profile
        env:
          AUTH_ZIP: ${{ secrets.NLM_AUTH_PROFILE }}
        run: |
          echo "$AUTH_ZIP" | base64 -d > /tmp/profile.zip
          unzip -o /tmp/profile.zip -d ~/.notebooklm-mcp-cli/
      
      # 或者使用環境變量（CI/CD 友好）
      - name: Use environment variable
        env:
          NOTEBOOKLM_AUTH_JSON: ${{ secrets.NOTEBOOKLM_COOKIES }}
        run: |
          # 設置 inline JSON 環境變量（無需文件寫入）
          nlm notebook list
      
      - name: Generate podcast
        run: |
          nlm notebook create "Daily Briefing" | tee notebook_id.txt
          NOTEBOOK_ID=$(cat notebook_id.txt | grep -oP 'Created notebook: \K[0-9a-f-]+')
          nlm source add "$NOTEBOOK_ID" --url "https://news.example.com/feed"
          nlm audio create "$NOTEBOOK_ID" --confirm
```

#### 方案 B：手動 File Mode（備選）

**適用場景：**
- 不想讓 Chrome 運行
- 想要完全控制 cookies
- 調試認證問題

**實施步驟：**

1. **提取 cookies**
   ```bash
   # 方法 1：交互式
   nlm login --manual
   # 按照提示從瀏覽器 DevTools 複製 cookies
   
   # 方法 2：直接指定文件
   nlm login --manual --file cookies.txt
   ```

2. **Cookie 文件格式**
   ```bash
   # cookies.txt
   SID=abc123...; HSID=xyz789...; SSID=...; APISID=...; SAPISID=...; __Secure-1PSID=...
   ```

3. **CI/CD 使用**
   ```yaml
   - name: Set up auth
     env:
       NOTEBOOKLM_AUTH_JSON: ${{ secrets.COOKIES_JSON }}
     run: |
       # Inline JSON 無需寫入文件
       export NOTEBOOKLM_AUTH_JSON='{"cookies":[{"name":"SID","value":"..."},{"name":"HSID","value":"..."}]}'
       nlm notebook list
   ```

### 5.3 安全考慮

**重要安全注意事項：**

1. **不要分享 auth.json 文件**
   - 包含敏感的 session cookies
   - 不要提交到版本控制

2. **權限設置**
   ```python
   # 設置嚴格的權限
   profile_dir.chmod(0o700)  # 只有擁有者可訪問
   cookies_file.chmod(0o600)  # 只有擁有者可讀寫
   ```

3. **Cookies 有效期**
   - Cookies 通常穩定幾週
   - CSRF token 和 session ID 會自動刷新
   - 當看到認證錯誤時，運行 `nlm login`

4. **環境變量認證（CI/CD）**
   ```bash
   # 支持內聯 JSON，無需文件寫入
   export NOTEBOOKLM_AUTH_JSON='{"cookies":[{"name":"SID","value":"..."}]}'
   ```

---

## 六、常見問題與故障排除

### 6.1 認證相關

**問題：** "Chrome is running but without remote debugging enabled"

**解決方案：**
```bash
# 完全關閉 Chrome
# macOS: Cmd+Q
# Linux: killall chrome

# 然後重新運行
nlm login
```

**問題：** "401 Unauthorized" 或 "403 Forbidden"

**解決方案：**
```bash
# Cookies 過期了
nlm login
```

**問題：** "Authentication expired or invalid"

**解決方案：**
```bash
# 檢查 profile 狀態
nlm login --check

# 重新認證
nlm login --profile <profile-name>
```

### 6.2 Headless 模式相關

**問題：** Headless Chrome 無法啟動

**解決方案：**
```bash
# 檢查 Chromium 是否安裝
which chromium

# 如果沒有，安裝它
apt-get install chromium-browser
```

**問題：** Profile locked 錯誤

**解決方案：**
```bash
# 檢查 SingletonLock 文件
ls ~/.notebooklm-mcp-cli/chrome-profiles/<profile-name>/SingletonLock

# 如果 Chrome 沒運行，刪除鎖文件
rm ~/.notebooklm-mcp-cli/chrome-profiles/<profile-name>/SingletonLock
```

### 6.3 容器環境

**Docker 搭配：**
```dockerfile
FROM python:3.11

# Install Chromium
RUN apt-get update && \
    apt-get install -y chromium chromium-driver && \
    rm -rf /var/lib/apt/lists/*

# Install notebooklm-mcp-cli
RUN pip install --no-cache pipx && \
    pipx install notebooklm-mcp-cli

# Set up auth directory
ENV NOTEBOOKLM_HOME=/workspace/.notebooklm-mcp-cli
RUN mkdir -p $NOTEBOOKLM_HOME && \
    chmod 700 $NOTEBOOKLM_HOME

WORKDIR /workspace
```

**運行時參數：**
```bash
docker run --rm \
  -v $(pwd)/auth:/workspace/.notebooklm-mcp-cli \
  --cap-add=SYS_ADMIN \
  notebooklm-cli \
  nlm notebook list
```

---

## 七、最佳實踐總結

### 7.1 認證流程建議

1. **首次設置**
   ```bash
   nlm login --profile production
   # 在瀏覽器中登入
   ```

2. **日常使用**
   ```bash
   # 直接使用，自動處理認證
   nlm notebook list
   ```

3. **Token 過期**
   ```bash
   # v0.1.9+ 自動刷新
   # 如果完全過期：
   nlm login
   ```

### 7.2 CI/CD 最佳實踐

**推薦方案 1：Profile 快照**
```yaml
# 保存整個認證 profile
# 在本地：
tar -czf nlm-auth.tar.gz ~/.notebooklm-mcp-cli/profiles/production/

# 在 CI 中：
echo "$AUTH_TAR" | base64 -d | tar -xz -C ~/.notebooklm-mcp-cli/
```

**推薦方案 2：環境變量**
```bash
# 本地獲取 JSON
cat ~/.notebooklm-mcp-cli/profiles/default/auth.json | jq -c .

# 設置為 GitHub Secret
# 然後在 CI 中：
export NOTEBOOKLM_AUTH_JSON='{{ secrets.NOTEBOOKLM_AUTH_JSON }}'
```

### 7.3 多帳號管理

```bash
# 每個帳號獨立 profile
nlm login --profile work   # 工作 Gmail
nlm login --profile personal   # 個人 Gmail

# 使用指定 profile
nlm notebook list --profile work
```

---

## 八、結論

### 主要結論：

1. **✅ 無人值守自動登入可行**：NotebookLM CLI v0.1.9+ 支持完整的 headless Chrome 認證
2. **✅ 自動 token 刷新**：三層恢復機制 (CSRF → 磁碟 → headless) 無需人工干預
3. **✅ Profile 隔離**：支持多帳號，每個都有獨立的 Chrome session
4. **✅ CI/CD 友好**：支持環境變量認證，無需文件寫入
5. **❌ 不建議使用 agent-browser**：OpenCode agent-browser 不支持 CDP 整合和 cookie 持久化

### 最佳實踐：

| 場景 | 推薦方案 |
|------|---------|
| **CI/CD 自動化** | v0.1.9+ Headless Auth + Profile 快照 |
| **開發環境** | Auto Mode (交互式登入) |
| **調試** | Manual File Mode |
| **多帳號** | Profile 隔離系統 |

### 實施建議：

1. 升級到最新版 notebooklm-mcp-cli (v0.2.0+)
2. 首次使用運行 `nlm login` 設置 profile
3. 在 CI/CD 中複製 profile 或使用環境變量
4. 讓 CLI 自動處理 token 刷新

### 未來展望：

- 專案持續更新，增加新功能
- 考慮添加 OAuth 2.0 支持（如果 Google 提供）
- 改進錯誤處理和用戶反饋
- 擴展對其他瀏覽器的支持

---

## 九、參考資源

### 官方文檔
- [NotebookLM MCP CLI README](https://github.com/jacob-bd/notebooklm-mcp-cli)
- [認證指南](https://github.com/jacob-bd/notebooklm-mcp-cli/blob/main/docs/AUTHENTICATION.md)
- [API 參考](https://github.com/jacob-bd/notebooklm-mcp-cli/blob/main/docs/API_REFERENCE.md)

### 原始碼
- [CDP 工具](https://github.com/jacob-bd/notebooklm-mcp-cli/blob/main/src/notebooklm_tools/utils/cdp.py)
- [認證模組](https://github.com/jacob-bd/notebooklm-mcp-cli/blob/main/src/notebooklm_tools/core/auth.py)
- [Headless Auth 實現](https://github.com/jacob-bd/notebooklm-mcp-cli/blob/main/src/notebooklm_tools/utils/cdp.py#L540)

### 相關專案
- [notebooklm-py](https://github.com/teng-lin/notebooklm-py) - 另一個 Python 實現

### 安全指南
- Google 的服務條款禁止自動化登入
- 此工具僅用於個人/實驗用途
- 不要分享認證文件或 cookies

---

**研究完成日期：** 2026-02-04
**研究者：** OpenCode Assistant (Sisyphus)
**專案版本：** notebooklm-mcp-cli v0.2.0+
