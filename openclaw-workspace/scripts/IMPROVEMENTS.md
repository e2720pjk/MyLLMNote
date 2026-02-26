# 腳本改進摘要

**改進時間**: 2026-02-04T06:30 UTC
**改進原因**: 修復同步執行問題、增強監控邏輯、添加主動回報機制

---

## 📋 check-opencode-sessions.sh 改進

### 改進前問題
1. ❌ 只根據更新時間判斷，未檢查實際狀態
2. ❌ 無法區分「正常完成」與「真正卡住」
3. ❌ 無恢復動作和通知機制
4. ❌ 時間解析不穩定（混合格式）

### 改進後功能
1. ✅ 檢查最後訊息的 `role` 來判斷狀態
   - `assistant` = 可能正常完成
   - `user` = 真正卡住（等待回覆）
   - `unknown` = 不確定

2. ✅ 改進時間解析邏輯
   - 支持多種格式：
     - "6:00 AM"
     - "12:10 PM · 2/2/2026"
     - "2026-02-02"

3. ✅ 主動回報機制
   - 使用 `openclaw message send --target main` 通知主 session
   - 包含詳細資訊：session ID、標題、更新時間、建議操作
   - 去重機制避免重複通知

4. ✅ 改進狀態記錄
   - 區分不同類型的 sessions:
     - `activeSessions`: 活躍中
     - `completedStaleSessions`: 已完成的舊 sessions
     - `stuckSessions`: 真正卡住的 sessions
     - `unknownStaleSessions`: 不明的舊 sessions

### 主要改進代码
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

# 新增：發送通知並去重
send_notification() {
    local content="$1"
    local hash=$(echo "$content" | md5sum | cut -d' ' -f1)

    # 檢查是否已發送過
    if [ -f "$NOTIFICATION_FILE" ] && grep -q "$hash" "$NOTIFICATION_FILE"; then
        return 0
    fi

    openclaw message send --target main --channel telegram --message "$content"
    echo "$hash" >> "$NOTIFICATION_FILE"
}
```

---

## 📋 check-ip.sh 改進

### 改進前問題
1. 🔴 **致命問題**: 同步執行 `opencode run` 會卡住整個腳本
2. ❌ 無超時機制，代理陷入無限循環導致 cron job 永久掛起
3. ❌ 日誌重定向錯誤：`2>&1 > /tmp/...`（stderr 仍顯示在終端）
4. ❌ IP 變動後無任何行動，只是列印
5. ❌ 無錯誤處理和進程追蹤

### 改進後功能
1. ✅ **非同步執行**: 使用 `&` 讓任務在背景運行
2. ✅ **超時機制**: 使用 `timeout -k 30s 30m` 限制執行時間
   - 30分鐘超時，30秒後強制殺死
   - 防止代理卡住導致 cron job 掛起
3. ✅ **修正日誌重定向**: `> "$LOG_FILE" 2>&1`
4. ✅ **主動回報機制**:
   - IP 變動時委派 OpenCode 檢查服務狀態
   - 使用 `openclaw message send` 通知主 session
5. ✅ **進程追蹤**:
   - 記錄所有任務的 PIDs 到 `task-pids/` 目錄
   - 日誌輸出到 `task-logs/` 目錄
   - 檢查是否已有運行中的任務，避免重複執行
6. ✅ **改進函數設計**:
   - `run_goal_async()`: 非同步執行單個目標
   - 支持重複執行時跳過已運行的任務

### 主要改進代码
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
}

# 改進：IP 變動時主動回報
if [ $HAS_CHANGE -eq 1 ]; then
    # 委派 OpenCode 檢查服務狀態
    timeout -k 30s 5m opencode run "IP 變動偵測..." > "$LOG_FILE" 2>&1 &

    # 通知主 session
    openclaw message send --target main --channel telegram --message "IP 變動偵測..."
fi
```

### 修正的日誌重定向
```bash
# ❌ 錯誤（stderr 仍顯示在終端）
opencode run "..." 2>&1 > /tmp/log

# ✅ 正確（全部重定向到檔案）
opencode run "..." > /tmp/log 2>&1
```

---

## 📊 測試結果

### check-opencode-sessions.sh
- ✅ 語法正確
- ✅ 執行成功
- ✅ 正確識別 sessions 狀態
- ✅ 創建狀態文件

### check-ip.sh
- ✅ 語法正確
- ✅ 執行成功
- ✅ IP 檢查正常
- ✅ 非同步啟動所有目標
- ✅ 創建必要的目錄 (task-pids/, task-logs/)

---

## 📅 建議的 Cron Job 配置

```cron
# 監控 OpenCode sessions（每小時檢查）
0 * * * * /home/soulx7010201/.openclaw/workspace/scripts/check-opencode-sessions.sh

# IP 檢查 + 探索任務（每天凌晨 2 點執行）
0 2 * * * /home/soulx7010201/.openclaw/workspace/scripts/check-ip.sh
```

---

## 🎯 符合設計意圖嗎？

### ✅ 委派 OpenCode 處理
- check-ip.sh: 將探索任務委派給 OpenCode（使用 `opencode run`）
- check-opencode-sessions.sh: 可以委派給 OpenCode 分析卡住的 sessions（已预留接口）

### ✅ 主動回報 OpenClaw
- check-ip.sh: IP 變動時通知主 session
- check-opencode-sessions.sh: 發現卡住的 sessions 時通知主 session（包含詳細資訊和建議操作）

### ✅ 非同步執行避免阻塞
- check-ip.sh: 使用 `timeout` + `&` 避免卡死 cron job
- 所有 OpenCode 任務都在背景運行

### ✅ 錯誤處理
- 超時機制防止永久掛起
- 進程追蹤避免重複執行
- 日誌記錄便於診斷問題

---

## 📁 新增/修改的文件

### 修改的文件
- `check-opencode-sessions.sh` - 增強監控邏輯 + 通知機制
- `check-ip.sh` - 非同步執行 + 超時 + 主動回報

### 新增的目錄
- `task-pids/` - 存儲所有任務的 PIDs
- `task-logs/` - 存儲所有任務的日誌

### 新增的文件
- `test-improved-scripts.sh` - 測試腳本
- `IMPROVEMENTS.md` - 本改進摘要
- `.notification-cache` - 通知去重緩存
- `test-improved.log` - 測試日誌

---

## 🔍 後續建議

1. **監控背景任務**: 可以創建一個腳本定期檢查 `task-pids/` 中的進程狀態
2. **日誌輪轉**: 添加日誌輪轉機制避免日誌檔案過大
3. **通知過濾**: 可以根據時間窗過濾非緊急通知（例如凌晨不通知）
4. **任務依賴**: Goal 005 (每日摘要) 應該等待其他 Goals 完成後才執行，需要改進邏輯
5. **恢復機制**: 對於卡住的 sessions，可以自動嘗試恢復或清理
