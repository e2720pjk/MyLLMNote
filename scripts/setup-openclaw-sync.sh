#!/bin/bash
#
# OpenClaw Workspace 同步腳本 - 改進的混合方案（方案 D +）
#
# 用途：將 ~/.openclaw/workspace 同步到 ~/MyLLMNote/openclaw-config
#       排除敏感檔案和外部 repos
#
# 使用：
#   1. 首次執行：./setup-openclaw-sync.sh --init
#   2. 定期同步：./setup-openclaw-sync.sh
#   3. cron 定時：0 */6 * * * /path/to/this/script
#
# 作者：Subagent (workspace-version-control-evaluation)
# 日期：2026-02-03
#

set -e

# 配置
SOURCE="$HOME/.openclaw/workspace"
TARGET="$HOME/MyLLMNote/openclaw-config"
LOG_FILE="$HOME/.openclaw-sync.log"

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $*" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $*" | tee -a "$LOG_FILE"
}

# 檢查源目錄是否存在
check_source() {
    if [ ! -d "$SOURCE" ]; then
        error "Source directory not found: $SOURCE"
        return 1
    fi
    log "Source directory found: $SOURCE"
}

# 初始化目標目錄
init_target() {
    log "Initializing target directory: $TARGET"

    if [ -d "$TARGET" ]; then
        warn "Target directory already exists. Checking if it's a git repo..."
        if [ -d "$TARGET/.git" ]; then
            log "Target is already a git repo. Skipping init."
        else
            error "Target directory exists but is not a git repo: $TARGET"
            error "Please remove it or initialize it manually."
            return 1
        fi
    else
        mkdir -p "$TARGET"
        cd "$TARGET"
        git init
        log "Target directory initialized as git repo."
    fi
}

# 檢查並優化 repos/（可選）
optimize_repos() {
    if [ ! -L "$SOURCE/repos" ] && [ -d "$SOURCE/repos" ]; then
        log "Checking repos/ directory..."
        REPOS_SIZE=$(du -sh "$SOURCE/repos" 2>/dev/null | cut -f1)
        log "Current repos/ size: $REPOS_SIZE"

        log "The repos/ directory is NOT a symbolic link."
        log "To save ~265MB, you can convert it to symbolic links:"
        log "  cd '$SOURCE'"
        log "  mv repos /tmp/repos-backup"
        log "  mkdir repos"
        log "  ln -s ~/MyLLMNote/llxprt-code repos/llxprt-code"
        log "  ln -s ~/MyLLMNote/CodeWiki repos/CodeWiki"
        log ""
        log "Or keep it as-is if you prefer (this script will exclude it from sync)."
    fi

    if [ -L "$SOURCE/repos" ]; then
        log "✓ repos/ is a symbolic link (no space waste)"
    fi
}

# 執行同步
perform_sync() {
    log "Starting rsync from $SOURCE to $TARGET"

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
        "$SOURCE/" "$TARGET/" \
        2>&1 | tee -a "$LOG_FILE"

    log "Rsync completed"
}

# Git commit 和 push
git_commit_push() {
    cd "$TARGET"

    # 檢查是否有變更
    if git diff --quiet && git diff --cached --quiet; then
        log "No changes to commit."
        return 0
    fi

    # 添加所有檔案
    git add .

    # 顯示將被 commit 的變更
    log "Changes to be committed:"
    git diff --cached --stat | tee -a "$LOG_FILE"

    # Commit
    COMMIT_MSG="Sync OpenClaw config $(date '+%Y-%m-%d %H:%M:%S')"
    git commit -m "$COMMIT_MSG"
    log "Committed: $COMMIT_MSG"

    # Push（如果設定了 remote）
    if git remote | grep -q .; then
        log "Pushing to remote..."
        git push 2>&1 | tee -a "$LOG_FILE"
        log "✅ Pushed to remote"
    else
        log "No remote configured. Skipping push."
        warn "To set up a remote, run:"
        warn "  cd '$TARGET'"
        warn "  git remote add origin <your-repo-url>"
        warn "  git branch -M main"
        warn "  git push -u origin main"
    fi
}

# 顯示統計
show_stats() {
    log ""
    log "=== Statistics ==="

    SOURCE_SIZE=$(du -sh "$SOURCE" 2>/dev/null | cut -f1)
    log "Source size: $SOURCE_SIZE"

    TARGET_SIZE=$(du -sh "$TARGET" 2>/dev/null | cut -f1)
    log "Target size: $TARGET_SIZE"

    if [ -d "$TARGET/.git" ]; then
        cd "$TARGET"
        COMMITS=$(git rev-list --count HEAD 2>/dev/null || echo "0")
        log "Total commits: $COMMITS"
    fi
}

# 主函數
main() {
    ACTION="${1:-sync}"

    case "$ACTION" in
        --init)
            log "=== Initial Setup ==="
            check_source || exit 1
            init_target || exit 1
            optimize_repos
            perform_sync
            git_commit_push
            show_stats
            log ""
            log "✅ Setup completed!"
            log "To schedule automatic sync, add to crontab:"
            log "  crontab -e"
            log "  # Add: 0 */6 * * * $0"
            ;;

        --optimize)
            log "=== Optimizing repos/ ==="
            check_source || exit 1
            optimize_repos
            log "Optimization suggestion displayed above."
            ;;

        *)
            log "=== Sync OpenClaw Configuration ==="
            check_source || exit 1
            perform_sync
            git_commit_push
            show_stats
            log ""
            log "✅ Sync completed!"
            ;;
    esac
}

# 執行主函數
main "$@"
