# Workspace 版控方案快速對比

| 項目 | 改進的混合方案（方案 D +） | 軟連結方案 |
|------|--------------------------|-----------|
| **複雜度** | 🟡 中（需設定腳本） | 🟢 低 |
| **空間效率** | 🟡 有複製（~500KB） | 🟢 無重複 |
| **MyLLMNote repo size** | 🟢 +500KB | 🔴 +265MB |
| **敏感資料保護** | 🟢 高（rsync exclude） | 🔴 低（需手動 gitignore） |
| **Git 巢式 repos** | 🟢 完全排除 | 🔴 嚴重衝突 |
| **OpenClaw 影響** | 🟢 無 | 🟡 需測試 |
| **維護成本** | 🟡 中（腳本） | 🟢 低 |
| **跨平台** | 🟢 高 | 🔴 Unix only |
| **repo 管理獨立性** | 🟢 高 | 🔴 低 |

---

## 🏆 最終推薦：改進的混合方案（方案 D +）

### 核心改進
```
~/.openclaw/workspace/
├── (所有配置、腳本、技能)
└── repos/ → 符號連結到 ~/MyLLMNote 的各專案
        ↓ rsync（過濾 sensitive files + 排除 repos）
~/MyLLMNote/openclaw-config/
└── (乾淨的配置歸檔，不含 repos)
```

### 優點
✅ 節省 265MB 空間（不複製 repos）
✅ 無 Git 巢式 repos 問題
✅ 敏感資料完全可控
✅ OpenClaw 完全不受影響
✅ MyLLMNote repo size 只增加 ~500KB

### 缺點
需要維護一個 sync 腳本（但很簡單）

---

## 💡 關鍵發現

#### 致命問題：`repos/ = 265MB`
```
~/.openclaw/workspace/repos/
├── llxprt-code/     (182MB, 完整的 git repo) ← 重複
└── CodeWiki/        (83MB, 完整的 git repo)  ← 重複
```

**MyLLMNote 已有這些專案！**
- `~/MyLLMNote/llxprt-code` (8.1MB)
- `~/MyLLMNote/CodeWiki` (3.1MB)

#### 如果用軟連結方案
- MyLLMNote repo 增加 **265MB**
- 造成 git-in-git 巢式 repos 問題
- 所有檔案都被加入 Git（包括敏感資料）

---

## 📋 推薦執行步驟

### 1. 優化 repos/（節省 265MB）
```bash
cd ~/.openclaw/workspace
rm -rf repos/
mkdir repos/
ln -s ~/MyLLMNote/llxprt-code repos/llxprt-code
ln -s ~/MyLLMNote/CodeWiki repos/CodeWiki
```

### 2. 創建歸檔目錄
```bash
cd ~/MyLLMNote
mkdir -p openclaw-config
cd openclaw-config
git init
```

### 3. 創建同步腳本
```bash
cat > ~/MyLLMNote/scripts/sync-openclaw.sh << 'EOF'
#!/bin/bash
SOURCE="$HOME/.openclaw/workspace"
TARGET="$HOME/MyLLMNote/openclaw-config"

rsync -av --delete \
    --exclude=".clawdhub/" \
    --exclude=".clawhub/" \
    --exclude="network-state.json*" \
    --exclude="*.tmp" \
    --exclude=".git/" \
    --exclude="repos/" \
    --exclude="memory/2026-*.md" \
    --exclude="MEMORY.md" \
    --include="memory/opencode-*.md" \
    "$SOURCE/" "$TARGET/"

cd "$TARGET"
git add .
git diff --cached --quiet || git commit -m "Sync $(date '+%Y-%m-%d %H:%M:%S')"
git push

echo "✅ synced"
EOF

chmod +x ~/MyLLMNote/scripts/sync-openclaw.sh
```

### 4. 首次同步
```bash
~/MyLLMNote/scripts/sync-openclaw.sh
```

### 5. 設定 cron
```bash
crontab -e
# 添加：
0 */6 * * * $HOME/MyLLMNote/scripts/sync-openclaw.sh
```

---

## ⚠️ 如果堅持用軟連結方案

必須處理這些問題：

1. **repos/ 必須改為符號連結**
```bash
mv ~/.openclaw/workspace/repos /tmp/repos-backup
mkdir ~/.openclaw/workspace/repos
ln -s ~/MyLLMNote/llxprt-code ~/.openclaw/workspace/repos/llxprt-code
ln -s ~/MyLLMNote/CodeWiki ~/.openclaw/workspace/repos/CodeWiki
```

2. **嚴格的 .gitignore**
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

3. **測試 OpenClaw**
```bash
openclaw help  # 確認符號連結不影響運作
```

4. **檢查 staged 檔案**
```bash
cd ~/MyLLMNote
git add openclaw-workspace/
git status  # 人工審查，確保沒有敏感資料
```

---

## 📊 數據總結

| 指標 | 混合方案 | 軟連結方案 (處理 repos/) | 軟連結方案 (處理 repos/) |
|-----|---------|----------------|--------|
| **MyLLMNote repo size** | +500KB | +265MB | +500KB |
| **空間效率** | 複製一次 | 無重複 | 無重複 |
| **敏感資料保護** | 高 | 低 | 適度 |
| **Git 問題** | 無 | 嚴重 | 無 |
| **推薦度** | ⭐⭐⭐⭐⭐ | ⭐ | ⭐⭐⭐ |

---

**結論：改進的混合方案（方案 D +）是最佳選擇，因為：**
1. 避免了 git-in-git 的複雜性
2. MyLLMNote repo size 只增加 500KB（vs 265MB）
3. 敏感資料完全可控
4. OpenClaw 不受任何影響
