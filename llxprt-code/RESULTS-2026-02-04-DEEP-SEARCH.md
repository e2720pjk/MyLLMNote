# 專案審查結果：llxprt-code
**生成時間**: 2026-02-04 15:59:00 UTC
**審查範圍**: 並行多代碼庫深度搜尋（9個探索代理）
**專案位置**: ~/MyLLMNote/llxprt-code/

---

## 專案現況

**llxprt-code** 是一個 **AI 驅動的 CLI 程式碼輔助工具**，採用 **TypeScript/Node.js monorepo** 架構，支援多種 LLM 提供商（Gemini、Anthropic、OpenAI 等）和本地模型。

### 當前狀態

| 指標 | 數值 |
|:-----|:-----|
| **Git 分支** | `main` (最新提交: e07cbec) |
| **會話記錄** | 29 個 Antigravity 會話 + 341 個 Opencode JSON 會話檔案 |
| **對齊度** | 85-90% |
| **性能提升** | +10.15%（目標：+30%，差距：+20%） |

### 主要進展

- ✅ **Static/Virtual 雙模式架構**: useRenderMode hook 與雙模式渲染
- ✅ **Screen Reader 支援**: ScreenReaderAppLayout 已實作
- ✅ **Tabs 基礎設施**: TabBar、TODO Tab、System Tab 已移植
- ✅ **Terminal Corruption 修復**: 解決 Issue #26 (CTRL+C 退出問題)
- ✅ **Fiber-Recorder 集成**: 已安裝並導入測試環境

---

## 未完成任務

### 🔴 高優先級（阻塞性問題）

#### 1. 虛擬化架構關鍵缺陷 ⚠️ DO NOT MERGE ⚠️
**來源**: `d94ee6dd-4f45-490b-92df-dc7c98f0e078/`
**狀態**: **未修復** - 三個關鍵缺陷已確認
**嚴重性**: **CRITICAL** - 破壞性架構缺陷

**三個缺陷確認**:

1. **Defect 1: 虛擬化繞過 (Virtualization Bypass)**
   - **位置**: `packages/cli/src/ui/layouts/DefaultAppLayout.tsx` lines 203-224
   - **問題**: `pendingHistoryItems` 被組合成單一大區塊，作為 `key: 'pending'` 傳遞
   - **影響**: 50+ 工具調用渲染為單一大 React 組件，完全繞過虛擬化
   - **代碼**:
   ```tsx
   const pendingElement = (
     <OverflowProvider>
       <Box ref={uiState.pendingHistoryItemRef} flexDirection="column">
         {pendingHistoryItems.map((item, i) => (
           <HistoryItemDisplay ... />
         ))}
         <ShowMoreLines constrainHeight={constrainHeight} />
       </Box>
     </OverflowProvider>
   );
   {
     key: 'pending',
     estimatedHeight: 100,
     element: pendingElement,
   },
   ```

2. **Defect 2: 脆弱顯示邏輯 (Fragile Display Logic)**
   - **位置**: `DefaultAppLayout.tsx` lines 206 & 466（雙重複製）
   - **問題**: 渲染邏輯在兩個路徑中重複（Alternate Buffer vs. Standard Buffer），無狀態檢查
   - **影響**: 增加 UI 不一致風險

3. **Defect 3: 低劣高度估算 (Poor Height Estimation)**
   - **位置**: `DefaultAppLayout.tsx` lines 72-73, 229, 234, 249
   - **問題**: 硬編碼 `function estimateScrollableMainContentItemHeight(_index: number): number { return 100; }`
   - **影響**: 導致跳動滾動和不正確的滾動條

**次要發現**:
- `ChatList.tsx` (Line 25): 使用 `.map()` 渲染對話列表而無虛擬化，數百個 checkpoints 會導致 Ink 渲染延遲

---

#### 2. Debug 'Range is not defined' Crash ✅ 根因已定位
**來源**: `a23b76fd-8e45-4fba-a290-640871f0ea9a/`
**狀態**: **根因已定位** - 待修復
**嚴重性**: **HIGH** - 運行時崩潰

**問題詳述**:
- **主要崩潰**: `packages/cli/src/ui/hooks/useMouseSelection.ts` line 243
  ```typescript
  const range = selectionRangeRef.current ?? new Range();  // 💥 Range not defined in Node.js
  ```
- **根因**: `Range` 是瀏覽器 API，在 Node.js/Ink 環境中不存在。雖然從 `ink` import，但可能只有類型定義或構造函數在運行時不可用
- **修復方案**:
  1. 添加環境檢查 `if (typeof Range !== 'undefined')`
  2. 使用 Ink 提供的 selection 機制或其他安全的替代方案
  3. 如果需要，實作一個 Node 環境的 mock

**其他瀏覽器 API 風險**:
- **ClipboardService.ts** (HIGH RISK):
  - Lines 17, 20, 25, 30: 直接使用 `navigator.clipboard`、`document.createElement`、`document.body.appendChild`、`document.execCommand`
  - 完全與 Node.js 不相容，會導致崩潰
  - **建議**: 統一改用 `commandUtils.ts` 中使用 `pbcopy`/`xclip`/`clip` 的平台特定解決方案

- **正確環境保護範例** (`renderLoopDetector.ts`):
  ```typescript
  if (typeof window !== 'undefined' && process.env.DEBUG) {
    // 瀏覽器代碼
  }
  ```

- **測試文件**:
  - `oauthUrlMessage.test.tsx`: 使用 JSDOM 提供 `document`（測試環境可接受）

---

#### 3. 系統化 Memoization（性能優化核心）
**來源**: `1121a3ee-459c-40b2-b86f-7b86564a1cb3/`
**時間估計**: 4-6 小時
**影響**: +20-30% 性能提升，達到目標 +30%

| 組件 | React.memo | useMemo 機會 | useCallback 狀態 | 影響級別 |
|------|-----------|-------------|-----------------|---------|
| **StatsDisplay** | ❌ MISSING | `computeSessionStats` (L174) | N/A | High |
| **ModelStatsDisplay** | ❌ MISSING | `activeModels` filtering (L51) | N/A | Medium |
| **CacheStatsDisplay** | ❌ MISSING | Cache calculation (L77-80) | N/A | Medium |
| **ToolStatsDisplay** | ❌ MISSING | `totalDecisions` reduce (L77-88) | N/A | Medium |
| **InputPrompt** | ❌ MISSING | `calculatePromptWidths`, `parseInputForHighlighting` | ✅ EXCELLENT | Medium |

**詳細優化需求**:

1. **StatsDisplay.tsx** (High Impact):
   - 像導出包裝為 `React.memo`
   - Line 174: `const computed = computeSessionStats(metrics);` 需要 `useMemo` 包裝
   - 子組件 `StatRow`、`SubStatRow`、`Section` 也應包裝為 `memo`

2. **ModelStatsDisplay.tsx**:
   - Line 51: `activeModels` 過濾邏輯和 Line 72: `getModelValues` 需要移入 `useMemo`

3. **CacheStatsDisplay.tsx**:
   - 組件從 `useRuntimeApi` 獲取數據並執行多個 null 檢查和對象訪問
   - 需要用 `useMemo` 穩定化渲染輸出

4. **ToolStatsDisplay.tsx**:
   - Line 77: `reduce` 函數計算 `totalDecisions` 是昂貴操作，必須用 `useMemo` 包裝

5. **InputPrompt.tsx**:
   - 已經大量使用 `useCallback` (L182, 210, 245, 292, 339, 718)
   - 但組件本身**未**包裝為 `React.memo`
   - Line 918, 926: `parseInputForHighlighting` 和 `buildSegmentsForVisualSlice` 在 `linesToRender.map` 內調用，屬於高頻計算

---

#### 4. AST-Grep 遷移（核心重構）
**來源**: `be07420c-f019-439b-bfaf-171328c12583/`
**目標**: 替換現有邏輯為 `@ast-grep/napi` 以加速程式碼分析

**調查發現**:
- **請求的函數不存在**: `validateASTSyntax`、`extractDeclarations`、`findRelatedSymbols` 在 llxprt-code 中未找到
- **CodeWiki 使用 tree-sitter**:
  - `CodeWiki/codewiki/src/be/dependency_analyzer/analyzers/typescript.py` — 使用 `tree_sitter_typescript`
  - `CodeWiki/codewiki/src/be/dependency_analyzer/analyzers/javascript.py` — 使用 `tree_sitter_javascript`
  - `CodeWiki/codewiki/src/be/dependency_analyzer/analyzers/python.py` — 使用 Python 原生 `ast`
- **llxprt-code 使用自定義解析**:
  - `packages/core/src/parsers/TextToolCallParser.ts` — 包含 `GemmaToolCallParser`，使用字符串操作和 regex 處理工具調用，而非完整 AST 解析
- **依賴狀態**:
  - `@ast-grep/napi`: 未在任何 package.json 中找到
  - `typescript`: 用於類型檢查，不用於運行時 AST 解析

**結論**:
- 如果目標是遷移 CodeWiki 的 Python tree-sitter 代碼：應將 `typescript.py` 和 `javascript.py` 的邏輯遷移到 `@ast-grep/napi`
- 如果目標是在 llxprt-code 中添加 AST 能力：應使用 `@ast-grep/napi` 實現新的 `CodeAnalyzer`

---

#### 5. E2E 測試強化 - Fiber-Recorder 遷移
**來源**: `223c9831-d817-4a30-a16c-52bfa9085b18/`
**狀態**: 🟡 **Integration Pending** - Library Verified, Phase 5 in progress

**建議**: 混合方法（增強現有測試，非替換）

**具體任務**:
- [x] Analysis Phase: All completed
- [x] Planning Phase: Review with user (id: 7 - Pending)
- [x] Implementation Phase 1-4: All completed
- [/] Implementation Phase 5: Update component snapshot tests
- [ ] Run pilot tests with fiber-recorder
- [ ] Measure test execution time impact
- [ ] Check for false positives in CI
- [ ] Integrate to CI/CD pipeline
- [ ] Document patterns and best practices

---

### 🟡 中優先級任務

#### 6. 基礎設施負債清理
**來源**: `3ab59064-4305-4ec2-a0d3-4ec372aee44c/`
**時間**: 2-3 小時

**發現**:

1. **esbuild.config.js externals** (Lines 44-59):
   - 包含平台特定 externals 如 `@lydell/node-pty-darwin-arm64`
   - **問題**: 如果支持的平台集合變化，需要更動態的方法或整合
   - **建議**: 考慮動態處理平台特定 externals

2. **zedIntegration.ts tool result handling** (Lines 688-732, 743-942):
   - `runTool` 方法執行工具並處理結果
   - 調用 `extractToolResultText` (line 944) 和 `toToolCallContent` (line 1420)
   - **問題**: 當前實現通過將 `ToolResult` 轉換為 `acp.ToolCallContent` 來處理
   - **建議**: 確保正確處理所有潛在的 `ToolResult` 形狀，特別是複雜輸出或錯誤

3. **ast-edit.ts**:
   - **文件未找到**: 可能已重命名或在不同上下文中
   - 搜索了 `ast-edit` 和 `resolveImportPath` 但未找到匹配
   - **下一步**: 驗證文件是否存在或名稱是否不同

4. **跨平台問題**:
   - **scripts/analyze-stale-sessions.sh** (Line 23): 使用 `find` 命令
     ```
     session_file=$(find "$STORAGE_ROOT/session" -name "${session_id}.json" ...)
     ```
     - **問題**: 非跨平台
     - **建議**: 替換為 Node.js 腳本使用 `fast-glob` 或更健壯的 shell 方法
   - **packages/core/src/tools/grep.ts** (Lines 151, 153, 154):
     - 使用 `process.platform === 'win32'` 決定 `where` 或 `command`
     - **評價**: 這是好的守護，確保所有此類用法集中在共享工具中
   - **packages/core/src/auth/token-store.ts**: 包含平台特定檔案權限邏輯

5. **resolvePath function** (`resolvePath.ts` Lines 10-21):
   - 正確處理 `~` 和 `%userprofile%`
   - **問題**: 檢查是否需要在解析路徑時支持多個擴展名

---

#### 7. MCP 實作比較完成
**來源**: `f54f70aa-8304-4e71-88c1-c2970ef637d1/`
**狀態**: 2 個未完成任務

**已完成**:
- [x] 探索 llxprt-code 和 llxprt-code-2 的文件結構
- [ ] Compare `loadExtensions` in `packages/cli/src/config/extension.ts` (Old vs New)
- [ ] Compare `ExtensionStorage` in `packages/cli/src/config/storage.ts`
- [ ] Identify the cause of the issue in `llxprt-code`
- [ ] Report findings to the user

---

#### 8. 待實作的功能（源碼 TODO 發現總結）
**總計**: 230+ 個標記（packages/core: 128 個, packages/cli: 109 個）

**高優先級（Critical/High Severity）**:

| 文件路徑 | 行 | 標記 | 上下文 | 嚴重性 |
|---------|---|------|--------|--------|
| `packages/core/.../OpenAIProvider.ts` | 974 | TODO | Server tools for OpenAI 完全未實作 | **Critical** |
| `packages/core/.../OpenAIProvider.ts` | 984 | TODO | Server tool invocation for OpenAI 缺失 | **Critical** |
| `packages/core/.../OpenAIProvider.ts` | 4663 | TODO | Tool response parsing 目前是佔位符（返回原始內容） | **High** |
| `packages/core/.../coreToolScheduler.test.ts` | 1302 | TODO | **Bug**: YOLO 模式並行工具執行違反順序要求 | **High** |
| `packages/core/.../yolo.toml` | 3 | WARNING | 禁用所有安全檢查；在不受信任環境中的嚴重安全風險 | **High** |

**按類別分類**:

1. **Provider Implementations**:
   - `OpenAIProvider.ts` — 多個缺失的 server-side tool 支持和響應格式標準化
   - `geminiChat.ts:777` — WARNING: 當工具聲明為空但工具數組存在時記錄
   - `subagent.ts:170` — TODO: 需要支持 'auto' 路由字串
   - `subagent.ts:188` — TODO: 子代理的 token 預算（`max_tokens`）未實作

2. **UI Components**:
   - `DialogManager.tsx` — 多個未移植的對話框：`LoopDetectionConfirmation`、`ProQuotaDialog`、`ModelDialog`、`IdeTrustChangeDialog`
   - `useCommandCompletion.tsx:215` — TODO: 不當的補全範圍邏輯需要修復
   - `AppContainer.tsx:63` — TODO: IDE 集成目前中斷或未驗證
   - `KeypressContext.tsx:324` — TODO: 需要更健壯的 IME 感知輸入處理系統

3. **Tools and Utilities**:
   - `shell.ts:479` — TODO: `summarizeToolOutput` 需要適配 `ServerToolsProvider` 架構
   - `read-many-files.ts:90` — TODO: 文件截斷行為應通過 CLI 參數可配置
   - `todoContinuationService.ts:104` — TODO: 長時間運行的 todo continuation 缺少超時功能

4. **Configuration and Settings**:
   - `config.ts:962` — TODO: 標記為 "hack" 關於 `contextFileName` 的傳遞方式
   - `extension.ts:356` — TODO: 通過下載歸檔而非完整 `.git` 歷史優化擴展加載
   - `ignorePatterns.ts:167` — TODO: Config interface 中 `getCustomExcludes` 仍未實作

5. **Testing Debt**:
   - `packages/cli/tsconfig.json:29` — TODO: 在測試中抑制類型錯誤（#5691）需要解決
   - `setupGithubCommand.test.ts` — 多個測試被禁用/跳過，等待適配當前環境
   - `prompts-async.test.ts:199` — 與文件夾結構緩存優化相關的跳過測試（#680）

---

#### 9. 配置介面修補
**來源**: 源碼 grep (`packages/core/src/utils/ignorePatterns.ts`)
**時間**: 1 小時

**具體任務**:
- [ ] 在 Config interface 中實作 `getCustomExcludes` 方法
- [ ] 移除 ignorePatterns.ts 中的 TODO 註解 (Line 167, 202)

---

#### 10. SettingsDialog 優化（Scheme 3）
**來源**: `3a428465-4482-42ed-8f08-452a32fa2b7c/`
**狀態**: 實作計畫已制定，待執行
**目標**: 防止不必要的 `generateDynamicToolSettings` 執行

---

#### 11. pendingHistory 欄位清理 ✅ 已完成
**時間**: 調查完成
**狀態**: **已清潔**

**調查結果**:
- ✅ `pendingHistory` 場位**不存在**於當前實作中（遞歸搜索無結果）
- ✅ `pendingHistoryItems` **活躍使用**且對當前 UI 架構**至關重要**用於渲染流式 AI 響應和工具執行
- ✅ 在 `UIStateContext.tsx` 中正確定義
- ✅ 在 DefaultAppLayout.tsx 中正確使用 (Lines 97, 206, 466)
- ✅ 在掛鉤中使用 `useMemo` 進行記憶化
- ✅ 在測試中正確初始化

**結論**: 無需進一步清潔，待辦事項可關閉

---

#### 12. TODO Tab 布局修復
**來源**: `1121a3ee-459c-40b2-b86f-7b86564a1cb3/`
**狀態**: 待調查（探索任務運行中）

**待執行任務**（來自 task.md）:
- [ ] Investigate and Refine TODO Tab Integration
- [ ] Fix the "pushing up" layout issue in the TODO tab
- [ ] Verify TODO tab styling and layout stability

---

### 🟢 低優先級任務

#### 13. Code Comment Reinforcement (CCR) 規則創建
**來源**: `7248c104-3e66-4f17-946a-472790e39773/`

**具體任務**:
- [ ] Finalize `.agent-rules.md` (AI-facing)
- [ ] Create `PROJECT_RECIPE.md` (Infrastructure/CI recommendations)
- [ ] Verify with comprehensive example

---

#### 14. Shopify App Template 架構設計
**來源**: `7906414f-3dc1-4452-9b96-13cf2108257e/`
**狀態**: 13 個未完成任務（仍在規劃階段）

**已完成**:
- [x] Evaluate llxprt Tool
- [x] Research and Explain Concepts (Monorepo, Shopify/Remix templates, Polyrepo vs Monorepo trade-offs)

**待執行**:
- [ ] Analyze Project Structure (package.json, app/root.tsx, app/routes)
- [ ] Design Template Architecture (Select Polyrepo, identify reusable UI components)
- [ ] Create Implementation Plan (Draft `implementation_plan.md`)

---

## 待處理事項

### Hacks 與臨時解決方案

#### 1. Ink Layout Retrieval Mock
**位置**: `src/ui/utils/ink-utils.ts`

**問題**: `getBoundingBox` 在核心 Ink 庫中不存在，使用了最佳化的 mock 實作

**待辦**:
- [ ] 調查正確的 Ink 佈局坐標檢索方法
- [ ] 取代 mock 實作為穩健的佈局檢索方法

---

#### 2. Config Context Hack
**位置**: `packages/cli/src/config/config.ts` (Line 962)

**問題**: 臨時 hack 用於傳遞 `contextFileName`

**待辦**:
- [ ] 重構 contextFileName 傳遞邏輯
- [ ] 移除 "This is a bit of a hack" 註解

---

### 架構差異與 Provider 實施間隙

#### OpenAIProvider (`packages/core/src/providers/openai/OpenAIProvider.ts`):
- [ ] Line 974: `TODO: Implement server tools for OpenAI provider`
- [ ] Line 984: `TODO: Implement server tool invocation for OpenAI provider`
- [ ] Line 4663: `TODO: Implement response parsing based on detected format`
- OpenAIProvider 缺少完整的 OAuth refresh 實作（測試中標記為 `NotYetImplemented`）
- Tool ID 正規化 (`call_`) 處於臨時私有方法狀態

#### AnthropicProvider:
- [ ] Server tools 和 tool invocation TODO（類似 OpenAI）
- [ ] Tool ID 正規化 (`toolu_`) 處於臨時私有方法狀態

#### GeminiProvider:
- ✅ Server tools 已實作 (`web_search`, `web_fetch`)
- [ ] GeminiOAuthProvider 處於過渡狀態，橋接新介面到舊版 Google OAuth 基礎設施

#### OpenRouter Support:
- 沒有專門的 OpenRouter provider
- 支援是通過 400 錯誤檢測和激進的工具回應壓縮在 OpenAIProvider 中「黑進來的」

---

### 架構「Hardening」不一致性
- 專案正在進行 **Stateless Hardening** 的中間階段
- AnthropicProvider 和 GeminiProvider 已大幅重構為無狀態
- OpenAIProvider 仍然是「熱點」的狀態邏輯和模型特定的條件 hacks

---

### 架構差異與上游同步問題

#### 與 gemini-cli 的主要差異
- **Settings Architecture**：上游遷移到嵌套設定 schema（V2）；llxprt-code 保留扁平設定以維持多提供商 UI 相容性
- **UI Parity**：DialogManager.tsx 列出四個未移植的組件
- **Subagents**：llxprt-code 使用自定義 subagent 架構

---

### Provider 架構問題

#### 1. 多個 OpenAI 實現
- **`OpenAIProvider`**：標準 OpenAI 實現（4941 行）
- **`OpenAIResponsesProvider`**：專用於 /responses API 和 Codex 模式
- **`OpenAIVercelProvider`**：使用 Vercel AI SDK 的替代實現

**問題**:
- 重複的工具轉換邏輯
- 重複的錯誤處理
- 模型特定 hacks 分散在多個文件

#### 2. Tool ID Normalization 碎片化
- **Standard Provider**：使用內部私有方法
- **Vercel Provider**：使用 `toolIdUtils.ts`
- **Responses Provider**：使用 `utils/toolIdNormalization.js`
- **ToolIdStrategy.ts**：嘗試統一 Kimi/Mistral ID 映射

#### 3. 思考/推論提取不一致
- **OpenAIProvider**：使用 regex-based stripping
- **OpenAIVercelProvider**：使用 SSE 攔截解析
- **AnthropicProvider**：使用專門的 redaction 邏輯

---

## 關鍵會話參考

### 重要會話目錄（按優先級排序）

**🔴 高優先級**:
- `d94ee6dd` - LLXPRT-4 虛擬化代碼審查（關鍵架構缺陷，DO NOT MERGE）
- `a23b76fd` - Debugging Runtime Crash and UI Layout（15 個未完成任務，Range crash）
- `1121a3ee` - Static Architecture 實作與相關任務（性能優化核心）
- `223c9831` - E2E 測試 Fiber-Recorder 遷移（Integration Pending）

**🟡 中優先級**:
- `be07420c` - AST-Grep 遷移任務
- `3ab59064` - Refining AST tools and build config（基礎設施負債）
- `db9177a6` - UI Architecture Parity Analysis
- `3a428465` - SettingsDialog 優化

**🟢 低優先級**:
- `7b2770fe` - UI 對齊與修復任務
- `7248c104` - Code Comment Reinforcement 規則創建
- `7906414f` - Shopify App Template 架構設計
- `f54f70aa` - MCP 實作比較（2 個未完成任務）
- `a0c75142` - ASTEdit Tool Refactoring 審查

**已完成或進行中**:
- `848a62d7` - Terminal Corruption Issue (Issue #26) - All tasks completed
- `e5d945a7` - Profile Loading & UI Bug Fix - All tasks completed
- `f4182ee1` - Dependency Migration - All tasks completed
- `d8053952` - Code Review: UI Architecture Parity Analysis - All tasks completed

### Ghost Tasks（狀態同步問題）

**16 個會話有 .resolved 檔案但 task.md 有未完成項**:

高優先級:
- `1121a3ee...` (4+ 個未完成，包含 Range crash)
- `a23b76fd...` (15 個未完成)

中優先級:
- `7906414f...` (13 個未完成，Shopify 模板)
- `f54f70aa...` (2 個未完成，MCP 實作比較)
- `3ab59064...` (4+ 個未完成)

低優先級:
- `be07420c...` (6 個未完成，AST-grep)
- `848a62d7...` (4 個未完成)
- `b5bc4f6f...` (2 個未完成)
- `7248c104...` (3 個未完成)
- `223c9831...` (5 個未完成)

---

## 建議執行順序

### 階段 A：臨界修復與核心優化（優先 - 本週）
**時間**: 8-10 小時

1. 🔧 **修復 'Range is not defined' Crash** (1-2 小時)
   - **Files**: `useMouseSelection.ts`, `ClipboardService.ts`
   - **Actions**:
     ```typescript
     // useMouseSelection.ts line 243
     const range = selectionRangeRef.current ?? (typeof Range !== 'undefined' ? new Range() : null);

     // 或使用 Ink 提供的 selection 機制
     const range = selectionRangeRef.current ?? selection.createRange?.();
     ```
   - **ClipboardService.ts**: 統一改用 `commandUtils.ts` 的平台特定解決方案

2. 🔧 **修復虛擬化架構缺陷** (3-4 小時)
   - **File**: `DefaultAppLayout.tsx`
   - **Actions**:
     - 扁平化 Pending Items 到 `listItems` 陣列
     - 創建 `PendingItemsList` 組件統一渲染邏輯
     - 實施動態高度估算

3. 📋 **系統化 Memoization** (4-6 小時)
   - **Files**: `StatsDisplay.tsx`, `ModelStatsDisplay.tsx`, `CacheStatsDisplay.tsx`, `ToolStatsDisplay.tsx`, `InputPrompt.tsx`
   - **Actions**:
     - 包裝 5 個組件為 `React.memo`
     - 實施 `useMemo` 處理昂貴計算
     - 運行性能測試驗證

---

### 階段 B：代碼清理與架構債務（1-2 週內）
**時間**: 4-6 小時

4. **pendingHistory 清理** ✅ **已完成的檢查** - 無需操作
5. **TODO Tab 修復** (30 分鐘)
6. **基礎設施負債清理** (2-3 小時)
   - Update `esbuild.config.js` externals
   - Stabilize `zedIntegration.ts` tool result handling
   - Refactor `ast-edit.ts` for cross-platform support（如存在）
   - 替換 `scripts/analyze-stale-sessions.sh` 中的 `find` 命令
7. **配置介面修補** (1 小時)
   - 實作 `getCustomExcludes` 方法
8. **MCP 實作比較完成** (1 小時)
   - Compare `loadExtensions` 和 `ExtensionStorage`
9. **ToolCall UI 驗證** (30 分鐘)

---

### 階段 C：增強功能與測試（可選/未來）
**時間**: 6-8 小時

10. **移植缺失的 UI 組件**（DialogManager）
11. **Provider Server Tools 統一**（Gemini → Shared Utility → OpenAI/Anthropic）
12. **OpenAI Stateless Refactor**（應用 Stateless Hardening 模式）
13. **統一 Tool ID 管理**（移至 core 的專用服務）
14. **性能測試完善**（3-4 小時）
15. **無障礙性測試**（2-3 小時）
16. **E2E 測試強化** (223c9831)
    - recordFiber/readFiberLog
    - waitForUIState

---

### 階段 D：核心重構（長期）

17. **AST-Grep 遷移完成** (be07420c)
    - 實施缺失功能（創建新的 CodeAnalyzer）
    - 遷移 CodeWiki 的 tree-sitter 代碼
    - 新增完整測試覆蓋

18. **統一 OpenAI Provider 實施**
    - 合併或棄用重複的 OpenAI provider
    - 中心化 Tool ID 邏輯
    - 抽象 Server Tools

19. **Code Comment Reinforcement 規則** (7248c104)
20. **Shopify App Template 架構** (7906414f)

---

## 預期成果

### 完成階段 A 後（8-10 小時）:
- ✅ **穩定性**: 修復 'Range' 崩潰和虛擬化缺陷
- ✅ **性能**: 達到 gemini-cli 目標（+30% 提升）
- ✅ **對齊度**: 90-95%
- ✅ **崩潰修復**: 瀏覽器 API 相關崩潰全部解決

### 完成階段 B 後（12-16 小時累計）:
- ✅ **代碼品質**: 移除重複，減少技術債務
- ✅ **架構穩健性**: 修補配置介面缺口
- ✅ **跨平台**: 修復 `find` 命令等跨平台兼容性問題

### 完成所有階段後（18-26 小時累計）:
- ✅ **性能**: 超越基準
- ✅ **對齊度**: 95%+
- ✅ **代碼品質**: 生產就緒，完整測試
- ✅ **Provider 統一**: OpenAI/Anthropic/Gemini server tools 一致實現

---

## 核心結論

### 最緊急（本週處理）
1. **'Range is not defined' Runtime Crash** - `useMouseSelection.ts:243`, `ClipboardService.ts` 多處
2. **虛擬化架構缺陷** - `DefaultAppLayout.tsx` - DO NOT MERGE

### 高優先級（2 週內）
3. **Systematic Memoization** - 達到 +30% 性能目標
4. **Configuration Interface Gap** - getCustomExcludes 實作
5. **Infrastructure Debt** - fast-glob, resolveImportPath, esbuild externals, `find` 命令

### 中優先級（1 個月內）
6. **OpenAI Provider Server Tools** - 實作缺失的功能（Critical severity）
7. **YOLO Mode Bug Fix** - 修正並行工具執行（High severity）
8. **Security Warning** - yolo.toml 禁用安全檢查的風險
9. **UI Dialog Migration** - 移植 4 個未移植的對話框

---

## 報告生成信息

**生成時間**: 2026-02-04 15:59:00 UTC
**審查範圍**:
- ~/MyLLMNote/llxprt-code/results.md（已有報告）
- ~/MyLLMNote/llxprt-code/comprehensive-results.md（已有報告）
- ~/MyLLMNote/llxprt-code/Antigravity/（29 個會話目錄）
- ~/MyLLMNote/llxprt-code/Opencode/（341 個 JSON 會話檔案）

**並行探索統計**:
- ✅ 探索代理 1/9: 虛擬化缺陷（完成，33秒）
- ✅ 探索代理 2/9: Range crash 問題（完成，2分21秒）
- ✅ 探索代理 3/9: Memoization 機會（完成，1分39秒）
- ✅ 探索代理 4/9: AST-Grep 遷移任務（完成，1分0秒）
- ✅ 探索代理 5/9: 基礎設施負債（完成，1分20秒）
- ✅ 探索代理 6/9: TODOs FIXMEs HACKs（完成，2分5秒）
- ⏳ 探索代理 7/9: Fiber-Recorder 使用（運行中 >4分）
- ✅ 探索代理 8/9: pendingHistory 使用（完成，1分28秒）
- ⏳ 探索代理 9/9: TODO Tab 問題（運行中 >3分）

**關鍵數據**:
- 230+ 個 TODO/FIXME/HACK 標記
- 3 個 CRITICAL 服務器工具缺失（OpenAIProvider）
- 1 個 HIGH 嚴重性並行執行 Bug（YOLO mode）
- 1 個 HIGH 安全警告（yolo.toml）
- 4 個未移植 UI 對話框
- 16 個會話有狀態同步問題（.resolved 存在但 task.md 未完成）

---

**下次審查建議**: 完成階段 A 後重新評估
**聯繫**: OpenClaw Gateway Agent 🦞
