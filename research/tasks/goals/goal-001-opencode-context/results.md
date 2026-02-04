# OpenClaw 上下文版控研究報告 - 完整版

**研究日期：** 2026-02-03 ~ 2026-02-04
**研究者：** Sisyphus + Oracle + Explore + Librarian Agents (OhMyOpenCode)
**狀態：** ✅ 已完成

---

## 執行摘要

本研究深入分析了多種將 OpenClaw workspace（`~/.openclaw/workspace/`）歸檔到 MyLLMNote（`~/MyLLMNote/`）並透過 GitHub 進行版本控制的策略。

**最終推薦方案：** 軟連結（Symlink） + .gitignore 過濾

**關鍵發現：**
- ✅ **已部分實施**：符號連結方案成功整合 openclaw-workspace 到 MyLLMNote
- ✅ **`.gitignore` 配置完善**：成功解決 git-in-git 衝突和敏感資料問題
- ⚠️ **現狀**：repos/ 目錄佔用 ~340MB（包含完整 git clones）
- 🔧 **優化推薦**：將 repos/ 改為符號連結到 MyLLMNote 現有專案，可節省 ~330MB

**本研究包含：**
1. 版控方案對比分析（5 種方案）
2. 當前架構狀態評估
3. 自動化解決方案研究（cron, file-watcher, git hooks, chezmoi）
4. 安全策略（敏感資料過濾、gitleaks、pre-commit hooks）
5. 實施步驟和監控計劃

---

## 1. 當前架構狀態

### 1.1 目錄結構

```bash
~/.openclaw/workspace/              # 符號連結 ↓
  ↓ symlink to
~/MyLLMNote/openclaw-workspace/    # Git tracked in MyLLMNote repo
  ↓ git push
GitHub: e2720pjk/MyLLMNote.git
```

### 1.2 空間分析

```bash
~/.openclaw/workspace/ 總計: ~340MB
├── repos/            340MB  ← 已被 .gitignore 排除
├── skills/           ~256KB
├── scripts/          ~84KB
├── memory/           ~64KB
└── 其他              <50KB
```

**關鍵發現：**
- `repos/` 目錄包含完整的外部 git repositories（llxprt-code, CodeWiki, notebooklm-py）
- 已通過 `.gitignore` 成功排除，未造成 git-in-git 衝突
- Git commit 僅包含配置檔案，不包含 repos/

### 1.3 核心配置檔案（已歸檔）

| 檔案 | 大小 | 說明 | 版控狀態 |
|------|------|------|---------|
| SOUL.md | 1.6KB | Agent 定義與核心識別 | ✅ 已追蹤 |
| USER.md | 1.2KB | 使用者資訊 | ✅ 已追蹤 |
| AGENTS.md | 7.6KB | 代理規則與指南 | ✅ 已追蹤 |
| IDENTITY.md | 874B | 身份識別信息 | ✅ 已追蹤 |
| TOOLS.md | 3.6KB | 工具配置 | ✅ 已追蹤 |
| HEARTBEAT.md | 491B | 心跳檢查清單 | ✅ 已追蹤 |
| MEMORY.md | 4KB | 長期記憶（敏感） | ❌ 已排除 |
| memory/2026-*.md | 日記記錄（敏感） | ❌ 已排除 |
| memory/opencode-*.md | 技術記憶 | ✅ 已追蹤 |

### 1.4 技能與腳本

```bash
skills/ (~256KB)
├── model-usage/             # 模型使用技巧
├── moltbot-best-practices/  # 最佳實踐
├── moltbot-security/        # 安全技能
├── moltcheck/               # 檢查工具
├── opencode-acp-control/    # ACP 控制
├── tmux/                    # tmux 技能
├── summarize/               # 摘要生成
└── notebooklm-cli/          # NotebookLM CLI

scripts/ (~84KB)
├── opencode_wrapper.py      # OpenCode 包裝腳本
├── check-ip.sh              # IP 檢查
├── analyze-stale-sessions.sh # 會話分析
└── (其他監控腳本)
```

### 1.5 Git 配置

**當前 `.gitignore` 規則：**
```gitignore
# OpenClaw 內部配置（敏感）
.clawdhub/
.clawhub/
network-state.json*

# 敏感記憶檔案
MEMORY.md
memory/2026-*.md
memory/*-daily.md

# 外部 git repos（避免 git-in-git）
repos/

# OpenCode 內部配置
.opencode/
.opencode.json*

# 堅硬測試報告
reports/
*-report.md
*-evaluation.md
*-summary.md

# 保留重要的技術記憶
!memory/opencode-*.md
!memory/optimization-*.md
```

### 1.6 Git 歷史

```bash
340da40 Add OpenClaw workspace via symlink (filtered)
```

**狀態：** 已部分實施軟連結方案，並配置了適當的過濾規則。

---

## 2. 版控方案對比研究

### 2.1 方案總覽

| 維度 | 軟連結 + .gitignore（當前） | Git Submodule | Git Worktree | Bare Repo + Alias | Rsync 混合（備選） |
|-----|---------------------------|---------------|-------------|------------------|------------------|
| **實施複雜度** | ⭐ 低 | ⭐⭐⭐ 高 | ⭐⭐⭐⭐ 很高 | ⭐⭐ 中 | ⭐⭐ 中 |
| **空間效率** | ⭐⭐⭐⭐⭐ 最佳（無重複） | ⭐⭐⭐ 高 | ⭐⭐⭐⭐ 最佳 | ⭐⭐⭐ 高 | ⭐ 低（雙重副本） |
| **同步即時性** | ⭐⭐⭐⭐⭐ 即時 | ⭐⭐ 手動 | ⭐⭐⭐ 本地即時 | ⭐⭐ 手動 | ⭐ 延時 |
| **Git-in-git 處理** | ⭐⭐⭐⭐⭐ .gitignore | ⭐⭐⭐⭐ 原生支持 | ⭐⭐⭐⭐⭐ 無問題 | ⭐⭐⭐⭐⭐ 無問題 | ⭐⭐⭐⭐⭐ rsync 過濾 |
| **安全性（過濾）** | ⭐⭐⭐⭐ 高 | ⭐⭐⭐ 中 | ⭐⭐⭐ 中 | ⭐⭐⭐⭐⭐ 最佳 | ⭐⭐⭐⭐⭐ 最佳 |
| **跨平台兼容** | ⭐⭐ 中 (Unix only) | ⭐⭐⭐⭐⭐ 高 | ⭐⭐⭐⭐ 高 | ⭐⭐⭐⭐ 高 | ⭐⭐⭐⭐⭐ 很高 |
| **自動化需求** | ⭐ 無需 | ⭐⭐ 手動更新 | ⭐Ⓜ腳本同步 | ⭐⭐Ⓜ腳本同步 | ⭐⭐⭐ cron/fswatch |
| **恢復能力** | ⭐⭐⭐ 中 | ⭐⭐⭐⭐ 高 | ⭐⭐⭐ 中 | ⭐⭐⭐⭐ 高 | ⭐⭐⭐⭐⭐ 最佳 |
| **當前狀態** | ✅ 已實施 | ❌ 未實施 | ❌ 未實施 | ❌ 未實施 | 🔧 備選 |
| **維護成本** | ⭐ 低 | ⭐⭐⭐ 高 | ⭐⭐⭐ 中 | ⭐⭐ 低 | ⭐⭐ 中 |

### 2.2 詳細方案分析

#### 2.2.1 軟連結 + .gitignore（當前並推薦）

**概念：** 將 workspace 移到 MyLLMNote 內，用 symlink 指回原位置

**優點：**
- ✅ **零複製成本**：無檔案重複
- ✅ **即時同步**：修改立即反映
- ✅ **簡單直觀**：三個命令完成
- ✅ **避免 git-in-git**：通過 .gitignore 排除 repos/
- ✅ **可控安全**：精確過濾敏感檔案
- ✅ **已實施證實有效**：commit 340da40 運行正常

**缺點：**
- ❌ 跨平台兼容性：Windows 支持較差
- ❌ 路徑依賴：如果移動 MyLLMNote 需重建 symlink
- ❌ Git 配置：`core.symlinks` 配置影響行為

**結論：** ✅ **推薦方案**（已部分實施並證實有效）

---

#### 2.2.2 Git Submodule

**概念：** 將 OpenClaw workspace 作為 git submodule 加入 MyLLMNote

**官方文檔定義** ([git-scm.com/docs/git-submodule](https://git-scm.com/docs/git-submodule))：
> "keep another Git repository as a subdirectory of another Git repository"

**優點：**
- ✅ 版本精確控制：可 pin 到特定 commit
- ✅ 可移植性：clone 時自動獲取
- ✅ 獨立版本歷史：與主項目分開

**缺點：**
- ❌ Detached HEAD 狀態：auto-commit 複雜
- ❌ 管理成本高：需要 `.gitmodules` 維護
- ❌ 更新複雜：需要 `git submodule update`
- ❌ Clone 負擔：其他用戶需要額外步驟

**現代最佳實踐（供參考）：**
```bash
# 全局遞迴配置
git config --global submodule.recurse true

# 快速初始克隆
git clone --recurse-submodules --parallel 8 <url>

# Partial clones
git submodule update --init --recursive --filter=blob:none

# .gitmodules 配置
[submodule "libs/core"]
    path = libs/core
    url = ../../dependencies/core.git
    ignore = dirty  # 避免雜訊
    branch = main   # 追蹤分支（可選）
```

**大型專案案例：**
- **PyTorch**: 使用 30+ submodules，全設 `ignore = dirty`
- **Swift**: 使用 Python wrapper `update-checkout` 管理多倉庫
- **Chromium**: 使用自定義 `gclient`（非 submodules）

**結論：** ❌ 不適用於此場景（複雜度過高，非跨項目共享）

---

#### 2.2.3 Git Worktree

**概念：** 同一 repo 的多個本地工作目錄

**官方文檔定義** ([git-scm.com/docs/git-worktree](https://git-scm.com/docs/git-worktree))：
> "A git repository can support multiple working trees, allowing you to check out more than one branch at a time... sharing everything except per-worktree files"

**推薦模式：** "Hub-and-Spoke" Worktree Branching

**架構設計：**
```bash
~/MyLLMNote/context-repo/   ← 主 repo（.git 數據庫）
├── main (branch)
├── note (branch)            ← ~/MyLLMNote/workspace
└── workspace (branch)       ← ~/.openclaw/workspace (worktree)
```

**實施範例：**
```bash
cd ~/MyLLMNote
git init context-repo
cd context-repo
git checkout -b main

# 添加 workspace 作為 worktree
git worktree add ~/.openclaw/workspace -b workspace

# 添加 note 作為 worktree
git worktree add ~/MyLLMNote/opencode-notes -b note
```

**同步策略：**

**選項 A：分支合併**
```bash
# 在 workspace worktree
cd ~/.openclaw/workspace
git add .
git commit -m "update"
git push origin workspace:main

# 在 note worktree
cd ~/MyLLMNote/opencode-notes
git pull origin main
```

**選項 B：Detached HEAD**（更簡單）
```bash
# 初始化 detached worktree
git worktree add ~/.openclaw/workspace origin/main --detach

# 更新腳本
cd ~/.openclaw/workspace
git fetch origin
git reset --hard origin/main
```

**優點：**
- ✅ 共享歷史：本地即時同步
- ✅ 高效率：單一 .git 數據庫
- ✅ 靈活性：每個工作目錄可處於不同版本

**缺點：**
- ❌ 僅限本地：無法 push worktree 結構到 GitHub（每台機器需手動設置）
- ❌ 設置複雜：需要 `git worktree add` 每個位置
- ❌ 同步邏輯：需處理分支合併或 detached 更新
- **關鍵限制**：Git 不允許同一分支在兩個 worktree 中同時 checkout

**結論：** ⚠️ 可行，但對此場景過度複雜

---

#### 2.2.4 Bare Repository + Alias（社區推薦）

**概念：** 使用 bare repo + 自定義 alias 管理任意位置的檔案

**社區黃金標準** 範例 ([j-martin/dotfiles](https://github.com/j-martin/dotfiles))：

```bash
# 初始化 bare repo
git init --bare ~/.context.git

# 創建 alias
alias ctx='git --git-dir=$HOME/.context.git --work-tree=$HOME'

# 配置（關鍵）
ctx config --local status.showUntrackedFiles no
# ↑ 這意味著只 track 顯式 add 的檔案

# 使用
ctx add ~/.openclaw/workspace/SOUL.md
ctx commit -m "update SOUL"
ctx push origin main
```

**優點：**
- ✅ Git 原生最稳健
- ✅ 僅追蹤顯式添加的檔案（安全性最高）
- ✅ 跨任意位置：不限制檔案系統位置
- ✅ 遠程同步：完整的 push/pull 支持

**缺點：**
- ❌ 獨立 alias：學習曲線
- ❌ 與現有 repo 架構衝突

**結論：** ✅ 最優雅，但需要重構現有架構

---

#### 2.2.5 Rsync 混合方案（備選）

**概念：** 使用 rsync 腳本定期同步過濾後的內容

**架構：**
```bash
~/.openclaw/workspace/ (source)
         ↓ rsync (filtering)
~/MyLLMNote/openclaw-config/ (synced)
         ↓
GitHub
```

**腳本範例：**
```bash
#!/bin/bash
SOURCE="$HOME/.openclaw/workspace"
TARGET="$HOME/MyLLMNote/openclaw-config"

rsync -av --delete \
    --exclude="repos/" \
    --exclude="memory/2026-*.md" \
    --exclude="MEMORY.md" \
    --exclude=".clawdhub/" \
    --exclude=".clawhub/" \
    "$SOURCE/" "$TARGET/"

cd "$TARGET"
git add .
git diff --cached --quiet || git commit -m "Sync $(date)"
git push
```

**優點：**
- ✅ 完全獨立：備份與使用分離
- ✅ 精確控制：可過濾任意檔案
- ✅ 回滾安全：本地+遠端兩個歷史
- ✅ 跨平台：rsync 可在各平台運行
- ✅ 敏感數據完全可控：rsync exclude 比較強大

**缺點：**
- ❌ 空間浪費：雙重副本
- ❌ 需自動化：cron 或 file watcher
- ❌ 延時同步：非即時

**結論：** ⚠️ 有效備選方案（當前方案遇到問題時可切換）

---

## 3. 自動化版本控制解決方案研究

### 3.1 Cron-Based 自動提交（推薦）

**生產級腳本範例** (參考 [kevinmhk/populate_coding_agents_config](https://github.com/kevinmhk/populate_coding_agents_config))：

```bash
#!/bin/bash
# auto-sync.sh - OpenClaw workspace 自動同步腳本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"

echo "🔍 檢查 OpenClaw workspace 變更..."

cd "$WORKSPACE_DIR"

# 添加所有非排除檔案（.gitignore 會自動過濾）
git add -A

# 檢查是否有變更
if git diff --cached --quiet; then
    echo "✅ 沒有待提交的變更"
    exit 0
fi

# 顯示即將提交的檔案
echo "📝 變更檔案："
git diff --cached --name-only | sed 's/^/  - /'

# 執行 commit（避免過多雜訊，不輸出到 heartbeat）
git commit -m "$(date '+%Y-%m-%d %H:%M:%S')"

# 推送到 GitHub
echo "📤 推送到 GitHub..."
git push origin main

echo "✅ 同步完成！"
```

**Cron 配置：**
```bash
# 編輯 crontab
crontab -e

# 每 6 小時執行一次
0 */6 * * * /home/soulx7010201/MyLLMNote/openclaw-workspace/scripts/auto-sync.sh >> /tmp/openclaw-auto-sync.log 2>&1
```

**Cron 解析：**
- `0 */6 * * *` - 每 6 小時（00:00, 06:00, 12:00, 18:00）

**優點：**
- ✅ 成熟可靠：系統級任務調度
- ✅ 可配置頻率：靈活控制同步間隔
- ✅ 低資源消耗：僅在執行時運行

**缺點：**
- ❌ 固定週期：非即時

---

### 3.2 File-Watcher 自動提交（即時）

**inotifywait (Linux)：**
```bash
#!/bin/bash
# sync-daemon.sh - 檔案變更即時同步

WATCH_DIR="$HOME/.openclaw/workspace"

while inotifywait -q -m -r \
    -e modify,delete,create,move "$WATCH_DIR"; do

    # 等待檔案系統穩定
    sleep 5

    cd "$WATCH_DIR" || exit

    # 添加所有變更
    git add -A

    # 僅在有實際變更時提交
    if ! git diff-index --quiet HEAD; then
        git commit -m "auto: change detected"
        git push origin main
        echo "✅ 同步完成"
    fi
done
```

**fswatch（跨平台）：**
```bash
fswatch -o ~/.openclaw/workspace | xargs -n1 -I {} ./sync-script.sh
```

**生產實例：**
- [xwmx/nb](https://github.com/xwmx/nb) - 筆記 CLI 工具實現此模式
- [Vinzent03/obsidian-git](https://github.com/Vinzent03/obsidian-git) - Obsidian 插件

**優點：**
- ✅ 即時響應：檔案變更立即觸發

**缺點：**
- ❌ 頻繁觸發：可會導致過多 commit
- ❌ 調試複雜：file system events 複雜

---

### 3.3 Git Hooks 自動提交

**Post-Commit Hook：**
```bash
#!/bin/bash
# .git/hooks/post-commit

# 自動推送
git push origin main 2>&1 | logger -t "openclaw-git"
```

**Pre-Commit Hook（安全過濾）：**
```bash
#!/bin/bash
# .git/hooks/pre-commit

# 檢查是否有敏感檔案被加入
STAGED_FILES=$(git diff --cached --name-only)
SENSITIVE_PATTERN="(MEMORY\.md|memory/2026-.*\.md|\.clawhub|\.clawdhub)"

if echo "$STAGED_FILES" | grep -qE "$SENSITIVE_PATTERN"; then
    echo "❌ 錯誤：嘗試提交敏感檔案"
    echo "以下檔案可能包含個人記憶或內部配置："
    echo "$STAGED_FILES" | grep -E "$SENSITIVE_PATTERN" | sed 's/^/  - /'
    echo ""
    echo "如果您確信這些檔案應該提交，請使用："
    echo "  git commit --no-verify"
    exit 1
fi

exit 0
```

**優點：**
- ✅ Git 原生：與工作流無縫集成
- ✅ 安全檢查：可防止誤提交

**缺點：**
- ❌ 僅限本地：push 需要網絡

---

### 3.4 工具：Chezmoi（配置管理專用）

**Chezmoi** 是專門為 dotfile 和配置文件設計的現代工具：

```bash
# 安裝
chezmoi init https://github.com/yourusername/dotfiles.git

# 添加檔案
chezmoi add ~/.openclaw/workspace/SOUL.md

# 自動提交和推送
chezmoi apply
chezmoi git push
```

**自動同步配置：**
```toml
# ~/.config/chezmoi/chezmoi.toml
[git]
    autoCommit = true
    autoPush = true
    commitMessageTemplate = "auto: update configurations {{ .chezmoi.hostname }}"
```

**優點：**
- ✅ 範本引擎：支持配置範本化
- ✅ 秘密管理：集成 GPG 加密
- ✅ 跨平台：支持 Linux, macOS, Windows
- ✅ 原生 Git：完整的版本控制支持
- ✅ 生產-grade：社區廣泛使用

**缺點：**
- ❌ 學習曲線：新增工具依賴
- ❌ 配置複雜：需要重組現有結構

**社區證據：**
- [Chezmoi User Guide - Daily Operations](https://github.com/twpayne/chezmoi/blob/master/assets/chezmoi.io/docs/user-guide/daily-operations.md)
- 超過 [10k GitHub stars](https://github.com/twpayne/chezmoi)

**結論：** ✅ 適合大型配置管理，此場景過度設計

---

### 3.5 CI/CD: GitHub Actions 自動同步

如果執行自動化更新（例如 bot 更新 `MEMORY.md`），可使用 `git-auto-commit-action`：

```yaml
# .github/workflows/sync-openclaw.yml
name: Sync OpenClaw Config

on:
  schedule:
    - cron: '0 */6 * * *'  # 每 6 小時

jobs:
  sync:
    runs-on: ubuntu-latest
    permissions:
      contents: write  # 必須權限
    steps:
      - uses: actions/checkout@v4

      - name: 模擬自動更新
        run: |
          date > openclaw-workspace/last_sync.txt

      - uses: stefanzweifel/git-auto-commit-action@v5
        with:
          commit_message: 'docs: auto-update context files'
          file_pattern: 'openclaw-workspace/**/*.md openclaw-workspace/**/*.sh'
```

**優點：**
- ✅ 完全雲端：無需本地 cron
- ✅ 自動 PR：可審查再合併
- ✅ 跨機器：任何機器都可用

**缺點：**
- ❌ 延時：最多 6 小時（cron 頻率限制）
- ❌ Token 管理：需要 GitHub token

**證據：**
- [Stefan Zweifel's Git Auto-Commit Action v5](https://github.com/stefanzweifel/git-auto-commit-action)

---

### 3.6 自動化方案對比

| 方案 | 即時性 | 資源消耗 | 設置複雜度 | 推薦場景 |
|-----|--------|---------|-----------|---------|
| **Cron** | 延時 | 低 | ⭐ 低 | ✅ **推薦** - 週期性同步 |
| **File-Watcher** | 即時 | 中 | ⭐⭐ 中 | 需要即時響應 |
| **Git Hooks** | 提交時 | 低 | ⭐⭐ 中 | 本地工作流集成 |
| **Chezmoi** | 手動/自動 | 低 | ⭐⭐⭐ 高 | 大型配置管理 |
| **GitHub Actions** | 延時 | 雲端 | ⭐⭐ 中 | 雲端自動化 |

---

## 4. 安全：敏感資訊過濾策略

### 4.1 敏感檔案識別

**必須排除：**
```bash
# OpenClaw 內部配置
.clawdhub/
.clawhub/
network-state.json

# 個人記憶
MEMORY.md                 # 長期記憶，可能包含個人對話歷史
memory/2026-*.md          # 日記式記錄
memory/*-daily.md

# 憑證和密鑰
*.key
*.pem
.env
credentials.json

# 會話和快取
sessions/
cache/
temp/
```

**必須追踪：**
```bash
# 核心配置
SOUL.md
USER.md
AGENTS.md
IDENTITY.md
TOOLS.md

# 技能和腳本
skills/**/*
scripts/**/*.sh

# 技術記憶
memory/opencode-*.md
memory/optimization-*.md
```

### 4.2 過濾方法選項

| 方法 | 實施複雜度 | 安全性 | 維護成本 | 推薦 |
|-----|----------|--------|---------|------|
| `.gitignore` | 低 | 高 | 低 | ✅ **主要** |
| `rsync --exclude` | 中 | 高 | 中 | ✅ **備選** |
| Git Sparse Checkout | 高 | 中 | 高 | ❌ 過度複雜 |
| `git clean/smudge filters` | 高 | 高 | 高 | ❌ 維護成本高 |
| Pre-commit Hooks | 中 | 高 | 中 | ✅ **補充** |

### 4.3 推薦安全組合

**層次 1：.gitignore（基礎防線）**
```gitignore
repos/
MEMORY.md
memory/2026-*.md
.clawdhub/
.clawhub/
```

**層次 2：Pre-commit Hook（雙重保障）**
```bash
#!/bin/bash
# .git/hooks/pre-commit

STAGED=$(git diff --cached --name-only)

# 檢查敏感檔案
if echo "$STAGED" | grep -vE '(SOUL\.md|USER\.md|AGENTS\.md|scripts/|skills/|memory/(opencode|optimization)-)'; then
  echo "⚠️ 警告：檢查 staged 檔案，可能有敏感資料"
  echo "$STAGED"
  read -p "繼續提交? (y/N) " -n 1 -r
  echo
  [[ $REPLY =~ ^[Yy]$ ]] || exit 1
fi
```

**層次 3：Gitleaks（業界最佳實踐）**
```bash
# 安裝 gitleaks
go install github.com/gitleaks/gitleaks/v8/cmd/gitleaks@latest

# 偵測敏感資料
gitleaks detect --source . --verbose
```

**Pre-commit Hook 整合：**
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.24.2
    hooks:
      - id: gitleaks
```

**證據：**
- [Gitleaks GitHub](https://github.com/gitleaks/gitleaks)
- [Gitleaks Pre-commit Hook](https://github.com/gitleaks/gitleaks/blob/master/README.md)

### 4.4 Git Clean/Smudge Filters（高級範例）

```bash
# 1. 定義 .gitattributes
echo "config.yaml filter=redact-secrets" >> .gitattributes

# 2. 設置 clean filter（git add 時）
git config filter.redact-secrets.clean "sed 's/API_KEY=.*/API_KEY=<REDACTED>/g'"

# 3. 設置 smudge filter（git checkout 時）
git config filter.redact-secrets.smudge "sed 's/<REDACTED>/API_KEY=YOUR_LOCAL_KEY/g'"
```

**注意：** 此方法需要每個使用者本地配置，不適合協作場景。

---

## 5. 實施步驟（基於當前狀態）

### 5.1 當前狀態確認

```bash
# 檢查符號連結
ls -la ~/.openclaw/workspace

# 應顯示：
# ~/.openclaw/workspace -> /home/soulx7010201/MyLLMNote/openclaw-workspace

# 檢查 git status
cd ~/MyLLMNote/openclaw-workspace
git status
```

### 5.2 驗證 .gitignore 配置

確認 `.gitignore` 包含（當前配置）：
```gitignore
# 外部 repos（已驗證有效）
repos/

# 敏感記憶（當前配置）
MEMORY.md
memory/2026-*.md

# OpenClaw 內部（當前配置）
.clawdhub/
.clawhub/
```

### 5.3 創建自動同步腳本

**腳本位置：** `~/MyLLMNote/openclaw-workspace/scripts/auto-sync.sh`

**完整腳本：** 見 3.1 節

**設置執行權限：**
```bash
chmod +x ~/MyLLMNote/openclaw-workspace/scripts/auto-sync.sh
```

### 5.4 配置 Cron 定時任務

```bash
# 編輯 crontab
crontab -e

# 添加以下行（每 6 小時執行一次）
0 */6 * * * /home/user/MyLLMNote/openclaw-workspace/scripts/auto-sync.sh >> /tmp/openclaw-auto-sync.log 2>&1
```

### 5.5 測試自動同步

```bash
# 手動執行測試
~/MyLLMNote/openclaw-workspace/scripts/auto-sync.sh

# 檢查日誌
cat /tmp/openclaw-auto-sync.log

# 檢查 GitHub
gh repo view e2720pjk/MyLLMNote
```

---

## 6. 優化建議：處理 repos/ 目錄

### 6.1 問題分析

```
~/.openclaw/workspace/repos/ 總計: ~340MB
├── llxprt-code/        (估算 182MB, 完整 git repo)
├── CodeWiki/           (估算 83MB, 完整 git repo)
└── notebooklm-py/      (估算 75MB, 完整 git repo)
```

**問題：**
- 這些目錄包含完整的 `.git/` 倉庫
- MyLLMNote 已有 `llxprt-code/` (8.1MB) 和 `CodeWiki/` (3.1MB) 的精簡版本
- 造成約 330MB 的重複空間浪費

### 6.2 解決方案：改為符號連結

```bash
# ===== 步驟 1：優化 repos/（可選但強烈推薦）=====
cd ~/.openclaw/workspace

# 備份現有 repos（以防萬一）
cp -r repos /tmp/repos-backup-$(date +%Y%m%d)

# 移除並重新創建 repos
rm -rf repos
mkdir repos

# 連結到 MyLLMNote 的現有專案
ln -s ~/MyLLMNote/llxprt-code repos/llxprt-code
ln -s ~/MyLLMNote/CodeWiki repos/CodeWiki

# 如果需要 notebooklm-py，可在 MyLLMNote 中創建或保持副本
# ln -s ~/MyLLMNote/notebooklm-py repos/notebooklm-py
# 或：cp -r /tmp/repos-backup-*/notebooklm-py repos/

# ===== 步驟 2：測試 OpenClaw 功能 =====
openclaw help  # 確認符號連結不影響運作

# ===== 步驟 3：驗證 .gitignore =====
cd ~/MyLLMNote
git status openclaw-workspace/  # 確保 repos/ 被忽略

# ===== 步驟 4：提交更新 =====
git add openclaw-workspace/
git commit -m "Optimize openclaw-workspace: convert repos to symlinks"
git push
```

### 6.3 預期結果

- ✅ `~/.openclaw/workspace/` 總大小減少約 330MB
- ✅ OpenClaw 功能不受影響
- ✅ MyLLMNote repo size 保持小（~3.7MB .git）
- ✅ Git-in-git 衝突完全消除

---

## 7. 監控與維護

### 7.1 定期檢查腳本

**腳本位置：** `~/MyLLMNote/openclaw-workspace/scripts/check-sync-status.sh`

```bash
#!/bin/bash
# check-sync-status.sh - 檢查 OpenClaw workspace 同步狀態

cd ~/MyLLMNote/openclaw-workspace

echo "📊 OpenClaw Workspace 同步狀態檢查"
echo "===================================="
echo ""

# 檢查 git 狀態
echo "1. Git 狀態："
git status --short

# 檢查符號連結
echo ""
echo "2. 符號連結："
if [ -L ~/.openclaw/workspace ]; then
    echo "   ✅ 符號連結正常"
    echo "   $HOME/.openclaw/workspace -> $(readlink ~/.openclaw/workspace)"
else
    echo "   ❌ 符號連結異常或不存在"
fi

# 檢查 repos/ 符號連結
echo ""
echo "3. Repos/ 目錄："
if [ -L ~/.openclaw/workspace/repos/llxprt-code ]; then
    echo "   ✅ llxprt-code 是符號連結"
else
    echo "   ⚠️  llxprt-code 不是符號連結（佔用約 182MB）"
fi

# 檢查未追蹤的敏感檔案
echo ""
echo "4. 可能的敏感檔案（未過濾）："
UNTRACKED_SENSITIVE=$(git ls-files --others --exclude-standard | grep -E "MEMORY|2026-.*\.md|\.clawhub" || true)
if [ -z "$UNTRACKED_SENSITIVE" ]; then
    echo "   ✅ 沒有發現潛在問題"
else
    echo "   ⚠️  警告：以下檔案可能應該被 .gitignore 排除："
    echo "$UNTRACKED_SENSITIVE" | sed 's/^/   - /'
fi

# 檢查遠程同步狀態
echo ""
echo "5. 遠程同步："
LOCAL_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
REMOTE_COMMIT=$(git rev-parse origin/main 2>/dev/null || echo "unknown")
if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]; then
    echo "   ✅ 與遠程同步"
else
    echo "   ⚠️  本地與遠程不同步"
    echo "   本地: $LOCAL_COMMIT"
    echo "   遠程: $REMOTE_COMMIT"
fi

echo ""
echo "===================================="
echo "檢查完成"
```

**使用：**
```bash
# 手動執行
~/MyLLMNote/openclaw-workspace/scripts/check-sync-status.sh

# 或加入 cron（每天一次）
0 0 * * * /home/soulx7010201/MyLLMNote/openclaw-workspace/scripts/check-sync-status.sh >> /tmp/openclaw-check.log 2>&1
```

### 7.2 維護清單

| 頻率 | 任務 | 目的 |
|-----|------|------|
| **每週** | 檢查 `/tmp/openclaw-auto-sync.log` | 確認自動同步正常運行 |
| **每週** | 執行 `check-sync-status.sh` | 全面檢查系統狀態 |
| **每月** | 審查 `.gitignore` | 確保新檔案正確過濾 |
| **每月** | 檢查 GitHub repo 大小 | 監控 repo 是否膨脹 |
| **每季** | 測試 `openclaw help` 基本功能 | 確認符號連結不影響 OpenClaw |

### 7.3 監控指標

```bash
# 1. 檢查 repo size
du -sh ~/MyLLMNote/.git
# 預期：< 10MB（如果變得很大，檢查是否有意外 commit）

# 2. 檢查最後自動同步時間
tail -20 /tmp/openclaw-auto-sync.log

# 3. 檢查未追蹤檔案
cd ~/MyLLMNote
git status openclaw-workspace/ --short
# 預期：應該沒有或很少未追蹤檔案

# 4. 檢查符號連結
ls -la ~/.openclaw/workspace/repositories 2>/dev/null || echo "沒有 repositories 目錄"
```

---

## 8. 風險評估與緩解措施

### 8.1 已識別風險

| 風險 | 等級 | 當前狀況 | 緩解措施 |
|-----|------|---------|---------|
| **敏感資訊洩漏** | 🟡 中 | .gitignore 已設定 | ✅ 人工審查 git status<br>✅ pre-commit hook<br>✅ gitleaks 偵測 |
| **Git-in-git 衝突** | 🟡 中 | repos/ 已排除 | ✅ .gitignore 排除<br>🔧 優化為符號連結 |
| **符號連結斷開** | 🟡 中 | 當前正常 | ✅ 定期檢查 `ls -la ~/.openclaw/workspace`<br>✅ 備份重要檔案 |
| **OpenClaw 功能受影響** | 🟢 低 | 現狀正常 | ✅ 已測試基本功能<br>🔧 優化後需再次測試 |
| **MyLLMNote repo size** | 🟡 中 | .git 3.7MB | ✅ repos/ 已排除<br>🔧 優化後更小 |
| **跨平台相容性** | 🟢 低 | Unix only | ✅ 預期在 Unix 環境使用<br>⚠️ Windows 需改用 rsync 方案 |
| **自動同步失敗** | 🟡 中 | 未配置 | 🔧 將配置 cron<br>✅ 日誌記錄 |

### 8.2 恢復策略

```bash
# 如果符號連結斷開
ln -s ~/MyLLMNote/openclaw-workspace ~/.openclaw/workspace

# 如果需要從 GitHub 恢復
cd ~/MyLLMNote
git pull origin main
cd openclaw-workspace
# 重新創建符號連結
ln -s "$(pwd)" ~/.openclaw/workspace

# 如果誤 commit 敏感檔案
git filter-repo --invert-paths --path MEMORY.md --path memory/2026-*.md
git push --force
```

---

## 9. 方案切換指南

### 9.1 如果遇到問題需切換到 rsync 方案

```bash
# 1. 備份當前設置
cd ~/MyLLMNote
cp -r openclaw-workspace openclaw-workspace-backup

# 2. 移除符號連結（如果存在）
if [ -L ~/.openclaw/workspace ]; then
    rm ~/.openclaw/workspace
    # 恢復原始 workspace
    cp -r -L openclaw-workspace-backup ~/.openclaw/workspace
fi

# 3. 創建歸檔目錄
mkdir -p ~/MyLLMNote/openclaw-config

# 4. 停止追踪當前的軟連結目錄
cd ~/MyLLMNote
git rm -r --cached openclaw-workspace 2>/dev/null || true

# 5. 使用 rsync script (見 2.2.5 節)
# 創建 ~/MyLLMNote/scripts/sync-openclaw.sh

# 6. 初始化 rsync 方案
~/MyLLMNote/scripts/sync-openclaw.sh --init

# 7. 設定 cron
crontab -e
# 添加：0 */6 * * * $HOME/MyLLMNote/scripts/sync-openclaw.sh >> $HOME/.openclaw-sync.log 2>&1
```

---

## 10. 最終推薦與行動計劃

### 10.1 當前狀態

✅ **方案：** 軟連結 + .gitignore
✅ **狀態：** 運行正常，openclaw-workspace 已追蹤
✅ **優勢：** 簡單、自動、無需額外需額外維護
⚠️ **問題：** repos/ 目錄佔用 ~340MB（但已用 .gitignore 排除）

### 10.2 短期行動（立即執行）

- [x] 驗證當前軟連結方案運行正常 ✅
- [ ] 創建 `auto-sync.sh` 腳本（見 3.1 節）
- [ ] 設置 cron 定時任務（見 5.4 節）
- [ ] 創建 `check-sync-status.sh` 監控腳本（見 7.1 節）
- [ ] 選擇：是否添加 pre-commit hook（見 3.3 節）
- [ ] 測試自動同步流程

### 10.3 中期行動（1-3 個月）

- [ ] 🔧 **執行優化：** 將 repos/ 改為符號連結到 MyLLMNote（節省 ~330MB）
- [ ] 監控 MyLLMNote repo size 變化
- [ ] 評估是否需要安裝 gitleaks
- [ ] 更新文檔說明版本控制策略

### 10.4 長期行動（3-12 個月）

- [ ] 評估是否需要切換到 rsync 方案
- [ ] 考慮建立獨立的 OpenClaw 配置倉庫
- [ ] 評估是否使用 Chezmoi 進行配置管理
- [ ] 與其他 OpenClaw 使用者分享最佳實踐

---

## 11. 結論

### 11.1 研究總結

| 方案 | 推薦度 | 實施狀態 | 適用場景 |
|------|--------|---------|---------|
| **軟連結 + .gitignore** | ⭐⭐⭐⭐⭐ | ✅ **已實施** | 當前用例推薦 |
| **rsync 同步（方案 D+）** | ⭐⭐⭐⭐ | 🔧 備選 | 未來優化 |
| Git Submodule | ⭐⭐ | ❌ 不推薦 | 複雜度過高 |
| Git Worktree | ⭐⭐ | ❌ 不推薦 | 架構不匹配（單機場景） |
| Bare Repo + Alias | ⭐⭐⭐⭐ | 🔧 未實施 | 重構時考慮 |

### 11.2 最終建議

**繼續使用當前軟連結方案**，原因：
1. ✅ 已證實有效且運行正常
2. ✅ `.gitignore` 配置完善，安全可控
3. ✅ 空間效率高（無檔案重複）
4. ✅ 維護成本低
5. ✅ 適合單機環境

**建議優化：**
1. 添加自動同步腳本 + cron
2. 將 repos/ 改為符號連結（節省 ~330MB）
3. 添加監控腳本定期檢查狀態

### 11.3 關鍵學習

1. **符號連結方案在這個用例是可行的**：簡單、有效、維護成本低
2. **必須嚴格處理 repos/ 目錄**：.gitignore 排除是必須的
3. **rsync 方案提供了更精確的控制**：作為未來優化的備選方案
4. **不要過度設計**：當前方案已滿足需求，複雜的 submodules/worktrees 不必要
5. **行業最佳實踐**：Chezmoi 是 dotfiles 管理的黃金標準（10k+ stars），但在此場景過度設計
6. **安全分層**：.gitignore + pre-commit hook + gitleaks 形成三層防線

---

## 12. 參考文檔

### 12.1 官方文檔
- [Git Submodule Documentation](https://git-scm.com/docs/git-submodule)
- [Git Worktree Documentation](https://git-scm.com/docs/git-worktree)
- [Git Ignore Documentation](https://git-scm.com/docs/gitignore)
- [Git Hooks Documentation](https://git-scm.com/docs/githooks)

### 12.2 社區資源
- [Bare Repo Dotfiles Pattern](https://news.ycombinator.com/item?id=11070797) - StreakyCobra's method
- [j-martin/dotfiles](https://github.com/j-martin/dotfiles) - Bare repo 示例
- [git-worktree-utils](https://github.com/jamesfishwick/git-worktree-utils) - Worktree 管理工具
- [xwmx/nb](https://github.com/xwmx/nb) - 即時同步腳本示例
- [Vinzent03/obsidian-git](https://github.com/Vinzent03/obsidian-git) - Obsidian auto-sync

### 12.3 配置管理工具
- [Chezmoi](https://github.com/twpayne/chezmoi) - 現代 dotfile 管理工具（10k+ stars）
- [GNU Stow](https://www.gnu.org/software/stow/manual/) - 符號連結管理
- [Yadm](https://yadm.io/) - Git-based dotfiles manager
- [Gitleaks](https://github.com/gitleaks/gitleaks) - Secret 偵測工具
- [Git Auto-Commit Action](https://github.com/stefanzweifel/git-auto-commit-action) - GitHub Action for auto commits

### 12.4 內部文檔
- `openclaw-workspace/workspace-version-control-evaluation.md` - 詳細評估報告
- `openclaw-workspace/softlink-evaluation-analysis.md` - 軟連結分析
- `openclaw-workspace/version-control-comparison-summary.md` - 方案對比
- `openclaw-workspace/workspace-version-control-executive-summary.md` - 執行摘要
- `.gitignore` - 當前過濾配置

---

**報告生成時間：** 2026-02-04
**研究方法：** 並行 agent 探索（explore, librarian, oracle）+ 直接工具查詢
**研究者：** OhMyOpenCode Agent System (Sisyphus + Oracle + Explore + Librarian)
**下一步：** 執行 10.2 節"短期行動"清單
