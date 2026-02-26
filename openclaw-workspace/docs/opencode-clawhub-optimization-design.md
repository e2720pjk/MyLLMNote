# OpenCode ClawHub 優化分析

## 任務說明

每 5 小時讓 OpenCode 深入分析 clawhub.com 上的最新技能，並結合已安裝的 moltbot 技能，提供具體的系統優化建議。

---

## 執行方式

### 手動委派給 OpenCode

使用 `opencode run` 委派任務：

```bash
cd ~/.openclaw/workspace

opencode run "作為 OpenClaw 系統優化顧問，請執行以下任務：

## 任務 1: 檢查已安裝的 Moltbot 技能

讀取以下檔案並摘要最關鍵的建議：
- ~/.openclaw/workspace/skills/moltbot-best-practices/SKILL.md
- ~/.openclaw/workspace/skills/moltbot-security/SKILL.md
- ~/.openclaw/workspace/skills/moltcheck/SKILL.md

## 任務 2: 瀏覽 ClawHub

使用瀏覽器訪問 https://www.clawhub.com/skills
- 尋找與「系統優化」、「自動化」、「監控」相關的新技能
- 識別我們還沒安裝但可能有用的技能

## 任務 3: 分析當前配置

讀取 ~/.openclaw/openclaw.json，檢查：
- Gateway 是否綁定到 loopback？
- 是否設置了 auth token？
- 文件權限是否安全？

## 任務 4: 生成報告

創建 ~/.openclaw/workspace/docs/clawhub-optimization-recommendations.md，包含：

1. 📊 發現的新技能（評分和用途）
2. 📋 Moltbot 技能的核心建議
3. 🔒 安全狀態評估
4. 💡 具體優化建議（用可執行的清單格式）
5. 🎯 優先級排序（高/中/低最優要）

## 回報

完成後，使用以下指令通知：
openclaw message send --target=main \"📊 ClawHub 優化報告已完成，見 ~/.openclaw/workspace/docs/clawhub-optimization-recommendations.md\""
```

---

## 腳本執行版本

如果沒有瀏覽器訪問權限，使用腳本版本：

```bash
~/.openclaw/workspace/scripts/clawhub-optimization-check.sh
```

腳本會：
- 讀取已安裝的 moltbot 技能
- 使用 `npx clawhub search` 搜尋相關技能
- 檢查系統安全狀態
- 生成報告到 `scripts/opencode-optimization-report.md`

---

## 報告範例

**第一次執行結果範例**：
- 發現 15 個可能在關的技能（optimization, security, monitoring）
- 安全檢查：0 critical · 1 warn · 1 info
- 建議優先處理安全加固和權限修復

**報告位置**：
- `scripts/opencode-optimization-report.md` (腳本版本)
- `docs/clawhub-optimization-recommendations.md` (OpenCode 深入分析)

---

## Cron Job

已設定：
- **Job ID**: `004f1b52`
- **頻率**: 每 5 小時
- **執行時間**: 下次約 2 小時後 (08:32 UTC)
- **任務**: 執行腳本並回報結果

---

## 技能清單

已安裝的 Moltbot 技能：

| 技能 | 版本 | 用途 |
|------|------|------|
| moltbot-best-practices | v1.1.0 | AI 代理最佳實踐（15 條規則） |
| moltbot-security | v1.0.0 | 安全加固指南（防範攻擊） |
| moltcheck | v1.0.4 | 安全掃描器（檢查 GitHub 倉庫） |

---

## 下一步改進

1. 安裝發現的有用技能
2. 設置文件權限
3. 配置 auth token
4. 定期更新技能庫
