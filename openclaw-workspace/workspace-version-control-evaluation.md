# Workspace 版控方案評估報告

**評估日期：** 2026-02-03
**評估者：** Subagent (workspace-version-control-evaluation)

---

## 執行摘要

經過深入分析，**軟連結方案存在重大缺陷，不建議採用**。繼續推薦使用 **Goal-001 的混合方案（方案 D）**，但需考慮新增對 `repos/` 目錄的 git submodule 處理。

---

## 1. Goal-001 原推薦方案分析（方案 D：混合方案）

### 1.1 方案概要
```
~/.openclaw/workspace/     <-- 真實工作區（本地 git repo，已初始化）
        ↓ rsync（過濾敏感資訊）
~/MyLLMNote/openclaw-archive/  <-- 過濾後的副本（獨立 git repo）
        ↓
GitHub
```

### 1.2 當時選擇此方案的原因

**主要原因：**
1. **最大靈活性**：可完全控制哪些檔案同步
2. **最佳安全性**：可過濾敏感資訊（MEMORY.md、日記式記憶等）
3. **保持獨立性**：OpenClaw workspace 和 MyLLMNote 各自獨立管理
4. **本地完整歷史**：保留 workspace 的完整 git 版本歷史
5. **不影響現有架構**：無需調整 OpenClaw 的現有配置

**適用場景：**
- 需要將 OpenClaw 的配置、腳本、技能檔案歸檔到 GitHub
- 需要過濾敏感的個人記憶數據
- 希望本地保留完整的原始數據

### 1.3 優缺點

| 優點 | 缺點 |
|-----|------|
| ✅ 完全控制同步內容 | ❌ 需要維護 sync 腳本 |
| ✅ 可過濾敏感資訊 | ❌ 有檔案複製（空間浪費） |
| ✅ 本地保留完整 git 歷史 | ❌ 需要定期執行腳本 |
| ✅ 兩個 repo 獨立管理 | ❌ 需要設定 cron 定時任務 |
| ✅ 不影響 OpenClaw運作 | 應 |

---

## 2. 軟連結方案評估（用戶提議方案）

### 2.1 方案概要
```bash
# 步驟 1：移動 workspace
mv ~/.openclaw/workspace ~/MyLLMNote/openclaw-workspace

# 步驟 2：建立軟連結
ln -s ~/MyLLMNote/openclaw-workspace ~/.openclaw/workspace

# 步驟 3：在 MyLLMNote 中提交
cd ~/MyLLMNote
git add openclaw-workspace/
git commit -m "Add OpenClaw workspace for version control"
git push
```

### 2.2 優點

| 項目 | 優點 |
|-----|------|
| 複雜度 | ✅ **極簡**，只需移動目錄和建立軟連結 |
| 空間效率 | ✅ 無檔案重複 |
| 版控整合 | ✅ 自動同步，任何修改都會在 MyLLMNote repo 中追蹤 |
| 維護成本 | ✅ 低，無需額外腳本 |

### 2.3 缺點與重大問題

#### 🔴 問題 1：Git 巢式 Repositories 嚴重衝突

**發現的關鍵問題：**
```
~/.openclaw/workspace/repos/
├── llxprt-code/     (182MB, 完整的 git repo)
└── CodeWiki/        (83MB, 完整的 git repo)
```

這兩個目錄**已經是完整的 git repositories**，且與 ~/MyLLMNote/ 下的同名專案重複：
- `workspace/repos/llxprt-code` (182MB) vs `~/MyLLMNote/llxprt-code` (8.1MB)
- `workspace/repos/CodeWiki` (83MB) vs `~/MyLLMNote/CodeWiki` (3.1MB)

**如果採用軟連結方案，會造成：**
```bash
~/MyLLMNote/
├── .git/                    # MyLLMNote 的 git repo
├── llxprt-code/             # 已有，8.1MB
├── CodeWiki/                # 已有，3.1MB
└── openclaw-workspace/      # ← 軟連結的實體位置
    └── repos/
        ├── llxprt-code/     # git repo 在 git repo 內！🚨
        └── CodeWiki/        # git repo 在 git repo 內！🚨
```

**Git 行為預測：**
- Git 會嘗試將 `workspace/repos/` 下的 `.git/` 目錄加入版本控制
- 如果 Git 不跟隨 symlinks，則無法追蹤 workspace 內容
- 如果 Git 跟隨 symlinks，會造成 git-in-git 問題（Git 會將這些視為單純目錄，而不會識別它們是子 repos）
- `git status` 會報告大量「未追蹤」的檔案
- Git 會嘗試 commit `.git/` 目錄本身，這是**極度不推薦**的做法

#### 🔴 問題 2：空間浪費

```
workspace size: 265MB (實際測量)
├── repos/           265MB  ← 問題核心
├── skills/           256KB
├── scripts/           84KB
├── memory/            64KB
└── 其他配置檔案      <50KB
```

**預估結果：**
- 如果將 workspace 納入 MyLLMNote，將新增約 **265MB** 到 repo
- 其中 **265MB** 是 `repos/` 目錄，包含重複的 git clones
- MyLLMNote 本身已有這兩個專案的精簡版本

#### 🔴 問題 3：敏感資訊無法過濾

**無法區分的檔案：**
```bash
openclaw-workspace/
├── MEMORY.md         # 個人長期記憶（可能敏感）
├── memory/           # 日記式記錄
│   ├── 2026-02-01.md
│   ├── 2026-02-02.md
│   └── ... (包含個人對話個人對話歷史)
├── .clawdhub/        # OpenClaw 內部配置
└── network-state.json # 臨時狀態檔案
```

**軟連結方案的問題：**
- 所有檔案都會被加入 Git 索引
- 無法使用 rsync 的 `--exclude` 參數過濾
- 雖然可以用 `.gitignore`，但需要手動維護，且容易遺漏
- 一旦誤 commit 敏感資料，就需要 rewrite git history

#### 🟡 問題 4：跨平台相容性

- **Unix only**：軟連結在 Windows 上不支援（需要改用 junction/symlink）
- **檔案系統依賴**：某些檔案系統（如 FAT32）不支援符號連結
- Git 配置敏感：`core.symlinks` 配置會影響行為

#### 🟡 問題 5：OpenClaw 依賴性風險

**潛在風險：**
- OpenClaw 可能在初始化或操作時檢查 `~/.openclaw/workspace` 的實際路徑
- 如果 OpenClaw 使用 `realpath()` 或類似函數解析符號連結，可能影響其內部邏輯
- 建議在使用前測試 OpenClaw 的基本功能

---

## 3. 兩方案對比

| 項目 | Git Submodule + 腳本（方案 D） | 軟連結方案 |
|------|------------------------------|-----------|
| **複雜度** | ⚠️ 中等（配置腳本） | ✅ 低（移動+連結） |
| **空間效率** | ❌ 低（複製一份） | ✅ 高（無重複） |
| **版控整合** | ⭐⭐⭐⭐ 過濾後的精確控制 | ⭐⭐ 全部同步，無法過濾 |
| **更新機制** | ⚠️ 需要手動或 cron 觸發 | ✅ 自動（隨 git commit） |
| **跨平台** | ✅ 高（rsync 腳本可調整） | ❌ 低（Unix only） |
| **回滾彈性** | ✅ 高（本地+遠端兩個 repo） | ⚠️ 中（同一 repo） |
| **OpenClaw 兼容性** | ✅ 高（完全不影響） | ⚠️ 需測試（符號連結） |
| **敏感資料保護** | ✅ 高（rsync exclude） | ❌ 低（容易誤 commit） |
| **Git repo size** | ✅ 低（~500KB 過濾後） | ❌ 高（~265MB 包含重複） |
| **Git 巢式 repos** | ✅ 可排除 `repos/` | 🔴 衝突（repos/ 是 git repos） |
| **維護成本** | ⚠️ 中等（腳本、cron） | ✅ 低（一次性設定） |

---

## 4. 潛在問題深入分析

### 4.1 OpenClaw 讀取 workspace 時的符號連結行為

**推測 OpenClaw 行為：**
- OpenClaw 的 Workspace 系統通常使用相對路徑或絕對路徑操作
- 符號連結在大多數 Unix 系統上是透明的
- 如果 OpenClaw 使用 `os.path.realpath()` 類似函數，會解析為實際路徑，但功能不應受影響

**測試建議（如果選軟連結方案）：**
```bash
# 測試基本功能
ls -la ~/.openclaw/workspace  # 應該顯示符號連結
cat ~/.openclaw/workspace/SOUL.md  # 應該正確讀取

# 測試 OpenClaw 的基本操作
openclaw help  # 檢查是否能正常啟動
```

### 4.2 Git 版控時的 .gitignore 設定

**軟連結方案需要的 .gitignore：**
```gitignore
# OpenClaw 內部配置
.clawdhub/
.clawhub/
network-state.json*
*.tmp

# 敏感記憶檔案
memory/2026-*.md
MEMORY.md

# Git repos（非常關鍵！）
repos/**/.git/

# 其他臨時檔案
reports/
migration_report.md
```

**問題：**
- `repos/**/.git/` 可能無法完全排除巢式 git 的問題
- Git 仍會嘗試 commit `repos/` 的檔案內容（不包括 .git 目錄）
- 這會導致 commit 265MB 的重複內容

### 4.3 敏感內容處理

**建議的處理策略（軟連結方案）：**
1. 仔細審查 `MEMORY.md` 內容，確定是否包含敏感個人資訊
2. 將所有 `memory/2026-*.md` 加入 `.gitignore`
3. 僅保留重要的技術記憶檔案（如 `opencode-*.md`）
4. 移除 `.clawdhub/` 和任何 OpenClaw 內部配置

### 4.4 .git 目錄的大小和歷史

**當前狀況：**
```bash
~/.openclaw/workspace/.git/  # 116KB，無 commits
```

**軟連結方案下的預期：**
```
MyLLMNote repo size increase:
- Configuration files: ~50KB
- skills/: ~256KB
- scripts/: ~84KB
- memory/ (filtered): ~30KB
- repos/: ~265MB (問題！)
Total: ~265.4MB 新增
```

**對 Git 的影響：**
- 每次修改 repos/ 中的檔案，都會增加 Git DB 大小
- 這些 repos 本身有完整的 git 歷史，會造成 Git 壓縮後仍佔用大量空間
- MyLLMNote 的 clone/pull 速度會顯著變慢

---

## 5. 最終推薦

### 🏆 推薦方案：**改進的混合方案（方案 D +）**

**核心改進：** 將 `repos/` 目錄處理為 **Git Submodule** 或 **Git Subtree**

#### 5. 1 架構設計

```
~/.openclaw/workspace/                    <-- OpenClaw 實際工作區
├── SOUL.md, AGENTS.md 等                 (配置檔案)
├── skills/                               (個人技能)
├── scripts/                              (個人腳本)
├── memory/                               (記憶憶檔案)
└── repos/                                (保持原樣，或改為 submodules)
    ├── llxprt-code/                      (保持為相對符號連結到 ~/MyLLMNote/llxprt-code)
    └── CodeWiki/                         (保持為相對符號連結到 ~/MyLLMNote/CodeWiki)

        ↓ rsync（過濾敏感資訊 + 排除 repos/）

~/MyLLMNote/openclaw-config/               <-- 歸檔到 GitHub
├── @SOUL.md
├── @AGENTS.md
├── .gitignore                            (過濾敏感檔案)
└── (不包含 repos/)
```

#### 5.2 優化點

**改進 1：處理 `repos/` 目錄**
```bash
# 選項 A：在 workspace 中將 repos/ 改為符號連結到 MyLLMNote
cd ~/.openclaw/workspace
rm -rf repos/
ln -s ~/MyLLMNote/llxprt-code repos/llxprt-code
ln -s ~/MyLLMNote/CodeWiki repos/CodeWiki

# 選項 B：在 rsync 中完全排除 repos/
# 這樣 MyLLMNote 中僅歸檔配置檔案，不歸檔外部 repos
```

**改進 2：增強 rsync 過濾規則**
```bash
#!/bin/bash
# ~/MyLLMNote/scripts/sync-openclaw.sh

SOURCE="$HOME/.openclaw/workspace"
TARGET="$HOME/MyLLMNote/openclaw-config"

rsync -av --delete \
    --exclude=".clawdhub/" \
    --exclude=".clawhub/" \
    --exclude="network-state.json*" \
    --exclude="*.tmp" \
    --exclude=".git/" \
    --exclude="repos/" \              # 排除外部 repos
    --exclude="memory/2026-*.md" \    # 排除日記式記憶
    --exclude="MEMORY.md" \           # 排除長期記憶
    --include="memory/opencode-*.md" \ # 包含技術記憶
    "$SOURCE/" "$TARGET/"

cd "$TARGET"
git add .
git diff --cached --quiet || git commit -m "Sync OpenClaw config $(date '+%Y-%m-%d %H:%M:%S')"
git push

echo "✅ OpenClaw config synced (excluding repos/ and sensitive files)"
```

**改進 3：.gitignore 設定**
```gitignore
# OpenClaw 內部
.clawdhub/
.clawhub/
network-state.json*
*.tmp

# 敏感記憶檔案
memory/2026-*.md
MEMORY.md
```

#### 5.3 執行步驟

**步驟 1：優化 workspace 的 repos/（可選）**
```bash
# 如果希望節省空間，將 repos/ 改為符號連結
cd ~/.openclaw/workspace
rm -rf repos/
mkdir repos/
ln -s ~/MyLLMNote/llxprt-code repos/llxprt-code
ln -s ~/MyLLMNote/CodeWiki repos/CodeWiki
```

**步驟 2：初始化 MyLLMNote 歸檔目錄**
```bash
cd ~/MyLLMNote
mkdir -p openclaw-config
cd openclaw-config
git init
# 可選：創建獨立的 GitHub repo
# git remote add origin https://github.com/e2720pjk/openclaw-config.git
```

**步驟 3：創建同步腳本**
```bash
# 將上面的腳本保存到 ~/MyLLMNote/scripts/sync-openclaw.sh
chmod +x ~/MyLLMNote/scripts/sync-openclaw.sh
```

**步驟 4：首次執行同步**
```bash
~/MyLLMNote/scripts/sync-openclaw.sh
```

**步驟 5：設定 cron 定時任務**
```bash
# 每 6 小時同步一次
crontab -e
# 添加：
0 */6 * * * $HOME/MyLLMNote/scripts/sync-openclaw.sh >> $HOME/.openclaw-sync.log 2>&1
```

---

## 6. 為何不推薦軟連結方案

| 原因 | 詳細說明 |
|-----|---------|
| **Git 巢式 repos 衝突** | `repos/` 包含完整的 git repos，會造成 git-in-git 問題 |
| **空間浪費嚴重** | 增加約 265MB，且 265MB 是重複的外部專案 clones |
| **無法過濾敏感資料** | 所有檔案會被加入 Git，容易誤 commit 個人記憶 |
| **MyLLMNote 已有這些專案** | `llxprt-code` 和 `CodeWiki` 已存在於 MyLLMNote |
| **repo size 膨脹** | 會嚴重拖慢 clone/pull 速度 |
| **版本歷史混亂** | workspace 的修改會混入 MyLLMNote 的 commit 歷史 |
| **無法獨立控制** | 不能單獨回滾 OpenClaw 配置而不影響 MyLLMNote |

---

## 7. 總結

### 推薦方案：**改進的混合方案（方案 D +）**

**核心改進：**
- ✅ 將 `repos/` 完全排除在同步之外（或改為符號連結到 MyLLMNote）
- ✅ 保持 rsync 過濾機制
- ✅ 歸檔的repo 大小減少至約 ~500KB（vs 軟連結方案的 ~265MB）
- ✅ 敏感資料完全可控
- ✅ OpenClaw 和 MyLLMNote 完全獨立管理

### 關鍵優勢
1. **不影響 OpenClaw 運作**：workspace 保持原樣
2. **空間效率高**：只歸檔配置檔案，不歸檔外部 repos
3. **安全性最佳**：可過濾所有的敏感記憶和配置
4. **Git repo size 小**：~500KB vs ~265MB
5. **維護簡單**：一個腳本 + cron
6. **靈活性高**：可隨時調整同步內容

### 如果堅持使用軟連結方案

**必須處理的問題：**
1. 🔴 必須將 `repos/` 改為符號連結到 MyLLMNote 的現有專案
2. 🔴 必須仔細設定 `.gitignore` 過濾所有敏感檔案
3. 🔴 必須測試 OpenClaw 的基本功能確認符號連結兼容
4. 🟡 考慮使用 `git filter-repo` 在首次 commit 前清理歷史

**最小可行步驟：**
```bash
# 1. 優化 repos/
cd ~/.openclaw/workspace
rm -rf repos/
mkdir repos/
ln -s ~/MyLLMNote/llxprt-code repos/llxprt-code
ln -s ~/MyLLMNote/CodeWiki repos/CodeWiki

# 2. 測試 OpenClaw 功能
openclaw help

# 3. 移動和建立軟連結
mv ~/.openclaw/workspace ~/MyLLMNote/openclaw-workspace
ln -s ~/MyLLMNote/openclaw-workspace ~/.openclaw/workspace

# 4. 在 MyLLMNote 中設定 .gitignore
cd ~/MyLLMNote
cat > openclaw-workspace/.gitignore << 'EOF'
.clawdhub/
.clawhub/
network-state.json*
*.tmp
memory/2026-*.md
MEMORY.md
repos/
EOF

# 5. 提交測試
git add openclaw-workspace/
git add openclaw-workspace/.gitignore
git commit -m "Add OpenClaw workspace (filtered)"
git status  # 檢查是否有遺漏的敏感檔案
```

---

## 8. 行動建議

### 立即執行（推薦）
1. 採用改進的混合方案（方案 D +）
2. 將 `repos/` 改為符號連結到 MyLLMNote 現有專案（節省 265MB）
3. 創建 rsync 同步腳本並測試
4. 設定 cron 定時任務

### 如果選擇軟連結方案（需謹慎）
1. ⚠️ 先進行 OpenClaw 功能測試
2. ⚠️ 嚴格設定 `.gitignore` 並人工檢查 git status
3. ⚠️ 必須處理 `repos/` 問題
4. ⚠️ 首次 commit 前審查所有 staged 檔案

---

**評估結論：軟連結方案雖然簡單，但由於Git 巢式 repos 衝突、空間浪費、無法過濾敏感資料等致命問題，**不推薦採用**。繼續使用改進的混合方案（方案 D +）是最佳選擇。**
