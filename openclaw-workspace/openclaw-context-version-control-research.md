# OpenClaw 上下文版控研究 - 最终综合报告

**研究日期**: 2026-02-04
**任务**: OpenClaw workspace 版本控制策略深度研究与实施
**状态**: ✅ 研究完成

---

## 执行摘要

### 核心结论

**推荐方案**: **软链接架构 + repos/ 目录优化** (当前架构 + 关键优化)

**关键发现**:
1. ✅ **当前架构已最优**: `~/.openclaw/workspace` → `~/MyLLMNote/openclaw-workspace` 软链接方式是最佳选择
2. ⚠️ **待实施优化**: `repos/` 目录需转换为软链接 以节省 **340MB** 空间并避免 git-in-git 冲突
3. ✅ **敏感数据保护**: `.gitignore` 配置完善，过滤逻辑完整
4. ❌ **替代方案已否决**: Git worktree 和 Git submodule 均不适用于此场景
5. 🟡 **可选增强**: 可使用 pre-commit 框架 + Gitleaks 加强安全性

### 预期收益

- **空间节省**: 340MB → ~0MB (repos 软链接后)
- **复杂度**: 低 (软链接原生 Git 支持，无需额外工具)
- **安全性**: 高 (完善的 .gitignore 过滤，可选 Gitleaks 扫描)
- **维护成本**: 最小 (无需定时任务，随 git commit 自动同步)

### 立即行动项

**优先级 1 (高) - 立即执行**:
```bash
# 优化 repos/ 目录 (节省 340MB)
cd ~/.openclaw/workspace
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mv repos /tmp/repos-backup-$TIMESTAMP
mkdir repos
ln -s ~/MyLLMNote/CodeWiki repos/CodeWiki
ln -s ~/MyLLMNote/llxprt-code repos/llxprt-code
# notebooklm-py 需先移动到 ~/MyLLMNote/ 再软链接，或保持原样
```

**优先级 2 (中) - 短期内完成**:
- Git 同步提交
- 设置 `core.symlinks=true` 确保配置正确
- 可选: 安装 pre-commit + Gitleaks

---

## 1. 当前系统架构分析

### 1.1 目录结构

```
~/.openclaw/workspace/                      ← OpenClaw 实际工作区 (软链接)
    ↓ 软链接 (symlink)
~/MyLLMNote/openclaw-workspace/             ← MyLLMNote Git 仓库 (真实目录)
    ├── SOUL.md                            ← 代理的灵魂/核心身份
    ├── AGENTS.md                          ← 多代理团队配置
    ├── IDENTITY.md                        ← 我是谁 (OpenClaw Gateway Agent)
    ├── TOOLS.md                           ← 工具清单
    ├── MEMORY.md                          ← 长期记忆 (已被 .gitignore)
    ├── skills/                            ← 个人技能模块 (10 个技能)
    │   ├── notebooklm-cli/                ← Google NotebookLM CLI
    │   ├── summarize/                     ← Web/PDF/URL 总结工具
    │   ├── model-usage/                   ← Codex 成本统计
    │   ├── moltcheck/                     ← 安全扫描器
    │   ├── moltbot-best-practices/
    │   ├── moltbot-security/
    │   ├── opencode-acp-control/
    │   ├── tmux/
    │   └── ...
    ├── scripts/                           ← 自动化脚本
    │   ├── check-ip.sh
    │   ├── check-opencode-sessions.sh
    │   ├── monitor-tasks.sh
    │   └── ...
    ├── memory/                            ← 记忆系统 (大部分被 .gitignore)
    │   ├── 2026-02-*.md                   ← 日常日志 (已忽略)
    │   ├── opencode-*.md                  ← 技术记忆 (已保留)
    │   └── optimization-*.md              ← 优化建议 (已保留)
    ├── repos/                             ← 340MB - 待优化! ⚠️
    │   ├── CodeWiki/                      ← 83MB, git repo (应软链接)
    │   ├── llxprt-code/                   ← 182MB, git repo (应软链接)
    │   └── notebooklm-py/                 ← 76MB, git repo (需处理)
    ├── docs/                              ← 文档目录
    ├── .gitignore                         ← 敏感数据过滤
    └── version-control-*.md               ← 版本控制研究报告

~/MyLLMNote/                                ← 主 Git 仓库
    ├── .git/
    ├── CodeWiki/                          ← 3.1MB (精简版本)
    ├── llxprt-code/                       ← 8.2MB (精简版本)
    ├── scripts/setup-openclaw-sync.sh     ← rsync 同步脚本 (不再需要)
    └── openclaw-workspace/                ← 软链接的实际目录
```

### 1.2 软链接验证

```bash
$ ls -la ~/.openclaw/workspace
lrwxrwxrwx 1 soulx7010201 soulx7010201 47 Feb  3 06:39 \
  /home/soulx7010201/.openclaw/workspace -> /home/soulx7010201/MyLLMNote/openclaw-workspace

$ test -L ~/.openclaw/workspace && echo "✅ 软链接健康" || echo "❌ 软链接失败"
✅ 软链接健康
```

**状态**: ✅ 软链接配置正确且健康

### 1.3 Git 状态

**远程仓库**:
- URL: `git@github.com:e2720pjk/MyLLMNote.git`
- 分支: main
- 状态: 与远程同步 (最新的 commit: e07cbec)

**Git 配置**:
```bash
$ cd ~/MyLLMNote
$ git config --get core.symlinks
# 输出: 空 (使用系统默认，Linux 通常为 true)
```

**状态**: 🟡 `core.symlinks` 未显式设置，建议显式设为 `true`

### 1.4 .gitignore 配置分析

当前 `.gitignore` (已优化):

```gitignore
# OpenClaw 内部配置（敏感）
.clawdhub/
.clawhub/
.clawhub.json*
network-state.json*
*.tmp
*.log

# 敏感记忆文件
MEMORY.md
memory/2026-*.md
memory/*-daily.md

# 外部 git repos（避免 git-in-git）
repos/

# OpenCode 内部配置
.opencode/
.opencode.json*

# 白名单：保留重要文件
!reports/
!*-report.md
!*-evaluation.md
!*-summary.md
!memory/opencode-*.md
!memory/optimization-*.md
!scripts/
!skills/
!docs/
```

**保护范围**:
- ✅ 敏感配置 (`.clawhub`, `.clawhub.json`)
- ✅ 临时状态 (`network-state.json`, `*.tmp`)
- ✅ 个人记忆 (`MEMORY.md`, `memory/2026-*.md`)
- ✅ 嵌套 Git 仓库 (`repos/`)
- ✅ OpenCode 配置 (`.opencode/`)

**版本控制内容**:
- ✅ 核心身份文件 (SOUL.md, AGENTS.md, TOOLS.md)
- ✅ 技能模块 (`skills/` - 10 个技能)
- ✅ 自动化脚本 (`scripts/`)
- ✅ 技术记忆 (`memory/opencode-*.md`)
- ✅ 研究报告和文档

**状态**: ✅ `.gitignore` 配置合理且完善

---

## 2. 版本控制方案对比

### 2.1 方案矩阵

| 方案 | 复杂度 | 空间效率 | 敏感数据保护 | Git-in-git风险 | OpenClaw影响 | 自动化 | 推荐度 |
|------|--------|----------|--------------|----------------|-------------|--------|--------|
| **软链接 + .gitignore** | 🟢 低 | 🟢 优秀 | 🟢 高 | 🟢 无 | ✅ 无影响 | 🟢 自动同步 | ⭐⭐⭐⭐⭐ |
| **rsync 混合方案** | 🟡 中 | 🔴 双副本 | 🟢 高 | 🟢 无 | ✅ 无影响 | 🔴 需cron | ⭐⭐⭐ |
| **Git Submodule** | 🔴 高 | 🟢 优秀 | 🟡 中 | 🟢 无 | ⚠️ 需测试 | 🔴 需init/pull | ⭐⭐ |
| **Git Worktree** | 🔴 高 | 🔴 双副本 | 🟡 中 | 🟢 无 | ✅ 无影响 | 🔴 需sync | ⭐ |

### 2.2 方案 A: 软链接 + 改进的 .gitignore (当前架构) ✅ 推荐

**架构**:
```
~/.openclaw/workspace/ (symlink) → ~/MyLLMNote/openclaw-workspace/
```

**优点**:
1. ✅ **零复制开销**: 软链接不实际复制文件，修改即时反映
2. ✅ **原生 Git 支持**: Git 自动处理软链接（需配置 `core.symlinks=true`）
3. ✅ **简单直观**: 一次性设置，之后隐式运作
4. ✅ **对 OpenClaw 无影响**: `~/.openclaw/workspace` 路径保持不变
5. ✅ **灵活过滤**: `.gitignore` 可精确控制版本内容
6. ✅ **自动化**: 随 `git commit` 自动同步，无需定时任务
7. ✅ **透明性**: 操作系统原生支持，无需额外工具

**缺点**:
1. 🟡 **Unix 专用**: Windows 需要 junction/symlink 替代
2. 🟡 **需手动维护 .gitignore**: 新增文件类型需要调整过滤规则
3. 🟡 **跨平台兼容性**: 在 Windows 环境下需要特殊处理

**适用场景**:
- 需要将 OpenClaw 的配置和技能文件归档到 GitHub
- 希望与 MyLLMNote 项目统一管理
- 需要过滤敏感的个人信息和记忆数据
- 用户环境是 Linux (当前环境)

### 2.3 方案 B: rsync 混合方案 (不推荐)

**架构**:
```
~/.openclaw/workspace/
    ↓ rsync (过滤敏感数据 + 排除 repos/)
~/MyLLMNote/openclaw-config/
    ↓ git
GitHub
```

**优点**:
1. ✅ 完全控制同步内容
2. ✅ 可过滤敏感信息
3. ✅ 两个 repo 独立管理
4. ✅ 可添加自定义过滤规则

**缺点**:
1. ❌ **有文件复制**: 空间浪费 (~500KB)
2. ❌ **需要维护 sync 脚本**
3. ❌ **需要定期执行**: 必须设定 cron
4. ❌ **同步延迟**: 修改不会立即反映在 Git 仓库
5. ❌ **额外维护成本**: 脚本调试、日志管理

**为何不推荐**:
- 当前已经是软链接架构，引入 rsync 是倒退
- 维护成本高（脚本 + cron）
- 同步不及时，可能与实际工作区不一致

### 2.4 方案 C: Git Submodule (不推荐)

**架构**:
```
~/MyLLMNote/
├── .gitmodules (记录 submodule 指针)
└── openclaw-workspace/ (submodule → 独立仓库)
```

**优点**:
1. ✅ 版本控制精确：可指定 submodule 的特定 commit
2. ✅ 空间效率：无文件重复
3. ✅ 独立管理：与 MyLLMNote 仓库分离

**缺点**:
1. ❌ **复杂度高**：需要 `git submodule init/update` 等额外命令
2. ❌ **更新复杂**：修改后需要 `git submodule update` 才能同步
3. ❌ **"双提交"问题**：每个 workspace 修改需要两次 commit（submodule + parent）
4. ❌ **高频率更新成本高**: OpenClaw workspace 频繁修改，submodule 维护负担重
5. ❌ **clone 需额外步骤**: `git clone --recursive` 或手动 init
6. ❌ **指针冲突**: 多人协作时 submodule 版本指针容易冲突

**为何不推荐**:
- OpenClaw workspace 是"活"的工作区，不是静态配置
- 高频修改场景下 "双提交" 开销太大
- 维护成本远超软链接方案

### 2.5 方案 D: Git Worktree (不适用)

**架构**:
```bash
git worktree add ~/.openclaw/workspace/ main
git worktree add ~/MyLLMNote/openclaw-workspace/ main
```

**优点**:
1. ✅ 共享 Git 对象和历史的多个工作目录
2. ✅ 适合多分支并行开发
3. ✅ 节省磁盘空间 (共享 .git 对象数据库)

**缺点**:
1. ❌ **解决错误问题**: Git worktree 是为"同一仓库的多分支并行开发"设计，不是"跨仓库的配置共享"
2. ❌ **复杂度高**: 需要管理命令（add, list, remove, prune）
3. ❌ **双副本**: 每个 worktree 都是完整副本（空间浪费）
4. ❌ **需 sync**: 两个 worktree 之间同步需要 commit/merge 操作
5. ❌ **配置风险**：所有 worktree 共享 `.git/hooks/`，存在跨工作目录 RCE 风险

**为何不适用**:
- **概念错误**: worktree 不能用于跨仓库的场景
- OpenClaw workspace 是独立目录，不是 MyLLMNote 的分支
- 实施完全不匹配需求

---

## 3. 关键问题与解决方案

### 3.1 repos/ 目录优化 (340MB → ~0MB)

#### 当前问题

**当前状态**:
```
repos/ 总大小: 340MB
├── CodeWiki/       83MB  (完整 git repo)
├── llxprt-code/    182MB (完整 git repo)
└── notebooklm-py/  76MB  (完整 git repo)
```

**问题分析**:
1. `repos/` 包含完整的 git clones，与 MyLLMNote 中的项目重复
2. 这些是 **Git-in-Git** 嵌套仓库（每个子目录都有自己的 `.git/`）
3. 虽然 `.gitignore` 已排除，但仍然占用磁盘空间 (340MB)
4. 造成 Git 操作可能混淆（两个 .git/ 目录）

#### 优化方案

**目标**: 将 repos/ 从嵌套的 git 克隆改为软链接，指向 MyLLMNote 中的现有项目。

**实施步骤**:

```bash
#!/bin/bash
# ===== OpenClaw repos/ 优化脚本 =====
# 目标: 将 340MB 的嵌套 git 仓库转换为软链接，节省空间并避免 git-in-git 冲突

# 步骤 1: 备份（关键安全措施）
cd ~/.openclaw/workspace
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
echo "[1/6] 备份当前 repos/ 到 /tmp/repos-backup-$TIMESTAMP"
mv repos /tmp/repos-backup-$TIMESTAMP

# 步骤 2: 创建新 repos 目录
echo "[2/6] 创建新的 repos 目录"
mkdir -p repos

# 步骤 3: 创建软链接到 MyLLMNote 项目
echo "[3/6] 创建软链接到 MyLLMNote 项目"
ln -s ~/MyLLMNote/CodeWiki repos/CodeWiki
ln -s ~/MyLLMNote/llxprt-code repos/llxprt-code

# 步骤 4: 处理 notebooklm-py
# 如果笔记本项目在 MyLLMNote 中不存在，则移动过去
if [ ! -d ~/MyLLMNote/notebooklm-py ]; then
    echo "[4/6] 移动 notebooklm-py 到 ~/MyLLMNote/ 并软链接"
    cp -a /tmp/repos-backup-$TIMESTAMP/notebooklm-py ~/MyLLMNote/
    ln -s ~/MyLLMNote/notebooklm-py repos/notebooklm-py
else
    echo "[4/6] notebooklm-py 已存在于 ~/MyLLMNote/，直接软链接"
    ln -s ~/MyLLMNote/notebooklm-py repos/notebooklm-py
fi

# 步骤 5: 验证
echo "[5/6] 验证软链接"
ls -la repos/
echo ""
echo "磁盘空间: $(du -sh repos/)"

# 步骤 6: 测试 OpenClaw 功能
echo "[6/6] 测试 OpenClaw 功能"
if command -v openclaw &> /dev/null; then
    openclaw help 2>&1 | head -3
else
    echo "OpenClaw 命令不可用，跳过功能测试"
fi

echo ""
echo "✅ repos/ 优化完成"
echo "备份位置: /tmp/repos-backup-$TIMESTAMP"
echo ""
echo "如需回滚，运行:"
echo "  cd ~/.openclaw/workspace"
echo "  rm -rf repos"
echo "  mv /tmp/repos-backup-$TIMESTAMP repos"
```

**优化后的效果**:
- 空间: 340MB → ~0MB (软链接无实际存储)
- 功能: OpenClaw 仍然可以通过 `repos/` 目录访问这些项目
- Git 健康: 不再有嵌套的 `.git/` 目录

---

## 4. 自动化方案

### 4.1 Git Hooks 自动化

#### Pre-commit Hook (敏感数据检测)

```bash
# .git/hooks/pre-commit
#!/bin/bash
# 检查暂存文件中的敏感数据

echo "🔍 检查敏感数据..."

# 检查 staged 文件
FILES=$(git diff --cached --name-only)

# 检查 Markdown 文件中的敏感模式
if echo "$FILES" | grep -q "\.md$"; then
  SENSITIVE="password|secret|api[-_]?key|token|bearer|private[-_]?key"

  if git diff --cached "*.md" | grep -iE "$SENSITIVE" > /dev/null; then
    echo "❌ 检测到可能的敏感数据！"
    echo "请检查 .md 文件是否有不应提交的信息。"
    exit 1
  fi
fi

echo "✅ 无敏感数据检测到"
```

### 4.2 Pre-commit 框架 (推荐)

#### 安装和配置

```bash
# 安装 pre-commit
pip install pre-commit

# 创建配置文件
cat > ~/MyLLMNote/.pre-commit-config.yaml << 'EOF'
repos:
  # Gitleaks - 密钥扫描
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.2
    hooks:
      - id: gitleaks

  # Pre-commit 内置钩子
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: check-yaml
      - id: end-of-file-fixer
      - id: trailing-whitespace
      - id: check-added-large-files
      - id: detect-private-key
EOF

# 安装钩子
cd ~/MyLLMNote
pre-commit install
```

---

## 5. 实施方案

### 5.1 完整实施步骤

#### 阶段 1: 优化 repos/ 目录 (优先级: 高)

```bash
#!/bin/bash
# ===== OpenClaw Workspace 优化脚本 =====
# 日期: 2026-02-04
# 目标: 优化 repos/ 目录，节省 340MB 空间

set -e  # 遇到错误立即退出

# 配置
WORKSPACE="$HOME/.openclaw/workspace"
BACKUP_DIR="/tmp/repos-backup-$(date +%Y%m%d_%H%M%S)"
REPO_DIR="$HOME/MyLLMNote"

# 步骤 1: 显示当前状态
echo "===== OpenClaw Workspace 优化 ====="
echo "工作区: $WORKSPACE"
echo "备份位置: $BACKUP_DIR"
echo ""

# 检查链接是否存在
if [ ! -L "$WORKSPACE" ]; then
    echo "❌ 错误: $WORKSPACE 不是软链接"
    exit 1
fi

# 步骤 2: 备份原始 repos/
echo "[1/6] 备份原始 repos/ 目录..."
cd "$WORKSPACE"
if [ -d "repos" ]; then
    mv repos "$BACKUP_DIR"
    echo "✅ 备份完成: $BACKUP_DIR"
else
    echo "⚠️  repos/ 目录不存在，跳过备份"
fi

# 步骤 3: 创建新的 repos/ 目录
echo "[2/6] 创建新 repos/ 目录..."
mkdir -p repos

# 步骤 4: 为每个项目创建软链接
echo "[3/6] 创建软链接..."
for repo in CodeWiki llxprt-code; do
    SOURCE="$REPO_DIR/$repo"
    TARGET="repos/$repo"

    if [ -d "$SOURCE" ]; then
        ln -s "$SOURCE" "$TARGET"
        echo "  ✅ $repo → $SOURCE"
    else
        echo "  ⚠️  $SOURCE 不存在"
    fi
done

# 处理 notebooklm-py
if [ ! -d "$REPO_DIR/notebooklm-py" ] && [ -d "$BACKUP_DIR/notebooklm-py" ]; then
    echo "  🔧 移动 notebooklm-py 到 ~/MyLLMNote/"
    cp -a "$BACKUP_DIR/notebooklm-py" "$REPO_DIR/"
fi
if [ -d "$REPO_DIR/notebooklm-py" ]; then
    ln -s "$REPO_DIR/notebooklm-py" repos/notebooklm-py
    echo "  ✅ notebooklm-py → $REPO_DIR/notebooklm-py"
fi

# 步骤 5: 验证
echo ""
echo "[4/6] 验证软链接..."
ls -la repos/

echo ""
echo "[5/6] 检查磁盘空间..."
echo "repos/ 大小: $(du -sh repos/ | cut -f1)"
REPOS_SIZE=$(du -sm repos/ | cut -f1)
if [ "$REPOS_SIZE" -lt 10 ]; then
    echo "✅ 优化成功: 磁盘空间已节省 (~340MB)"
else
    echo "⚠️  警告: repos/ 仍然较大 ($REPOS_SIZE MB)"
fi

# 步骤 6: 测试 OpenClaw 功能
echo ""
echo "[6/6] 测试 OpenClaw 功能..."
if command -v openclaw &> /dev/null; then
    if timeout 5 openclaw help &> /dev/null; then
        echo "✅ OpenClaw 命令正常"
    else
        echo "⚠️  OpenClaw 响应超时，但可能不影响功能"
    fi
else
    echo "ℹ️  OpenClaw 命令不可用，跳过功能测试"
fi

# 完成
echo ""
echo "===== 优化完成 ====="
echo "备份位置: $BACKUP_DIR"
echo "备份保留期限: 7 天"
echo ""
echo "如需回滚，运行:"
echo "  cd $WORKSPACE"
echo "  rm -rf repos"
echo "  mv $BACKUP_DIR repos"
```

#### 阶段 2: Git 同步测试 (优先级: 中)

```bash
# 切换到 Git 仓库
cd ~/MyLLMNote

# 设置 core.symlinks=true
git config core.symlinks true

# 查看更改
git status

# 添加更改（注意：repos/ 已在 .gitignore 中，不会被添加）
git add openclaw-workspace/

# 提交
git commit -m "优化 OpenClaw workspace: 使用 repos 软链接节省空间 (340MB -> ~0MB)"

# 推送
git push origin main
```

### 5.2 验证与测试

```bash
# 测试 1: 验证软链接
test -L ~/.openclaw/workspace && echo "✅ workspace 是软链接"
readlink -f ~/.openclaw/workspace

# 测试 2: 验证 repos 优化
du -sh ~/.openclaw/workspace/repos/
# 应显示 ~0MB 或极小

# 测试 3: 验证 Git 健康状态
cd ~/MyLLMNote
git status
# 应显示 repos/ 目录为忽略状态

# 测试 4: 验证 OpenClaw 功能
openclaw help
# 或通过 Telegram Bot 测试
```

---

## 6. 结论

### 6.1 最终推荐

**方案 A: 软链接 + 改进的 .gitignore + repos/ 优化**

**核心理由**:
1. ✅ **当前架构已最优**: 软链接方式简单、可靠、自动同步
2. ✅ **唯一调整点**: 优化 `repos/` 目录，节省 340MB 空间
3. ✅ **安全性良好**: `.gitignore` 配置完善，过滤敏感数据
4. ✅ **维护成本最低**: 无需额外脚本、定时任务或复杂命令
5. ✅ **对 OpenClaw 零影响**: `~/.openclaw/workspace` 路径不变

### 6.2 不推荐替代方案

- ❌ **Git Worktree**: 解决错误问题（多分支 vs 跨仓库）
- ❌ **Git Submodule**: 高维护成本（"双提交"、"双初始化"）
- ❌ **rsync 混合方案**: 倒退，增加复杂度和维护成本

### 6.3 立即行动

```bash
# 1. 优化 repos/ (关键)
cd ~/.openclaw/workspace
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mv repos /tmp/repos-backup-$TIMESTAMP
mkdir repos
ln -s ~/MyLLMNote/CodeWiki repos/CodeWiki
ln -s ~/MyLLMNote/llxprt-code repos/llxprt-code
ln -s ~/MyLLMNote/notebooklm-py repos/notebooklm-py
openclaw help  # 验证

# 2. Git 同步
cd ~/MyLLMNote
git config core.symlinks true
git add openclaw-workspace/
git commit -m "优化 OpenClaw workspace: 使用 repos 软链接节省空间 (340MB -> ~0MB)"
git push origin main

# 3. 可选: 安装 pre-commit (安全增强)
pip install pre-commit
cd ~/MyLLMNote
cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.2
    hooks:
      - id: gitleaks
EOF
pre-commit install
```

---

## 7. 附录

### 7.1 参考资料

#### 官方文档
- [Git Book - Git Tools: Submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
- [Git Worktree Documentation](https://git-scm.com/docs/git-worktree)
- [Git Ignore Documentation](https://git-scm.com/docs/gitignore)

#### 开源项目
- [twpayne/chezmoi](https://github.com/twpayne/chezmoi) - 配置管理工具
- [gitleaks/gitleaks](https://github.com/gitleaks/gitleaks) - 密钥扫描工具
- [pre-commit/pre-commit](https://github.com/pre-commit/pre-commit) - Pre-commit 框架

### 7.2 内部研究报告

- `version-control-final-research.md` - 最终综合研究报告 (2026-02-04)
- `workspace-version-control-evaluation.md` - 详细对比评估
- `workspace-version-control-executive-summary.md` - 执行摘要
- `version-control-comparison-summary.md` - 对比总结
- `results-v2.md` - 第二轮研究结果
- `results-v3.md` - 第三轮研究结果

### 7.3 背景研究任务

本次研究使用了 4 个并行背景任务:
- `bg_71c72cf4` - 探索 OpenClaw 文件系统结构
- `bg_719dfe64` - Librarian 研究最佳实践
- `bg_6b482a64` - 探索现有版本控制文档
- `bg_9f55578d` - 研究 Git 工具和自动化

---

**报告完成时间**: 2026-02-04 16:45 UTC
**研究团队**: OpenClaw Gateway Agent + 4 个并行研究代理
**总研究时间**: ~15 分钟

**状态**: ✅ 研究完成，等待实施执行
