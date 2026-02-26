# OpenClaw 上下文版控研究 - 綜合結果報告

**研究日期**: 2026-02-04
**研究範圍**: 版本控制策略選項（Submodule、Worktree、腳本同步）
**目標**: 推薦最佳方案並提供實施步驟

---

## 執行摘要

**推薦方案**: 軟連結 + 改進的 .gitignore（改良版混合方案）

**核心原因**:
1. ✅ **簡單可靠**: 一行軟連結命令，自動同步
2. ✅ **節省空間**: 避免重複儲存（vs rsync 雙副本）
3. ✅ **靈活過濾**: .gitignore 可精確控制版本內容
4. ✅ **對 OpenClaw 無影響**: 軟連結保持路徑不變
5. ✅ **已在使用**: 當前系統已採用此方案（部分實作）

**關鍵發現**:
- `~/.openclaw/workspace/repos/` 目錄已存在 (340MB)
- MyLLMNote 已有 CodeWiki (3.1MB) 和 llxprt-code (8.2MB)
- 已有完善腳本: `~/MyLLMNote/scripts/setup-openclaw-sync.sh`
- .gitignore 已配置過濾規則

---

## 1. 現有系統狀態分析

### 1.1 目錄結構

```
~/.openclaw/workspace/                      ← OpenClaw 實際工作區 (軟連結)
├── SOUL.md, AGENTS.md, MEMORY.md         (配置檔案)
├── skills/, scripts/, memory/             (個人檔案)
├── repos/                               (340MB - 需要優化)
└── .gitignore                           (已配置過濾規則)

~/MyLLMNote/                             ← Git 倉庫
├── openclaw-workspace/                   ← 軟連結指向 ~/.openclaw/workspace
│   ※ 已在 MyLLMNote 的 git 控制之下
├── CodeWiki/                            (3.1MB)
├── llxprt-code/                         (8.2MB)
└── scripts/setup-openclaw-sync.sh        (rsync 同步腳本)
```

### 1.2 Git 狀態

**MyLLMNote Repository**:
- Remote: `git@github.com:e2720pjk/MyLLMNote.git`
- 最新 commit: "docs: complete OpenClaw context version control research"
- 分支: main

**Git Workflow**:
1. `~/.openclaw/workspace/` → 軟連結 → `~/MyLLMNote/openclaw-workspace/`
2. `~/MyLLMNote/` 主要 Git 倉庫
3. openclaw-workspace/ 已納入 git 索引（透過 .gitignore 過濾）

### 1.3 .gitignore 配置分析

現行 `.gitignore` (in `~/MyLLMNote/openclaw-workspace/`):
```gitignore
# OpenClaw 內部配置（敏感）
.clawdhub/
.clawhub/
network-state.json*
*.tmp
*.log

# 敏感記憶檔案
MEMORY.md
memory/2026-*.md
memory/*-daily.md

# 外部 git repos（避免 git-in-git）
repos/

# OpenCode 內部配置
.opencode/
.opencode.json*
```

**保留的重要檔案**:
```gitignore
!reports/           !*-report.md
!*-evaluation.md    !*-summary.md
!memory/opencode-*.md
!memory/optimization-*.md
!scripts/           !skills/
!docs/
```

---

## 2. 版控策略選項對比

| 方案 | 複雜度 | 空間效率 | 靈活性 | 對 OpenClaw 影響 | 自動化 | 推薦度 |
|------|--------|----------|--------|-----------------|--------|--------|
| **軟連結 + .gitignore** | 🟢 低 | 🟢 優秀 | 🟡 中 | ✅ 無影響 | 🟢 自動 | ⭐⭐⭐⭐⭐ |
| **rsync 混合方案** | 🟡 中 | 🔴 雙副本 | 🟢 高 | ✅ 無影響 | 🔴 需 cron | ⭐⭐⭐ |
| **Git Submodule** | 🔴 高 | 🟢 優秀 | 🔴 低 | ⚠️ 需測試 | 🔴 需 init | ⭐⭐ |
| **Git Worktree** | 🔴 高 | 🔴 雙副本 | 🔴 低 | ✅ 無影響 | 🔴 需 sync | ⭐⭐ |

---

## 3. 各方案詳細分析

### 3.1 方案 A: 軟連結 + .gitignore（推薦）✅

#### 架構
```
~/.openclaw/workspace/                     ← OpenClaw 實際工作區 (真實目錄)
    ↓ 軟連結
~/MyLLMNote/openclaw-workspace/           ← MyLLMNote Git 倉庫 (軟連結)
    ↓ commit/push
GitHub: e2720pjk/MyLLMNote.git
```

#### 實施步驟

**步驟 1: 確認現有狀態**
```bash
# 檢查軟連結
ls -la ~/.openclaw/workspace
# 應該顯示: ~/.openclaw/workspace -> /home/soulx7010201/MyLLMNote/openclaw-workspace

# 檢查 Git 狀態
cd ~/MyLLMNote
git status
git remote -v
```

**步驟 2: 優化 repos/ 目錄（關鍵）**
```bash
# 備份現有 repos（以防萬一）
cd ~/.openclaw/workspace
mv repos /tmp/repos-backup-$(date +%Y%m%d)

# 建立新 repos 目錄並使用軟連結
mkdir repos
ln -s ~/MyLLMNote/CodeWiki repos/CodeWiki
ln -s ~/MyLLMNote/llxprt-code repos/llxprt-code

# 驗證
ls -la repos/
# 應該顯示: CodeWiki -> ~/MyLLMNote/CodeWiki
#           llxprt-code -> ~/MyLLMNote/llxprt-code

# 測試 OpenClaw 運作
openclaw help  # 確認功能正常
```

**步驟 3: 檢視並調整 .gitignore**
```bash
cd ~/MyLLMNote/openclaw-workspace

# 查看現有 .gitignore
cat .gitignore

# 如需調整，使用編輯器修改
# vim .gitignore
```

**步驟 4: 提交變更到 MyLLMNote**
```bash
cd ~/MyLLMNote

# 檢視變更
git status

# 添加變更
git add openclaw-workspace/.gitignore
git add openclaw-workspace/repos/  # (如果有新連結)

# 提交
git commit -m "优化 OpenClaw workspace: 使用 repos 软链接节省空间 (340MB -> ~0MB)"

# 推送
git push origin main
```

**步驟 5: 驗證**
```bash
# 在 MyLLMNote 中驗證
cd ~/MyLLMNote
git status
git log --oneline -5

# 確認 OpenClaw 正常運作
openclaw --help
# 或透過 Telegram Bot 測試
```

#### 優點
1. ✅ **零複製成本**: 軟連結不實際複製檔案
2. ✅ **即時同步**: 修改立即反映，無需手動同步
3. ✅ **簡單直觀**: 一次性設置，之後隱式運作
4. ✅ **原生 Git 支援**: Git 原生處理軟連結
5. ✅ **對 OpenClaw 無影響**: `~/.openclaw/workspace` 路徑保持不變
6. ✅ **版控簡單**: 直接納入 MyLLMNote 的 Git 管理

#### 缺點
1. ⚠️ **需要 .gitignore**: 手動配置過濾規則
2. ⚠️ **Windows 支援較差**: 跨平台需注意

---

### 3.2 方案 B: rsync 混合方案（備選）

#### 架構
```
~/.openclaw/workspace/                       ← OpenClaw 實際工作區
    ↓ rsync (定期同步)
~/MyLLMNote/openclaw-config/                 ← 歸檔目錄 (Git)
    ↓ commit/push
GitHub: e2720pjk/MyLLMNote.git
```

#### 實施步驟

**步驟 1: 使用現有腳本**
```bash
# 首次初始化
~/MyLLMNote/scripts/setup-openclaw-sync.sh --init

# 之後定期同步
~/MyLLMNote/scripts/setup-openclaw-sync.sh
```

**步驟 2: 設定 cron 自動同步**
```bash
crontab -e
# 添加：
# 0 */6 * * * /home/soulx7010201/MyLLMNote/scripts/setup-openclaw-sync.sh >> /home/soulx7010201/.openclaw-sync.log 2>&1
```

#### 優點
1. ✅ **完全獨立**: 備份與使用完全分離
2. ✅ **精確控制**: rsync 過濾規則靈活
3. ✅ **安全性高**: 誤 commit 風險較低
4. ✅ **跨平台**: 可移植到 Windows

#### 缺點
1. ❌ **雙副本**: 佔用雙倍磁碟空間
2. ❌ **需手動同步**: 非即時，需 cron 或手動觸發
3. ❌ **維護成本**: 需管理 cron 任務和腳本

#### 何時使用此方案？
- 不信任 .gitignore 的過濾
- 希望備份完全獨立
- 可能移植到 Windows
- 需要更精確的版本控制範圍

---

### 3.3 方案 C: Git Submodule（不推薦）

#### 架構
```bash
git submodule add <repo-url> openclaw-workspace/repos/llxprt-code
```

#### 為什麼不推薦
1. ❌ **複雜度高**: `git submodule init/update` 步驟
2. ❌ **OpenClaw 影響**: "detached HEAD" 狀態可能導致問題
3. ❌ **更新複雜**: 需要 `git submodule update`
4. ❌ **clone 負擔**: 其他用戶需下載多個 repo
5. ❌ **維護成本**: 子模組狀態管理容易出錯

#### 何時使用？
- 真的需要追蹤 `repos/` 的特定 commit 版本
- 這些 repo 沒有自己的遠端倉庫

---

### 3.4 方案 D: Git Worktree（適用特定場景）

#### 架構
```bash
git init --bare ~/.openclaw-config.git
git worktree add ~/.openclaw/workspace/ main
git worktree add ~/MyLLMNote/openclaw-workspace/ main
```

#### 適用場景
- 需要不同分支在不同位置（prod vs dev）
- 需要分支感知的配置管理

#### 不推薦原因
1. ❌ **複雜度高**: 需要 worktree 管理命令
2. ❌ **雙副本**: 兩個 worktree 都是完整副本
3. ❌ **需要同步**: 修改後需手動 sync

---

## 4. 記憶檔案處理策略

### 4.1 檔案分類

| 檔案類型 | 路徑 | 是否版本控制 | 原因 |
|---------|------|-------------|------|
| **核心配置** | `SOUL.md`, `USER.md`, `IDENTITY.md` | ✅ 版控 | 定義代理行為，應追踪 |
| **規則文件** | `AGENTS.md`, `TOOLS.md`, `HEARTBEAT.md` | ✅ 版控 | 運作規則和工具指引 |
| **長期記憶** | `MEMORY.md` | ❌ 排除 | 個人長期記憶，可能含敏感資料 |
| **日記記憶** | `memory/2026-*.md` | ❌ 排除 | 日記式對話歷史，含個人資訊 |
| **技術記憶** | `memory/opencode-*.md`, `memory/optimization-*.md` | ✅ 版控 | 技術知識，值得保存 |
| **Script** | `scripts/*.sh` | ✅ 版控 | 自動化腳本 |
| **Skill** | `skills/**/*` | ✅ 版控 | 技能文件和知識庫 |
| **報告** | `*-report.md`, `*-evaluation.md` | ✅ 版控 | 研究報告和分析結果 |
| **外部專案** | `repos/` | ❌ 排除 | 已有自己的 Git 倉庫 |

### 4.2 推薦的過濾規則

```gitignore
# ===== 敏敏資料（絕對不提交）=====
*.key
*.pem
.env
credentials.json
.secrets/

# ===== OpenClaw 內部配置=====
.clawdhub/
.clawhub/
network-state.json*
.opencode/
.opencode.json*

# ===== 記憶檔案（排除個人記憶，保留技術記憶）=====
MEMORY.md
memory/2026-*
memory/*-daily.md
# 保留技術記憶:
!memory/opencode-*.md
!memory/optimization-*.md
!memory/*-research.md

# ===== 外部 Git Repos（避免 git-in-git）=====
repos/

# ===== 臨時檔案=====
*.log
*.tmp
*.swp
*.bak
*.pid
```

### 4.3 記憶檔案備份策略

**推薦：分層備份**
1. **技術記憶**: Git 版控（MyLLMNote）
2. **個人記憶**: 本地備份或加密後推送到私有 repo

```bash
# 可選：加密備份 MEMORY.md
openssl enc -aes-256-cbc -salt -in MEMORY.md -out MEMORY.md.enc

# 解密
openssl enc -d -aes-256-cbc -in MEMORY.md.enc -out MEMORY.md
```

---

## 5. 敏感資料處理

### 5.1 識別敏感資料類型

| 類型 | 範例 | 處理方式 |
|------|------|----------|
| API Keys | `.env`, credentials.json | .gitignore + 佔位符文件 |
| 個人記憶 | `MEMORY.md`, `memory/2026-*.md` | .gitignore 或加密備份 |
| OpenClaw 配置 | `.clawdhub/`, `.clawhub/` | .gitignore |
| 網絡狀態 | `network-state.json*` | .gitignore |

### 5.2 使用佔位符文件範例

```bash
# .env.example
OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxx
TELEGRAM_BOT_TOKEN=your_bot_token_here
DATABASE_URL=postgresql://user:pass@localhost/db
```

---

## 6. 整合方案推薦（最佳實踐）

### 6.1 推薦架構

```bash
# ===== 主要工作區: ~/.openclaw/workspace/ =====
SOUL.md              ✅ 版控: 定義代理人格
USER.md              ✅ 版控: 使用者偏好
IDENTITY.md          ✅ 版控: 代理身份
AGENTS.md            ✅ 版控: 運作規則
TOOLS.md             ✅ 版控: 工具指引
HEARTBEAT.md         ✅ 版控: 主動任務列表

memory/              📁 記憶目錄
├── MEMORY.md        ❌ 排除: 長期個人記憶（本地備份）
├── 2026-02-04.md    ❌ 排除: 日記記憶（本地備份）
├── opencode-*.md    ✅ 版控: 技術記憶
└── optimization-*.md ✅ 版控: 優化記憶

skills/              ✅ 版控: 技能知識庫
scripts/             ✅ 版控: 自動化腳本
docs/                ✅ 版控: 文件

repos/               ❌ 排除: 外部專案
├── CodeWiki/        → 軟連結 → ~/MyLLMNote/CodeWiki/
└── llxprt-code/     → 軟連結 → ~/MyLLMNote/llxprt-code/

.clawdhub/           ❌ 排除: 內部配置
network-state.json*  ❌ 排除: 網絡狀態
```

### 6.2 自動化策略

**推薦：Git 週期性提交**
```bash
#!/bin/bash
# sync-openclaw-context.sh

WORKSPACE="$HOME/.openclaw/workspace"
LOG="$HOME/.openclaw-sync.log"

cd "$WORKSPACE"

# 提交技術記憶
if [ -d "memory" ]; then
  git add memory/opencode-*.md memory/optimization-*.md
fi

# 提交配置檔案
git add *.md skills/ scripts/ docs/

# 檢查是否有變更
if ! git diff --cached --quiet; then
  git commit -m "Auto-sync: OpenClaw context $(date +%Y-%m-%d_%H:%M)"
  git push origin main
fi

# 本地備份記憶檔案
rsync -avz --backup --backup-dir="$HOME/.memory-backup/$(date +%Y%m%d)" \
  memory/ MEMORY.md "$HOME/memory-backup/" 2>/dev/null || true
```

**Cron 設定**:
```cron
# 每 6 小時同步一次
0 */6 * * * /home/soulx7010201/MyLLMNote/scripts/sync-openclaw-context.sh >> /home/soulx7010201/.openclaw-sync.log 2>&1
```

---

## 7. 風險評估

| 風險 | 影響 | 緩解措施 |
|------|------|----------|
| **誤提交敏感資料** | 🔴 高 | 嚴格的 .gitignore + commit 前人工審查 |
| **Git-in-git 衝突** | 🔴 高 | 排除 `repos/` 目錄或使用軟連結 |
| **軟連結失效** | 🟡 中 | 定期檢查連結，備份重要檔案 |
| **記憶檔案遺失** | 🔴 高 | 本地備份 + 加密遠端備份 |
| **OpenClaw 功能受影響** | 🟡 中 | 測試確保軟連結不影響運作 |

---

## 8. 實施建議與時程

### 8.1 立即可做（本日）

1. ✅ **確認軟連結已正確設定**
   ```bash
   ls -la ~/.openclaw/workspace
   ```

2. ✅ **優化 repos/ 目錄**
   ```bash
   # 備份現有 repos
   cd ~/.openclaw/workspace
   mv repos /tmp/repos-backup-$(date +%Y%m%d)

   # 建立軟連結
   mkdir repos
   ln -s ~/MyLLMNote/CodeWiki repos/CodeWiki
   ln -s ~/MyLLMNote/llxprt-code repos/llxprt-code
   ```

3. ✅ **測試 OpenClaw**
   ```bash
   openclaw --help
   # 或透過 Telegram Bot 測試
   ```

4. ✅ **更新 .gitignore**
   ```bash
   cd ~/MyLLMNote/openclaw-workspace
   # 根據第 4.3 節更新過濾規則
   ```

5. ✅ **提交到 MyLLMNote**
   ```bash
   cd ~/MyLLMNote
   git add openclaw-workspace/.gitignore
   git add openclaw-workspace/repos/  # (如果有新連結)
   git commit -m "优化 OpenClaw workspace: 使用 repos 软链接节省空间"
   git push origin main
   ```

### 8.2 一週內完成

1. ⏳ **建立備份策略**
   - 本地備份目錄: `~/memory-backup/`
   - 定期 rsync 記憶檔案

2. ⏳ **設定自動同步腳本**
   - 建立周期性 Git 提交腳本
   - 設定 cron 任務

### 8.3 未來可選

1. ⏳ **加密敏感記憶檔案**
   - 使用 OpenSSL 加密 MEMORY.md
   - 推送到私有 repo

2. ⏳ **記憶檔案分倉**
   - 技術記憶: MyLLMNote（公開）
   - 個人記憶: Private repo（加密）

---

## 9. 快速參考

### 9.1 現狀檢查命令

```bash
# 檢查軟連結
ls -la ~/.openclaw/workspace
ls -la ~/.openclaw/workspace/repos/

# 檢查 Git 狀態
cd ~/MyLLMNote
git status
git remote -v
git log --oneline -5

# 檢查記憶檔案
ls -lh ~/.openclaw/workspace/memory/
du -sh ~/.openclaw/workspace/

# 檢查同步腳本
cat ~/MyLLMNote/scripts/setup-openclaw-sync.sh
```

### 9.2 常用操作

```bash
# 優化 repos/ (節省 340MB)
cd ~/.openclaw/workspace
mv repos /tmp/repos-backup-$(date +%Y%m%d)
mkdir repos
ln -s ~/MyLLMNote/CodeWiki repos/CodeWiki
ln -s ~/MyLLMNote/llxprt-code repos/llxprt-code

# 同步到 GitHub
cd ~/MyLLMNote
git add openclaw-workspace/
git commit -m "更新 OpenClaw workspace"
git push origin main
```

---

## 10. 結論

**推薦方案**: 軟連結 + 改進的 .gitignore（已在使用，只需優化）

**核心優勢**:
1. ✅ 當前系統已採用此方案，只需優化
2. ✅ 一次設置，自動運作
3. ✅ 對 OpenClaw 無影響
4. ✅ 節省 340MB 空間（repos/ 優化後）
5. ✅ 靈活過濾敏感資料
6. ✅ Git 原生支援，無需額外工具

**次選方案**: rsync 混合方案（現有腳本已準備好，適用特殊需求）

**不推薦**: Git Submodule 和 Git Worktree（複雜度高，收益有限）

---

## 11. 相關文件

本次參考的研究文件：
1. **workspace-version-control-executive-summary.md** - 執行摘要（軟連結 vs rsync）
2. **softlink-evaluation-analysis.md** - 軟連結方案詳細評估
3. **script-based-sync-research.md** - 腳本同步研究結果
4. **workspace-version-control-evaluation.md** - 完整評估報告
5. **version-control-comparison-summary.md** - 方案對比摘要

---

*研究完成時間: 2026-02-04 UTC*
*研究人員: OpenClaw Sisyphus Agent (多代理協作)*
