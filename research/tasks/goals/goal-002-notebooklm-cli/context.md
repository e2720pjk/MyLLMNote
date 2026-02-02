# NotebookLM CLI 使用研究 Context

## 背景資訊
- 已安裝 Chromium 瀏覽器
- 已安裝 notebooklm-cli skill
- skill 位置：`~/.openclaw/workspace/skills/notebooklm-cli/`

## 目前已知
1. notebooklm-cli 需要 `nlm login` 來登入
2. 登入流程需要啟動瀏覽器
3. 已安裝 Chromium 在 `/usr/bin/chromium`

## 關鍵問題
1. 能否無人值守自動登入？（提取 cookies？）
2. 是否每次都需要登入？
3. OpenCode 能否透過 ACP 控制瀏覽器登入流程？
4. agent-browser (vercel-labs) 是否有相關功能？

## 研究目標
- 找到最佳的自動化登入方案
- 評估是否為最佳實踐
- 如果無法自動，提出替代方案

## 預期產出
- 登入流程分析
- 自動化方案評估
- 推薦實施方案
