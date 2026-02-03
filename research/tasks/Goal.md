# Goal.md - 探索任務目標

---

## 📂 類別：系統架構研究

### Goal 1: OpenClaw 上下文與對話記錄的 MyLLMNote 版控方案

- **id**: goal-001
- **agent**: Sisyphus（規劃） + Oracle（分析）
- **frequency**: 每週一次
- **status**: pending
- **description**: 研究如何將 OpenClaw 的上下文和對話記錄適當歸檔到 MyLLMNote，透過 GitHub 進行定期版控
- **context**:
  - 目標：建立可持續更新的記錄系統
  - 考慮：工作區設定、記憶檔案、會話歷史
- **output**: goals/goal-001/results.md

---

### Goal 2: OpenCode 上使用 NotebookLM CLI 的最佳實踐

- **id**: goal-002
- **agent**: Librarian（搜尋） + Oracle（分析）
- **frequency**: 每週一次
- **status**: pending
- **description**: 探索如何在 OpenCode 環境中使用 NotebookLM CLI，分析是否為最佳實踐
- **context**:
  - 已安裝 Chromium 瀏覽器
  - 已安裝 notebooklm-cli skill
  - 需解決登入流程自動化問題
- **output**: goals/goal-002/results.md

---

## 📂 類別：專案現況整理

### Goal 3: llxprt-code 專案現況整理

- **id**: goal-003
- **agent**: Librarian（搜尋 GitHub PR） + Atlas（執行）
- **frequency**: 每週一次
- **status**: pending
- **description**: 整理 llxprt-code 的最新狀況，通過 GitHub PR 和聊天記錄找到待辦事項
- **context**:
  - **AST 工具**：已經建置並更新，但有修正項目尚未處理完成
  - **UI Tab 組件**：更新計畫推行的最新進度排查
  - 位置：~/MyLLMNote/llxprt-code/
  - 方法：查看 GitHub PR 紀錄 + Antigravity 聊天記錄
- **output**: goals/goal-003/results.md

---

### Goal 4: CodeWiki RAG 新技術導入現況

- **id**: goal-004
- **agent**: Librarian（搜尋 GitHub PR） + Atlas（執行）
- **frequency**: 每週一次
- **status**: pending
- **description**: 確認 CodeWiki RAG 新技術導入相關狀況，整合多種技術的延伸研究項目計畫
- **context**:
  - **RAG 新技術導入**：最新進展與整合狀況
  - **延伸研究項目**：整合多種技術的計畫狀況確認
  - 位置：~/MyLLMNote/CodeWiki/
  - 方法：查看 GitHub PR 紀錄 + Antigravity 聊天記錄 + 策略文檔
- **output**: goals/goal-004/results.md

---

## 📂 類別：日常執行回報

### Goal 5: 任務執行狀況整理回報

- **id**: goal-005
- **agent**: Atlas（執行）
- **frequency**: 每天一次（在所有任務完成後）
- **status**: pending
- **description**: 整理各個任務的執行狀況並回報摘要
- **context**:
  - 在其他目標執行完後觸發
  - 讀取各目標的 results.md
  - 產出執行摘要與重要發現
- **output**: goals/goal-005/results.md（每日摘要報告）
