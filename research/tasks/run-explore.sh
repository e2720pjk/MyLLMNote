#!/bin/bash
# OpenCode 探索任務執行腳本
# 由 cron 定期調用

TASK_DIR="$HOME/MyLLMNote/research/tasks"
GOAL_FILE="$TASK_DIR/Goal.md"
RULES_FILE="$TASK_DIR/執行規則.md"
TEMPLATE_FILE="$TASK_DIR/探索模板.md"
GOALS_DIR="$TASK_DIR/goals"

echo "[INFO] OpenCode 探索任務開始執行"
echo "[INFO] 時間: $(date '+%Y-%m-%d %H:%M:%S')"

# 檢查 Goal.md 狀態
if [ ! -f "$GOAL_FILE" ]; then
    echo "[ERROR] Goal.md 不存在: $GOAL_FILE"
    exit 1
fi

# 尋找 pending 的 goals
echo "[INFO] 分析 Goal.md..."
# 使用 grep 找出包含 "status: pending" 的行，並獲取對應的 goal_id
# 簡化版本：直接處理已知 goals

# 處理 Goal 1
if grep -q "status: pending" "$GOAL_FILE"; then
    echo "[INFO] 發現 pending 目標，開始處理..."

    # Goal 1: notebooklm
    GOAL_ID="goal-001-notebooklm"
    GOAL_NAME="研究 NotebookLM 自動登入"
    GOAL_DESC="研究如何自動化 NotebookLM 登入流程"
    GOAL_AGENT="Librarian（搜尋） + Oracle（分析）"
    GOAL_FOLDER="$GOALS_DIR/$GOAL_ID"
    CONTEXT_FILE="$GOAL_FOLDER/context.md"
    RESULTS_FILE="$GOAL_FOLDER/results.md"

    if [ -d "$GOAL_FOLDER" ]; then
        echo "[INFO] 處理目標: $GOAL_NAME"

        # 讀取 context
        GOAL_CONTEXT=$(cat "$CONTEXT_FILE" 2>/dev/null || echo "")

        # 準備提示詞
        PROMPT=$(cat "$TEMPLATE_FILE" | \
            sed "s|{{goal_name}}|$GOAL_NAME|g" | \
            sed "s|{{goal_description}}|$GOAL_DESC|g" | \
            sed "s|{{goal_id}}|$GOAL_ID|g" | \
            sed "s|{{goal_folder}}|$GOAL_FOLDER|g" | \
            sed "s|{{goal_agent}}|$GOAL_AGENT|g" | \
            sed "s|{{goal_context}}|$GOAL_CONTEXT|g")

        # 執行 OpenCode
        echo "[INFO] 執行 OpenCode 在 $GOAL_FOLDER"
        cd "$GOAL_FOLDER" || exit 1
        echo "## 執行時間: $(date '+%Y-%m-%d %H:%M:%S')" >> "$RESULTS_FILE"
        echo "" >> "$RESULTS_FILE"

        opencode run "$PROMPT" 2>&1 | tee -a "$RESULTS_FILE"

        echo "" >> "$RESULTS_FILE"
    fi
fi

echo "[INFO] OpenCode 探索任務完成"
