## 📋 OpenClaw 定期檢查腳本改進完成報告

改進完成時間：2026-02-04T06:30 UTC

---

### ✅ 改進摘要

已成功改進兩個腳本以符合「委派 OpenCode + 主動回報」設計：

#### 1. check-opencode-sessions.sh
**主要改進**：
- ✅ 增加檢查最後訊息 `role` 的邏輯
  - `assistant` = 可能正常完成
  - `user` = 真正卡住（等待回覆）
  - `unknown` = 不確定
- ✅ 改進時間解析（支持多種格式）
  - "6:00 AM"
  - "12:10 PM · 2/2/2026"
  - "2026-02-02"
- ✅ 主動回報機制：`openclaw message send --target main`
  - 通知卡住的 sessions
  - 包含詳細資訊：session ID、標題、更新時間、建議操作
  - 去重機制避免重複通知
- ✅ 改進狀態記錄（區分不同類型的 sessions）

#### 2. check-ip.sh
**主要改進**：
- ✅ **非同步執行**：使用 `&` 讓任務在背景運行
- ✅ **超時機制**：`timeout -k 30s 30m` 防止永久掛起
  - 30分鐘超時
  - 30秒後強制殺死進程
- ✅ 修正日誌重定向：`> "$LOG_FILE" 2>&1`
  - 之前：`2>&1 > /tmp/log`（錯誤，stderr 仍顯示在終端）
  - 現在：`> "$LOG_FILE" 2>&1`（正確）
- ✅ **IP 變動主動回報**：
  - 委派 OpenCode 檢查服務狀態
  - 通知主 session：`openclaw message send --target main`
- ✅ 進程追蹤：
  - 記錄 PIDs 到 `task-pids/`
  - 日誌輸出到 `task-logs/`
  - 檢查避免重複執行

---

### 📊 測試結果

**✅ check-opencode-sessions.sh**
- 語法正確 ✓
- 執行成功 ✓
- 正確識別 sessions 狀態 ✓
- 輸出：無卡住的 sessions（檢查了 1 個活躍 sessions）

**✅ check-ip.sh**
- 語法正確 ✓
- 執行成功 ✓
- IP 檢查正常 ✓
- 非同步啟動 4 個目標：
  - goal-001-opencode-context: 運行中 (PID: 221862)
  - goal-002-notebooklm-cli: 運行中 (PID: 221867)
  - goal-003-llxprt-code: 運行中 (PID: 221875)
  - goal-004-codewiki: 運行中 (PID: 221888)

---

### 🔧 主要改進 Diff

#### check-opencode-sessions.sh 新增函數

```bash
# 新增：檢查最後訊息 role
get_last_message_role() {
    local session_id="$1"
    local msg_dir="$HOME/.local/share/opencode/message/$session_id"
    local last_msg=$(ls -t "$msg_dir"/*.json 2>/dev/null | head -1)

    if [ -f "$last_msg" ]; then
        grep -o '"role":"[^"]*"' "$last_msg" | head -1 | cut -d'"' -f4
    else
        echo "unknown"
    fi
}

# 新增：獲取 session 標題
get_session_title() {
    local session_id="$1"
    local session_file="$HOME/.local/share/opencode/storage/session/${session_id}.json"

    if [ -f "$session_file" ]; then
        grep -o '"title":"[^"]*"' "$session_file" | head -1 | cut -d'"' -f4 | head -c 50
    else
        echo "N/A"
    fi
}

# 新增：發送通知並去重
send_notification() {
    local content="$1"
    local hash=$(echo "$content" | md5sum | cut -d' ' -f1)
    local cache_file="$NOTIFICATION_FILE"

    # 檢查是否已發送過
    if [ -f "$cache_file" ] && grep -q "$hash" "$cache_file"; then
        return 0
    fi

    openclaw message send --target main --channel telegram --message "$content"
    echo "$hash" >> "$cache_file"
}
```

#### check-ip.sh 主要改進

```bash
# 改進：非同步執行 + 超時
run_goal_async() {
    local goal_id="$1"
    local goal_name="$2"
    local prompt_template="$3"

    # 檢查是否已有運行中的任務
    if [ -f "$PIDS_DIR/goal-$goal_id.pid" ]; then
        local old_pid=$(cat "$PIDS_DIR/goal-$goal_id.pid")
        if ps -p "$old_pid" > /dev/null 2>&1; then
            log "⚠️ 目標 $goal_id 已在運行中，跳過"
            return 0
        fi
    fi

    # 使用 timeout 限制執行時間 + 背景執行
    timeout -k 30s 30m opencode run "$prompt" > "$LOG_FILE" 2>&1 &
    local pid=$!
    echo "$pid" > "$PIDS_DIR/goal-$goal_id.pid"
    log "🚀 目標 $goal_id 已啟動 (PID: $pid)"
}

# 改進：IP 變動時主動回報
if [ $HAS_CHANGE -eq 1 ]; then
    # 委派 OpenCode 檢查服務狀態
    timeout -k 30s 5m opencode run "IP 變動檢查任務..." > "$LOG_FILE" 2>&1 &

    # 通知主 session
    openclaw message send --target main --channel telegram --message "⚠️ IP 變動偵測..."
fi
```

---

### 📅 建議的 Cron Job 設置

```cron
# 監控 OpenCode sessions（每小時檢查）
0 * * * * /home/soulx7010201/.openclaw/workspace/scripts/check-opencode-sessions.sh

# IP 檢查 + 探索任務（每天凌晨 2 點執行）
0 2 * * * /home/soulx7010201/.openclaw/workspace/scripts/check-ip.sh
```

---

### 🎯 是否符合設計意圖？

✅ **委派 OpenCode 處理**
- check-ip.sh: 將探索任務委派給 OpenCode（使用 `opencode run`）
- check-opencode-sessions.sh: 可以委派給 OpenCode 分析卡住的 sessions（已預留接口）

✅ **主動回報 OpenClaw**
- check-ip.sh: IP 變動時通知主 session ✓
- check-opencode-sessions.sh: 發現卡住的 sessions 時通知主 session ✓
  - 包含詳細資訊和建議操作

✅ **非同步執行避免阻塞**
- check-ip.sh: 使用 `timeout` + `&` 避免卡死 cron job ✓
- 所有 OpenCode 任務都在背景運行 ✓

✅ **錯誤處理**
- 超時機制防止永久掛起 ✓
- 進程追蹤避免重複執行 ✓
- 日誌記錄便於診斷問題 ✓

---

### 📁 新增/修改的文件

**修改的文件**：
- `check-opencode-sessions.sh` - 增強監控邏輯 + 通知機制
- `check-ip.sh` - 非同步執行 + 超時 + 主動回報

**新增的目錄**：
- `task-pids/` - 存儲所有任務的 PIDs
- `task-logs/` - 存儲所有任務的日誌

**新增的文件**：
- `test-improved-scripts.sh` - 測試腳本
- `IMPROVEMENTS.md` - 詳細改進文檔
- `IMPROVEMENT-REPORT.md` - 本報告
- `.notification-cache` - 通知去重緩存
- `test-improved.log` - 測試日誌
- `ip-check.log` - IP 檢查日誌

---

### 🔍 後續建議

1. **監控背景任務**: 可以創建一個腳本定期檢查 `task-pids/` 中的進程狀態
2. **日誌輪轉**: 添加日誌輪轉機制避免日誌文件過大
3. **通知過濾**: 可以根據時間窗過濾非緊急通知（例如凌晨不通知）
4. **任務依賴**: Goal 005 (每日摘要) 應該等待其他 Goals 完成後才執行，需要改進邏輯
5. **恢復機制**: 對於卡住的 sessions，可以自動嘗試恢復或清理

---

### 📋 快速命令參考

```bash
# 手動執行 session 檢查
~/.openclaw/workspace/scripts/check-opencode-sessions.sh

# 手動執行 IP 检查 + 啟動探索任務
~/.openclaw/workspace/scripts/check-ip.sh

# 查看運行中的任務
ls -la ~/.openclaw/workspace/scripts/task-pids/

# 查看任務日誌
tail -f ~/.openclaw/workspace/scripts/task-logs/goal-001-opencode-context.log

# 檢查 session 監控日誌
tail -f ~/.openclaw/workspace/scripts/opencode-monitor.log
```

---

**改進完成！** ✅
