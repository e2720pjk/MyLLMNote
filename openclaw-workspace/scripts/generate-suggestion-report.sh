#!/bin/bash
# 優化建議週報生成腳本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEMORY_FILE="$HOME/.openclaw/workspace/memory/optimization-suggestions.md"
REPORT_FILE="$HOME/.openclaw/workspace/docs/weekly-suggestion-report.md"

generate_report() {
    # 提取當前日期
    local today=$(date -u +"%Y-%m-%d")

    cat > "$REPORT_FILE" <<EOF
# 優化建議週報
*週期: 週期報告*
*生成時間: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*

---

## 📊 本週摘要

\`\`\`
$(grep -A 100 "當前建議列表" "$MEMORY_FILE" | grep -B 2 "待審核 (Pending)" | head -20)
\`\`\`

---

## 🔵 待審核建議 $(grep -c "待審核" "$MEMORY_FILE") 個

\`\`\`
$(grep -A 10 "待審核 (Pending)" "$MEMORY_FILE" | grep -A 10 "^####")
\`\`\`

---

## 🟡 已接受建議 $(grep -c "已接受" "$MEMORY_FILE") 個

\`\`\`
$(grep -A 10 "已接受 (Accepted)" "$MEMORY_FILE" | grep -A 10 "^####" || echo "無")
\`\`\`

---

## 🜃 已拒絕建議 $(grep -c "已拒絕" "$MEMORY_FILE") 個

\`\`\`
$(grep -A 10 "已拒絕 (Rejected)" "$MEMORY_FILE" | grep -A 10 "^####" || echo "無")
\`\`\`

---

## 🎯 本週重點建議

### 高優先級建議

$(grep -A 6 "優先級.*🔴 高" "$MEMORY_FILE" | head -30)

---

## 💬 處理建議

如果想要處理這些建議，請告訴我：
- "採用 [建議編號]" - 採納建議並準備實施
- "拒絕 [建議編號]: [原因]" - 拒絕並說明原因
- "延後 [建議編號]" - 延後到下一週
- "詳細 [建議編號]" - 查看建議的詳細信息

---

**報告位置**: $REPORT_FILE
**建議庫**: $MEMORY_FILE

EOF
}

main() {
    generate_report
    echo "✅ 週報已生成: $REPORT_FILE"
}

main "$@"
