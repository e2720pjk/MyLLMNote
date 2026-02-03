# HEARTBEAT.md - 定期檢查清單

## 執行邏輯

當收到 cron 觸發的訊息時：

### System Events（主 session）

1. 如果訊息包含 "定期任務：每小時檢查 OpenCode sessions 狀態"
   - 執行：`~/.openclaw/workspace/scripts/check-opencode-sessions.sh`
   - 檢查結果，如果有停住的 sessions > 個，則回報（不是 HEARTBEAT_OK）

2. 否則（普通 heartbeat）
   - 檢查 IP 是否變動
   - 執行 OpenCode 對話監控腳本
   - 回報 HEARTBEAT_OK（如果無異常）

### Agent Turns（Isolated Session）

收到 isolated session 的 agentTurn 任務時：
- 由子代理執行分析任務（OpenCode 配置、ClawHub 搜尋、安全檢查）
- 子代理透過 `openclaw message send --target=main` 回報結果給主 session
- 主 session 轉達給用戶

---

## 定期任務

### 任務 1: IP 監控 + OpenCode 探索

執行腳本包含兩項工作：
1. IP 變動檢查
2. OpenCode 探索任務執行

```bash
~/.openclaw/workspace/scripts/check-ip.sh
```

**IP 監控觸發回報時機：**
- 內部或外部 IP 變動時
- Google Cloud 執行個體重新啟動後

**探索任務：**
- 讀取 `~/MyLLMNote/research/tasks/Goal.md`
- 呼叫 OpenCode 執行待處理的探索目標
- 結果寫入對應的 goal 子資料夾

---

### 任務 2: OpenCode 對話監控

檢查 OpenCode sessions 狀態，如果停住或中斷則嘗試恢復。

```bash
~/.openclaw/workspace/scripts/check-opencode-sessions.sh
```

**檢查頻率：** 每小時一次（自動化已設定：cron id=ea6f14f2）

**檢查內容：**
- 列出所有 OpenCode sessions
- 識別超過 2 小時沒有活動的 session（視為停住）
- 記錄停住的 sessions 到日誌

**日誌位置：** `~/.openclaw/workspace/scripts/opencode-monitor.log`

**狀態文件：** `~/.openclaw/workspace/scripts/opencode-sessions-state.json`

---

### 任務 3: 定期系統檢查（委派給 OpenCode）

**檢查頻率：** 每 5 小時一次（自動化已設定：cron id=dacb4d6b）

**執行方式：**
- 觸發 isolated session 的 agentTurn
- 子代理委派給 OpenCode 執行分析任務
- 子代理透過 `openclaw message send --target=main` 回報結果

**檢查內容：**
1. 檢查 OpenCode 配置是否有優化建議
2. 搜尋 clawhub 上的新 skill（optimization, security, monitoring 相關）
3. 讀取已安裝的 moltbot 技能內容
4. 檢查系統安全狀態
5. 產生整合報告

**⚠️ 重要規則：**
- 只回報分析結果，**不要自動下載或安裝任何 skill**
- 建議的 skill 需要經過用戶審查後才能安裝
- 子代理必須主動回報給主 session

**回報流程：**
```
Cron → Isolated Session → OpenCode
                         ↓
                    `openclaw message send --target=main`
                         ↓
                 主 session（我）→ 轉達給用戶
```

---

## 重要規則

### 委派原則（Moltbot Best Practices）

**規則 1**: 主代理（我）負責協調和設置，不應親自執行複雜的分析任務。

**規則 2**: OpenCode 執行委派任務後，必須主動回報給主代理再轉達用戶。

**規則 3**: 技能搜尋和下載必須經過用戶審查，不應自動安裝。

**規則 4**: 任何外部操作（搜尋、下載、安裝）都需要用戶明確批准。

### 回報流程

```
用戶指示
   ↓
我（協調者）設置 Cron
   ↓
Isolated Session → OpenCode 執行分析
   ↓
OpenCode：`openclaw message send --target=main`
   ↓
我（轉達者）→ 用戶審查
   ↓
用戶批准 → 安裝操作
```

---

### 系統調整規則

**規則 1**: 對 OpenClaw Gateway 的任何調整必須經過人工審核。

**規則 2**: OpenCode 研究 Moltbot 的建議不應直接實現。記錄建議並定期告知，由用戶決定是否採用。

---

### 優化建議追蹤

- **記錄位置**: `memory/optimization-suggestions.md`
- **狀態追蹤**: 待審核 🔵 / 已接受 🟡 / 已拒絕 🜃 / 已延後 ⚪ / 已完成 ✅
- **定期報告**: 週報（每週日）/ 月報（每月 1 日）
