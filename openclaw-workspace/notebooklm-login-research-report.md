# NotebookLM CLI 自動登入最佳實踐研究報告

## 關鍵問題摘要

| 問題 | 答案 | 可行性 |
|------|------|--------|
| 能否無人值守自動登入？ | **部分可行** - 通過 Cookie 重用 | 中等 |
| 是否每次都需要登入？ | **否** - Cookies 有效期約 2-4 週 | 高 |
| OpenCode 可透過 ACP 控制瀏覽器？ | **可以** - Playwright MCP 可用 | 高 |
| agent-browser 是否有相關功能？ | **有限** - 主要用於交互式瀏覽 | 中等 |

---

## 一、NotebookLM CLI 認證機制分析

### 1.1 當前實現方式

根據 `notebooklm-mcp-cli` 官方文檔和源代碼分析，認證流程如下：

```
用戶運行 nlm login
    ↓
啟動 Chrome 瀏覽器（專用 profile）
    ↓
導航到 notebooklm.google.com
    ↓
用戶手動登入 Google 賬戶
    ↓
使用 Chrome DevTools Protocol 提取 session cookies
    ↓
保存 cookies 到本地存儲
    ↓
後續請求使用提取的 cookies
```

**關鍵技術細節：**

- **Cookie 提取：** 通過 Chrome DevTools Protocol 的 `Network.getCookies()` 方法
- **存儲位置：** `~/.notebooklm-mcp-cli/` 目錄（根據 profile 區分）
- **Session 生命週期：**
  - Cookies: ~2-4 週
  - CSRF Token: ~分鐘（自動刷新）
  - Session ID: 每次 MCP session

### 1.2 認證命令選項

```bash
# Auto 模式 - 啟動瀏覽器自動提取
nlm login

# Check 模式 - 檢查當前認證狀態
nlm login --check

# Profile 模式 - 多帳號管理
nlm login --profile work

# Manual 模式 - **關鍵：支持從文件導入 cookies**
nlm login --manual --file cookies.txt
```

---

## 二、無人值守自動登入方案評估

### 方案 1：Cookie 重用（推薦 - 最低成本）

**原理：**
一次性手動提取 cookies，保存到文件，所有自動化腳本直接使用該文件。

**實現步驟：**

```bash
# 1. 初始設置（一次性)
nlm login --manual --file /path/to/cookies.txt
# 這會啟動瀏覽器，手動登入後，cookies 會保存到指定文件

# 2. 自動化腳本使用（無人值守)
nlm login --manual --file /path/to/cookies.txt --check
# 或直接跳過 login，如果 MCP/CLI 已有內部機制載入 cookies
```

**優點：**
- ✅ 簡單易實現
- ✅ 無需瀏覽器自動化
- ✅ 無需處理 2FA/CAPTCHA
- ✅ 資源消耗低

**缺點：**
- ❌ Cookies 會過期（2-4 週），需手動更新
- ❌ 安全風險（cookies 文件需保護）
- ❌ 多帳號管理複雜

**自動化改進 - 定期更新：**

```bash
#!/bin/bash
# update-cookies.sh - 每週通過 cron 自動更新

COOKIE_EXP=$(date -d "$(date -d '+14 days')" +%s)
LAST_UPDATE=$(stat -c %Y /path/to/cookies.txt)

if [ $LAST_UPDATE -lt $((COOKIE_EXP - 7*24*3600)) ]; then
    echo "Cookies 即將過期，需要更新。請手動運行："
    echo "nlm login --manual --file /path/to/cookies.txt"
    # 或者發送通知到用戶
    notify-send "NotebookLM Cookies 需要更新"
fi
```

**安全措施：**
```bash
# 限制 cookies 文件權限
chmod 600 /path/to/cookies.txt
chown $USER:$USER /path/to/cookies.txt

# 加密存儲（可選）
gpg -c cookies.txt # 加密
gpg -d cookies.txt.gpg > /tmp/cookies.txt # 解密後使用
```

**推薦度：** ⭐⭐⭐⭐⭐（個人/小團隊使用）

---

### 方案 2：Playwright 瀏覽器自動化（中等成本）

**原理：**
使用 Playwright 自動化登入流程，提取並保存 cookies。

**實現示例（Python）：**

```python
import asyncio
from playwright.async_api import async_playwright

async def extract_cookies(email: str, password: str, totp_secret: str = None):
    async with async_playwright() as p:
        # 使用持久化的 browser context
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            viewport={'width': 1920, 'height': 1080},
            user_agent='Mozilla/5.0 ...'
        )

        page = await context.new_page()
        await page.goto('https://notebooklm.google.com')

        # 1. 填寫 Google 登入表單
        await page.fill('input[type="email"]', email)
        await page.click('identifierNext')

        # 2. 填寫密碼
        await page.fill('input[type="password"]', password)
        await page.click('passwordNext')

        # 3. 處理 2FA（如果啟用）
        if totp_secret:
            import pyotp
            totp = pyotp.TOTP(totp_secret)
            code = totp.now()
            await page.fill('input[type="text"]', code)
            await page.click('totpverify')

        # 4. 等待登入成功並導航到 NotebookLM
        await page.wait_for_url('**/notebooklm.google.com/**')

        # 5. 提取 cookies
        cookies = await context.cookies()

        # 6. 保存到文件
        with open('cookies.json', 'w') as f:
            import json
            json.dump(cookies, f)

        # 7. 保存 storageState（包含 cookies, localStorage, IndexedDB）
        await context.storage_state(path='auth-state.json')

        await browser.close()

        return cookies

# 使用
asyncio.run(extract_cookies(
    email='your-email@gmail.com',
    password='your-password',
    totp_secret='JBSWY3DPEHPK3PXP'  # 可選
))
```

**使用 OpenCode 的 Playwright MCP：**

根據 Playwright MCP 文檔，可以這樣使用：

```bash
# 啟動 dev-browser server
cd skills/dev-browser && npm run start &

# 使用 dev-browser 實現自動登入
cd skills/dev-browser && npx tsx <<'EOF'
import { connect } from "@/client.js";

const client = await connect();
const page = await client.page("notebooklm-auth");

await page.goto('https://notebooklm.google.com');
// ... 執行登入交互 ...

// 提取 cookies
const cookies = await page.context().cookies();
console.log(JSON.stringify(cookies));

await client.disconnect();
EOF
```

**優點：**
- ✅ 可以完全自動化
- ✅ 支持 2FA（如果使用 TOTP）
- ✅ 可集成到 CI/CD
- ✅ 可以定期自動刷新

**缺點：**
- ❌ 依賴瀏覽器自動化
- ❌ 需要處理 2FA/CAPTCHA
- ❌ Google 可能檢測並阻擋自動化
- ❌ 維護成本高（UI 變化需更新腳本）
- ❌ 安全風險（密碼/TOTP secret 需存儲）

**Google 反自動化措施：**

Google 強大的安全機制會自動檢測並阻擋非自然登入行為：

- 瀏覽器指紋識別技術能快速發現異常登入模式
- 未知的 User-Agent 會立即觸發安全警報
- 自動化腳本的行為特徵會被深入分析
- 可能需要額外驗證或直接拒絕訪問

**推薦度：** ⭐⭐⭐（需要定期自動刷新的場景）

---

### 方案 3：專用服務帳號（高成本 - 不推薦）

**原理：**
創建一個專用的 Google 帳號，關閉 2FA，使用簡單密碼，專門用於自動化。

**實現：**
1. 創建新 Google 帳號
2. 關閉所有安全功能（不推薦）
3. 使用方案 2 的 Playwright 自動化

**優點：**
- ✅ 可以完全自動化
- ✅ 無需 2FA

**缺點：**
- ❌ **極不安全** - 關閉 2FA 違反安全最佳實踐
- ❌ 違反 Google 服務條款
- ❌ 可能被 Google 封禁
- ❌ 無法訪問個人數據

**推薦度：** ❌（不推薦）

---

## 三、最佳實踐推薦

### 3.1 場景 1：個人開發/研究使用

**推薦方案：** Cookie 重用 + 手動更新

**實現步驟：**

```bash
# 1. 初始設置
nlm login --manual --file ~/.notebooklm-cookies/cookies.txt

# 2. 創建 wrapper 腳本
cat > /usr/local/bin/nlm-auto <<'EOF'
#!/bin/bash
COOKIE_FILE="$HOME/.notebooklm-cookies/cookies.txt"

# 檢查 cookies 是否過期
if [ -f "$COOKIE_FILE" ]; then
    LAST_MOD=$(stat -c %Y "$COOKIE_FILE")
    CURRENT=$(date +%s)
    AGE_DAYS=$(( ($CURRENT - $LAST_MOD) / 86400 ))

    if [ $AGE_DAYS -gt 20 ]; then
        echo "⚠️  Cookies 已於 $AGE_DAYS 天前提取，可能即將過期。"
        echo "   請手動運行: nlm login --manual --file $COOKIE_FILE"
    fi
else
    echo "❌ Cookies 文件不存在。請運行: nlm login --manual --file $COOKIE_FILE"
    exit 1
fi

# 使用 cookies 執行命令
nlm login --manual --file "$COOKIE_FILE" --check

# 執行原始命令
/usr/bin/env nlm "$@"
EOF

chmod +x /usr/local/bin/nlm-auto

# 3. 使用
nlm-auto notebook list
```

### 3.2 場景 2：CI/CD 自動化

**推薦方案：** GitHub Actions Secrets + Cookie 重用 + 手動更新

**實現步驟：**

```yaml
# .github/workflows/notebooklm.yml
name: NotebookLM Automation

on:
  schedule:
    - cron: '0 9 * * 1'  # 每週一 9am
  workflow_dispatch:

jobs:
  update-notebook:
    runs-on: ubuntu-latest
    steps:
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'

      - name: Install notebooklm-mcp-cli
        run: |
          pip install notebooklm-mcp-cli

      - name: Import cookies from secrets
        run: |
          echo "${{ secrets.NOTEBOOKLM_COOKIES }}" > cookies.json

      - name: Authenticate
        run: |
          nlm login --manual --file cookies.json --check

      - name: Run automation
        run: |
          # 你的自動化邏輯
          nlm notebook list

      - name: Cleanup
        run: |
          rm cookies.json
```

**如何在 GitHub Secrets 中存儲 cookies：**

```bash
# 在本地提取 cookies
nlm login --manual --file cookies.json

# 壓縮為 base64（避免格式問題）
cat cookies.json | base64 -w 0 > cookies.b64

# 復製 cookies.b64 的內容到 GitHub Secret: NOTEBOOKLM_COOKIES
```

### 3.3 場景 3：需要定期自動刷新（生產環境）

**推薦方案：** Playwright 自動化 + TOTP 2FA

**架構設計：**

```
+-------------------+     +-------------------+     +-------------------+
|   定時任務       | --> |  Playwright Bot   | --> |  Cookie File      |
| (cron/scheduler) |     |  (自動登入)       |     |  (存儲在安全位置) |
+-------------------+     +-------------------+     +-------------------+
           |                       |                       |
           v                       v                       v
    每週觸發                使用 TOTP 2FA          獲取新 cookies
```

**實現示例：**

```python
# cookie_refresh_bot.py
import asyncio
import pyotp
import json
from datetime import datetime
from playwright.async_api import async_playwright

CONFIG = {
    'email': 'bot@example.com',
    'password': 'bot-password',  # 使用環境變量或密鑰管理系統
    'totp_secret': 'JBSWY3DPEHPK3PXP',  # 從 Google 帳號獲取
    'cookie_file': '/secure/path/cookies.json',
    'headless': True
}

async def refresh_cookies():
    print(f"[{datetime.now()}] 開始刷新 cookies...")

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=CONFIG['headless'])
        context = await browser.new_context()
        page = await context.new_page()

        # 訪問 NotebookLM
        await page.goto('https://notebooklm.google.com')

        # ... 登入邏輯（同方案 2）...

        # 提取 cookies
        cookies = await context.cookies()

        # 保存 cookies
        with open(CONFIG['cookie_file'], 'w') as f:
            json.dump(cookies, f, indent=2)

        await browser.close()

    print(f"[{datetime.now()}] Cookies 已刷新並保存")

if __name__ == '__main__':
    asyncio.run(refresh_cookies())
```

**Systemd 服務配置：**

```ini
# /etc/systemd/system/cookie-refresh.service
[Unit]
Description=NotebookLM Cookie Refresh Bot
After=network.target

[Service]
Type=simple
User=notebooklm-bot
WorkingDirectory=/opt/notebooklm-bot
ExecStart=/usr/bin/python3 cookie_refresh_bot.py
Restart=always
RestartSec=3600

[Install]
WantedBy=multi-user.target
```

```ini
# /etc/systemd/system/cookie-refresh.timer
[Unit]
Description=Run cookie refresh weekly

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
```

**啟用服務：**

```bash
sudo systemctl enable cookie-refresh.timer
sudo systemctl start cookie-refresh.timer
```

---

## 四、安全建議

### 4.1 Cookie 文件保護

```bash
# 限制文件權限
chmod 600 ~/.notebooklm-cookies/cookies.json
chown $USER:$USER ~/.notebooklm-cookies/cookies.json

# 如果使用 GPG 加密
gpg --default-recipient-self --encrypt cookies.json
# 解密時使用
gpg --decrypt cookies.json.gpg > /tmp/cookies.json
```

### 4.2 密碼管理

```bash
# 使用環境變量
export GOOGLE_PASSWORD='your-password'

# 或使用密鑰管理系統
# HashiCorp Vault
vault kv get secret/notebooklm/bot

# AWS Secrets Manager
aws secretsmanager get-secret-value --secret-id notebooklm/bot
```

### 4.3 2FA 管理

```bash
# 使用 TOTP，避免 SMS 2FA
pip install pyotp
python -c "import pyotp; print(pyotp.TOTP('JBSWY3DPEHPK3PXP').now())"
```

---

## 五、故障排除

### 5.1 常見問題

**問題 1：Cookies 過期**

```bash
# 診斷
nlm login --check

# 解決
nlm login --manual --file cookies.txt
```

**問題 2：Chrome 未找到**

```bash
# 診斷
which google-chrome chromium

# 解決
# 指定 Chrome 路徑
export CHROME_BIN=/usr/bin/chromium
nlm login
```

**問題 3：認證失敗 - 401 Unauthorized**

```bash
# 可能原因：
# 1. 已被 Google 登出
# 2. IP 地址變化太大
# 3. 帳號安全設置變更

# 解決：重新登入
nlm login
```

### 5.2 調試技巧

```bash
# 啟用詳細日誌
export NOTEBOOKLM_DEBUG=1
nlm login

# 檢查 cookies 內容
cat ~/.notebooklm-cookies/cookies.json | jq .

# 測試 cookies 是否有效
curl -b cookies.json https://notebooklm.google.com
```

---

## 六、總結與推薦

### 推薦方案排序

| 排名 | 方案 | 適用場景 | 成本 | 可靠性 | 安全性 |
|------|------|----------|------|--------|--------|
| 1 | Cookie 重用 + 手動更新 | 個人/小團隊 | 低 | 高 | 中 |
| 2 | Cookie 重用 + CI/CD Secrets | 自動化流程 | 中 | 高 | 中 |
| 3 | Playwright 自動化 + TOTP | 生產環境 | 高 | 中 | 低 |

### 立即行動步驟

**對於快速開始/測試：**

```bash
# 1. 安裝 notebooklm-mcp-cli
uv tool install notebooklm-mcp-cli

# 2. 首次登入
nlm login

# 3. 開始使用
nlm notebook list
```

**對於生產環境：**

```bash
# 1. 使用 Manual 模式提取 cookies
nlm login --manual --file /secure/path/cookies.json

# 2. 加密 cookies 文件
gpg --encrypt cookies.json

# 3. 創建 wrapper 腳本
cat > nlm-auto <<'EOF'
#!/bin/bash
gpg --decrypt /secure/path/cookies.json.gpg > /tmp/cookies.json
nlm login --manual --file /tmp/cookies.json --check
nlm "$@"
rm /tmp/cookies.json
EOF

chmod +x nlm-auto
```

### 注意事項

1. **Cookies 有效期：** 約 2-4 週，定期更新
2. **Google 政策：** 使用內部 API，可能隨時變化
3. **Rate Limiting：** 免費帳號約 50 queries/day
4. **多帳號：** 使用 `--profile` 參數區分
5. **安全：** 始終保護 cookies 和密碼文件

---

## 七、參考資源

- **NotebookLM MCP CLI:** https://github.com/jacob-bd/notebooklm-mcp-cli
- **Playwright Authentication:** https://playwright.dev/docs/auth
- **Chrome DevTools Protocol:** https://chromedevtools.github.io/devtools-protocol/
- **TOTP Library:** https://github.com/pyauth/pyotp
- **OpenCode Skills:** 前端 UI/UX, Git Master, Playwright, Dev-Browser

---

## 八、聯繫與支持

- **GitHub Issues:** https://github.com/jacob-bd/notebooklm-mcp-cli/issues
- **Discord:** (項目 Discord 服務器)
- **OpenCode 社區:** 相關技能和工具支持

---

*文檔生成日期：2026-02-05*
*版本：1.0*
*作者：OpenCode AI Agent (Sisyphus)*
