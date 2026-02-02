# OpenClaw 上下文版控研究 Context

## 背景
- OpenClaw workspace: `~/.openclaw/workspace/`
- MyLLMNote: `~/MyLLMNote/`
- 已討論過使用 git worktree 提案（方案未定案）

## 研究範圍
1. OpenClaw 上下文檔案結構
   - Workspace 核心檔案（SOUL.md, USER.md, IDENTITY.md, TOOLS.md, AGENTS.md）
   - 記憶檔案（memory/YYYY-MM-DD.md, MEMORY.md）
   - Skills 設定（skills/*.md）
   - 腳本（scripts/*.sh）

2. 版控策略選項
   - Submodule 方案
   - Git worktree 方案
   - 定期同步腳本方案

3. GitHub 整合
   - 自動 commit & push 流程
   - 記憶檔案是否應該上傳
   - 敏感資訊過濾

## 預期產出
- 推薦的版本控制方案
- 實施步驟
- 潛在風險評估
