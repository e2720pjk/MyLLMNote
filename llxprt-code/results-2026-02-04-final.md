# 專案現況：llxprt-code 全面審查
**生成時間**：2026-02-04
**審查範圍**：Antigravity 會話記錄、Opencode 會話檔案、源碼標記、架構不一致性

---

## 專案現況

llxprt-code 是一個 **AI 驅動的 CLI 程式碼輔助工具**，採用 **TypeScript/Node.js monorepo** 架構，支援多種 LLM 提供商（Gemini、Anthropic、OpenAI 等）和本地模型。

### 當前狀態
- **Git 分支**：`opencode-dev`
- **最新提交**：`07b8f13b6` (ci: update OpenCode model to glm-4.7-free)
- **工作目錄**：Clean（但有多個 Untracked files）
- **對齊度狀態**：85-90%
- **會話檔案**：86 個 `.resolved` 檔案表示已完成的會話

### 主要進展
- ✅ **Static/Virtual 雙模式架構**：已實施 useRenderMode hook 與雙模式渲染
- ✅ **Screen Reader 支援**：ScreenReaderAppLayout 已實作
- ✅ **Tabs 基礎設施整合**：TabBar、TODO Tab、System Tab 已移植
- ✅ **Terminal Corruption 修復**：解決 Issue #26 (CTRL+C 退出問題)
- ✅ **UI Parity 完成**：部分 ToolCall UI 組件已移植
- ✅ **Fiber-Recorder 集成**：已安裝並集成到測試環境

### 性能狀態
- **當前提升**：+10.15%
- **目標提升**：+30%
- **差距**：需額外 +20%

---

## 未完成任務

### 🔴 高優先級（阻塞性問題）

#### 1. 虛擬化架構關鍵缺陷 ⚠️ DO NOT MERGE
**來源**：`d94ee6dd-4f45-490b-92df-dc7c98f0e078/`
**嚴重性**：**CRITICAL** - 破壞性架構缺陷

**問題詳述**：
- **Defect 1**：虛擬化繞過 - Pending Items 被組合成單一大區塊導致無法虛擬化
- **Defect 2**：脆弱顯示邏輯 - 只在 `streamingState === 'responding'` 時渲染
- **Defect 3**：低劣高度估算 - 硬編碼 `const getEstimatedItemHeight = () => 100`

**影響**：
- 性能：50 個工具調用或長回應會渲染為單一大 React 組件
- 穩定性：任何流更新強制重新渲染整體

**修復計畫**：
1. 扁平化 Pending Items - 類似 history 映射的方式
2. 修正渲染條件 - 應為 `pendingHistoryItems.length > 0`
3. 動態估算 - 實施更智慧的 `estimatedItemHeight`

---

#### 2. Debug 'Range is not defined' Crash
**來源**：`a23b76fd-8e45-4fba-a290-640871f0ea9a/`
**會話狀態**：有 15 個未完成任務

**具體任務**：
- [x] Search for `Range` usage in codebase
- [ ] Inspect `DebugProfiler.tsx` for browser-specific APIs
- [ ] Inspect dependencies for `Range` usage
- [ ] Reproduce crash locally if possible
- [ ] Fix the `Range` error（polyfill or remove offending code）
- [ ] Fix UI Layout Overlap
- [ ] Refine E2E Tests
- [ ] Final Verification

---

#### 3. 系統化 Memoization（性能優化核心）
**來源**：`1121a3ee-459c-40b2-b86f-7b86564a1cb3/`
**時間估計**：4-6 小時
**影響**：+20-30% 性能提升（達到目標 +30%）

**具體任務**：
- [ ] 審查 gemini-cli 的 memoization 策略
- [ ] 識別未 memoize 的昂貴組件：
  - [ ] `StatsDisplay`
  - [ ] `StatsDisplay/ModelStatsDisplay`
  - [ ] `StatsDisplay/CacheStatsDisplay`
  - [ ] `StatsDisplay/ToolStatsDisplay`
  - [ ] `InputPrompt`（部分）
- [ ] 實施 `React.memo` 包裝
- [ ] 實施 `useMemo` / `useCallback` 優化
- [ ] 性能測試驗證
- [ ] Investigate and Refine TODO Tab Integration
- [ ] Fix the "pushing up" layout issue in the TODO tab
- [ ] Verify TODO tab styling and layout stability

**發現**：staticAreaMaxItemHeight 已實施於 `DefaultAppLayout.tsx:143`

---

#### 4. AST-Grep 遷移（核心重構）
**來源**：`be07420c-f019-439b-bfaf-171328c12583/`
**目標**：替換現有邏輯為 `@ast-grep/napi` 以加速程式碼分析

**具體任務**：
- [ ] Create Golden Master safety test (`packages/core/src/tools/tabby-edit.safety.test.ts`)
- [ ] Install `@ast-grep/napi` dependency
- [ ] Implement `validateASTSyntax` using `ast-grep`
- [ ] Refactor `extractDeclarations` to use `ast-grep`
- [ ] Refactor `findRelatedSymbols` to use `ast-grep`
- [ ] Verify with Golden Master and existing tests

**審查發現**：
- 🔴 **Working Set Context 未顯示**：editPreviewLlmContent 只顯示連接文件數量，隱藏了上下文
- 🟠 **缺少單元測試**：驗證 Freshness Check 邏輯和 RepositoryContextProvider 測試
- 🟡 **簽名資訊不足**：Skeleton View 只提供名稱和類型，缺少參數和回傳類型
- 🟡 **Git 命令穩健性**：處理檔名編碼問題（空格或非 ASCII 字元）

---

#### 5. E2E 測試強化 - Fiber-Recorder 遷移
**來源**：`223c9831-d817-4a30-a16c-52bfa9085b18/`
**狀態**：🟡 **Integration Pending** - Library Verified, Phase 5 in progress

**具體任務**：
- [x] Analysis Phase: All completed
- [x] Planning Phase: Review with user (id: 7 - Pending)
- [x] Implementation Phase 1-4: All completed
- [/] Implementation Phase 5: Update component snapshot tests
- [ ] Run pilot tests with fiber-recorder
- [ ] Measure test execution time impact
- [ ] Check for false positives in CI
- [ ] Integrate to CI/CD pipeline
- [ ] Document patterns and best practices

**關鍵發現**：
- Fiber-recorder 已驗證為可用於 UI 測試
- 應採用 Hybrid Approach（增強現有測試，非完全替換）
- 需創建 fiber assertion helpers（fiber-test-utils.ts）
- 應遷移 placeholder tests 為真實 UI 測試

---

### 🟡 中優先級（代碼品質與架構）

#### 6. 基礎設施負債清理
**來源**：`3ab59064-4305-4ec2-a0d3-4ec372aee44c/`
**時間**：2-3 小時

**具體任務**：
- [ ] Update `esbuild.config.js` externals
- [ ] Stabilize `zedIntegration.ts` tool result handling
- [ ] Refactor `ast-edit.ts` for cross-platform support
    - [ ] Replace `find` with `fast-glob` in `getWorkspaceFiles`
    - [ ] Support multiple extensions in `resolveImportPath`
- [ ] Verification and PR update

---

#### 7. MCP 實作比較完成
**來源**：`f54f70aa-8304-4e71-88c1-c2970ef637d1/`
**會話狀態**：2 個未完成任務

**具體任務**：
- [ ] Compare `loadExtensions` in `packages/cli/src/config/extension.ts` (Old vs New)
- [ ] Compare `ExtensionStorage` in `packages/cli/src/config/storage.ts`
- [ ] Identify the cause of the issue in `llxprt-code`
- [ ] Report findings to the user

---

#### 8. 待實作的功能（源碼 TODO/FIXME/HACK）

**Core Package (`packages/core/src/`)**：

1. **OpenAIProvider.ts** (`packages/core/src/providers/openai/`)
   - Line 974: `TODO: Implement server tools for OpenAI provider`
   - Line 984: `TODO: Implement server tool invocation for OpenAI provider`
   - Line 4663: `TODO: Implement response parsing based on detected format`

2. **coreToolScheduler.test.ts**
   - Line 1302: `TODO: Fix these tests - the current implementation executes tools in parallel in YOLO mode`

3. **ignorePatterns.ts** (`packages/core/src/utils/`)
   - Line 167: `TODO: getCustomExcludes method needs to be implemented in Config interface`
   - Line 202: `TODO: getCustomExcludes method needs to be implemented in Config interface`

4. **shell.ts** (`packages/core/src/tools/`)
   - Line 479: `TODO: Need to adapt summarizeToolOutput to use ServerToolsProvider`

5. **subagent.ts** (`packages/core/src/core/`)
   - Line 170: `TODO: In the future, this needs to support 'auto' or some other string to support routing use cases.`
   - Line 188: `TODO: Consider adding max_tokens as a form of budgeting.`

6. **client.ts** (`packages/core/src/core/`)
   - Line 690: `WARNING: setTools called but toolDeclarations is empty!`

7. **code_assist/server.ts**
   - Line 42: `TODO: Use production endpoint once it supports our methods.`

8. **ide/ide-client.ts**
   - Line 479: `TODO(#3487): use the CLI version here.`

**CLI Package (`packages/cli/src/`)**：

9. **config/config.ts**
   - Line 635: `TODO: Consider if App.tsx should get memory via a server call or if Config should refresh itself.`
   - Line 962: `TODO: This is a bit of a hack. The contextFileName should ideally be passed`

10. **DialogManager.tsx**
   - Not yet ported from upstream:
     - `LoopDetectionConfirmation`
     - `ProQuotaDialog`
     - `ModelDialog`
     - `IdeTrustChangeDialog`

11. **ui/hooks/useCommandCompletion.tsx**
   - Line 215: `TODO: Fix this - need proper completion range`

12. **ui/commands/setupGithubCommand.ts**
   - `TODO: Adapt this command for llxprt-code`

13. **ui/contexts/KeypressContext.tsx**
   - Line 324: `TODO: Replace with a more robust IME-aware input handling system`

14. **services/todo-continuation/todoContinuationService.ts**
   - Line 104: `TODO: Add timeout functionality in the future`

15. **utils/privacy/ConversationDataRedactor.ts**
   - Line 237 & 470: `TODO: Re-add redactContentPart/isPatternEnabled method when needed`

16. **config/settings.test.ts**
   - Line 2348: `TODO: needsMigration and migrateDeprecatedSettings functions not yet implemented`

**A2A Server Package (`packages/a2a-server/src/`)**：

17. **config/config.ts**
   - Line 82: `/// TODO: Wire up folder trust logic here.`

18. **agent/task.ts**
   - Line 848 & 888: `TODO: Determine what it mean to have, then add a prompt ID.`

---

#### 9. 配置介面修補
**來源**：源碼 grep (`packages/core/src/utils/ignorePatterns.ts`)
**時間**：1 小時

**具體任務**：
- [ ] 在 Config interface 中實作 `getCustomExcludes` 方法
- [ ] 移除 ignorePatterns.ts 中的 TODO 註解 (Line 167, 202)

---

#### 10. SettingsDialog 優化（Scheme 3）
**來源**：`3a428465-4482-42ed-8f08-452a32fa2b7c/`
**狀態**：實作計畫已制定，待執行
**目標**：防止不必要的 `generateDynamicToolSettings` 執行

---

#### 11. Code Review Report Generation
**來源**：`a0c75142-4be2-4289-bffc-07f99f0b5650/`
**會話狀態**：Report Generation in progress (id: 11 - Pending)

**具體任務**：
- [ ] Compile findings into a structured review report

---

### 🟢 低優先級（增強功能 / 技術債）

#### 12. Code Comment Reinforcement (CCR) 規則創建
**來源**：`7248c104-3e66-4f17-946a-472790e39773/`

**具體任務**：
- [ ] Finalize `.agent-rules.md` (AI-facing)
- [ ] Create `PROJECT_RECIPE.md` (Infrastructure/CI recommendations)
- [ ] Verify with comprehensive example

---

#### 13. Shopify App Template 架構設計
**來源**：`7906414f-3dc1-4452-9b96-13cf2108257e/`
**狀態**：13 個未完成任務（仍在規劃階段）

**具體任務**：
- [ ] Analyze Project Structure
- [ ] Design Architecture
- [ ] Identify Reusable UI Components
- [ ] Define Interfaces

---

#### 14. pendingHistory 欄位清理
**時間**：30-60 分鐘
**風險**：極低

**調查結果**：
- `pendingHistory` 未被使用
- 但 `pendingHistoryItems` 仍被使用於 `DefaultAppLayout.tsx` 和 `AppContainer.tsx`

---

#### 15. useFlickerDetector 重複調用檢查
**時間**：1-2 小時

**調查結果**：
- `AppContainer.tsx` 僅調用一次（Line 1397）
- `DefaultAppLayout.tsx` 未調用
- **結論**：無重複調用問題

---

#### 16. staticAreaMaxItemHeight 約束
**狀態**：**已完成** - 已實施於 `DefaultAppLayout.tsx:143`
```typescript
const staticAreaMaxItemHeight = Math.max(terminalHeight * 4, 100);
```

---

#### 17. 移除重複 preferredEditor 設置
**來源**：`7b2770fe-5b28-4a7a-a72d-4cdb7a593ebc/`
**狀態**：已延後（因建置相容性需求，已添加 TODO）

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

**問題**：臨時 hack 用於傳遞 `contextFileName`

**待辦**：
- [ ] 重構 contextFileName 傳遞邏輯
- [ ] 移除 "This is a bit of a hack" 註解

---

#### 3. 待實作的 Notifications 組件

**問題**：計畫中提到的 `Notifications` 組件尚未實作

**發現**：
- `DialogManager.tsx` 計畫中有 Notifications
- 實際實施中沒有
- 可能已在 `DefaultAppLayout` 中處理

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

### 臨時 Hacks & Mocks
- **硬編碼模型**：Gemini 和 Anthropic provider 在 OAuth 激活時退回到硬編碼模型列表
- **Ink Stubbing**：測試工具依賴於 `ink-stub`
- **Tool ID Mapping**：`call_`、`toolu_` 和 `hist_tool_` 之間的正規化通過每個 provider 中的臨時私有方法處理

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

**問題**：
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

## 待驗證的功能

### ToolCall UI 實作驗證
**來源**：`1121a3ee-459c-40b2-b86f-7b86564a1cb3/` + `db9177a6-5a0e-4aed-ab83-8ec071b1078c/`

**具體任務**：
- [ ] 驗證新增移植的 `ToolResultDisplay`、`StickyHeader`、`ShellToolMessage` 的建置通過
- [ ] 驗證 lint 通過

---

### ScreenReader 完整測試
**已實作**：
- ✅ `ScreenReaderAppLayout.tsx`
- ✅ SR 條件渲染

**待測試**：
- [ ] 實際使用 NVDA/VoiceOver 測試
- [ ] 驗證導航流程
- [ ] 確認 Footer 資訊優先播報

---

### 修復驗證（多個會話）
**來源**：多個會話的 `.resolved` 檔案存在但 task.md 未更新

**具體任務**：
- [ ] 驗證 E2E 測試修復通過
- [ ] 驗證 UI 穩定性修復生效
- [ ] 確認無迴歸
- [ ] 更新 task.md 以反映實際狀態

---

## 關鍵會話參考

### 重要會話目錄（按優先級排序）

**🔴 高優先級（Critical Issues）**：
- `d94ee6dd-4f45-490b-92df-dc7c98f0e078` - LLXPRT-4 虛擬化代碼審查（關鍵架構缺陷，DO NOT MERGE）
- `a23b76fd-8e45-4fba-a290-640871f0ea9a` - Debugging Runtime Crash and UI Layout（15 個未完成任務）
- `1121a3ee-459c-40b2-b86f-7b86564a1cb3` - Static Architecture 實作與相關任務（性能優化核心）
- `223c9831-d817-4a30-a16c-52bfa9085b18` - E2E 測試 Fiber-Recorder 遷移（Integration Pending）

**🟡 中優先級（Architecture & Refactoring）**：
- `be07420c-f019-439b-bfaf-171328c12583` - AST-Grep 遷移任務
- `3ab59064-4305-4ec2-a0d3-4ec372aee44c` - Refining AST tools and build config（基礎設施負債）
- `db9177a6-5a0e-4aed-ab83-8ec071b1078c` - UI Architecture Parity Analysis
- `3a428465-4482-42ed-8f08-452a32fa2b7c` - SettingsDialog 優化

**🟢 低優先級（Enhancements & Documentation）**：
- `7b2770fe-5b28-4a7a-a72d-4cdb7a593ebc` - UI 對齊與修復任務
- `7248c104-3e66-4f17-946a-472790e39773` - Code Comment Reinforcement 規則創建
- `7906414f-3dc1-4452-9b96-13cf2108257e` - Shopify App Template 架構設計
- `f54f70aa-8304-4e71-88c1-c2970ef637d1` - MCP 實作比較（2 個未完成任務）
- `a0c75142-4be2-4289-bffc-07f99f0b5650` - ASTEdit Tool Refactoring 審查

**已完成或進行中**：
- `848a62d7-51b3-4016-badd-81e6dba9ca30` - Terminal Corruption Issue (Issue #26) - All tasks completed
- `e5d945a7-e9f5-4d19-8785-f48e9c29963b` - Profile Loading & UI Bug Fix - All tasks completed
- `f4182ee1-ea5d-469a-9972-a5d1749e7105` - Dependency Migration - All tasks completed
- `d8053952-039a-4e8c-b3d7-17c6a2795a7b` - Code Review: UI Architecture Parity Analysis - All tasks completed

### Opencode Session Files
- `/home/soulx7010201/MyLLMNote/llxprt-code/Opencode/add233c5043264d47ecc6d3339a383f41a241ae8/`
  - 包含 341 個 JSON 會話檔案
  - 主要用於 OpenCode 框架的會話管理元數據

---

## 建議執行順序

### 階段 A：臨界修復與核心優化（優先）
**時間**：8-10 小時

1. **Debug 'Range is not defined' Crash**
   - 修復運行時崩潰以確保系統穩定性

2. **修復虛擬化架構缺陷** (d94ee6dd)
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
5. **useFlickerDetector 重複檢查**（已確認無重複）
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
15. **性能測試完善**（3-4 小時）
16. **無障礙性測試**（2-3 小時）
17. **E2E 測試強化** (223c9831)
    - recordFiber/readFiberLog
    - waitForUIState

---

### 階段 D：核心重構（長期）

18. **AST-Grep 遷移完成** (be07420c)
    - 實施缺失功能
    - 修復 Working Set Context 顯示
    - 新增完整測試覆蓋

19. **統一 OpenAI Provider 實施**
    - 合併或棄用重複的 OpenAI provider
    - 中心化 Tool ID 邏輯
    - 抽象 Server Tools

20. **Code Comment Reinforcement 規則** (7248c104)
21. **Shopify App Template 架構** (7906414f)

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

## 🚫 明確排除/已完成項目

### 已完成
- ✅ **Phase 4: 剩餘 Tabs 實作** - 已完成
- ✅ **Terminal Corruption Issue (Issue #26)** - 已完成
- ✅ **Screen Reader AppLayout** - 已實施
- ✅ **Fiber-Recorder 集成** - 已完成
- ✅ **Profile Loading & UI Bug Fix** - 已完成
- ✅ **Dependency Migration** - 已完成

### 明確排除
- ❌ **gemini-cli 完全同步**
  - 原因：llxprt-code 有自己的架構優勢
  - 不需要 100% 複製 gemini-cli
  - 目標是**對齊核心優化**，非完全一致

---

## 報告生成信息
**生成時間**：2026-02-04
**審查範圍**：
- ~/MyLLMNote/llxprt-code/results.md (已有報告)
- ~/MyLLMNote/llxprt-code/comprehensive-results.md (已有報告)
- ~/MyLLMNote/llxprt-code/Antigravity/（29 個會話目錄）
- ~/MyLLMNote/llxprt-code/Opencode/（341 個 JSON 會話檔案）
- 源碼中 TODO/FIXME/HACK 標記的全面掃描

**關鍵數據**：
- 86 個 `.resolved` 檔案表示已完成工作
- 多個會話有 `.resolved` 檔案但 `task.md` 未更新，表示需要狀態同步
- 18 個不同位置的 TODO/FIXME/HACK 標記
- 4 個未移植的 UI 組件
- 多個 Provider 實施間隙
