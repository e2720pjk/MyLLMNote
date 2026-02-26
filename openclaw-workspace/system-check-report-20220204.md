# 定期系統檢查報告（2026-02-04）

檢查時間：2026-02-04 22:34 UTC
執行者：system-check-20260204 subagent

---

## 1. 配置分析 - OpenCode (~/.config/opencode/opencode.json)

✅ **整體狀態：良好**

配置檔案結構完整，已安裝：
- `oh-my-opencode@latest`（多代理框架）
- `opencode-antigravity-auth@latest`（身份認證）

已配置 Google 提供商，包含多個 Gemini 模型：
- Gemini 3 Pro (1M context)
- Gemini 3 Flash (多種 thinking levels)
- Gemini 2.5 Pro/Flash
- Claude Sonnet 4.5 系列
- Claude Opus 4.5 Thinking

⚠️ **優化建議：**
- 考慮為常用模型設定變體配置，以更好地控制 thinking levels
- 可以添加更多推理模型（如 GPT-4o）以備用

---

## 2. 已安裝 MoltBot 技能分析

### 📘 moltbot-best-practices (v1.1.0)
✅ **狀態：就緒**

核心原則摘要：
1. 執行前確認（避免重新做 20 分鐘）
2. 總是先展示草稿再發布
3. 僅在真正需要時生成代理
4. 用戶說 STOP 就立即停止
5. 失敗 2-3 次後詢問用戶
6. 逐一任務處理，不分心
7. 快速失敗，快速詢問
8. 失敗時減少敘述
9. 匹配用戶能量（焦慮用戶 = 簡潔回應）
10. 執行前先問清楚

推薦配置（已部分實施）：
- `memoryFlush enabled` ✅（已在 openclaw.json 中啟用）
- `memorySearch + sessionMemory` ✅（已在 openclaw.json 中啟用）

### 🔒 moltbot-security (v1.0.0)
✅ **狀態：就緒**

基於 1,673+ 個暴露閘道的實際漏洞研究。

✅ **已實施的安全措施：**
- Gateway bind: `loopback` ✅
- Auth mode: `token` ✅
- File permissions: `600/700` ✅
- Node.js v24.13.0（超過要求的 v22.12.0+）✅

⚠️ **建議改進：**
- 可以考慮啟用 Tailscale 以便安全遠端訪問
- 已配置 disable_bonjour（默認情況下已禁用）

### 🔍 moltcheck
✅ **狀態：就緒**

Moltbot 技能安全掃描器，可：
- 掃描 GitHub 倉庫的漏洞
- 信賴評分（0-100，A-F 評級）
- 權限審計
- 免費層：每天 3 次掃描

狀態：準備就緒（未配置 API key，使用免費層）

---

## 3. 系統安全狀態檢查

### OpenClaw Security Audit 結果：

#### 🔴 CRITICAL: 小型模型需要沙箱並禁用 web 工具

檢測到的小型模型（<=300B 參數）：
- `nvidia/qwen/qwq-32b` (32B) @ `agents.defaults.model.fallbacks` (unsafe; sandbox=off; web=[web_fetch, browser])
- `nvidia/meta/llama-3.3-70b-instruct` (70B) @ `agents.defaults.model.fallbacks` (unsafe; sandbox=off; web=[web_fetch, browser])
- `nvidia/qwen/qwen2.5-coder-7b-instruct` (7B) @ `agents.defaults.model.fallbacks` (unsafe; sandbox=off; web=[web_fetch, browser])

**問題：** 允許非受控輸入工具：web_fetch, browser
**風險：** 小型模型不建議用於非受信任輸入

**解決方案：**
- 選項 A：為所有 session 啟用沙箱（`agents.defaults.sandbox.mode="all"`）
- 選項 B：禁用 web 工具（`tools.deny=["group:web","browser"]`）
- 選項 C：從 fallbacks 中移除小型模型

#### ⚠️ WARN: 未設置受信任代理

`gateway.bind` 為 `loopback` 且 `gateway.trustedProxies` 為空。
如果通過反向代理暴露 Control UI，需配置受信任代理以防止本地客戶端檢查被欺騙。

**解決方案：**
- 將 `gateway.trustedProxies` 設置為您的代理 IP
- 或者保持 Control UI 僅限本地訪問

#### ℹ️ INFO: 攻擊面摘要

- 防火牆組：開啟=0，白名單=1
- 提權工具：已啟用
- Hooks：已禁用
- 瀏覽器控制：已啟用

### Doctor 檢查結果：

- ⚠️ **Legacy state detected：** `sessions.json` 需要規範化舊 key
- ⚠️ **Gateway 使用 Node 版本管理器：** 建議安裝系統 Node 22+ 以避免升級後失效
- ✅ **無通道安全警告**
- ✅ **Telegram：ok (@MyLLMNoteBot)**

---

## 4. ClawHub 新技能搜尋

### 🔍 Optimization 相關：

| 技能名稱 | 版本 | 描述 | 匹配度 |
|---------|------|------|--------|
| prompt-optimizer | v1.0.0 | Prompt 優化器 | 0.416 ⭐ |
| testosterone-optimization | v1.0.0 | 內分泌優化 | 0.382 |
| seo-optimizer | v0.1.0 | SEO 優化 | 0.379 |
| app-store-optimization | v0.1.0 | ASO 優化 | 0.362 |
| geo-optimization | v1.1.0 | GEO 優化 | 0.354 |
| marketing-mode | v1.0.0 | 行銷模式 | 0.353 |
| context-engineering | v1.0.0 | Agent 上下文工程 | 0.334 |
| prompt-engineering-expert | v1.0.0 | Prompt 工程專家 | 0.307 |
| macbook-optimizer | v1.0.1 | MacBook 優化器 | 0.307 |

### 🔒 Security 相關：

| 技能名稱 | 版本 | 描述 | 匹配度 |
|---------|------|------|--------|
| zero-trust | v1.0.0 | 零信任架構 | 0.372 |
| security-sentinel | v1.1.2 | 安全哨兵 | 0.359 ⭐ |
| pentest | v1.0.0 | 安全審查員 | 0.357 |
| clawgatesecure | v3.1.0 | Claw Gate Secure | 0.342 |
| security-auditor | v1.0.0 | 安全審計員 | 0.341 |
| openclaw-sec | v0.2.3 | OpenClaw 安全工具 | 0.340 |
| security-check | v1.0.1 | 安全檢查 | 0.331 |
| security-audit-toolkit | v1.0.0 | 安全審計工具包 | 0.331 |
| clawdbot-security-suite | v1.0.0 | Clawdbot 安全套件 | 0.326 |
| insecure-defaults | v1.0.0 | 不安全默認檢測 | 0.325 |

### 📊 Monitoring 相關：

| 技能名稱 | 版本 | 描述 | 匹配度 |
|---------|------|------|--------|
| security-monitor | v1.0.0 | 安全監控 | 0.428 ⭐ |
| mrc-monitor | v1.0.0 | MRC 監控 | 0.402 |
| task-status | v1.0.0 | 任務狀態追蹤 | 0.362 |
| uptime-kuma | v1.0.0 | Uptime Kuma 集成 | 0.344 |
| bmkg-monitor | v1.0.0 | BMKG 監控 | 0.342 |
| linkedin-monitor | v1.1.0 | LinkedIn 監控 | 0.329 |
| uptime-monitor | v1.0.0 | 24/7 監控 | 0.328 |
| price-tracker | v1.0.0 | 價格追蹤 | 0.327 |
| crypto | v1.0.1 | 加密貨幣市場 | 0.293 |
| security-system-zf | v1.0.0 | 技能安全系統 | 0.285 |

⭐ = 值得審查的推薦技能

---

## 5. 綜合建議

### 🔴 高優先級（建議立即處理）

1. **修復小型模型沙箱問題**

   當前配置中的小型模型（<100B 參數）在 fallbacks 中不受限地使用 web 工具，存在安全風險。

   **解決方案選項：**

   選項 A - 啟用全局沙箱：
   ```json
   {
     "agents": {
       "defaults": {
         "sandbox": {
           "mode": "all"
         }
       }
     }
   }
   ```

   選項 B - 從 fallbacks 中移除小型模型：
   - 從 `fallbacks` 中移除：`nvidia/qwen/qwq-32b`, `nvidia/meta/llama-3.3-70b-instruct`, `nvidia/qwen/qwen2.5-coder-7b-instruct`

   選項 C - 保留小型模型但禁用 web 工具：
   ```json
   {
     "tools": {
       "deny": ["group:web", "browser"]
     }
   }
   ```

   ⚠️ **注意：** 選項 C 會影響所有 session 的瀏覽器功能

### ⚠️ 中優先級（建議近期處理）

2. **考慮安裝安全監控工具**

   基於當前的安全配置狀態，以下工具值得審查：

   - **security-monitor v1.0.0** (匹配度 0.428)
     - 持續監控安全狀態
     - 主動檢測潛在威脅
     - 與現有安全配置相輔相成

   - **security-sentinel v1.1.2** (匹配度 0.359)
     - 安全哨兵功能
     - 可能提供額外的防護層

   建議安裝前使用 `moltcheck` 掃描這些技能的 GitHub 倉庫。

3. **優化 Agent 行為**

   已安裝 `moltbot-best-practices`，建議：
   - 確保所有新建 agent 遵循最佳實踐
   - 考慮安裝 `prompt-optimizer` (v1.0.0) 改善提示品質
   - 定期審查 agent 行為是否符合最佳實踐

### 💡 低優先級（改進建議）

4. **系統層級改進**

   - 安裝系統級 Node 22+ 以符合 OpenClaw 最佳實踐
   - 如果需要遠端訪問，啟用 Tailscale 配置
   - 考慮設置 `gateway.trustedProxies` 如果使用反向代理

5. **監控擴展**

   根據需求考慮：
   - **uptime-kuma** - 集成 Uptime Kuma 進行服務監控
   - **uptime-monitor** - 簡單的 24/7 監控解決方案

---

## 6. 技能狀態摘要

### ✅ 已安裝（16 個，可正常使用）：

生產力工具：
- 🐙 github - GitHub CLI 集成
- 📦 model-usage - 模型使用情況統計
- 📦 skill-creator - 技能創建工具
- 📦 summarize - URL/文件摘要工具
- 📦 tmux - tmux 會話遠端控制
- 🌤️ weather - 天氣預報

MoltBot 生態：
- 📦 moltbot-best-practices - Agent 最佳實踐指南
- 📦 moltbot-security - 安全強化指南
- 📦 moltcheck - 安全掃描工具

開發與集成：
- 📦 bluebubbles - BlueBubbles 通道插件
- 📦 clawhub - ClawHub CLI（技能管理）
- 🧩 coding-agent - 代碼代理（Codex/Claude/OpenCode）
- ♊️ gemini - Gemini CLI
- 📦 healthcheck - 健康檢查工具
- 📦 mcporter - MCP 服務器管理
- 📦 opencode-acp-control - OpenCode ACP 控制

### ⏸️ 缺失需求（38 個，無法在本環境使用）：

大多數需要：
- macOS 特定工具
- 外部 CLI 程式
- API keys 或特定配置

例如：
- macOS 工具：apple-notes, apple-reminders, bear-notes, imsg, things-mac
- 外部 CLI：1password, bird, blogwatcher, blucli, etc.
- 需要配置：notion, slack, trello, openai 服務

---

## 7. 系統環境摘要

### 硬體/軟體：
- Node.js：v24.13.0 ✅（超過要求的 v22.12.0+）
- 操作系統：Linux 6.1.0-42-cloud-arm64 (arm64)
- OpenClaw 版本：2026.2.2-3
- OpenCode 版本：1.1.48

###網絡配置：
- Gateway bind：loopback ✅
- Gateway auth：token ✅
- Tailscale：關閉
- 防火牆：0 開啟，1 白名單

### 配置安全：
- openclaw.json 權限：600 ✅
- credentials/ 目錄權限：700 ✅
- 所有敏感檔案：僅擁有者可讀寫 ✅

---

## 總結

整體而言，系統配置良好。主要安全措施（loopback bind + token auth + 文件權限）已正確實施，核心的 MoltBot 技能（最佳實踐、安全、檢查）均已安裝並就緒。

**關鍵行動項：**
1. 🔴 修復小型模型沙箱問題（CRITICAL）
2. ⚠️ 審查並考慮安裝 security-monitor 或 security-sentinel
3. ⚠️ 考慮安裝 prompt-optimizer 提升提示品質

**附註：**
- 建議的 skill 需經過用戶審查後才能安裝
- 已執行分析和檢查，未進行任何變更或安裝
- 完整報告已保存至：`~/.openclaw/workspace/system-check-report-20220204.md`
