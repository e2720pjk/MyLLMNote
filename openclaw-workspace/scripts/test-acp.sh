#!/bin/bash
# ACP 模式測試腳本

echo "啟動 OpenCode ACP 伺服器..."

# 啟動 ACP（背景模式），但不保存 sessionId，直接使用重定向方式
# 使用 nohup 或 disown 避免卡住

# 方式 A: 使用 ACP 並寫入到暫存檔，讓我們之後讀取
# 或者直接用 opencode session 來管理

echo "列出當前 sessions"
opencode session list 2>/dev/null || echo "無法列出 sessions"

echo ""
echo "嘗試簡單測試：建立新 session"
mkdir -p /tmp/acp-test
cd /tmp/acp-test

echo "test acp" > test.txt

echo "嘗試使用 opencode 執行簡單命令（非 TUI 模式）"

# 檢查是否有 non-interactive 模式
echo "檢查 opencode 其他命令..."
