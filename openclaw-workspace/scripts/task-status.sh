#!/bin/bash
# 任務狀態快速檢查（非交互版）

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDS_DIR="$SCRIPT_DIR/task-pids"
LOGS_DIR="$SCRIPT_DIR/task-logs"

echo "=== OpenCode 探索任務狀態 ===" && echo ""

if [ ! -d "$PIDS_DIR" ]; then
    echo "⚠️  未找到任務目錄"
    exit 1
fi

total=0
running=0
completed=0

for pid_file in "$PIDS_DIR"/*.pid; do
    if [ -f "$pid_file" ]; then
        goal=$(basename "$pid_file" .pid)
        pid=$(cat "$pid_file" 2>/dev/null)
        log_file="$LOGS_DIR/$goal.log"
        total=$((total + 1))

        if [ -n "$pid" ] && ps -p "$pid" >/dev/null 2>&1; then
            elapsed=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
            minutes=$((elapsed / 60))
            echo "🟢 $goal | PID:$pid | ⏱️ ${minutes}m"
            running=$((running + 1))
        else
            echo "⚪ $goal | 已完成"
            completed=$((completed + 1))
        fi
    fi
done

echo "" && echo "📊 總計:$total  運行:$running  完成:$completed" && echo ""
echo "💡 詳細日誌: $LOGS_DIR/"
echo "💡 結果文件: ~/MyLLMNote/research/tasks/goals/*/results.md"
