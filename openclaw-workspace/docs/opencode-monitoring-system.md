# OpenCode 對話監控系統 (2026-02-02)

## 概述

建立 OpenCode 對話監控系統，每小時自動檢查 sessions 狀態。

## 組件

### 1. 監控腳本
**位置**: `~/.openclaw/workspace/scripts/check-opencode-sessions.sh`

**功能：**
- 列出所有 OpenCode sessions
- 檢查最後更新時間
- 識別停住的 sessions（超過 2 小時無活動）
- 記錄到日誌和狀態文件

**配置：**
- `MAX_INACTIVE_MINUTES=120` - 超過 2 小時視為停住

### 2. 日誌文件
**位置**: `~/.openclaw/workspace/scripts/opencode-monitor.log`

**格式：**
```
[2026-02-02T19:07:37Z] === 開始檢查 OpenCode sessions ===
[2026-02-02T19:07:38Z] 活躍 sessions: 0
[2026-02-02T19:07:38Z] 停住 sessions: 13
[2026-02-02T19:07:38Z] 🔴 發現停住的 session: ses_...
```

### 3. 狀態文件
**位置**: `~/.openclaw/workspace/scripts/opencode-sessions-state.json`

```json
{
  "lastCheck": "2026-02-02T19:07:38Z",
  "activeSessions": 0,
  "staleSessions": 13,
  "maxInactiveMinutes": 120
}
```

## 執行方式

### 手動執行
```bash
~/.openclaw/workspace/scripts/check-opencode-sessions.sh
```

### 自動執行

#### 選項 1: Cron (推薦)
```bash
# 每小時執行一次
0 * * * * ~/.openclaw/workspace/scripts/check-opencode-sessions.sh
```

#### 選項 2: OpenClaw Cron Jobs
使用 `cron` tool 設定：
```javascript
{
  "name": "OpenCode Sessions Monitor",
  "schedule": {
    "kind": "every",
    "everyMs": 3600000  // 1 小時
  },
  "payload": {
    "kind": "systemEvent",
    "text": "🔍 OpenCode 對話檢查：執行監控腳本"
  }
}
```

## 恢復機制

當發現停住的 sessions 時，可以：

### 方式 1: 繼續 session
```bash
opencode --continue
# 或指定 session
opencode --session ses_3e2e13852ffeqc8gPGneKQPuwq
```

### 方式 2: 子代理恢復
委派給子代理來分析和恢復停住的 sessions：

```
發送給 OpenCode 子代理：
"發現以下停住的 sessions：
- ses_3e2e13852ffeqc8gPGneKQPuwq (最後更新: 6:51 AM)
- ...

請分析這些 sessions，判斷是否需要繼續，並執行恢復。"
```

## 當前狀態 (2026-02-02 19:07 UTC)

- **活躍 sessions**: 0
- **停住 sessions**: 13
- **最後活動**: 6:51 AM (今早) - 2026-02-01 4:06 PM (昨天)

### 停住的 sessions

1. ses_3e2e13852ffeqc8gPGneKQPuwq - 算術測試 (6:51 AM)
2. ses_3e2e28955ffef7B9Cl7b53r22s - Basic math (6:50 AM)
3. ses_3e7a24feffed6fhocKlGZBw4F - (4:54 PM) ⬅️ 這個可能是重要的
4. ses_3eb2268a3ffe1zwatYUQg2xA15 - (4:24 PM) ⬅️ 這個可能是重要的
5. ... (更多)

## 下一步

1. 測試恢復機制
2. 設定 cron 或 OpenClaw cron jobs 自動執行
3. 設定通知機制（發現停住 session 時通知）
