# NotebookLM CLI 自動登入研究結果

## 執行摘要

**研究結論**：NotebookLM CLI 的自動登入是**部分可行的**，但需要采用混合策略：

1. **初始設定需要用戶介入** - 首次登入必須由人員完成
2. **後續操作可完全自動** - 使用持久化會話狀態
3. **無法實現完全無人值守的首次登入** - Google 的安全檢測會阻擋純 headless 操作

## 1. 登入流程分析

### 1.1 當前 `nlm login` 實現方式

根據 `notebooklm-cli` (jacob-bd) 技術文檔：

```
nlm login → 啟動 Chrome → 打開 NotebookLM → 用戶手動登入 → 提取 Cookie
```

**技術細節**：
- 使用 **Chrome DevTools Protocol (CDP)** 控制瀏覽器
- 需要安裝 Google Chrome（Chromium 可能不兼容）
- 提取會話 Cookie 並存儲到本地數據庫
- 會話有效期約 **20 分鐘**（無活動後過期）

### 1.2 為何需要瀏覽器登入？

Google 的 NotebookLM 服務沒有提供官方 API 密鑰，必須通過：
- OAuth2 認證流程
- 綁定 Google 帳戶
- 使用瀏覽器 Cookie 進行後續請求

這與其他 Google 服務（如 Gmail API 使用 OAuth 密鑰）不同。

---

## 2. 自動化方案評估

### 2.1 方案 A：純 Headless 自動登入 ❌ **不可行**

**原因**：Google 的安全措施
- 檢測到 headless 瀏覽器會顯示「此瀏覽器或應用程式可能不安全」
- 阻止自動登入流程
- 即使用 Stealth 模式（`--disable-blink-features=AutomationControlled`）也可能被檢測

**證據**：
- `notebooklm-mcp` 項目文檔明確提到「純 headless 自動化經常觸發 Google 的安全封鎖」
- 多個 GitHub issue 報告類似問題

### 2.2 方案 B：持久化會話（推薦）✅ **可行**

**原理**：
1. 首次登入時用戶手動完成（headful 模式）
2. 保存瀏覽器上下文（Cookie、localStorage、IndexedDB）
3. 後續操作使用保存的狀態，無需再次登入

**實現技術**：

#### 方法 1：使用 dev-browser MCP

```typescript
// 持久上下文配置
const context = await chromium.launchPersistentContext(
  './profiles/browser-data',  // Cookie 存儲目錄
  {
    headless: false,  // 首次登入需要可見
    args: [`--remote-debugging-port=${cdpPort}`]
  }
);

// 等待用戶登入完成
await page.goto("https://notebooklm.google.com/");
await page.waitForURL("**notebooklm.google.com/**", { timeout: 600000 });

// 會話已自動保存到 browser-data 目錄
```

**優點**：
- 內置持久化支持
- 支持後續 headless 操作
- 與 OpenCode 完美集成

#### 方法 2：使用 notebooklm-mcp 的 HTTP API 模式

```bash
# 首次設置認證
npm run setup-auth  # 打開 Chrome，手動登入
npm run start:http  # 啟動 HTTP 服務器（使用保存的會話）

# 後續使用 API（無需瀏覽器）
curl -X POST http://localhost:3000/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "Explain X", "notebook_id": "my-notebook"}'
```

**優點**：
- 完全無瀏覽器介入（後續操作）
- 支持遠程 API 調用
- 支持多帳戶配置檔

### 2.3 方案 C：擴展模式連接現有瀏覽器 ✅ **可行**

**原理**：
- 使用 `dev-browser` 的擴展模式
- 連接到用戶已登入的 Chrome/Chromium
- 直接使用現有會話，無需重新登入

```bash
# 啟動擴展模式服務器
cd skills/dev-browser
npm run start-extension &

# 安裝並激活 dev-browser 擴展程序
# 在 Chrome 中打開並登入 NotebookLM
# 現在 agent 可以使用現有會話
```

**優點**：
- 完全無需重新登入
- 用戶可以保留瀏覽器中的其他會話

**缺點**：
- 需要用戶保持瀏覽器開啟
- 需要手動安裝擴展程序

---

## 3. Cookie 持久化技術細節

### 3.1 關鍵 Cookie 列表

根據 `notebooklm-mcp` 的實現，以下 Cookie 需要持久化：

| Cookie 名稱 | 用途 | 有效期 |
|------------|------|--------|
| `SID`, `HSID`, `SSID` | Google 核心會話 | 通常 2 週 |
| `APISID`, `SAPISID` | API 認證 | 通常 2 週 |
| `__Secure-OSID` | NotebookLM 特定會話 | ~20 分鐘（無活動） |

### 3.2 Cookie 儲存位置

- **notebooklm-cli**: 本地數據庫（SQLite 或 JSON）
- **dev-browser**: `profiles/browser-data/` 目錄（Playwright 格式）
- **notebooklm-mcp**: `data/browser_state/` 目錄

---

## 4. 推薦實施方案

### 方案 1：使用 dev-browser（最簡單集成）

**適用場景**：OpenCode 環境中使用

```bash
# 步驟 1：首次設置（一次性）
cd skills/dev-browser
./server.sh --headless=false &
# 運行腳本打開 NotebookLM，手動登入

# 步驟 2：後續自動操作
cd skills/dev-browser
./server.sh --headless=true &
# 運行腳本，使用持久化會話
```

**優點**：
- 與 OpenCode 技能系統集成
- 無需額外依賴
- 支持持久化

### 方案 2：使用 notebooklm-mcp HTTP API（最靈活）

**適用場景**：需要遠程調用或多 agent 協作

```bash
# 安裝
git clone https://github.com/roomi-fields/notebooklm-mcp.git
cd notebooklm-mcp
npm install && npm run build

# 首次認證
npm run setup-auth  # 手動登入

# 啟動服務器
npm run start:http  # 端口 3000

# 使用 API（完全自動化）
curl -X POST http://localhost:3000/ask \
  -H "Content-Type: application/json" \
  -d '{
    "question": "What are the key concepts?",
    "notebook_id": "abc123"
  }'
```

**優點**：
- 後續操作完全無瀏覽器
- 支持多種集成方式（n8n、Zapier、自定義腳本）
- 持久化會話

### 方案 3：使用原始 notebooklm-cli（最穩定）

**適用場景**：純命令行環境

```bash
# 首次登入
nlm login

# 後續使用（會話過期前有效）
nlm notebook list
nlm audio create abc123 --confirm

# 會話過期後重新登入
nlm login  # 再次需要瀏覽器
```

**缺點**：
- 每次過期後都需要手動重新登入
- 無法持久化跨重啟會話

---

## 5. 最佳實踐建議

### 5.1 自動化工作流程

```
1. 初始化階段（僅一次）
   ├─ 用戶手動登入 NotebookLM
   ├─ 保存瀏覽器上下文/ Cookie
   └─ 驗證持久化可用

2. 自動化階段（無人值守）
   ├─ 檢查會話有效性
   ├─ 使用持久化上下文調用 API
   └─ 如果會話過期，提醒用戶更新

3. 會話更新階段（定期或按需）
   ├─ 用戶重新登入
   └─ 刷新持久化上下文
```

### 5.2 會話過期處理

**檢測方法**：
```javascript
// 嘗試訪問 NotebookLM API
const response = await fetch('https://notebooklm.google.com/api/...');
if (response.status === 401) {
  // 會話過期，通知用戶重新登入
  throw new Error('Session expired - please re-login');
}
```

**自動刷新策略**：
- 定期（如每 15 分鐘）發送 keep-alive 請求
- 在每次 API 調用前驗證會話有效性

### 5.3 安全建議

⚠️ **重要安全提示**：

1. **使用專用 Google 帳戶**
   - 自動化工具可能被 Google 檢測
   - 主帳戶存在封禁風險

2. **保護敏感數據**
   - Cookie 和會話文件應加入 `.gitignore`
   - 使用加密存儲（如需要）

3. **遵守 Google 服務條款**
   - 自動化可能違反 Google 的使用政策
   - 使用前確認服務條款

---

## 6. 性能對比

| 方案 | 首次設定時間 | 後續操作時間 | 完全無人值守 | 複雜度 |
|------|-------------|-------------|-------------|--------|
| notebooklm-cli | 2-5 分鐘 | 秒級 | ❌ | 低 |
| dev-browser | 2-5 分鐘 | 秒級 | ✅（首次後） | 中 |
| notebooklm-mcp HTTP | 2-5 分鐘 | 毫秒級 | ✅（首次後） | 中 |
| 擴展模式 | 無需設定 | 秒級 | ✅（需瀏覽器開啟） | 高 |

---

## 7. 結論

### 主要發現

1. ✅ **可以部分自動化**：使用持久化會話，首次登入後可無人操作
2. ❌ **無法完全自動首次登入**：Google 安全措施阻擋純 headless 自動登入
3. ✅ **dev-browser 可用於此場景**：支持持久化上下文和擴展模式
4. ✅ **存在現成解決方案**：`notebooklm-mcp` 提供了完整的自動化框架

### 推薦方案

**對於 OpenCode 使用者**：
1. 優先使用 **dev-browser** 技能的持久化模式
2. 首次設定時用戶手動登入（2-5 分鐘）
3. 後續操作使用保存的上下文進行自動化

**對於需要深度自動化的場景**：
1. 使用 **notebooklm-mcp HTTP API** 模式
2. 支持遠程調用和完全無瀏覽器操作
3. 支持 n8n、Zapier 等工作流程工具集成

### 限制

- 會話有效期約 20 分鐘（無活動）
- Google 可能檢測到自動化並限制使用
- 需要定期刷新會話

---

## 8. 參考資料

### 官方文檔
- [notebooklm-cli DeepWiki](https://deepwiki.com/jacob-bd/notebooklm-cli)
- [dev-browser GitHub](https://github.com/SawyerHood/dev-browser)

### 開源項目
- [notebooklm-mcp](https://github.com/roomi-fields/notebooklm-mcp) - 持久化認證實現
- [notebooklm-skill](https://github.com/PleasePrompto/notebooklm-skill) - Claude Code 技能
- [notebooklm-cli](https://github.com/jacob-bd/notebooklm-cli) - 原始 CLI 工具

### 技術參考
- Playwright `launchPersistentContext` 文檔
- Chrome DevTools Protocol Cookie 管理
- Google OAuth2 流程文檔

---

**研究完成日期**：2026-02-04
**研究者**：Sisyphus AI Agent
**版本**：1.0
