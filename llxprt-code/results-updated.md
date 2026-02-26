## 專案現況 (更新 2026-02-04)

llvmprt-code 是一個 **AI 驅動的 CLI 程式碼輔助工具**，採用 **TypeScript/Node.js monorepo** 架構，支援多種 LLM 提供商（Gemini、Anthropic、OpenAI 等）和本地模型。

---

### 專案狀態摘要 (2026-02-04)

**最新同步日期**：2026-01-31 (Antigravity), 2026-02-02 (Source Code)

**主要進展**：
- ✅ **Static/Virtual 雙模式架構**：已實施 useRenderMode hook 與雙模式渲染
- ✅ **Screen Reader 支援**：ScreenReaderAppLayout 已實作
- ✅ **Tabs 基礎設施整合**：TabBar、TODO Tab、System Tab 已移植
- ✅ **Terminal Corruption 修復**：解決 Issue #26 (CTRL+C 退出問題)
- ✅ **UI Parity 完成**：ToolCall UI 組件已移植 (待驗證建置)

**性能狀態**：
- **當前提升**：+10.15%
- **目標提升**：+30%
- **差距**：需額外 +20%

**對齊度狀態**：**90-95%** (排除完全同步需求)

**Git 狀態**：
- **Branch**: `opencode-dev`
- **Working Tree**: Clean
- **最新提交**: `07b8f13b6` (ci: update OpenCode model to glm-4.7-free)

---

## 未完成任務

### 🔴 高優先級（性能關鍵 / 阻塞問題）

#### 1. 系統化 Memoization（性能優化核心）
**來源**：`1121a3ee-459c-40b2-b86f-7b86564a1cb3/`
**時間估計**：4-6 小時
**影響**：+20-30% 性能提升（達到目標 +30%）

**具體任務**：
- [ ] 審查 gemini-cli 的 memoization 策略
- [ ] 識別未 memoize 的昂貴組件：
  - [ ] `StatsDisplay`
  - [ ] `InputPrompt`（部分）
  - [ ] 其他需要 memoization 的組件
- [ ] 實施 `React.memo` 包裝
- [ ] 實施 `useMemo` / `useCallback` 優化
- [ ] 性能測試驗證

---

#### 2. Debug 'Range is not defined' Crash
**來源**：`a23b76fd-8e45-4fba-a290-640871f0ea9a/`
**問題**：Runtime crash due to browser API leak in Node.js/Ink environment

**具體任務**：
- [x] Search for `Range` usage in codebase
- [ ] Inspect `DebugProfiler.tsx` for browser-specific APIs
- [ ] Inspect dependencies for `Range` usage
- [ ] Reproduce crash locally if possible
- [ ] Fix the `Range` error（polyfill or remove offending code）

---

#### 3. 虛擬化架構修復（關鍵缺陷）
**來源**：`d94ee6dd-4f45-490b-92df-dc7c98f0e078/review_report.md`
**狀態**：🔴 **DO NOT MERGE** 發現關鍵架構缺陷

**關鍵缺陷**：
- 🔴 **Defect 1**: 虛擬化繞過 - Pending Items 被組合成單一大區塊導致無法虛擬化
- 🔴 **Defect 2**: 脆弱顯示邏輯 - 只在 `streamingState === 'responding'` 時渲染
- 🟠 **Defect 3**: 低劣高度估算 - 硬編碼 `const getEstimatedItemHeight = () => 100`

**修復計畫**：
1. 扁平化 Pending Items - 類似 history 映射的方式
2. 修正渲染條件 - 應為 `pendingHistoryItems.length > 0`
3. 動態估算 - 實施更智慧的 `estimatedItemHeight`

---

#### 4. AST-Grep 遷移（核心重構）
**來源**：`be07420c-f019-439b-bfaf-171328c12583/`
**目標**：替換現有邏輯為 `@ast-grep/napi` 以加速程式碼分析

**具體任務**：
- [ ] 實施 `validateASTSyntax`
- [ ] 重構 `extractDeclarations`
- [ ] 重構 `findRelatedSymbols`
- [ ] 新增單元測試（Freshness & Git 邏輯）

**審查發現**：
- 🔴 **Working Set Context 未顯示**：editPreviewLlmContent 只顯示連接文件數量，隱藏了上下文
- 🟠 **缺少單元測試**：驗證 Freshness Check 邏輯和 RepositoryContextProvider 測試
- 🟡 **簽名資訊不足**：Skeleton View 只提供名稱和類型，缺少參數和回傳類型
- 🟡 **Git 命令穩健性**：處理檔名編碼問題（空格或非 ASCII 字元）

---

### 🟡 中優先級（代碼品質與架構）

#### 5. pendingHistory 欄位清理
**時間**：30-60 分鐘
**風險**：極低（已確認未被使用）

**調查結果**：gemini-cli 根本沒有 `pendingHistory` 欄位

**具體任務**：
- [ ] 從 `UIStateContext` interface 移除 `pendingHistory: HistoryItem[]`
- [ ] 從 `AppContainer.tsx` 移除初始化（Line 1530）
- [ ] 確認無其他引用
- [ ] 運行測試確保無破壞

---

#### 6. 重複 useFlickerDetector 調用檢查
**時間**：1-2 小時
**背景**：審查報告聲稱 DefaultAppLayout 重複調用

**具體任務**：
- [ ] 檢查 `DefaultAppLayout.tsx` 的 useFlickerDetector 使用
- [ ] 確認 AppContainer 是否也調用
- [ ] 如有重複，移除重複調用
- [ ] 測試閃爍檢測功能正常

---

#### 7. TODO Tab 布局修復
**來源**：`1121a3ee-459c-40b2-b86f-7b86564a1cb3/`

**具體任務**：
- [ ] Investigate and Refine TODO Tab Integration
- [ ] Fix the "pushing up" layout issue in the TODO tab
- [ ] Verify TODO tab styling and layout stability

---

#### 8. 基礎設施負債清理 (新增)
**來源**：`3ab59064-4305-4ec2-a0d3-4ec372aee44c/`
**時間**：2-3 小時

**具體任務**：
- [ ] 替換 `getWorkspaceFiles` 中的 `find` 命令為 `fast-glob` (提升性能與可靠性)
- [ ] 更新 `resolveImportPath` 以支援多種副檔名
- [ ] 更新 `esbuild.config.js` externals，確保建置管道正確

---

#### 9. MCP 實作比較完成 (新增)
**來源**：`f54f70aa-8304-4e71-88c1-c2970ef637d1/`

**具體任務**：
- [ ] 比較 `loadExtensions` (extension.ts) 的實作
- [ ] 比較 `ExtensionStorage` (storage.ts) 的實作
- [ ] 確認新 extension 載入邏輯的一致性

---

#### 10. 配置介面修補
**來源**：來源碼 grep (`packages/core/src/utils/ignorePatterns.ts`)
**時間**：1 小時

**具體任務**：
- [ ] 在 Config interface 中實作 `getCustomExcludes` 方法
- [ ] 移除 ignorePatterns.ts 中的 TODO 註解 (Line 167, 202)

---

### 🟢 低優先級（增強功能 / 技術債）

#### 11. SettingsDialog 優化（Scheme 3）
**來源**：`3a428465-4482-42ed-8f08-452a32fa2b7c/`
**狀態**：實作計畫已制定，待執行
**目標**：防止不必要的 `generateDynamicToolSettings` 執行

---

#### 12. staticAreaMaxItemHeight 約束
**時間**：2-3 小時
**背景**：gemini-cli 有此功能，llxprt-code 目前沒有

**具體任務**：
- [ ] 研究 gemini-cli 的 `staticAreaMaxItemHeight` 實施
- [ ] 評估是否對 llxprt-code 有價值
- [ ] 如果有價值，實施高度約束邏輯
- [ ] 測試 Static 模式穩定性

---

#### 13. 移除重複 preferredEditor 設置
**來源**：`7b2770fe-5b28-4a7a-a72d-4cdb7a593ebc/`
**狀態**：已延後（因建置相容性需求，已添加 TODO）

**具體任務**：
- [-] Remove duplicate `preferredEditor` in `packages/cli/src/config/settingsSchema.ts`

---

#### 14. Code Comment Reinforcement (CCR) 規則創建 (新增)
**來源**：`7248c104-3e66-4f17-946a-472790e39773/`

**具體任務**：
- [ ] 生成最終化的 CCR 規則集
- [ ] 創建 `PROJECT_RECIPE.md` 提供基礎設施與 CI 推薦

---

#### 15. Shopify App Template 架構設計 (新增)
**來源**：`7906414f-3dc1-4452-9b96-13cf2108257e/`

**具體任務**：
- [ ] 審查實作計畫
- [ ] 實作設計中的 polyrepo 方法

---

## 待處理事項

### Hacks 與臨時解決方案

#### 1. Ink Layout Retrieval Mock
**位置**：`src/ui/utils/ink-utils.ts`

**問題**：`getBoundingBox` 在核心 Ink 庫中不存在，使用了最佳化的 mock 實作

**待辦**：
- [ ] 調查正確的 Ink 佈局坐標檢索方法
- [ ] 取代 mock 實作為穩健的佈局檢索方法

---

#### 2. Config Context Hack
**位置**：`packages/cli/src/config/config.ts` (Line 962)

**問題**：臨時 hack 用於傳遞 `contextFileName`，應該通過更好的依賴注入或狀態管理處理

**待辦**：
- [ ] 重構 contextFileName 傳遞邏輯
- [ ] 移除 "This is a bit of a hack" 註解

---

#### 3. 待實作的 Notifications 組件

**問題**：計畫中提到的 `Notifications` 組件尚未實作

---

### 架構差異與上游同步問題

#### 1. 與 gemini-cli 的主要差異
- **Settings Architecture**：上游遷移到嵌套設定 schema（V2）；llxprt-code 保留扁平設定以維持多提供商 UI 相容性
- **UI Parity**：DialogManager.tsx 列出四個未移植的組件：
  - `LoopDetectionConfirmation`
  - `ProQuotaDialog`
  - `ModelDialog`
  - `IdeTrustChangeDialog`
- **Subagents**：llxprt-code 使用自定義 subagent 架構，與上游的 `CodebaseInvestigator` 模式不相容

---

#### 2. Provider Implementation Gaps

**OpenAIProvider** (`packages/core/src/providers/openai/OpenAIProvider.ts`):
- [ ] Line 974: `TODO: Implement server tools for OpenAI provider`
- [ ] Line 984: `TODO: Implement server tool invocation for OpenAI provider`
- [ ] Line 4663: `TODO: Implement response parsing based on detected format`
- [ ] OpenAIProvider 缺少完整的 OAuth refresh 實作（在測試中標記為 `NotYetImplemented`）
- [ ] Tool ID 正規化 (`call_`) 處於臨時私有方法狀態

**AnthropicProvider**:
- [ ] Server tools 和 tool invocation TODO (類似 OpenAI)
- [ ] Tool ID 正規化 (`toolu_`) 處於臨時私有方法狀態

**GeminiProvider**:
- ✅ Server tools 已實作 (`web_search`, `web_fetch`)
- [ ] GeminiOAuthProvider 處於過渡狀態，橋接新介面到舊版 Google OAuth 基礎設施

**OpenRouter Support**:
- 沒有專門的 OpenRouter provider。支援是通過 400 錯誤檢測和激進的工具響應壓縮在 OpenAIProvider 中「黑進來的」

---

#### 3. 架構「Hardening」不一致性
- 專案正在進行 **Stateless Hardening** (`PLAN-20251023-STATELESS-HARDENING`) 的中間階段
- AnthropicProvider 和 GeminiProvider 已大幅重構為無狀態
- OpenAIProvider 仍然是「熱點」的狀態邏輯和模型特定的條件 hacks（例如 Kimi 和 Mistral 特定的工具 ID 正規化）

---

#### 4. 臨時 Hacks & Mocks
- **硬編碼模型**：Gemini 和 Anthropic provider 在 OAuth 激活時退回到硬編碼模型列表，因為 `models.list` 端點通常在 OAuth tokens 時失敗
- **Ink Stubbing**：測試工具依賴於 `ink-stub`，表明終端機 UI 整合測試的局限性
- **Tool ID Mapping**：`call_` (OpenAI)、`toolu_` (Anthropic) 和 `hist_tool_` (內部歷史) 之間的正規化是通過每個 provider 中的臨時私有方法處理，而不是 core 中的統一服務

---

### 待驗證的功能

#### ToolCall UI 實作驗證
**來源**：`1121a3ee-459c-40b2-b86f-7b86564a1cb3/` + `db9177a6-5a0e-4aed-ab83-8ec071b1078c/`

**具體任務**：
- [ ] 驗證新增移植的 `ToolResultDisplay`、`StickyHeader`、`ShellToolMessage` 的建置通過
- [ ] 驗證 lint 通過

---

#### ScreenReader 完整測試
**已實作**：
- ✅ `ScreenReaderAppLayout.tsx`
- ✅ SR 條件渲染

**待測試**：
- [ ] 實際使用 NVDA/VoiceOver 測試
- [ ] 驗證導航流程
- [ ] 確認 Footer 資訊優先播報

---

#### 修復驗證 (多個會話)
**來源**：`0a732cb1`, `cc881aa8`, `a23b76fd` 等會話

**具體任務**：
- [ ] 驗證 E2E 測試修復通過
- [ ] 驗證 UI 穩定性修復生效
- [ ] 確認無迴歸
- [ ] 找到這些會話的 `.resolved` 檔案以確認完成狀態

---

### E2E 測試強化 (新增)
**來源**：`223c9831-d817-4a30-a16c-52bfa9085b18/e2e_migration_analysis.md`

**具體任務**：
- [ ] 添加 `recordFiber` 到測試執行器
- [ ] 實作 `readFiberLog()` 輔助函數
- [ ] 實作 `waitForUIState(predicate)` 輔助函數以加強非同步 UI 測試
- [ ] 整合到 CI/CD 流程

---

### 程式碼中的其他 TODO 發現

**packages/core/src/core/subagent.ts**:
- Line 170: `TODO: In the future, this needs to support 'auto' or some other string to support routing use cases.`
- Line 188: `TODO: Consider adding max_tokens as a form of budgeting.`

**packages/core/src/code_assist/server.ts**:
- Line 42: `TODO: Use production endpoint once it supports our methods.`

**packages/core/src/tools/shell.ts**:
- Line 479: `TODO: Need to adapt summarizeToolOutput to use ServerToolsProvider`

**packages/core/src/tools/edit.ts**:
- Line 498: `TODO(chrstn): See GitHub PR #5618` (Legacy debt)

**packages/core/src/ide/ide-client.ts**:
- Line 479: `TODO(#3487): use the CLI version here.`

**packages/cli/src/config/config.ts**:
- Line 635: `TODO: Consider if App.tsx should get memory via a server call or if Config should refresh itself.`

**packages/cli/src/ui/contexts/KeypressContext.tsx**:
- Line 324: `TODO: Replace with a more robust IME-aware input handling system`

**packages/cli/src/ui/commands/setupGithubCommand.ts**:
- Line 101: `TODO: Adapt this command for llxprt-code` (功能目前禁用)

**packages/cli/src/ui/hooks/useCommandCompletion.tsx**:
- Line 215: `TODO: Fix this - need proper completion range`

**packages/cli/src/services/todo-continuation/todoContinuationService.ts**:
- Line 104: `TODO: Add timeout functionality in the future`

**packages/cli/src/utils/privacy/ConversationDataRedactor.ts**:
- Line 237 & 470: `TODO: Re-add redactContentPart/isPatternEnabled method when needed`

**packages/a2a-server/src/config/config.ts**:
- Line 82: `/// TODO: Wire up folder trust logic here.`

**packages/a2a-server/src/agent/task.ts**:
- Line 848 & 888: `TODO: Determine what it mean to have, then add a prompt ID.`

---

## 最近工作摘要

### 1. UI Architecture Parity Analysis (`db9177a6...`)
- **狀態**：部分/接近完成
- **完成**：移植了 gemini-cli 的高性能虛擬化和 UI 組件
- **待辦**：驗證 ToolCall UI 組件的建置和 lint 通過

### 2. Profile Loading & UI Bug Fix (`e5d945a7...`)
- **狀態**：已完成
- **完成**：修復了 "Initializing..." 畫面的 UI bug

### 3. Dependency Migration (`f4182ee1...`)
- **狀態**：已完成
- **完成**：將依賴移動到正確的 package 位置

### 4. Terminal Corruption Issue (Issue #26) (`848a62d7...`)
- **狀態**：已完成
- **完成**：實作了同步清理以修復終端機損壞
- **修復內容**：
  - 使用 `fs.writeSync` 進行同步寫入
  - 對齊 SIGINT 處理器
  - 新增 SIGTERM、uncaughtException、unhandledRejection 處理

### 5. Code Review: LLXPRT-4 Virtualization (`d94ee6dd...`)
- **狀態**：🔴 **DO NOT MERGE**
- **發現**：關鍵架構缺陷
  - 虛擬化繞過
  - 脆弱顯示邏輯
  - 低劣高度估算

### 6. Tree-sitter to ast-grep Migration Plan (`be07420c...`)
- **狀態**：計畫已審查，待實施
- **完成**：Golden Master 測試準備

### 7. Debugging UI Instability (`a23b76fd...`)
- **狀態**：部分完成
- **完成**：問題理解與分析、初始修復、UI 穩定性優化
- **待完成**：修復驗證（缺少 .resolved 檔案）

---

## 建議執行順序

### 階段 A：臨界修復與核心優化（優先）
**時間**：8-10 小時

1. **Debug 'Range is not defined' Crash**
   - 修復運行時崩潰以確保系統穩定性

2. **修復虛擬化架構缺陷**
   - 扁平化 Pending Items
   - 修正渲染條件
   - 實施動態高度估算

3. **系統化 Memoization**
   - 審查 gemini-cli 策略
   - 識別未 memoize 的昂貴組件
   - 實施優化
   - 性能測試

---

### 階段 B：代碼清理與架構債務（1-2 週內）
**時間**：4-6 小時

4. **pendingHistory 清理**（30-60 分鐘）
5. **useFlickerDetector 重複檢查**（1-2 小時）
6. **TODO Tab 修復**（30 分鐘）
7. **基礎設施負債清理**（2-3 小時）
   - fast-glob 遷移
   - resolveImportPath 更新
   - esbuild.config.js externals
8. **配置介面修補**（1 小時）
   - 實作 getCustomExcludes
9. **MCP 實作比較完成**（1 小時）
10. **ToolCall UI 驗證**（30 分鐘）

---

### 階段 C：增強功能與測試（可選/未來）
**時間**：6-8 小時

11. **移植缺失的 UI 組件**（DialogManager）
12. **Provider Server Tools 統一**（Gemini → Shared Utility → OpenAI/Anthropic）
13. **OpenAI Stateless Refactor**（應用 Stateless Hardening 模式）
14. **統一 Tool ID 管理**（移至 core 的專用服務）
15. **staticAreaMaxItemHeight**（2-3 小時）
16. **性能測試完善**（3-4 小時）
17. **無障礙性測試**（2-3 小時）
18. **E2E 測試強化**
   - recordFiber/readFiberLog
   - waitForUIState

---

### 階段 D：核心重構（長期）

19. **AST-Grep 遷移完成**
    - 實施缺失功能
    - 修復 Working Set Context 顯示
    - 新增完整測試覆蓋

20. **Code Comment Reinforcement 規則**（新增）
21. **Shopify App Template 架構**（新增）

---

## 預期成果

### 完成階段 A 後：
- **穩定性**：修復 'Range' 崩潰和虛擬化缺陷
- **性能**：達到 gemini-cli 目標（+30% 提升）
- **對齊度**：90-95%
- **總時間**：8-10 小時

### 完成階段 B 後：
- **代碼品質**：移除未使用欄位，減少重複，清理基礎設施負債
- **架構穩健性**：修補配置介面缺口
- **總時間**：12-16 小時

### 完成所有階段（A + B + C + D）後：
- **性能**：超越基準
- **對齊度**：95%+
- **代碼品質**：生產就緒，完整測試
- **總時間**：18-26 小時

---

## 🚫 明確排除項目

### Phase 4: 剩餘 Tabs 實作 ✅
**狀態**：已完成
- [x] 移植 `TodoTab`
- [x] 移植 `SystemTab`

### gemini-cli 完全同步
**原因**：
- llxprt-code 有自己的架構優勢（FlickerDetector 增強版）
- 不需要 100% 複製 gemini-cli
- 目標是**對齊核心優化**，非完全一致

---

## 關鍵會話參考

### 重要會話目錄
- **`1121a3ee-459c-40b2-b86f-7b86564a1cb3`** - Static Architecture 實作與相關任務（性能優化核心）
- **`a23b76fd-8e45-4fba-a290-640871f0ea9a`** - Debugging Runtime Crash and UI Layout
- **`848a62d7-51b3-4016-badd-81e6dba9ca30`** - Terminal Corruption Issue (Issue #26)
- **`3a428465-4482-42ed-8f08-452a32fa2b7c`** - SettingsDialog 優化
- **`7b2770fe-5b28-4a7a-a72d-4cdb7a593ebc`** - UI 對齊與修復任務
- **`223c9831-d817-4a30-a16c-52bfa9085b18`** - 專案狀態報告與 E2E 遷移分析
- **`d94ee6dd-4f45-490b-92df-dc7c98f0e078`** - LLXPRT-4 虛擬化代碼審查（關鍵架構缺陷，DO NOT MERGE）
- **`a0c75142-4be2-4289-bffc-07f99f0b5650`** - ASTEdit Tool Refactoring 審查
- **`be07420c-f019-439b-bfaf-171328c12583`** - AST-Grep 遷移任務
- **`db9177a6-5a0e-4aed-ab83-8ec071b1078c`** - UI Architecture Parity Analysis
- **`3ab59064-4305-4ec2-a0d3-4ec372aee44c`** - Refining AST tools and build config（基礎設施負債）
- **`f54f70aa-8304-4e71-88c1-c2970ef637d1`** - MCP 實作比較
- **`7248c104-3e66-4f17-946a-472790e39773`** - Code Comment Reinforcement 規則創建
- **`7906414f-3dc1-4452-9b96-13cf2108257e`** - Shopify App Template 架構設計
- **`0a732cb1-a6b2-4b72-ba36-65ab416c2cf1`**, **`cc881aa8-2376-4413-9ffd-2df9e3200323`** - 修復驗證（缺少 .resolved 檔案）

### Opencoded Session Files
- `/home/soulx7010201/MyLLMNote/llxprt-code/Opencode/add233c5043264d47ecc6d3339a383f41a241ae8/`
  - 包含多個 JSON 會話檔案（最後修改：2026-01-31）
  - 主要用於 OpenCode 框架的會話管理元數據

---

## 下一步行動建議

**立即行動**（本日/本週）：
1. 🚨 Debug 'Range is not defined' Crash - 優先級最高，阻塞系統穩定性
2. 🔧 修復虛擬化架構缺陷 - DO NOT MERGE 關鍵問題
3. 🔄 Start 階段 A：系統化 Memoization
4. ✅ 驗證 ToolCall UI 組件建置通過

**短期行動**（1-2 週）：
5. 完成階段 B：代碼清理與架構債務
6. 修復 TODO Tab 布局
7. 清理基礎設施負債（fast-glob 等）
8. 驗證多個會話的修復狀態（找到 .resolved 檔案）
9. 性能測試驗證

**長期行動**（視需求）：
10. 階段 C：增強功能與測試
11. 階段 D：核心重構（AST-Grep）
12. Code Comment Reinforcement 規則
13. Shopify App Template 架構

---

## 報告生成信息
**生成時間**：2026-02-04
**審查範圍**：
- ~/MyLLMNote/llxprt-code/results.md (原有報告)
- ~/MyLLMNote/llxprt-code/Antigravity/（29 個會話目錄）
- ~/MyLLMNote/llxprt-code/Opencode/（JSON 會話檔案）
- ~/MyLLMNote/openclaw-workspace/repos/llxprt-code/（原始碼目錄）
- 4 個並行背景 Explore Agent 的綜合分析結果
- 來源碼中 TODO/FIXME/HACK 標記的全面掃描

**更新內容**：
- ✅ 保留所有原有任務與發現
- ✅ 新增 8 個會話中發現的未記錄任務
- ✅ 詳細列出所有原始碼中的 TODO/FIXME 標記
- ✅ 更新優先級與執行順序建議
- ✅ 新增 E2E 測試強化任務
- ✅ 驗證 Git 狀態（clean，最新提交：07b8f13b6）

**關鍵發現**：
1. 架構缺陷（虛擬化繞過）未被列入高優先級修復
2. 多個基礎設施負債（fast-glob, MCP 比較）未被記錄
3. 配置介面缺口（getCustomExcludes）未列入待辦
4. 多個會話缺少 .resolved 檔案，修復狀態未確認
5. E2E 測試強化任務未被追蹤
