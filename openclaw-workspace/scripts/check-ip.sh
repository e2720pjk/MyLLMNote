#!/bin/bash
# 定期任務腳本 - IP 檢查 + 非同步探索任務執行（改進版）

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$SCRIPT_DIR/../network-state.json"
TASK_DIR="$HOME/MyLLMNote/research/tasks"
LOG_FILE="$SCRIPT_DIR/ip-check.log"
PIDS_DIR="$SCRIPT_DIR/task-pids"
LOGS_DIR="$SCRIPT_DIR/task-logs"

# 建立必要的目錄
mkdir -p "$PIDS_DIR" "$LOGS_DIR"

log() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a "$LOG_FILE"
}

# --- 步驟 1: 檢查 IP 變動 ---

log "=== 開始 IP 檢查 ==="

# 獲取當前 IP
CURRENT_INTERNAL=$(hostname -I | awk '{print $1}')
CURRENT_EXTERNAL=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 ipinfo.io/ip 2>/dev/null || echo "unknown")

# 讀取狀態
if [ -f "$STATE_FILE" ]; then
    OLD_INTERNAL=$(jq -r '.internalIP' "$STATE_FILE" 2>/dev/null || echo "")
    OLD_EXTERNAL=$(jq -r '.externalIP' "$STATE_FILE" 2>/dev/null || echo "")
else
    OLD_INTERNAL=""
    OLD_EXTERNAL=""
fi

# 檢查變動
HAS_CHANGE=0
CHANGE_MSG=""
if [ "$CURRENT_INTERNAL" != "$OLD_INTERNAL" ] && [ -n "$OLD_INTERNAL" ]; then
    CHANGE_MSG="內部 IP: $OLD_INTERNAL → $CURRENT_INTERNAL"
    HAS_CHANGE=1
fi
if [ "$CURRENT_EXTERNAL" != "$OLD_EXTERNAL" ] && [ -n "$OLD_EXTERNAL" ]; then
    if [ -n "$CHANGE_MSG" ]; then
        CHANGE_MSG="$CHANGE_MSG, "
    fi
    CHANGE_MSG="${CHANGE_MSG}外部 IP: $OLD_EXTERNAL → $CURRENT_EXTERNAL"
    HAS_CHANGE=1
fi

# 更新狀態
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > "$STATE_FILE" <<EOF
{
  "lastCheck": "$NOW",
  "internalIP": "$CURRENT_INTERNAL",
  "externalIP": "$CURRENT_EXTERNAL",
  "hasChange": $HAS_CHANGE
}
EOF

# 輸出 IP 結果
if [ $HAS_CHANGE -eq 1 ]; then
    log "⚠️ IP 變動偵測：$CHANGE_MSG"
else
    log "✅ IP 無變動：內部=$CURRENT_INTERNAL，外部=$CURRENT_EXTERNAL"
fi

# 如果 IP 變動，委派 OpenCode 檢查服務狀態
if [ $HAS_CHANGE -eq 1 ]; then
    log "📧 IP 變動，委派 OpenCode 檢查服務狀態..."

    # 使用 timeout 防止卡死，背景執行
    timeout -k 30s 5m opencode run "📋 任務：IP 變動偵測

IP 變動偵測：
$CHANGE_MSG

當前狀態：
- 內部 IP: $CURRENT_INTERNAL
- 外部 IP: $CURRENT_EXTERNAL

請檢查：
1. OpenClaw Gateway 是否正常運作
2. OpenCode ACP server 是否正常
3. 相關服務是否需要重新配置

回報檢查結果。" > "$LOGS_DIR/ip-change-check.log" 2>&1 &

    local ip_check_pid=$!
    echo "$ip_check_pid" > "$PIDS_DIR/ip-change-check.pid"
    log "✅ IP 檢查任務已啟動 (PID: $ip_check_pid)"

    # 通知主 session
    openclaw message send --target main --channel telegram --message "⚠️ **IP 變動偵測**

偵測到 IP 變動：$CHANGE_MSG

已委派 OpenCode 檢查服務狀態。" >> "$LOG_FILE" 2>&1
fi

log "---"

# --- 步驟 2: 非同步執行探索任務 ---

run_goal_async() {
    local goal_id="$1"
    local goal_name="$2"
    local prompt_template="$3"

    local context_file="$TASK_DIR/goals/$goal_id/context.md"

    if [ ! -f "$context_file" ]; then
        log "⚠️ 目標 $goal_id 的 context.md 不存在，跳過"
        return 1
    fi

    local context=$(cat "$context_file")
    local full_prompt="# 探索任務：$goal_name

## 背景
$context

$prompt_template

請開始執行。"

    local log_file="$LOGS_DIR/goal-$goal_id.log"
    local pid_file="$PIDS_DIR/goal-$goal_id.pid"

    # 檢查是否已有運行中的任務
    if [ -f "$pid_file" ]; then
        local old_pid=$(cat "$pid_file")
        if ps -p "$old_pid" > /dev/null 2>&1; then
            log "⚠️ 目標 $goal_id 已在運行中 (PID: $old_pid)，跳過"
            return 0
        else
            log "ℹ️  目標 $goal_id 的 PID $old_pid 已失效，重新啟動"
        fi
    fi

    # 使用 timeout 限制執行時間（超時會殺死進程）
    # 30分鐘超時，30秒後強制殺死
    timeout -k 30s 30m opencode run "$full_prompt" > "$log_file" 2>&1 &
    local pid=$!

    echo "$pid" > "$pid_file"
    log "🚀 目標 $goal_id 已啟動 (PID: $pid)"

    return 0
}

if [ -d "$TASK_DIR" ] && [ -f "$TASK_DIR/Goal.md" ]; then
    log "🔍 開始非同步執行探索任務..."
    log ""

    # Goal 001: OpenClaw 上下文版控
    run_goal_async "goal-001-opencode-context" \
        "OpenClaw 上下文版控" \
        "## 你的角色
使用 OhMyOpenCode 的 Sisyphus (規劃) 和 Oracle (分析) 代理進行探索

## 執行步驟
1. 研究版本控制方案選項
2. 分析每個方案的優缺點
3. 提供推薦方案和實施步驟
4. 將結果寫入 results.md"

    # Goal 002: NotebookLM CLI 研究
    run_goal_async "goal-002-notebooklm-cli" \
        "NotebookLM CLI 最佳實踐" \
        "## 你的角色
使用 OhMyOpenCode 的 Librarian (搜尋) 和 Oracle (分析) 代理進行探索

## 執行步驟
1. 搜尋 NotebookLM CLI 自動登入方法
2. 分析 agent-browser 可行性
3. 評估最佳實踐
4. 將結果寫入 results.md"

    # Goal 003: llxprt-code 審查
    run_goal_async "goal-003-llxprt-code" \
        "llxprt-code 專案審查" \
        "## 你的角色
使用 OhMyOpenCode 的 Librarian (搜尋) 和 Sisyphus (規劃) 代理

## 執行步驟
1. 瀏覽 ~/MyLLMNote/llxprt-code/ 目錄
2. 識別未完成的任務
3. 整理專案現況
4. 將結果寫入 results.md"

    # Goal 004: CodeWiki 審查
    run_goal_async "goal-004-codewiki" \
        "CodeWiki 專案審查" \
        "## 你的角色
使用 OhMyOpenCode 的 Librarian (搜尋) 和 Sisyphus (規劃) 代理

## 執行步驟
1. 瀏覽 ~/MyLLMNote/CodeWiki/ 目錄
2. 識別未完成的任務
3. 整理專案現況
4. 將結果寫入 results.md"

    log ""
    log "---"
    log "✅ 所有目標已啟動（非同步執行）"
    log ""
    log "📊 任務狀態："
    # 記錄當前啟動的任務實際狀態
    for pid_file in "$PIDS_DIR"/*.pid; do
        if [ -f "$pid_file" ]; then
            goal=$(basename "$pid_file" .pid)
            pid=$(cat "$pid_file")
            if ps -p "$pid" > /dev/null 2>&1; then
                log "  • $goal: 運行中 (PID: $pid)"
            else
                log "  • $goal: 已完成或失敗 (PID: $pid)"
            fi
        fi
    done
else
    log "⚠️ 探索任務目錄不存在，略過"
fi

log ""
log "=== 檢查完成 ==="

# 輸出摘要到 stdout
echo "✅ IP 檢查完成：內部=$CURRENT_INTERNAL，外部=$CURRENT_EXTERNAL"
if [ $HAS_CHANGE -eq 1 ]; then
    echo "⚠️  IP 變動：$CHANGE_MSG（已委派 OpenCode 檢查）"
fi
