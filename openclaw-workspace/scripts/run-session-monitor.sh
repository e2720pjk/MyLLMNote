#!/bin/bash
# 子代理執行腳本 - OpenCode Session 監控並回報

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$SCRIPT_DIR/opencode-sessions-state.json"
MAX_INACTIVE_MINUTES=120

# 執行檢查腳本
bash ~/.openclaw/workspace/scripts/check-opencode-sessions.sh

# 讀取結果
if [ -f "$STATE_FILE" ]; then
    ACTIVE=$(jq -r '.activeSessions' "$STATE_FILE")
    STALE=$(jq -r '.staleSessions' "$STATE_FILE")

    # 如果有停住的 sessions，發送通知
    if [ "$STALE" -gt 0 ]; then
        openclaw message send --target=main <<EOF
🔍 OpenCode Session 監控報告

| 狀態 | 數量 |
|------|------|
| 🟢 活躍 sessions | $ACTIVE |
| 🔴 停住的 sessions | $STALE |

⚠️ 發現 $STALE 個停住的 sessions（超過 $MAX_INACTIVE_MINUTES 分鐘無活動）

詳情請查看日誌：~/.openclaw/workspace/scripts/opencode-monitor.log
EOF
    fi
else
    openclaw message send --target=main "❌ Session 監控失敗：無法讀取狀態文件"
fi
