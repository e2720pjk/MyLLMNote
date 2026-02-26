#!/bin/bash
# 測試腳本 - 手動觸發 Goal 001 探索任務

TASK_DIR="$HOME/MyLLMNote/research/tasks"

echo "🔍 測試 Goal 001: OpenClaw 上下文版控"
echo ""
echo "工作目錄: $TASK_DIR/goals/goal-001-opencode-context"
echo ""

cd "$TASK_DIR/goals/goal-001-opencode-context"
opencode run "
# 探索任務：OpenClaw 上下文版控

## 目標
研究如何將 OpenClaw 的上下文和對話記錄適當歸檔到 MyLLMNote，透過 GitHub 進行定期版控

## 背景
$(cat "$TASK_DIR/goals/goal-001-opencode-context/context.md")

## 你的角色
使用 OhMyOpenCode 的 Sisyphus (規劃) 和 Oracle (分析) 代理進行探索

## 執行步驟
1. 研究版本控制方案選項
2. 分析每個方案的優缺點
3. 提供推薦方案和實施步驟
4. 將結果寫入 results.md

## 重要：完成後
完成後請執行以下命令來通知：
\`\`\`bash
openclaw message send --target=main \"📋 Goal 001 完成：OpenClaw 上下文版控\"
\`\`\`
"
