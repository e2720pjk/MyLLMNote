#!/bin/bash
# 單個目標測試腳本 - 測試 Goal 001

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASK_DIR="$HOME/MyLLMNote/research/tasks"
GOAL_DIR="$TASK_DIR/goals/goal-001-opencode-context"

echo "🔍 測試 Goal 001: OpenClaw 上下文版控"
echo ""

cd "$GOAL_DIR"

# 讀取 context
CONTEXT=$(cat context.md)

# 構建訊息
MESSAGE="# 探索任務：OpenClaw 上下文版控

## 目標
研究如何將 OpenClaw 的上下文和對話記錄適當歸檔到 MyLLMNote，透過 GitHub 進行定期版控

## 背景
$CONTEXT

## 你的角色
使用 OhMyOpenCode 的 Sisyphus (規劃) 和 Oracle (分析) 代理進行探索

## 執行步驟
1. 研究版本控制方案選項
2. 分析每個方案的優缺點
3. 提供推薦方案和實施步驟
4. 將結果寫入 results.md

請開始執行。"

echo "正在呼叫 OpenCode..."
echo ""

# 執行 OpenCode 並保存結果
echo "$MESSAGE" | python3 "$SCRIPT_DIR/opencode_wrapper.py" "$GOAL_DIR" > /tmp/goal-001-output.log 2>&1 &
PID=$!

echo "進程 PID: $PID"
echo "輸出檔案: /tmp/goal-001-output.log"
echo ""

# 等待一段時間（給予 OpenCode 時間執行）
echo "等待 30 秒..."
sleep 30

# 檢查進程狀態
if ps -p $PID > /dev/null 2>&1; then
    echo "⏳ OpenCode 仍在運行中..."
    echo "可以透過 'tail -f /tmp/goal-001-output.log' 查看輸出"
else
    echo "✅ OpenCode 已完成"
    RESULT=$(cat /tmp/goal-001-output.log)
    echo ""
    echo "結果:"
    echo "$RESULT"
fi
