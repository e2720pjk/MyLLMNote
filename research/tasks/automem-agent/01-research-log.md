# Automem 記憶管理 Agent 研究日誌

## 研究開始
- **日期**: 2026-02-04
- **任務**: 評估 Automem 作為獨立記憶管理 Agent 的可行性

## 目標
1. 確認 Automem 能否作為獨立的 agent 運行
2. 開發給 agent 使用的 Skills
3. 設定專職 OpenClaw agent

---

## 目前發現

### 1. Automem 在 CodeWiki 專案中的定位

根據 CodeWiki 的分析文件，Automem 將扮演「Semantic Sidecar」的角色：

**核心特性**：
- Vector Store（向量存儲）
- Hybrid Search（混合搜尋）
- Time-aware Memory + Clustering（時間感知記憶和聚類）
- Consolidation Engine（整合引擎）
- 使用資料庫：FalkorDB, Qdrant

**在 CodeWiki 架構中的層次**：
- Layer 1: Code Database (CGR/Joern) - 儲存 AST, Call Graph, Data Flow
- Layer 2: Semantic Memory (AutoMem) - 儲存模組摘要、提交意圖、用戶對話、重要見解
- Layer 3: The View - 在需求時生成文件

### 2. 整合策略

CodeWiki 採用 **Option A: Sidecar（外部服務）** 的整合方式：
- CodeWiki CLI 產生 `summaries/*.json`
- 新命令 `codewiki memory-sync` 將摘要推送到運行中的 AutoMem 實例
- Chat 介面查詢 AutoMem

### 3. OpenCode/LLxprt Code 的記憶系統

OpenCode 內建 `save_memory` 工具：
- 將記憶資訊儲存到 Markdown 檔案 (`~/.llxprt/LLXPRT.md`)
- 支援 global 和 project 範圍
- 簡單的檔案基礎系統

---

## 待研究事項

1. **Automem 原始碼位置**: 目前只在 CodeWiki 文件中找到架構評估，尚未找到 Automem 的實現代碼
2. **MCP Server 支援**: 需確認 Automem 是否能作為 MCP server 運行
3. **記憶查詢 API**: 需了解 Automem 的查詢介面
4. **整合可行性**: 如何將 Automem 整合到 OpenClaw Agent 系統中

---

## 下一步行動
1. 使用 OpenCode CLI 多代理系統深入研究
2. 搜尋 Automem 的原始碼倉庫
3. 設計記憶管理 agent 的架構
