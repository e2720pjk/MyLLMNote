# Results - Goal 001: OpenClaw Context Version Control Research

## Executive Summary
研究分析了將 OpenClaw workspace （~/.openclaw/workspace/）的上下文和對話記錄歸檔到 MyLLMNote（~/MyLLMNote/）並透過 GitHub 進行定期版控的多種方案。基於安全和實用性考量，**推薦方案為：Git Submodule + 自動同步腳本**。

---

## 1. OpenClaw 上下文檔案結構分析

### 1.1 核心配置檔案（建議版控）
```
~/.openclaw/workspace/
├── SOUL.md          (1.6KB) - Agent 定義與核心識別
├── IDENTITY.md      (874B)  - 身份識別
├── USER.md          (1.2KB) - 使用者資訊
├── AGENTS.md        (7.6KB) - 代理規則與指南
├── TOOLS.md         (3.6KB) - 工具配置
├── HEARTBEAT.md     (491B)  - 心跳檢查清單
└── BOOTSTRAP.md     (1.4KB) - 系統引導設定
```

### 1.2 記憶檔案（需謹慎處理）
```
memory/
├── 2026-02-01.md  (4.6KB) - 日記式記錄
├── 2026-02-02.md  (748B)
├── opencode-automation-findings.md
├── opencode-automation-problems.md
└── opencode-run-pty-fix.md
```

### 1.3 技能與腳本（建議版控）
```
skills/
├── notebooklm-cli/     - NotebookLM CLI 整合
└── opencode-acp-control/ - OpenCode ACP 控制

scripts/
├── opencode_wrapper.py  (2.8KB)
├── check-ip.sh          (5.6KB)
├── test-goal-001.sh
├── test-single-goal.sh  (1.4KB)
└── test-acp.sh
```

### 1.4 關鍵發現
- **OpenClaw workspace 已有 git 初始化**，目前為 master 分支但無任何 commit
- **MyLLMNote 已連接 GitHub**：`https://github.com/e2720pjk/MyLLMNote.git`
- **總工作區大小約 260KB**（不含 .git 目錄）

---

## 2. 版控策略選項比較

### 2.1 方案 A：Git Submodule（推薦⭐）

**架構：**
```
~/MyLLMNote/
├── .git/
├── research/
├── ... (其他內容)
└── openclaw-workspace/  <-- 作為 submodule 連結
    └── (指向 ~/.openclaw/workspace)
```

**實 施方式：**
```bash
cd ~/MyLLMNote

# 1. 將 OpenClaw workspace 新增為 submodule
git submodule add ~/.openclaw/workspace openclaw-workspace

# 2. 或是創建獨立的 GitHub repo 作為 submodule
git submodule add <openclaw-repo-url> openclaw-workspace

# 3. 提交到 MyLLMNote
git add .gitmodules openclaw-workspace
git commit -m "Add OpenClaw workspace as submodule"
```

**優點：**
- ✅ 保持 OpenClaw workspace 的獨立性
- ✅ 可以在 MyLLMNote 中同步追蹤更新
- ✅ 可以在本地和 GitHub 同時維護
- ✅ 版本歷史清晰獨立
- ✅ MyLLMNote 和 OpenClaw workspace 可以分開管理

**缺點：**
- ❌ 需要顯式執行 `git submodule update` 來同步
- ❌ 增加了一層複雜度
- ❌ 更新需要兩步驟（更新 submodule + 更新 MyLLMNote）

**適合場景：**
- 同時在本地和 GitHub 維護 OpenClaw 配置
- 需要跨多個專案共享 OpenClaw 配置

---

### 2.2 方案 B：Git Worktree（已討論過）

**架構：**
```bash
# 在 MyLLMNote 中創建 OpenClaw repo 的 worktree
cd ~/MyLLMNote
git worktree add openclaw-workspace ~/.openclaw/workspace
```

**優點：**
- ✅ 共享同一個 git repository
- ✅ 節省磁碟空間

**缺點：**
- ❌ 需要將 ~/.openclaw/workspace 初始化為 git repo
- ❌ worktree 必須在同一個 git repo 系統內
- ❌ 當前 OpenClaw workspace 無 commits 無法建立 worktree
- ❌ 管理複雜度較高

**適合場景：**
- OpenClaw workspace 已經是 MyLLMNote 的一部分（不符合當前現況）

---

### 2.3 方案 C：定期同步腳本（簡單直接）

**架構：**
```
~/.openclaw/workspace/    <-- 真實工作區
        ↓ rsync/cp
~/MyLLMNote/openclaw-archive/  <-- 複製用於版控
        ↓
GitHub
```

**實施方式：**
```bash
#!/bin/bash
# sync-openclaw.sh

SOURCE="$HOME/.openclaw/workspace"
TARGET="$HOME/MyLLMNote/openclaw-archive"

# 排除檔案（敏感資訊）
EXCLUDE_PATTERNS=(
    ".clawdhub/*"
    "network-state.json*"
    ".git/*"
    "memory/*"  # 可選：是否包含記憶檔案
)

# 執行複製
rsync -av --delete \
    --exclude="*.tmp" \
    "${SOURCE}/" "${TARGET}/"

cd "$TARGET"
git add .
git commit -m "Auto-sync OpenClaw workspace $(date +%Y-%m-%d)"
git push
```

**優點：**
- ✅ 最簡單直接
- ✅ 完全控制哪些檔案被同步
- ✅ 可以過濾敏感資訊
- ✅ 容易透過 cron 自動化

**缺點：**
- ❌ 有重複檔案（磁碟空間）
- ❌ 不會自動追蹤到本地 OpenClaw workspace 的 git 歷史
- ❌ 需要定期執行腳本

**適合場景：**
- 不需要共享 git 歷史
- 需要完全控制同步內容
- 簡單自動化方案

---

### 2.4 方案 D：混合方案（推薦⭐⭐）

**架構：**
```
~/.openclaw/workspace/    <-- 真實工作區（本地 git repo）
        ↓ rsync/cp（過濾敏感資訊）
~/MyLLMNote/openclaw-archive/  <-- 過濾後的副本（獨立 git repo）
        ↓
GitHub
```

**實施方式：**
1. 將 OpenClaw workspace 初始化為 git repo（如果尚未）
2. 創建過濾複製腳本
3. 在 MyLLMNote 中建立獨立的 openclaw-archive 目錄
4. 設定定時任務或觸發式同步

**優點：**
- ✅ 本地保留完整 git 歷史
- ✅ GitHub 上只存儲必要檔案
- ✅ 靈活控制敏感資訊
- ✅ 可以分開管理不同版控策略

**缺點：**
- ❌ 需要維護兩個 git repo
- ❌ 需要配置 rsync 過濾規則

**適合場景：**
- 需要本地完整歷史
- 需要過濾敏感資訊上傳 GitHub
- 需要靈活控制版控內容

---

### 2.5 方案 E：符號連結（不推薦）

**架構：**
```bash
cd ~/MyLLMNote
ln -s ~/.openclaw/workspace openclaw-workspace
```

**優點：**
- ✅ 無檔案重複

**缺點：**
- ❌ 無法分別版本控制
- ❌ Git 可能跟隨或忽視符號連結（取決於配置）
- ❌ 符號連結失效會導致問題
- ❌ 不符合使用場景

**適合場景：**
- 不適合當前需求

---

## 3. GitHub 整合考量

### 3.1 自動 Commit & Push 流程

**方案 A：Cron 定時任務**
```bash
# 每小時同步一次
0 * * * * $HOME/MyLLMNote/scripts/sync-openclaw.sh
```

**方案 B：OpenClaw Hook**
在 OpenClaw workspace 更新時自動觸發腳本

**方案 C：手動觸發**
```bash
# 在需要時執行推送
./scripts/sync-openclaw.sh
```

### 3.2 記憶檔案處理策略

| 檔案類型 | 建議處理 | 理由 |
|---------|---------|------|
| `memory/2026-02-*.md` | **排除**（或選擇性上傳） | 包含個人對話歷史，可能涉及敏感資訊 |
| `memory/opencode-*.md` | **包含** | 技術記錄和問題解決，有參考價值 |
| `MEMORY.md`（若有） | **排除** | 長期記憶可能包含個人背景 |
| `.clawdhub/*` | **排除** | 內部配置，無須上傳 |
| `network-state.json*` | **排除** | 臨時狀態檔案 |

**推薦設定：**
```bash
# rsync 排除清單
--exclude=".clawdhub/*"
--exclude="network-state.json*"
--exclude=".git/*"
--exclude="*.tmp"
--exclude="memory/2026-*.md"  # 排除日記式記錄
--include="memory/opencode-*.md"  # 包含技術記錄
```

### 3.3 敏感資訊過濾機制

**方法 1：.gitignore**
```gitignore
# OpenClaw 敏感檔案
.clawdhub/
network-state.json*
*.tmp

# 記憶檔案（可選）
memory/*-*.md
!memory/opencode-*.md
```

**方法 2：Git-secrets（可選）**
預防性的敏感資訊掃描工具

**方法 3：Pre-commit Hook**
在 commit 前檢檔案內容

---

## 4. 風險評估

### 4.1 安全風險

| 風險 | 等級 | 緩解措施 |
|-----|------|---------|
| 敏感資訊洩漏 | ⚠️ 中 | - 使用 .gitignore 過濾<br>- 審查上傳檔案<br>- Private repo |
| GitHub 存取權限 | ⚠️ 中 | - 使用私人 repositories<br>- 適當的 token 權限管理 |
| 記憶檔案隱私 | 🔴 高 | - 排除日記式記錄<br>- 選擇性上傳技術記錄 |

### 4.2 實作風險

| 风险 | 等級 | 緩解措施 |
|-----|------|---------|
| 同步衝突 | ⚠️ 中 | - 使用 rsync --delete 選項<br>- 檢查變更再提交 |
| 磁碟空間 | 🟢 低 | - 實施版本清理腳本<br>- 設定合理的保留期限 |
| 腳本錯誤 | ⚠️ 中 | - 充分測試<br>- 加入錯誤處理和通知 |
| 版控混亂 | 🟢 低 | - 清晰的文檔<br>.gitignore 正確配置 |

---

## 5. 最終推薦方案

### 5.1 推薦選擇：**方案 D（混合方案）**

**理由：**
1. ✅ 靈活性最高：可以完全控制同步內容
2. ✅ 安全性最佳：可以過濾敏感資訊
3. ✅ 最適合當前架構：
   - OpenClaw workspace 保持本地獨立 git repo
   - MyLLMNote 有自己的 GitHub repo
   - 通過腳本橋接兩者

### 5.2 實施步驟

**步驟 1：初始化 OpenClaw workspace 為 git repo**
```bash
cd ~/.openclaw/workspace
git init
git add .
git commit -m "Initial commit: OpenClaw workspace"
```

**步驟 2：在 MyLLMNote 創建歸檔目錄**
```bash
cd ~/MyLLMNote
mkdir -p openclaw-archive
cd openclaw-archive
git init
git remote add origin https://github.com/e2720pjk/openclaw-archive.git
```

**步驟 3：創建同步腳本**
```bash
# ~/MyLLMNote/scripts/sync-openclaw.sh
#!/bin/bash

set -e

SOURCE=$HOME/.openclaw/workspace
TARGET=$HOME/MyLLMNote/openclaw-archive

# 排除檔案清單
EXCLUDE=(
    ".clawdhub"
    "network-state.json"
    ".git"
)

# 構建 rsync 排除參數
EXCLUDE_ARGS=""
for excl in "${EXCLUDE[@]}"; do
    EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude='$excl'"
done

# 排除日記式記憶檔案，但保留技術記錄
rsync -av --delete \
    --exclude="*.tmp" \
    --exclude=".clawdhub" \
    --exclude="network-state.json*" \
    --exclude=".git" \
    --exclude="memory/2026-*.md" \
    "$SOURCE/" "$TARGET/"

# Commit and push
cd "$TARGET"
git add .
git diff --cached --quiet || git commit -m "Auto-sync OpenClaw workspace $(date '+%Y-%m-%d %H:%M:%S')"
git push origin main

echo "✅ OpenClaw workspace synced and pushed to GitHub"
```

**步驟 4：設定 cron 定時任務**
```bash
crontab -e
# 添加：每 6 小時同步一次
0 */6 * * * $HOME/MyLLMNote/scripts/sync-openclaw.sh
```

**步驟 5：創建 .gitignore（在 openclaw-archive 中）**
```gitignore
# 敏感檔案
.clawdhub/
network-state.json*
*.tmp

# 記憶檔案過濾
memory/2026-*.md
```

### 5.3 後續優化建議

1. **測試腳本**：在正式啟用前充分測試同步腳本
2. **設定 notifications**：git push 失敗時發送通知
3. **記憶檔案策略**：定期審查 memory/ 中的檔案，決定是否上傳
4. **版本清理**：實施定期的 git garbage collection
5. **文檔化**：在 MyLLMNote README 中說明同步機制

---

## 6. 總結

| 方案 | 推薦度 | 適用場景 |
|------|--------|---------|
| 方案 A：Git Submodule | ⭐⭐⭐ | 需要跨 repo 共享 OpenClaw 配置 |
| 方案 B：Git Worktree | ⭐ | 不適合當前架構 |
| 方案 C：定期同步腳本 | ⭐⭐⭐⭐ | 簡單直接，控制力強 |
| **方案 D：混合方案** | **⭐⭐⭐⭐⭐** | **最推薦：靈活、安全、適合當前需求** |
| 方案 E：符號連結 | - | 不推薦 |

**最終推薦：方案 D（混合方案）**

理由：
- ✅ 靈活性與安全性的最佳平衡
- ✅ 完全控制同步內容，可過濾敏感資訊
- ✅ 保留本地完整的 git 歷史
- ✅ 不影響現有架構
- ✅ 容易實施和維護

---

## 7. 附錄：相關命令參考

```bash
# 檢查 git submodule 狀態
git submodule status
git submodule update --remote

# Git worktree 操作
git worktree add <path> <branch>
git worktree list
git worktree remove <path>

# Rsync 參數說明
-a                   # archive mode，保留屬性
-v                   # verbose，詳細輸出
--delete            # 刪除目標目錄中源目錄不存在的檔案
--exclude=PATTERN   # 排除符合模式的檔案
```

---

**研究完成日期：** 2026-02-02
**研究者：** OhMyOpenCode Agent System (Sisyphus + Oracle)
