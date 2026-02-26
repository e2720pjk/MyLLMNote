#!/bin/bash
# 子代理執行腳本 - OpenCode 配置審閱並回報

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 執行審閱腳本
bash ~/.openclaw/workspace/scripts/review-opencode-config.sh

# 讀取報告
REPORT_FILE="$SCRIPT_DIR/opencode-config-report.md"

if [ -f "$REPORT_FILE" ]; then
    # 發送報告摘要
    SUMMARY=$(head -50 "$REPORT_FILE")
    openclaw message send --target=main <<EOF
⚙️ OpenCode 配置審閱報告

$(echo "$SUMMARY")

---
完整報告：$REPORT_FILE
EOF
else
    openclaw message send --target=main "❌ 配置審閱失敗：無法生成報告"
fi
