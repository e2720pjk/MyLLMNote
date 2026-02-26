#!/bin/bash
# 監控探索任務進度腳本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDS_DIR="$SCRIPT_DIR/task-pids"
LOGS_DIR="$SCRIPT_DIR/task-logs"

echo "======================================"
echo "OpenCode 探索任務進度監控"
echo "======================================"
echo ""

# 檢查是否有任務目錄
if [ ! -d "$PIDS_DIR" ]; then
    echo "⚠️  未找到任務目錄，請先執行 check-ip.sh"
    exit 1
fi

echo "📊 當前任務狀態"
echo "---"
echo ""

# 統計計數器
total=0
running=0
completed=0
failed=0

# 遍歷所有 PID 文件
for pid_file in "$PIDS_DIR"/*.pid; do
    if [ -f "$pid_file" ]; then
        goal=$(basename "$pid_file" .pid)
        pid=$(cat "$pid_file" 2>/dev/null)
        log_file="$LOGS_DIR/$goal.log"

        total=$((total + 1))

        echo "📋 $goal"

        if [ -z "$pid" ]; then
            echo "  狀態: ❌ PID 文件為空"
            failed=$((failed + 1))
        elif ps -p "$pid" > /dev/null 2>&1; then
            echo "  狀態: 🟢 運行中"
            echo "  PID: $pid"

            # 獲取運行時間
            elapsed=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
            if [ -n "$elapsed" ]; then
                minutes=$((elapsed / 60))
                echo "  執行時間: ${minutes} 分鐘"
            fi

            # 獲取 CPU 和內存使用
            cpu=$(ps -o %cpu= -p "$pid" 2>/dev/null | tr -d ' ')
            mem=$(ps -o %mem= -p "$pid" 2>/dev/null | tr -d ' ')
            echo "  CPU: ${cpu}% | Mem: ${mem}%"

            # 檢查日誌最後幾行
            if [ -f "$log_file" ]; then
                last_line=$(tail -1 "$log_file" 2>/dev/null)
                echo "  最後輸出: ${last_line:0:80}..."
            fi

            running=$((running + 1))
        else
            # 進程已結束，檢查日誌中最後幾行判斷狀態
            if [ -f "$log_file" ]; then
                last_lines=$(tail -10 "$log_file" 2>/dev/null)
                echo "  狀態: ⚪ 已結束"

                # 檢查是否有錯誤
                if echo "$last_lines" | grep -qi "error\|fail\|exception"; then
                    echo "  ⚠️  檢測到錯誤，請查看日誌"
                    failed=$((failed + 1))
                else
                    echo "  ✅ 可能正常完成"
                    completed=$((completed + 1))
                fi

                echo "  日誌: $log_file"
            else
                echo "  狀態: ⚠️  已結束（無日誌）"
                completed=$((completed + 1))
            fi
        fi

        echo ""
    fi
done

echo "---"
echo "📈 匯總"
echo "  總計: $total"
echo "  運行中: $running"
echo "  已完成: $completed"
echo "  失敗/有問題: $failed"
echo ""

# 如果有完成的任務，提示查看結果
if [ $completed -gt 0 ]; then
    echo "✅ 已完成的任務結果位置："
    for pid_file in "$PIDS_DIR"/*.pid; do
        if [ -f "$pid_file" ]; then
            goal=$(basename "$pid_file" .pid)
            pid=$(cat "$pid_file" 2>/dev/null)
            if [ -n "$pid" ] && ! ps -p "$pid" > /dev/null 2>&1; then
                # 對應的 results.md 位置
                goal_id="${goal#goal-}"
                results_file="$HOME/MyLLMNote/research/tasks/goals/$goal_id/results.md"
                if [ -f "$results_file" ]; then
                    echo "  • $goal_id: $results_file"
                fi
            fi
        fi
    done
fi

# 如果有運行中的任務，提供實時監控選項
if [ $running -gt 0 ]; then
    echo ""
    echo "💡 實時監控命令："
    echo "  查看特定任務日誌: tail -f $LOGS_DIR/goal-<ID>.log"
    echo "  重新運行此腳本: $0"
    echo ""
    echo "🔄 按 Ctrl+C 查看特定任務日誌，或輸入 q 退出"
    read -r choice

    if [ "$choice" = "q" ]; then
        exit 0
    fi

    # 選擇要查看的任務
    echo ""
    echo "選擇要查看的任務編號："
    select task_file in "$LOGS_DIR"/*.log; do
        if [ -f "$task_file" ]; then
            echo ""
            echo "📻 實時監控: $(basename "$task_file")"
            echo "按 Ctrl+C 退出"
            tail -f "$task_file"
        fi
        break
    done
fi
