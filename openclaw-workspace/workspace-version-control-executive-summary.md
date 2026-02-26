# Workspace 版控方案評估 - 執行摘要

**評估日期：** 2026-02-03
**任務：** 評估軟連結方案是否為最佳選擇
**結論：** ❌ **軟連結方案不推薦**，建議採用改進的混合方案（方案 D +）

---

## 🎯 核心發現

### 致命問題 1：`repos/` 目錄 = 265MB

```
~/.openclaw/workspace/repos/
├── llxprt-code/     (182MB, 完整的 git repo)
└── CodeWiki/        (83MB, 完整的 git repo)
```

**問題：**
- 這兩個目錄已經是完整的 git repos
- MyLLMNote 已有這些專案（分別為 8.1MB 和 3.1MB）
- 如果用軟連結方案進入 MyLLMNote，會造成 **git-in-git 巢式 repos 嚴重衝突**

### 致命問題 2：無法過濾敏感資料

- `MEMORY.md` - 個人長期記憶
- `memory/2026-*.md` - 日記式個人對話歷史
- `.clawdhub/`, `.clawhub/` - OpenClaw 內部配置

**軟連結方案的問題：**
- 所有檔案都會被加入 Git 索引
- 只能用 `.gitignore` 過濾，容易誤 commit

---

## 📊 兩方案對比

| 項目 | 改進的混合方案（方案 D +） | 軟連結方案 |
|------|--------------------------|-----------|
| **複雜度** | 🟡 中 | 🟢 低 |
| **MyLLMNote repo size** | 🟢 +500KB | 🔴 +265MB |
| **Git 巢式 repos** | 🟢 完全排除 | 🔴 嚴重衝突 |
| **敏感資料保護** | 🟢 高（rsync exclude） | 🔴 低（需手動） |
| **MyLLMNote 已有專案** | 🟢 不重複 | 🔴 重複 |
| **空間效率** | 🟡 複製一次 | 🟢 無億複 |
| **OpenClaw 影響** | 🟢 無 | 🟡 需測試 |

---

## 🏆 推薦：改進的混合方案（方案 D +）

### 架構
```
~/.openclaw/workspace/                         ← OpenClaw 實際工作區
├── SOUL.md, AGENTS.md, MEMORY.md 等          (配置)
├── skills/, scripts/, memory/                 (個人檔案)
└── repos/ → (可選: 符號連結到 MyLLMNote)       ← 關鍵優化！
        ↓ rsync (過濾敏感資料 + 排除 repos)
~/MyLLMNote/openclaw-config/                   ← 歸檔到 GitHub
└── (乾淨的配置，不含敏感資料，不含 repos)
```

### 執行步驟

#### 1. 優化 `repos/`（節省 265MB）
```bash
cd ~/.openclaw/workspace
mv repos /tmp/repos-backup  # 備份以防萬一
mkdir repos
ln -s ~/MyLLMNote/llxprt-code repos/llxprt-code
ln -s ~/MyLLMNote/CodeWiki repos/CodeWiki
```

#### 2. 使用準備好的腳本
```bash
# 首次初始化
~/MyLLMNote/scripts/setup-openclaw-sync.sh --init

# 之後定期同步
~/MyLLMNote/scripts/setup-openclaw-sync.sh
```

#### 3. 設定 cron（自動同步）
```bash
crontab -e
# 添加：
0 */6 * * * $HOME/MyLLMNote/scripts/setup-openclaw-sync.sh >> $HOME/.openclaw-sync.log 2>&1
```

---

## ⚠️ 如果堅持用軟連結方案

**必須處理這些問題：**

### 1. 優化 `repos/`（強制）
```bash
cd ~/.openclaw/workspace
mv repos /tmp/repos-backup
mkdir repos
ln -s ~/MyLLMNote/llxprt-code repos/llxprt-code
ln -s ~/MyLLMNote/CodeWiki repos/CodeWiki
```

### 2. 嚴格的 `.gitignore`
```bash
cat > ~/.openclaw/workspace/.gitignore << 'EOF'
.clawdhub/
.clawhub/
network-state.json*
*.tmp
memory/2026-*.md
MEMORY.md
repos/
EOF
```

### 3. 測試 OpenClaw 功能
```bash
openclaw help  # 確認符號連結不影響運作
```

### 4. 手動審查 git status
```bash
cd ~/MyLLMNote
mv ~/.openclaw/workspace ~/MyLLMNote/openclaw-workspace
ln -s ~/MyLLMNote/openclaw-workspace ~/.openclaw/workspace
git add openclaw-workspace/
git status  # ⚠️ 人工審查所有 staged 檔案！
```

---

## 📁 產出的文件

本次評估已產生以下文件：

1. **workspace-version-control-evaluation.md** (10.3KB)
   - 完整的分析報告
   - 詳細的優缺點比較
   - 潛在問題分析

2. **version-control-comparison-summary.md** (3.3KB)
   - 快速對比表格
   - 推薦執行步驟
   - 數據總結

3. **MyLLMNote/scripts/setup-openclaw-sync.sh** (5.3KB)
   - 準備好可用的同步腳本
   - 支援初始化、優化、自動同步
   - 完整的日誌和錯誤處理

---

## 📌 結論

**軟連結方案雖然簡單，但由於致命的 git-in-git 問題和空間浪費，不推薦採用。**

**改進的混合方案（方案 D +）是最佳選擇，因為：**
1. ✅ 避免了 265MB 的重複檔案和 git-in-git 衝突
2. ✅ MyLLMNote repo size 只增加 500KB（vs 265MB）
3. ✅ 敏感資料完全可控（rsync exclude）
4. ✅ OpenClaw 完全不受影響
5. ✅ 維護成本低（一個腳本 + cron）
6. ✅ 靈活性高（可隨時調整同步內容）

---

## 🚀 下一步行動

**立即可執行：**
```bash
# 1. 優化 repos/（節省 265MB）
cd ~/.openclaw/workspace
mv repos /tmp/repos-backup && mkdir repos && \
ln -s ~/MyLLMNote/llxprt-code repos/llxprt-code && \
ln -s ~/MyLLMNote/CodeWiki repos/CodeWiki

# 2. 首次同步
~/MyLLMNote/scripts/setup-openclaw-sync.sh --init

# 3. 設定自動同步（可選）
crontab -e
# 添加：0 */6 * * * $HOME/MyLLMNote/scripts/setup-openclaw-sync.sh
```

**如有任何問題，請參考完整評估報告。**
