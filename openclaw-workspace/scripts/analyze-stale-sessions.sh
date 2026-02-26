#!/bin/bash
# 停滯 sessions 快速分析腳本

SESSIONS=(
    "ses_3e18f159effeViSWVJnHbnDSB0"
    "ses_3e1c135c6ffeAl47J10FKc6QWC"
    "ses_3e1caaeccffebNVapHLX9gveEl"
    "ses_3e1e4a273ffeBVr8jylmbXJzhE"
    "ses_3e2c6c413ffeVFPwuLsIiQ0AYd"
    "ses_3e2c6538effecE9cXzQmFOz3Fp"
    "ses_3e2c76c2fffe97h5IEyatFgUU8"
    "ses_3e2c93505ffeNBP6OZbuskjrdA"
    "ses_3e2cafb5bffevT22fyXlZt5cC4"
    "ses_3e2d49ed5ffeKJoPN31Hr2AtrJ"
    "ses_3e2df3307ffeQoFBKTb1eu0QdP"
)

STORAGE_ROOT="$HOME/.local/share/opencode/storage"
echo "=== 停滯 Sessions 快速分析 ==="
echo ""

for session_id in "${SESSIONS[@]}"; do
    session_file=$(find "$STORAGE_ROOT/session" -name "${session_id}.json" 2>/dev/null | head -1)
    message_dir="${STORAGE_ROOT}/message/${session_id}"

    if [ ! -f "$session_file" ]; then
        echo "❌ $session_id - 找不到 session 文件"
        continue
    fi

    session_title=$(grep -o '"title":"[^"]*"' "$session_file" | cut -d'"' -f4)
    updated_ts=$(grep -o '"updated":[0-9]*' "$session_file" | cut -d':' -f2)
    updated_date=$(date -d "@$((updated_ts/1000))" -u "+%Y-%m-%d %H:%M:%S UTC")

    # 分析最後消息
    last_msg_role="unknown"
    last_msg_time="unknown"
    last_msg_file=$(ls -t "${message_dir}"/*.json 2>/dev/null | head -1)

    if [ -f "$last_msg_file" ]; then
        last_msg_role=$(grep -o '"role":"[^"]*"' "$last_msg_file" | head -1 | cut -d'"' -f4)
        last_msg_ts=$(grep -o '"created":[0-9]*' "$last_msg_file" | head -1 | cut -d':' -f2)
        last_msg_time=$(date -d "@$((last_msg_ts/1000))" -u "+%Y-%m-%d %H:%M:%S UTC")
    fi

    # 判斷狀態
    status="⚠️ 未知"
    if [ "$last_msg_role" = "assistant" ]; then
        status="✅ 可能正常結束（最後是助手回覆）"
    elif [ "$last_msg_role" = "user" ]; then
        status="🔴 等待助手回應（最後是用戶訊息）"
    fi

    echo "Session: $session_id"
    echo "  標題: $session_title"
    echo "  更新: $updated_date"
    echo "  最後消息: $last_msg_role @ $last_msg_time"
    echo "  狀態: $status"
    echo ""
done

echo "=== 分析完成 ==="
