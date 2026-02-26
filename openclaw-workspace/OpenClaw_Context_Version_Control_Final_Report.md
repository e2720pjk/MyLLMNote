# OpenClaw 上下文版控 - 探索任務最終研究報告

**研究日期**: 2026-02-04  
**執行者**: 並行研究代理 + 綜合分析  
**狀態**: ✅ 研究完成，準備實施

---

## 執行摘要

本研究基於深入的技術研究分析，對 OpenClaw workspace 版本控制策略提供了全面的評估。透過對 5 份深度研究報告的分析，我們得出了以下關鍵結論：

### 🎯 核心推薦方案

**方案 A：本地 Cron + Rsync + Git（主推薦）**
- ✅ 最簡單、最可靠、零外部依賴
- ✅ 適合單機環境和配置文件同步需求
- ✅ 簡單易理解，維護成本低
- ⚠️ 需要設定 cron job

**方案 B：Git Worktree（進階選項）**
- ✅ 適合需要多環境並行開發
- ✅ 測試配置不影響生產環境
- ⚠️ repos/ 需要先排除（避免 submodule 相關問題）
- ⚠️ 需要更多學習時間

### ❌ 不推薦方案

- **Git Submodules**：錯誤工具選擇，設計用於不同場景
- **GitHub Actions 自動同步**：只能在 GitHub 伺服器運行，無法偵測本地未提交變更
- **即時檔案監控 (inotify/fswatch)**：過度工程化，資源耗費高
- **加密工具 (git-crypt, SOPS)**：增加複雜度但未解決核心問題

---

## 1. 研究方法與發現

### 1.1 現有研究資源

本研究基於 5 份現有的深度研究報告：

1. **git-submodule-research.md** (約 900 行)
   - 結論：Submodules 不適用於此場景
   - 推薦：簡單 Git + .gitignore

2. **git-worktree-research.md** (約 1,400 行)
   - 結論：Worktree 可行，但 repos/ 需排除
   - 官方警告：Submodules 與 Worktree 不相容

3. **file-sync-research-report.md** (約 1,300 行)
   - 結論：Cron-based sync 是最佳選擇
   - 推薦：每 15-30 分鐘同步一次

4. **MEMORY_FILES_GIT_SECURITY_RESEARCH.md** (約 1,800 行)
   - 結論：.gitignore + pre-commit hooks 多層防護
   - GDPR 合規考量

5. **github-integration-research.md** (約 1,300 行)
   - 結論：GitHub Actions 不適合本地變更偵測
   - 推薦：本地 cron 腳本為主，Actions 僅作驗證

---

## 2. OpenClaw Workspace 檔案結構

### 2.1 目錄結構

```
~/.openclaw/workspace/
├── AGENTS.md                  # 核心配置：代理角色定義
├── SOUL.md                    # Agent 靈魂：身份與原則
├── USER.md                    # 用戶資訊
├── IDENTITY.md                # 身份配置
├── MEMORY.md                  # ❌ 個人長期記憶（敏感，需排除）
├── TOOLS.md                   # 工具配置
├── .gitignore                 # 版本控制排除規則
├── skills/                    # 技能定義（共 10 目錄）
│   ├── moltcheck/
│   └── tmux/
├── scripts/                   # 自動化腳本（13 個 .sh，約 84KB）
├── memory/                    # ❌ 每日記憶檔案（16 個檔案，需排除）
├── repos/                     # ❌ 外部 git repositories（~340MB，需排除）
│   ├── CodeWiki/              # 完整 git repo
│   ├── llxprt-code/           # 完整 git repo
│   └── notebooklm-py/          # 完整 git repo
├── docs/                      # 文件
├── reports/                   # 報告
└── [多個研究檔案 .md]
```

### 2.2 檔案類別分類

| 類別 | 應該上傳到 GitHub | 說明 |
|------|------------------|------|
| **核心配置** | ✅ 是 | AGENTS.md, SOUL.md, USER.md, IDENTITY.md, TOOLS.md |
| **技能定義** | ✅ 是 | skills/*.md |
| **腳本** | ✅ 是 | scripts/*.sh |
| **技術記憶** | ⚠️ 可選 | memory/*-research.md（需清理敏感資料） |
| **個人記憶** | ❌ 否 | MEMORY.md, memory/YYYY-MM-DD.md（日記式內容） |
| **外部 Repos** | ❌ 否 | repos/（嵌套 .git 目錄） |
| **日誌/狀態** | ❌ 否 | *.log, network-state.json |

---

## 3. 版本控制策略方案詳解

### 方案一：本地 Cron + Rsync + Git（推薦）

#### 架構圖

```
┌─────────────────────────────────────────────────────────┐
│  本機機器                                                │
│                                                         │
│  ~/.openclaw/workspace/ (軟連結)                        │
│       ↓ 軟連結                                           │
│  ~/MyLLMNote/openclaw-workspace/ (真實目錄)              │
│                                                         │
│  ├── .gitignore (排除 MEMORY.md, memory/, repos/)       │
│  ├── AGENTS.md      ────┐                               │
│  ├── SOUL.md        ────┤                               │
│  ├── skills/        ────┤───→ 版本控制（MyLLMNote repo） │
│  └── scripts/       ────┘                               │
│                                                         │
│  ❌ MEMORY.md / memory/ / repos/ ──────→ 排除（不追蹤）  │
└─────────────────────────────────────────────────────────┘
                    ↓ (每 30-60 分鐘)
                    ↓ 本機腳本執行
                    ↓
┌─────────────────────────────────────────────────────────┐
│  MyLLMNote Git Repository                               │
│  https://github.com/e2720pjk/MyLLMNote.git             │
│                                                         │
│  - 自動同步 (cron job)                                     │
│  - 手動 commit & push (如果需要立即同步)                  │
└─────────────────────────────────────────────────────────┘
```

#### 實施步驟

**步驟 1：驗證 .gitignore 配置**

```bash
cd ~/MyLLMNote

# 檢查現有 .gitignore
cat openclaw-workspace/.gitignore

# 應該包含：
# MEMORY.md
# memory/
# repos/
```

**步驟 2：設置 Pre-commit Hooks（安全第一）**

```bash
# 建立 pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# 阻止敏感檔案提交

echo "🔍 Checking for sensitive files..."

STAGED_FILES=$(git diff --cached --name-only)

# 檢查 memory/ 目錄
if echo "$STAGED_FILES" | grep -q "^openclaw-workspace/memory/"; then
  echo "❌ 檢測到 memory/ 目錄中的檔案!"
  echo "Memory 檔案不應提交到 Git。"
  exit 1
fi

# 檢查 MEMORY.md
if echo "$STAGED_FILES" | grep -q "openclaw-workspace/MEMORY.md$"; then
  echo "❌ 檢測到 MEMORY.md 檔案!"
  exit 1
fi

echo "✅ Pre-commit 檢查通過"
exit 0
EOF

chmod 755 .git/hooks/pre-commit
```

**步驟 3：建立同步腳本**

```bash
cat > /usr/local/bin/openclaw-sync.sh << 'SCRIPT_EOF'
#!/bin/bash
# OpenClaw Workspace Auto-Sync Script

set -euo pipefail

WORKSPACE="$HOME/MyLLMNote/openclaw-workspace"
LOG_FILE="$HOME/.openclaw/sync.log"
ERROR_LOG="$HOME/.openclaw/sync-errors.log"
LOCK_FILE="/tmp/openclaw-sync.lock"
MAX_RETRIES=3

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error_log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$ERROR_LOG"
}

cleanup() {
  rm -f "$LOCK_FILE"
}
trap cleanup EXIT

# 防止並發運行
if [ -f "$LOCK_FILE" ]; then
  log "Sync already running, skipping"
  exit 0
fi

touch "$LOCK_FILE"
log "=== Starting sync ==="

cd "$HOME/MyLLMNote" || { error_log "Cannot cd to MyLLMNote"; exit 1; }

# Pull latest changes
log "Pulling latest changes..."
git pull --rebase origin main >> "$LOG_FILE" 2>&1 || true

# Check for changes
cd "$HOME/MyLLMNote"
if [[ -z $(git status openclaw-workspace/ --short) ]]; then
  log "No changes to commit"
  exit 0
fi

log "Changes detected, creating commit..."
git add openclaw-workspace/

COMMIT_MSG="Auto-sync: $(date '+%Y-%m-%d %H:%M:%S UTC')

Changes:
$(git status --short openclaw-workspace/)"

if ! git commit -m "$COMMIT_MSG"; then
  error_log "Git commit failed (no changes?)"
  exit 0
fi

log "Pushing to GitHub..."
for attempt in {1..3}; do
  if git push origin main >> "$LOG_FILE" 2>&1; then
    log "✅ Sync completed successfully"
    exit 0
  fi
  sleep 5
done

error_log "Git push failed after 3 attempts"
exit 1
SCRIPT_EOF

chmod 700 /usr/local/bin/openclaw-sync.sh
```

**步驟 4：設定 Cron Job**

```bash
crontab -e

# 添加以下行（每 30 分鐘執行一次）
*/30 * * * * /usr/local/bin/openclaw-sync.sh

# 或者每小時執行一次（更穩定）
# 0 * * * * /usr/local/bin/openclaw-sync.sh
```

**步驟 5：首次同步**

```bash
cd ~/MyLLMNote

# 檢查變更
git status openclaw-workspace/

# 提交開始配置
git add openclaw-workspace/
git commit -m "feat: 初始化 OpenClaw workspace 版本控制

- 配置 .gitignore
- 設置 pre-commit hooks
- 建立自動同步腳本

排除：
- 個人記憶檔案 (MEMORY.md, memory/)
- 外部 repos (repos/)
- 敏感配置檔案"

git push origin main
```

---

### 方案二：Git Worktree（進階選項）

#### 適用場景

- 需要同時開發多個配置版本
- 在不影響生產環境的情況下測試新配置
- 需要快速切換不同技能配置

#### 實施步驟

**步驟 1：確保 repos/ 已排除**

```bash
cd ~/MyLLMNote/openclaw-workspace

# 檢查 .gitignore 包含 repos/
if grep -q "^repos/$" .gitignore; then
  echo "✅ repos/ 已排除"
else
  echo "repos/" >> .gitignore
  echo "已添加 repos/ 到 .gitignore"
fi
```

**步驟 2：建立開發 Worktree**

```bash
cd ~/MyLLMNote

# 建立開發 worktree
git worktree add ~/openclaw-workspace-dev develop

# 驗證
git worktree list
```

**步驟 3：使用 Worktree**

```bash
# 在主 worktree（生產環境）
cd ~/MyLLMNote/openclaw-workspace
# 進行生產修改...

# 在開發 worktree（測試環境）
cd ~/openclaw-workspace-dev
# 進行開發測試，但不影響生產...
```

**步驟 4：合併變更**

```bash
# 從開發合併到主分支
cd ~/MyLLMNote
git merge develop
git push origin main
```

---

## 4. 記憶檔案處理策略

### 4.1 GDPR 合規考量

| 類型 | 版本控制策略 | 處理方式 |
|------|-------------|---------|
| **MEMORY.md** | ❌ 完全排除 | 個人長期記憶，包含偏好、上下文 |
| **memory/YYYY-MM-DD.md** | ❌ 完全排除 | 每日日記，可能包含個人資訊 |
| **memory/*-research.md** | ✅ 可以上傳 | 技術研究，需確認無敏感資料 |
| **memory/*-results.md** | ✅ 可以上傳 | 技術結果，需確認無敏感資料 |

### 4.2 自動化記憶保留腳本

```bash
cat > scripts/memory-retention.sh << 'EOF'
#!/bin/bash
# GDPR 合規記憶檔案保留政策

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RETENTION_DAYS=90
LOG_FILE="$REPO_DIR/logs/memory-retention.log"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] $*" | tee -a "$LOG_FILE"
}

log "=== Memory Retention Cleanup Started ==="

cd "$REPO_DIR" || exit 1

# 刪除舊的每日記憶檔案
DELETED_COUNT=$(find memory/ -name "20*.md" -not -name "*-research.md" -not -name "*-results.md" -mtime +$RETENTION_DAYS -print -delete 2>&1 | wc -l)
log "Deleted $DELETED_COUNT old daily memory files (> $RETENTION_DAYS days)"

log "=== Memory Retention Cleanup Complete ==="
log ""
EOF

chmod 755 scripts/memory-retention.sh

# 設置 cron（每週日早上 2 點執行）
crontab -e
# 添加: 0 2 * * 0 /home/soulx7010201/MyLLMNote/openclaw-workspace/scripts/memory-retention.sh
```

---

## 5. 安全性強化措施

### 5.1 多層防禦策略

#### 第一層：.gitignore

```gitignore
# 個人記憶檔案
MEMORY.md
memory/

# 敏感配置
*.env
credentials.json
secrets/

# 外部 repos（避免 git-in-git）
repos/

# 運行時狀態
*.log
*.tmp
network-state.json*
```

#### 第二層：Pre-commit Hooks

```bash
# .git/hooks/pre-commit
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# 阻止敏感檔案提交

if git diff --cached --name-only | grep -E "^openclaw-workspace/MEMORY\.md$|^openclaw-workspace/memory/|^openclaw-workspace/repos/"; then
  echo "❌ ERROR: Personal memory files or repos detected."
  echo "These files should not be committed to version control."
  exit 1
fi

exit 0
EOF

chmod 755 .git/hooks/pre-commit
```

---

## 6. 方案比較與選擇

| 特性 | 方案一：Cron + Git | 方案二：Git Worktree | GitHub Actions |
|------|------------------|---------------------|---------------|
| **簡單性** | ✅ 最高 | ⚠️ 中等 | ❌ 無法用於本地變更 |
| **設定時間** | 30 分鐘 | 1 小時 | N/A（架構不符） |
| **可靠性** | ✅ 高（本地運行） | ✅ 高 | ⚠️ 不適用此場景 |
| **並行開發** | ❌ 不支援 | ✅ 支援 | N/A |
| **資源使用** | 低 | 低 | 中（GitHub quota） |
| **推薦度** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ❌ |

### 選擇建議

**選擇方案一如果：**
- ✅ 單一環境即可
- ✅ 簡單、可靠是優先考量
- ✅ 目前只在一台機器上使用
- ✅ 不需要並行測試配置

**選擇方案二如果：**
- ✅ 需要同時開發多個配置版本
- ✅ 經常測試新技能定義
- ✅ 需要快速切換環境
- ✅ 願意投入學習時間

---

## 7. 實施檢查清單

### 方案一實施清單

**階段 1：基礎設置（第一週）**
- [ ] 驗證 .gitignore 配置完整
- [ ] 設置 pre-commit hooks
- [ ] 建立同步腳本 (`/usr/local/bin/openclaw-sync.sh`)
- [ ] 配置 cron job
- [ ] 測試自動同步

**階段 2：監控與維護（持續）**
- [ ] 檢查同步日誌
- [ ] 設置記憶保留腳本
- [ ] 定期檢查 git 狀態

### 方案二實施附加清單

**額外步驟：**
- [ ] 驗證 repos/ 已排除
- [ ] 建立開發 worktree
- [ ] 測試 worktree 運作
- [ ] 文件化使用流程

---

## 8. 潛在風險評估

| 風險 | 影響 | 可能性 | 緩解措施 |
|------|------|--------|---------|
| **意外上傳個人記憶檔案** | 高（隱私洩露） | 中 | .gitignore + pre-commit hooks |
| **自動同步失敗** | 低（資料未備份） | 中 | Cron 日誌監控 |
| **Worktree 操作錯誤** | 中（配置混亂） | 中 | 文件化 + 培訓 |
| **歷史污染** | 中 | 低 | 使用 git-filter-repo 清理 |

---

## 9. 結論

### 核心推薦

**方案一：本地 Cron + Rsync + Git** 是 OpenClaw workspace 版本控制的最佳選擇

**關鍵原因：**
1. ✅ 簡單可靠：標準 Git 工作流，無需複雜學習
2. ✅ 安全：.gitignore + pre-commit hooks 多層防護
3. ✅ 可維護：日誌詳盡，易排查問題
4. ✅ 資源效率：無持續進程，cron 定期執行
5. ✅ 適合配置檔案：~500KB 不需要即時同步

### 實施優先級

**立即實施（第一週）：**
1. 驗證 .gitignore 配置
2. 設置 pre-commit hooks
3. 建立同步腳本
4. 配置 cron job

**短期實施（第二週）：**
1. 記憶保留腳本
2. 監控日誌設置
3. 文件化操作手冊

**中期優化（第一個月）：**
1. 性能調整
2. 錯誤處理加強

### 成功指標

- ✅ 同步成功率 > 95%
- ✅ 零個人資料洩漏
- ✅ 恢復時間 < 1 小時

---

## 10. 參考資料

### 詳細研究報告

1. `git-submodule-research.md` - Git Submodules 完整分析
2. `git-worktree-research.md` - Git Worktree 使用指南
3. `file-sync-research-report.md` - 檔案同步方案比較
4. `MEMORY_FILES_GIT_SECURITY_RESEARCH.md` - 記憶檔案安全策略
5. `github-integration-research.md` - GitHub 整合指南

### 官方文件

- Git 官方文件: https://git-scm.com/docs  
- Cron 用法: https://crontab.guru/
- Pre-commit 框架: https://pre-commit.com/

---

**報告完成日期**: 2026-02-04  
**研究深度**: 深度分析（5+ 份研究報告，綜合分析）  
**狀態**: ✅ 準備好實施  
**推薦方案**: 方案一（本地 Cron + Rsync + Git）
