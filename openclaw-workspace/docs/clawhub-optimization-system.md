# ClawHub 優化快報系統 - 完整設置

## 📋 概述

建立一個自動化的系統優化快報機制，每 5 小時檢查 clawhub.com 上的新技能，結合已安裝的 Moltbot 技能，提供具體的系統優化建議。

---

## ✅ 已完成的工作

### 1. 安裝 Moltbot 技能

| 技能 | 版本 | 用途 |
|------|------|------|
| moltbot-best-practices | v1.1.0 | AI 代理最佳實踐（15 條規則） |
| moltbot-security | v1.0.0 | 安全加固指南（防範攻擊） |
| moltcheck | v1.0.4 | 安全掃描器（檢查 GitHub 倉庫） |

安裝位置：`~/.openclaw/workspace/skills/`

---

### 2. 建立檢查腳本

**腳本 1**: `clawhub-optimization-check.sh`
- 搜尋 clawhub 上相關的技能
- 讀取已安裝的 Moltbot 技能
- 檢查系統安全狀態
- 生成報告到 `scripts/opencode-optimization-report.md`

**腳本 2**: `clawhub-optimization-opencode.sh`
- 委派完整任務給 OpenCode（深度分析版本）
- 使用推理能力提供更有價值的建議
- 生成報告到 `docs/clawhub-optimization-recommendations.md`

---

### 3. 設定 Cron Job

**Job ID**: `004f1b52`
**名稱**: ClawHub 優化建議快報
**頻率**: 每 5 小時
**下次執行**: 2026-02-03 08:32 UTC (約 2 小時後)

---

## 📊 執行方式

### 方式 1: 手動執行（腳本版本）

```bash
~/.openclaw/workspace/scripts/clawhub-optimization-check.sh
```

### 方式 2: 手動執行（OpenCode 深度分析）

```bash
~/.openclaw/workspace/scripts/clawhub-optimization-opencode.sh
```

### 方式 3: 自動執行

Cron 會每 5 小時自動執行腳本版本。

---

## 📁 文件結構

```
~/.openclaw/workspace/
├── skills/
│   ├── moltbot-best-practices/
│   │   └── SKILL.md         # AI 代理最佳實踐
│   ├── moltbot-security/
│   │   └── SKILL.md         # 安全加固指南
│   └── moltcheck/
│       └── SKILL.md         # 安全掃描器
├── scripts/
│   ├── clawhub-optimization-check.sh        # 腳本版本
│   ├── clawhub-optimization-opencode.sh     # OpenCode 版本
│   └── opencode-optimization-report.md     # 腳本報告
├── docs/
│   ├── opencode-clawhub-optimization-design.md  # 設計文檔
│   └── clawhub-optimization-recommendations.md  # OpenCode 分析報告（執行後生成）
└── HEARTBEAT.md  # 已更新，包含任務 4
```

---

## 📋 第一次執行結果 (2026-02-03 03:32 UTC)

### 發現的新技能

**Optimization 相關**：
- prompt-optimizer v1.0.0 (得分 0.416)
- token-saver v1.1.0 (得分 0.382)

**Monitoring 相關**：
- security-monitor v1.0.0 (得分 0.428)
- topic-monitor v1.1.0 (得分 0.408)

### 安全狀態

- Critical: 0
- Warning: 1 (Reverse proxy headers are not trusted)
- Info: 1

---

## 💡 Moltbot 核心建議

### 最佳實踐
1. 執行前確認任務
2. 發布前展示草稿
3. 用戶說 STOP 時立即停止
4. 2-3 次失敗後停止並詢問

### 安全加固
1. Gateway 綁定到 loopback ✅
2. 設置 auth token
3. 修復文件權限（600/700）
4. 更新 Node.js 到 v22.12.0+
5. 使用 Tailscale 進行遠程訪問

---

## 🎯 建議行動

### 🔴 高優先級（立即處理）

- [ ] 設置 auth token
- [ ] 修復文件權限

### 🟡 中優先級（本週處理）

- [ ] 安裝 security-monitor 技能
- [ ] 安裝 token-saver 技能
- [ ] 更新 Node.js

### 🟢 低優先級（有空處理）

- [ ] 探索其他 optimization 相關技能

---

## 🔧 使用方式

### 瀏覽 clawhub

```bash
# 搜尋技能
npx clawhub search optimization
npx clawhub search security
npx clawhub search monitoring

# 安裝技能
npx clawhub install skill-name

# 查看已安裝的技能
openclaw skills list
```

### 檢查安全

```bash
# 快速安全審計
openclaw security audit

# 深入審計並自動修復
openclaw security audit --deep --fix
```

---

## 📝 討論點

### 下一步改進

1. 讓 OpenCode 更智能地評估新技能的價值
2. 加入更多檢查項目（性能、成本）
3. 自動安裝高價值的技能（經過確認後）
4. 加入技能相關性分析（避免衝突）

### 潛在問題

1. clawhub search 可能會變化
2. OpenCode 版本需要 PTY 模式執行
3. 某些技能可能需要额外的依賴或配置

---

## 🔗 相關資源

- ClawHub: https://www.clawhub.com
- Moltbot GitHub: NextFrontierBuilds/moltbot-*
- OpenClaw 文檔: https://docs.openclaw.ai

---

## ✨ 特點

✅ **自動化** - 腳本會定期執行並生成報告
✅ **智能化** - 可選 OpenCode 深入分析
✅ **可擴展** - 輕鬆加入新的檢查項目
✅ **可追蹤** - 所有報告和日誌都有記錄
✅ **低干擾** - 作為快報/新聞通知，不影響主流程
