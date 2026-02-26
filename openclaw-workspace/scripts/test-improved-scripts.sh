#!/bin/bash
# 測試改進後的腳本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/test-improved.log"

log() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a "$LOG_FILE"
}

echo "======================================"
echo "測試改進後的腳本"
echo "======================================"
echo ""

# 測試 1: check-opencode-sessions.sh
log "🧪 測試 1: check-opencode-sessions.sh"
echo "---"
echo ""

if "$SCRIPT_DIR/check-opencode-sessions.sh"; then
    log "✅ check-opencode-sessions.sh 執行成功"
else
    log "❌ check-opencode-sessions.sh 執行失敗"
fi

echo ""
echo "---"
echo ""

# 測試 2: check-ip.sh（乾運行，只檢查 IP 部分）
log "🧪 測試 2: check-ip.sh"
echo "---"
echo ""

# 臨時修改 TASK_DIR 變量以跳過探索任務
export ORIGINAL_TASK_DIR="$HOME/MyLLMNote/research/tasks"
export EMPTY_TASK_DIR="/tmp/test-empty-tasks-$$"
mkdir -p "$EMPTY_TASK_DIR"

# 建立一個空的 Goal.md
echo "# Empty Goal" > "$EMPTY_TASK_DIR/Goal.md"

# 修改腳本使用臨時目錄
sed "s|TASK_DIR=\\\"\\$HOME/MyLLMNote/research/tasks\\\"|TASK_DIR=\\\"$EMPTY_TASK_DIR\\\"|g" "$SCRIPT_DIR/check-ip.sh" > "$SCRIPT_DIR/check-ip-test.sh"
chmod +x "$SCRIPT_DIR/check-ip-test.sh"

if "$SCRIPT_DIR/check-ip-test.sh"; then
    log "✅ check-ip.sh (IP 檢查部分) 執行成功"
else
    log "❌ check-ip.sh (IP 檢查部分) 執行失敗"
fi

# 清理
rm -rf "$EMPTY_TASK_DIR"
rm -f "$SCRIPT_DIR/check-ip-test.sh"

echo ""
echo "---"
echo ""

# 測試 3: 檢查是否創建了必要的目錄
log "🧪 測試 3: 檢查必要的目錄和文件"
echo "---"
echo ""

if [ -d "$SCRIPT_DIR/task-pids" ]; then
    log "✅ task-pids 目錄存在"
else
    log "⚠️  task-pids 目錄不存在（運行 check-ip.sh 後會創建）"
fi

if [ -d "$SCRIPT_DIR/task-logs" ]; then
    log "✅ task-logs 目錄存在"
else
    log "⚠️  task-logs 目錄不存在（運行 check-ip.sh 後會創建）"
fi

if [ -f "$SCRIPT_DIR/opencode-sessions-state.json" ]; then
    log "✅ opencode-sessions-state.json 存在"
else
    log "⚠️  opencode-sessions-state.json 不存在（運行 check-opencode-sessions.sh 後會創建）"
fi

echo ""
echo "---"
echo ""

# 測試 4: 檢查腳本語法
log "🧪 測試 4: 檢查腳本語法"
echo "---"
echo ""

if bash -n "$SCRIPT_DIR/check-opencode-sessions.sh"; then
    log "✅ check-opencode-sessions.sh 語法正確"
else
    log "❌ check-opencode-sessions.sh 語法錯誤"
fi

if bash -n "$SCRIPT_DIR/check-ip.sh"; then
    log "✅ check-ip.sh 語法正確"
else
    log "❌ check-ip.sh 語法錯誤"
fi

echo ""
echo "======================================"
echo "測試完成"
echo "======================================"
echo ""
echo "📋 詳細日誌: $LOG_FILE"
