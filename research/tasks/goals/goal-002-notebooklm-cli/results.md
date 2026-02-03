# NotebookLM CLI 最佳實踐研究結果

## 研究目標
探索如何在 OpenCode 環境中使用 NotebookLM CLI，分析是否為最佳實踐，特別關注自動登入方法。

## 現有環境
- 已安裝 Chromium 瀏覽器：`/usr/bin/chromium`
- 已安裝 notebooklm-cli skill：`~/.openclaw/workspace/skills/notebooklm-cli/`

---

## 核心發現

### 1. NotebookLM CLI 認證機制 (jacob-bd/notebooklm-mcp-cli)

#### 認證方式
NotebookLM CLI 使用**反向工程**的基於瀏覽器 Cookie 的認證系統，模擬瀏覽器使用者與 NotebookLM 內部 RPC 端點互動。

**主要指令：**
- `nlm login` - 啟動瀏覽器並導航至 NotebookLM，提取會話 Cookie
- `nlm login --check` - 驗證當前憑證
- `nlm auth status` - 檢查會話有效性
- `nlm auth list` - 列出所有設定檔
- `nlm login --profile <name>` - 登入特定設定檔

**會話持續時間：** 約 20 分鐘（內部 session_id 和 csrf_token 每隔 ~20 分鐘刷新）
**Cookie 生命周期：** 通常可維持數週至數月

#### 自動化無人值守登入可行性

**✅ 支援頭部模式 (Headless)** - 但需要**預先存在的認證 Chrome 設定檔**

**工作機制：**
1. 首次登入必須是互動式（解決 Google OAuth 和 2FA）
2. 會話保存在持久的 Chrome 設定檔中
3. 後續 Token 過期時，系統會自動嘗試頭部重新認證

**儲存位置：**
- 認證令牌 (JSON)：`~/.notebooklm-mcp-cli/auth.json` 或 `~/.notebooklm-mcp-cli/profiles/<name>/cookies.json`
- Chrome 設定檔：`~/.notebooklm-mcp-cli/chrome-profile/`

**三次恢復層級：**
1. **CSRF/Session 刷新**：在 `401 Unauthorized` 錯誤時自動刷新短期令牌
2. **Token 重新載入**：磁碟令牌若由其他並行會話更新則重新載入
3. **頭部認證**：如果磁碟令牌失效，嘗試背景 Chrome 會話以獲取新 Cookie

#### 自動化部署最佳實踐

**步驟：**
1. **本地設定**：在本地機器上以可見瀏覽器執行 `nlm login` 完成 Google 登入
2. **傳輸狀態**：將整個 `~/.notebooklm-mcp-cli/` 目錄複製到遠端/頭部伺服器
3. **驗證**：在伺服器上執行 `nlm login --check`。如果 Chrome 設定檔存在，CLI 對所有後續刷新使用頭部模式
4. **Browser 設定**：由於你有 `/usr/bin/chromium`，確保 CLI 指向它：
   ```bash
   nlm config set browser chromium
   ```

#### Cookie 手動導入方式

```bash
# 從其他瀏覽器手動導入 Cookie
nlm login --manual --file cookies.txt

# 或使用環境變數繞過磁碟儲存
export NOTEBOOKLM_COOKIES="..."
```

---

### 2. agent-browser (vercel-labs) 能力分析

#### MCP 工具與指令
在 OpenCode 環境中，`agent-browser` 主要作為 **Skill** 暴露，允許代理透過 CLI 執行自動化指令套件：

**核心指令：**
- **導航**：`open <url>`, `back`, `forward`, `reload`, `close`
- **分析**：`snapshot -i` (返回帶有 semantic refs like `@e1` 的互動式可訪問性樹)
- **互動**：`click <ref>`, `fill <ref> <text>`, `type <ref> <text>`, `check <ref>`, `select <ref> <value>`
- **等待機制**：`wait --url <pattern>`, `wait --load networkidle`, `wait --text <string>`
- **狀態管理**：`state save <path>`, `state load <path>`, `cookies`, `storage local`

#### 頭部瀏覽器控制
`agent-browser` **預設為頭部模式**，使用 Playwright Core 控制 Chromium：

```bash
export AGENT_BROWSER_EXECUTABLE_PATH="/usr/bin/chromium"
agent-browser open https://notebooklm.google.com
```

#### 表單填寫與 Cookie 提取

**優化設計：** 最小化上下文視窗使用：

```bash
# 表單填寫 - 使用 snapshot 的 semantic refs
agent-browser fill @e1 "your-email@gmail.com"
agent-browser click @e2  # Submit button

# Cookie 提取
agent-browser cookies --json
```

#### 會話持久化模型

**1. State Save/Load（推薦）：** 將 Cookie 和 `localStorage` 保存到 JSON 檔案：
```bash
agent-browser state save session_state.json
# 下次會話：
agent-browser state load session_state.json
```

**2. 具名 Sessions：** 使用 `--session` 標記維持隔離的瀏覽器上下文：
```bash
agent-browser --session notebook-auth open <url>
```

#### 自動化認證流程示例

```bash
# 1. 開啟登入頁面
agent-browser open https://notebooklm.google.com

# 2. 獲取互動元素
agent-browser snapshot -i

# 3. 執行登入 (假設 @e1 是 email，@e2 是 next)
agent-browser fill @e1 "user@example.com"
agent-browser click @e2
agent-browser wait --text "Enter your password"

# 4. 處理密碼並等待儀表板
agent-browser fill @p1 "password123"
agent-browser click @p2
agent-browser wait --url "**/notebook/*"

# 5. 保存狀態供未來 CLI 使用
agent-browser state save ~/.config/notebooklm/auth.json
```

#### OpenCode ACP 整合

**ACP (Agent Control Protocol)** 整合在 `agent-browser` 中實作為 **WebSocket Stream Server**：

- **功能**：將瀏覽器視口的 base64 幀流式傳輸到代理並接受輸入訊息 (`input_mouse`, `input_keyboard`)
- **用途**：允許 OpenCode 代理「即時看到」瀏覽器並對視覺變化做出反應（如 2FA 提示或 CAPTCHAs）
- **連接埠**：預設 `9223` (可透過 `AGENT_BROWSER_STREAM_PORT` 配置)

---

### 3. 頭部認證最佳實踐 (2026)

#### 標準方法：會話持久化

Google 的反爬蟲系統 (reCAPTCHA v3, Cloudflare Turnstile, 內部行為分析) 有效阻止 99% 的純頭部登入嘗試。現代標準已從嘗試以頭部方式解決登入挑戰轉移到**會話持久化**。

**方法 A：Session State Injection（推薦）**
1. 在 **headed** 瀏覽器中執行一次性手動登入
2. 導出會話狀態 (Cookies, LocalStorage, IndexedDB)
3. 將此狀態注入到頭部瀏覽器上下文供所有後續運行使用

**方法 B：Managed Browser Environments**
使用如 Browserless 或 BrowserStack 等平台，這些平台預設提供「stealth」，通常涉及預先配置的指紋和住宅代理旋轉。

#### Playwright vs Puppeteer

**Playwright** 因其優越的會話管理而成為 Google OAuth 的業界首選：

```typescript
// 保存狀態
await context.storageState({ path: 'auth_state.json' });
// 重用狀態
const context = await browser.newContext({ storageState: 'auth_state.json' });
```

Puppeteer 需要 `puppeteer-extra-plugin-stealth`，但在實際登入 POST 請求期間仍頻繁遇到「This browser or app may not be secure」阻擋。

#### 安全與速率限制考慮

- **IP 聲譽**：從資料中心 IP (AWS/GCP) 登入幾乎肯定會觸發安全挑戰。需要住宅或 ISP 代理
- **MFA 障礙**：頭部瀏覽器無法輕鬆解決 2FA (SMS/Authenticator)。重用會話令牌 (有效期 ~14-30 天) 是以程式方式繞過 MFA 的唯一可靠方法
- **加密**：在生產環境中，狀態檔案 (如 `auth_state.json`) 必須加密，因為它們包含完整的存取令牌

#### NotebookLM Enterprise API 替代方案 (2026 新增)

Google 現在提供正式的 **NotebookLM Enterprise API**，完全繞過瀏覽器自動化需求：

- `notebooks.create`：建立新研究筆記本
- `sources.add`：以程式方式上傳 PDF、YouTube URL 或網頁內容
- `sharing`：管理協作存取

**建議：** 如果您的用例適用於企業或高規模工具，請使用 **Enterprise API** 與服務帳戶。它高度合規，不會因 UI 變更而中斷。

#### 常見陷阱與反爬蟲檢測

| 陷阱 | 影響 | 緩解 |
|------|------|------|
| **"Browser not secure"** | 在輸入密碼前阻擋登入 | 使用 headed 登入一次 + `storageState` |
| **Navigator.webdriver** | 立即檢測為機器人 | 使用 `stealth` 插件或自定義 CDP 參數 |
| **指紋不匹配** | CAPTCHA 循環 | 將 User-Agent 與特定 Chromium 版本匹配 |
| **Headless Glitches** | 某些元素 (如 Google 的「Sign In」按鈕) 在頭部模式下渲染不同 | 在 Playwright 中使用 `headless: "new"` 匹配 headed 渲染 |

---

## 綜合評估與建議

### 是否為最佳實踐？

**對於個人/小規模使用：** ✅ **是**
- NotebookLM CLI 提供完整的程式化存取
- 會話持久化機制可用於無人值守操作
- 無需 API 金鑰或服務帳戶設定

**對於企業/大規模使用：** ⚠️ **建議使用 Enterprise API**
- 瀏覽器自動化方法有維護成本 (UI 變更、Anti-bot 更新)
- 需要 IP 聲譽管理
- Enterprise API 穩定性更高

### 推薦實施方案

#### 方案一：本地設定 + 頭部執行 (推薦用於 CI/CD)

```bash
# 1. 本地機器上首次設定 (互動式)
nlm login

# 2. 備份認證狀態
tar czf notebooklm-auth.tar.gz ~/.notebooklm-mcp-cli/

# 3. 部署到目標環境
scp notebooklm-auth.tar.gz target:/tmp/
ssh target "tar xzf /tmp/notebooklm-auth.tar.gz -C ~/"

# 4. 驗證並使用
ssh target "nlm login --check"
ssh target "nlm notebook list"
```

**優點：**
- 利用內建的頭部認證支援
- 最低複雜度
- 自動 Token 刷新

**缺點：**
- 首次需要手動登入
- 需要 Chrome 設定檔複製

#### 方案二：agent-browser 代理登入 (更靈活)

```bash
# 1. 使用 agent-browser 登入並保存狀態
agent-browser --session notebooklm open https://notebooklm.google.com
# [手動完成登入流程後]
agent-browser state save ~/.config/notebooklm/agent-state.json

# 2. 之後重用狀態
agent-browser state load ~/.config/notebooklm/agent-state.json
agent-browser open https://notebooklm.google.com
```

**優點：**
- 更靈活的瀏覽器控制
- 可視化排程 (如 2FA)
- 狀態檔案格式標準

**缺點：**
- 需要整合 agent-browser
- 需要自定義腳本提取 Cookie 供 nlm 使用

#### 方案三：環境變數 (簡單部署)

```bash
# 從瀏覽器開發者工具提取必要 Cookie
export NOTEBOOKLM_COOKIES='{"SID":"...","HSID":"...","SSID":"...","APISID":"...","SAPISID":"..."}'

# 在伺服器上使用
nlm notebook list
```

**優點：**
- 最簡部署
- 無需瀏覽器依賴

**缺點：**
- 手動提取複雜
- Cookie 過期需要手動更新

---

## 關鍵配置

```bash
# 設定 Chromium 路徑
nlm config set browser chromium

# 驗證登入狀態
nlm auth status

# 使用特定設定檔
nlm notebook list --profile work
```

---

## 總結

1. **自動無人值守登入可行** - 通過預先建立認證的 Chrome 設定檔實現
2. **內建三次恢復機制** - 確保長時間運作的穩定性
3. **無需 API 金鑰** - 使用反向工程方法適合個人/小規模用途
4. **agent-browser 提供靈活性** - 可用於更複雜的認證流程
5. **Enterprise API 是企業級替代方案** - 更穩定但需成本

**對於當前環境的推薦：**
使用 **方案一** (本地設定 + 頭部執行)，因為：
- 已有 `/usr/bin/chromium`
- notebooklm-cli 已安裝為 skill
- 內建的頭部認證支援最可靠
- 部署複雜度最低
