#!/bin/bash
# OpenCode 對話監控腳本（改進版）
# 用途：檢查 OpenCode sessions 識別停住的會話並主動回報

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$SCRIPT_DIR/opencode-sessions-state.json"
LOG_FILE="$SCRIPT_DIR/opencode-monitor.log"

# 配置
MAX_INACTIVE_MINUTES=120  # 超過 2 小時沒活動視為停住
NOTIFICATION_FILE="$SCRIPT_DIR/.notification-cache"

log() {
    local level="$1"
    shift
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [$level] $*" >> "$LOG_FILE"
}

# 獲取 sessions
get_sessions() {
    opencode session list --max-count 50 2>/dev/null || echo ""
}

# 檢查 session 是否過期
is_session_stale() {
    local updated="$1"
    local now=$(date -u +%s)

    # 解析更新時間（處理混合格式）
    local session_time=""

    # 格式1: "6:00 AM"
    if [[ $updated =~ ^[0-9]{1,2}:[0-9]{2}\ (AM|PM)$ ]]; then
        local date_str="$(date -u +%Y-%m-%d)"
        session_time=$(date -d "$date_str $updated" +%s 2>/dev/null)
    # 格式2: "12:10 PM · 2/2/2026"
    elif [[ $updated =~ ^[0-9]{1,2}:[0-9]{2}\ (AM|PM)\ ·\ ([0-9]{1,2}/[0-9]{1,2}/[0-9]{4})$ ]]; then
        local time_part="${BASH_REMATCH[0]%% *}"
        local date_part="${BASH_REMATCH[2]}"
        # 轉換為 YYYY-MM-DD 格式
        local year=$(echo "$date_part" | cut -d'/' -f3)
        local month=$(echo "$date_part" | cut -d'/' -f1)
        local day=$(echo "$date_part" | cut -d'/' -f2)
        local date_str="$year-$month-$day"
        session_time=$(date -d "$date_str $time_part" +%s 2>/dev/null)
    # 格式3: "2026-02-02"
    elif [[ $updated =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        session_time=$(date -d "$updated" +%s 2>/dev/null)
    fi

    if [ -z "$session_time" ]; then
        return 1
    fi

    local diff=$((now - session_time))
    local diff_minutes=$((diff / 60))

    if [ $diff_minutes -gt $MAX_INACTIVE_MINUTES ]; then
        return 0  # 已停住
    else
        return 1  # 還在活躍中
    fi
}

# 獲取最後一條訊息的 role
get_last_message_role() {
    local session_id="$1"
    local msg_dir="$HOME/.local/share/opencode/message/$session_id"

    # 找到最新的消息文件
    local last_msg=$(ls -t "$msg_dir"/*.json 2>/dev/null | head -1)

    if [ -f "$last_msg" ]; then
        grep -o '"role":"[^"]*"' "$last_msg" | head -1 | cut -d'"' -f4
    else
        echo "unknown"
    fi
}

# 獲取 session 標題
get_session_title() {
    local session_id="$1"
    local session_file="$HOME/.local/share/opencode/storage/session/${session_id}.json"

    if [ -f "$session_file" ]; then
        grep -o '"title":"[^"]*"' "$session_file" | head -1 | cut -d'"' -f4 | head -c 50
    else
        echo "N/A"
    fi
}

# 發送通知（去重）
send_notification() {
    local content="$1"
    local hash=$(echo "$content" | md5sum | cut -d' ' -f1)
    local cache_file="$NOTIFICATION_FILE"

    # 檢查是否已發送過相同的通知
    if [ -f "$cache_file" ]; then
        if grep -q "$hash" "$cache_file"; then
            log "INFO" "通知已發送過，跳過: ${content:0:50}..."
            return 0
        fi
    fi

    # 發送通知
    log "INFO" "發送通知到 main session"
    openclaw message send --target main --channel telegram --message "$content" >> "$LOG_FILE" 2>&1

    # 記錄到緩存
    echo "$hash" >> "$cache_file"

    # 清理舊緩存（只保留最近100條）
    tail -100 "$cache_file" > "${cache_file}.tmp" && mv "${cache_file}.tmp" "$cache_file"
}

# 主邏輯
main() {
    log "INFO" "=== 開始檢查 OpenCode sessions ==="

    local sessions=$(get_sessions)

    if [ -z "$sessions" ]; then
        log "WARN" "無法獲取 sessions"
        exit 0
    fi

    local stale_sessions=()
    local completed_stale_sessions=()
    local stuck_sessions=()
    local active_sessions=()

    # 解析 sessions
    while IFS= read -r line; do
        if [[ $line =~ (^|)ses_[a-z0-9]+ ]]; then
            local session_id=$(echo "$line" | awk '{print $1}')
            local updated=$(echo "$line" | grep -oE '[0-9]{1,2}:[0-9]{2} (AM|PM)|[0-9]{4}-[0-9]{2}-[0-9]{2}|[0-9]{1,2}:[0-9]{2} (AM|PM) · [0-9]{1,2}/[0-9]{1,2}/[0-9]{4}')

            if is_session_stale "$updated"; then
                # 檢查最後消息 role
                local role=$(get_last_message_role "$session_id")
                local title=$(get_session_title "$session_id")

                if [ "$role" = "assistant" ]; then
                    completed_stale_sessions+=("$session_id|$updated|$title")
                elif [ "$role" = "user" ]; then
                    stuck_sessions+=("$session_id|$updated|$title")
                else
                    stale_sessions+=("$session_id|$updated|$title")
                fi
            else
                active_sessions+=("$session_id")
            fi
        fi
    done <<< "$sessions"

    log "INFO" "活躍 sessions: ${#active_sessions[@]}"
    log "INFO" "已完成的舊 sessions: ${#completed_stale_sessions[@]}"
    log "INFO" "真正卡住的 sessions: ${#stuck_sessions[@]}"
    log "INFO" "不明的舊 sessions: ${#stale_sessions[@]}"

    # 更新狀態文件
    cat > "$STATE_FILE" <<EOF
{
  "lastCheck": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "activeSessions": ${#active_sessions[@]},
  "completedStaleSessions": ${#completed_stale_sessions[@]},
  "stuckSessions": ${#stuck_sessions[@]},
  "unknownStaleSessions": ${#stale_sessions[@]},
  "maxInactiveMinutes": $MAX_INACTIVE_MINUTES
}
EOF

    # 處理卡住的 sessions
    if [ ${#stuck_sessions[@]} -gt 0 ]; then
        log "WARN" "發現 ${#stuck_sessions[@]} 個卡住的 sessions"

        local notify_content="⚠️ **OpenCode Session 監控警告**

發現 **${#stuck_sessions[@]} 個** 卡住的 sessions（最後是用戶訊息，無助手回覆）：
"

        for session_info in "${stuck_sessions[@]}"; do
            local session_id=$(echo "$session_info" | cut -d'|' -f1)
            local updated=$(echo "$session_info" | cut -d'|' -f2)
            local title=$(echo "$session_info" | cut -d'|' -f3)

            log "WARN" "🔴 卡住的 session: $session_id (更新: $updated, 標題: $title)"
            notify_content+="
• **$session_id**
  - 標題: ${title}
  - 最後更新: ${updated}
  - 狀態: 等待助手回覆中

建議操作:
1. 檢查: \`opencode run -s $session_id\`
2. 繼續或關閉卡住的任務
"
        done

        notify_content+="
---

查看日誌: \`~/.openclaw/workspace/scripts/opencode-monitor.log\`"

        # 發送通知
        send_notification "$notify_content"
    fi

    log "INFO" "=== 檢查完成 ==="

    # 輸出到 stdout（供 cron 日誌）
    if [ ${#stuck_sessions[@]} -gt 0 ]; then
        echo "⚠️ 發現 ${#stuck_sessions[@]} 個卡住的 OpenCode sessions"
        for session_info in "${stuck_sessions[@]}"; do
            local session_id=$(echo "$session_info" | cut -d'|' -f1)
            echo "  - $session_id"
        done
    else
        echo "✅ 無卡住的 sessions（檢查了 ${#active_sessions[@]} 個活躍 sessions）"
    fi
}

main
