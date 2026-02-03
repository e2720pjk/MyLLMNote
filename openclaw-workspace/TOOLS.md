# TOOLS.md - 環境工具清單

## OpenCode 相關服務（容易混淆！）

### 1. OpenCode (LLM CLI 工具) ✅ 已安裝
- **版本**：1.1.48
- **路徑**：`/home/soulx7010201/.nvm/versions/node/v24.13.0/bin/opencode`
- **數據目錄**：`~/.local/share/opencode/`
- **功能**：
  - LLM 命令行介面 (TUI)
  - Agent 管理 (`opencode agent`)
  - MCP 伺服器管理 (`opencode mcp`)
  - ACP (Agent Client Protocol) 伺服器
  - Web 介面

### 2. OhMyOpenCode
- **類型**：裝在 OpenCode 上的多代理框架/配置
- **用途**：提供多代理編排能力
- **代理角色**：
  - **Sisyphus** - 代理主管（任務分配、Todo 管理）
  - **Oracle** - 諮詢顧問（nvidia/glm-4.7，架構審查、Bug 診斷）
  - **Explore/Librarian** - 情報員（Flash 模型，程式碼庫搜尋、文件檢索）
  - **Atlas** - 執行官（長期計劃實作）
- **工作模式**：
  - `search`/`find` - 深入搜索模式
  - `analyze`/`investigate` - 深度分析模式
  - `ultrawork`/`ulw` - 終極工作模式
  - `Tab` + Prometheus - 精確規劃模式

### 3. OpenCode Zen (服務平台)
- **類型**：模型服務提供商
- **用途**：提供 LLM 模型 API
- **關聯**：OpenClaw Gateway 的模型來源
- **當前使用模型**：`opencode/glm-4.7-free`

### 4. OpenClaw (我) 🦞
- **類型**：AI Gateway Agent
- **平台**：OpenClaw Gateway
- **通道**：Telegram
- **模型來源**：OpenCode Zen (opencode/glm-4.7-free)
- **角色**：工程協調者（委派給 OpenCode/OmMyOpenCode）

---

## 架構關係

```
┌─────────────────────────────────────────────────────────┐
│  OpenClaw Gateway (🦞 我)                                │
│  - Telegram Bot 通道                                      │
│  - 模型來源: OpenCode Zen (opencode/glm-4.7-free)        │
│  - 角色: 工程協調者                                        │
└─────────────────────────────────────────────────────────┘
                          │
                          │ 委派任務
                          ▼
┌─────────────────────────────────────────────────────────┐
│  OpenCode CLI v1.1.48 (已裝 OhMyOpenCode)                │
└─────────────────────────────────────────────────────────┘
                          │
                          ├──> Sisyphus (主管)
                          ├──> Oracle (諮詢)
                          ├──> Librarian (情報)
                          └──> Atlas (執行)
```

---

## 命令快速參考

### OpenCode CLI
```bash
opencode [project]      # 啟動 TUI
opencode run "message"  # 執行任務
opencode agent          # 管理代理
opencode mcp             # 管理 MCP 伺服器
opencode web            # 開啟 Web 介面
```

### OpenClaw (我的呼叫方式)
- 透過 Telegram 訊息
- 或 `openclaw message send --target ...`

---

## 我的工作原則

✅ 我會做的：
- 理解你的需求並選擇正確的工具
- 委派任務給 OpenCode CLI（使用 OhMyOpenCode 多代理）
- 整合 OhMyOpenCode 多代理團隊的輸出結果
- 管理專案進度和 Todo

❌ 我不會做的：
- 自行撰寫大量程式碼
- 直接修改核心專案檔案
- 取代 OhMyOpenCode 專家代理的工作
