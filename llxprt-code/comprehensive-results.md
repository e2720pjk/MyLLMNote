## 專案現況全面審查報告

**生成時間**：2026-02-04
**審查範圍**：Antigravity 會話記錄、源碼標記、架構不一致性、測試覆蓋率
**專案位置**：~/MyLLMNote/llxprt-code/

---

## 專案摘要

llvmprt-code 是一個 **AI 驅動的 CLI 程式碼輔助工具**，採用 **TypeScript/Node.js monorepo** 架構，支援多種 LLM 提供商（Gemini、Anthropic、OpenAI 等）和本地模型。

### 當前狀態
- **Git 分支**：`opencode-dev`
- **最新提交**：`07b8f13b6` (ci: update OpenCode model to glm-4.7-free)
- **工作目錄**：Clean
- **對齊度狀態**：85-90%（排除完全同步需求）

### 主要進展
- ✅ **Static/Virtual 雙模式架構**：已實施 useRenderMode hook 與雙模式渲染
- ✅ **Screen Reader 支援**：ScreenReaderAppLayout 已實作
- ✅ **Tabs 基礎設施整合**：TabBar、TODO Tab、System Tab 已移植
- ✅ **Terminal Corruption 修復**：解決 Issue #26 (CTRL+C 退出問題)
- ✅ **UI Parity 完成**：部分 ToolCall UI 組件已移植

### 性能狀態
- **當前提升**：+10.15%
- **目標提升**：+30%
- **差距**：需額外 +20%

---

## 🔴 高優先級未完成任務（阻塞性問題）

### 1. 虛擬化架構關鍵缺陷 ⚠️ DO NOT MERGE
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
1. **扁平化 Pending Items** - 類似 history 映射的方式
2. **修正渲染條件** - 應為 `pendingHistoryItems.length > 0`
3. **動態估算** - 實施更智慧的 `estimatedItemHeight`

---

### 2. Debug 'Range is not defined' Crash
**來源**：`a23b76fd-8e45-4fba-a290-640871f0ea9a/`
**問題**：Runtime crash due to browser API leak in Node.js/Ink environment

**具體任務**：
- [x] Search for `Range` usage in codebase
- [ ] Inspect `DebugProfiler.tsx` for browser-specific APIs
- [ ] Inspect dependencies for `Range` usage
- [ ] Reproduce crash locally if possible
- [ ] Fix the `Range` error（polyfill or remove offending code）

**會話狀態**：`task.md` 仍有 15 個未完成任務，雖然 `.resolved` 文件表明工作已進行

---

### 3. 系統化 Memoization（性能優化核心）
**來源**：`1121a3ee-459c-40b2-b86f-7b86564a1cb3/phase_2_memoization_plan.md`
**時間估計**：4-6 小時
**影響**：+20-30% 性能提升（達到目標 +30%）

**具體任務**：
- [ ] 審查 gemini-cli 的 memoization 策略
- [ ] 識別未 memoize 的昂貴組件：
  - [ ] `StatsDisplay`
  - [ ] `ModelStatsDisplay`
  - [ ] `CacheStatsDisplay`
  - [ ] `ToolStatsDisplay`
  - [ ] `InputPrompt`（部分）
- [ ] 實施 `React.memo` 包裝
- [ ] 實施 `useMemo` / `useCallback` 優化
- [ ] 性能測試驗證

**發現**：staticAreaMaxItemHeight 已實施於 `DefaultAppLayout.tsx:143`（硬編碼 `Math.max(terminalHeight * 4, 100)`）

---

### 4. AST-Grep 遷移（核心重構）
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

### 5. E2E 測試強化 - Fiber-Recorder 遷移
**來源**：`223c9831-d817-4a30-a16c-52bfa9085b18/e2e_migration_analysis.md`
**狀態**：🟡 **Integration Pending** - Library Verified

**具體任務**：
- [ ] 添加 `recordFiber` 到測試執行器
- [ ] 實作 `readFiberLog()` 輔助函數
- [ ] 實作 `waitForUIState(predicate)` 輔助函數以加強非同步 UI 測試
- [ ] 運行引導式測試驗證
- [ ] 測量測試執行時間影響
- [ ] 檢測 CI 誤報
- [ ] 整合到 CI/CD 流程
- [ ] 文件化模式和最佳實踐

---

## 🟡 中優先級任務（代碼品質與架構）

### 6. pendingHistory 欄位清理
**時間**：30-60 分鐘
**風險**：極低（已確認未被使用）

**調查結果**：gemini-cli 根本沒有 `pendingHistory` 欄位

**具體任務**：
- [ ] 從 `UIStateContext` interface 移除 `pendingHistory: HistoryItem[]`
- [ ] 從 `AppContainer.tsx` 移除初始化（Line 1530）
- [ ] 確認無其他引用
- [ ] 運行測試確保無破壞

**發現**：`pendingHistoryItems` 仍被使用於 `DefaultAppLayout.tsx`（lines 97, 206, 466）和 `AppContainer.tsx`（lines 136, 1087）

---

### 7. 基礎設施負債清理
**來源**：`3ab59064-4305-4ec2-a0d3-4ec372aee44c/`
**時間**：2-3 小時

**具體任務**：
- [ ] 替換 `getWorkspaceFiles` 中的 `find` 命令為 `fast-glob` (提升性能與可靠性)
- [ ] 更新 `resolveImportPath` 以支援多種副檔名
- [ ] 更新 `esbuild.config.js` externals，確保建置管道正確

---

### 8. 配置介面修補
**來源**：源碼 grep (`packages/core/src/utils/ignorePatterns.ts`)
**時間**：1 小時

**具體任務**：
- [ ] 在 Config interface 中實作 `getCustomExcludes` 方法
- [ ] 移除 ignorePatterns.ts 中的 TODO 註解 (Line 167, 202)

**TODO 位置**：
- Line 167: `TODO: getCustomExcludes method needs to be implemented in Config interface`
- Line 202: `TODO: getCustomExcludes method needs to be implemented in Config interface`

---

### 9. MCP 實作比較完成
**來源**：`f54f70aa-8304-4e71-88c1-c2970ef637d1/`

**具體任務**：
- [ ] 比較 `loadExtensions` (extension.ts) 的實作
- [ ] 比較 `ExtensionStorage` (storage.ts) 的實作
- [ ] 確認新 extension 載入邏輯的一致性

**狀態**：仍有 2 個未完成任務

---

### 10. SettingsDialog 優化（Scheme 3）
**來源**：`3a428465-4482-42ed-8f08-452a32fa2b7c/`
**狀態**：實作計畫已制定，待執行
**目標**：防止不必要的 `generateDynamicToolSettings` 執行

---

### 11. TODO Tab 布局修復
**來源**：`1121a3ee-459c-40b2-b86f-7b86564a1cb3/`

**具體任務**：
- [ ] Investigate and Refine TODO Tab Integration
- [ ] Fix the "pushing up" layout issue in the TODO tab
- [ ] Verify TODO tab styling and layout stability

---

### 12. useFlickerDetector 重複調用檢查
**時間**：1-2 小時

**調查結果**：
- `AppContainer.tsx` 僅調用一次（Line 1397）
- `DefaultAppLayout.tsx` 未調用
- **結論**：無重複調用問題

---

## 🟢 低優先級任務（增強功能 / 技術債）

### 13. Code Comment Reinforcement (CCR) 規則創建
**來源**：`7248c104-3e66-4f17-946a-472790e39773/`

**具體任務**：
- [ ] Finalize `.agent-rules.md` (AI-facing)
- [ ] Create `PROJECT_RECIPE.md` (Infrastructure/CI recommendations)
- [ ] Verify with comprehensive example

---

### 14. Shopify App Template 架構設計
**來源**：`7906414f-3dc1-4452-9b96-13cf2108257e/`
**狀態**：13 個未完成任務（仍在規劃階段）

**具體任務**：
- [ ] Analyze Project Structure
- [ ] Design Architecture
- [ ] Identify Reusable UI Components
- [ ] Define Interfaces

---

### 15. staticAreaMaxItemHeight 約束
**時間**：2-3 小時

**狀態**：已實施於 `DefaultAppLayout.tsx:143`
```typescript
const staticAreaMaxItemHeight = Math.max(terminalHeight * 4, 100);
```

**結論**：**已完成** - 與 gemini-cli 功能一致

---

### 16. 移除重複 preferredEditor 設置
**來源**：`7b2770fe-5b28-4a7a-a72d-4cdb7a593ebc/`
**狀態**：已延後（因建置相容性需求，已添加 TODO）

---

## 📊 源碼中的 TODO/FIXME/HACK 發現

### Core Package (packages/core/src/)

#### 開發者關鍵發現

**1. OpenAIProvider.ts** (`packages/core/src/providers/openai/`)
```typescript
// Line 974: TODO: Implement server tools for OpenAI provider
// Line 984: TODO: Implement server tool invocation for OpenAI provider
// Line 4663: TODO: Implement response parsing based on detected format
```
- **類別**：Feature/Architecture
- **影響**：OpenAI provider 缺少核心功能

**2. coreToolScheduler.test.ts**
```typescript
// Line 1302: TODO: Fix these tests - the current implementation executes tools in parallel in YOLO mode
```
- **類別**：Bug/Architecture
- **影響**：YOLO 模式的並行執行測試失敗

**3. ignorePatterns.ts** (`packages/core/src/utils/`)
```typescript
// Line 167: TODO: getCustomExcludes method needs to be implemented in Config interface
// Line 202: TODO: getCustomExcludes method needs to be implemented in Config interface
```
- **類別**：Architecture
- **影響**：配置介面不完整

**4. shell.ts** (`packages/core/src/tools/`)
```typescript
// Line 479: TODO: Need to adapt summarizeToolOutput to use ServerToolsProvider
```
- **類別**：Architecture
- **影響**：工具輸出摘要不統一

**5. subagent.ts** (`packages/core/src/core/`)
```typescript
// Line 170: TODO: In the future, this needs to support 'auto' or some other string to support routing use cases.
// Line 188: TODO: Consider adding max_tokens as a form of budgeting.
```
- **類別**：Feature
- **影響**：Subagent 功能增強

**6. client.ts** (`packages/core/src/core/`)
```typescript
// Line 690: WARNING: setTools called but toolDeclarations is empty!
```
- **類別**：Bug (Logic Warning)
- **影響**：工具配置警告

**7. code_assist/server.ts**
```typescript
// Line 42: TODO: Use production endpoint once it supports our methods.
```
- **類別**：Infrastructure
- **影響**：Production endpoint 支持

**8. ide/ide-client.ts**
```typescript
// Line 479: TODO(#3487): use the CLI version here.
```
- **類別**：Infrastructure
- **影響**：CLI 版本使用

### CLI Package (packages/cli/src/)

**9. config/config.ts**
```typescript
// Line 635: TODO: Consider if App.tsx should get memory via a server call or if Config should refresh itself.
// Line 962: TODO: This is a bit of a hack. The contextFileName should ideally be passed
```
- **類別**：Architecture (Hack)
- **影響**：Context file name 傳遞架構問題

**10. DialogManager.tsx**
- Not yet ported from upstream:
  - `LoopDetectionConfirmation`
  - `ProQuotaDialog`
  - `ModelDialog`
  - `IdeTrustChangeDialog`
- **類別**：Feature (Missing)
- **影響**：UI 差異

**11. ui/hooks/useCommandCompletion.tsx**
```typescript
// Line 215: TODO: Fix this - need proper completion range
```
- **類別**：Bug/UX
- **影響**：命令補全功能

**12. ui/commands/setupGithubCommand.ts**
```typescript
// TODO: Adapt this command for llxprt-code
```
- **類別**：Feature Disabled
- **影響**：GitHub 設置功能禁用

**13. ui/contexts/KeypressContext.tsx**
```typescript
// Line 324: TODO: Replace with a more robust IME-aware input handling system
```
- **類別**：Architecture
- **影響**：IME 輸入處理

**14. services/todo-continuation/todoContinuationService.ts**
```typescript
// Line 104: TODO: Add timeout functionality in the future
```
- **類別**：Feature
- **影響**：Todo 續行超時功能

**15. utils/privacy/ConversationDataRedactor.ts**
```typescript
// Line 237 & 470: TODO: Re-add redactContentPart/isPatternEnabled method when needed
```
- **類別**：Feature
- **影響**：內容過濾功能

**16. config/settings.test.ts**
```typescript
// Line 2348: TODO: needsMigration and migrateDeprecatedSettings functions not yet implemented
```
- **類別**：Technical Debt
- **影響**：設置遷移未完成

### A2A Server Package (packages/a2a-server/src/)

**17. config/config.ts**
```typescript
// Line 82: /// TODO: Wire up folder trust logic here.
```
- **類別**：Feature/Security
- **影響**：文件夾信任邏輯未實施

**18. agent/task.ts**
```typescript
// Line 848 & 888: TODO: Determine what it mean to have, then add a prompt ID.
```
- **類別**：Feature
- **影響**：Prompt ID 管理

---

## 🏗️ Provider 架構不一致性發現

### 架構狀態概覽

| Feature | OpenAIProvider | AnthropicProvider | GeminiProvider | OpenAIResponsesProvider |
|:---|:---|:---|:---|:---|
| **OAuth Status** | Partial (Qwen only) | Complete (Custom) | Complete (CodeAssist) | Complete (Codex mode) |
| **Server Tools** | Missing (TODOs) | Missing | Implemented | Missing |
| **State Pattern** | Stateless (Hardened) | Stateless (Hardened) | Stateless (Hardened) | Stateless (Hardened) |
| **Tool ID Norm** | Internal call_ mapping | Internal toolu_ mapping | call.id fallback | External util mapping |
| **Core Dependency**| `openai` SDK | `@anthropic-ai/sdk` | `@google/genai` | `fetch` (direct REST) |

### 關鍵架構問題

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

**問題**：缺乏凝聚力，邏輯分散

#### 3. 思考/推論提取不一致
- **OpenAIProvider**：使用 regex-based stripping in `sanitizeProviderText`
- **OpenAIVercelProvider**：使用 SSE 攔截解析原始 chunks for `reasoning_content`
- **AnthropicProvider**：使用專門的 redaction 邏輯

#### 4. "Hot" vs "Hardened" 實施
- **Hardened**：`GeminiProvider` 和 `OpenAIResponsesProvider`（Codex 模式）
  - 深度集成外部服務（`CodeAssist`）
  - 魯棒的 history patching
- **Hot**：`OpenAIProvider`
  - 包含許多條件塊和特定模型的 hacks
  - 未抽象到 base layer

### 模型特定 Hacks

- **Kimi K2**：
  - OpenAIProvider: regex extraction
  - OpenAIVercelProvider: SSE interception
  - Tool name prefix stripping 重複

- **Mistral**：
  - 嚴格執行 9 字元字母數字 ID（`ToolIdStrategy.ts`）
  - 修復 OpenAIProvider.ts 移除 `content` property（當 `tool_calls` 存在時）

- **Gemini 3.x**：
  - 需要函數調用中的 `thoughtSignature`（"active loop"）
  - `ensureActiveLoopHasThoughtSignatures` in `GeminiProvider.ts`

- **OpenRouter**：
  - 特殊 400 錯誤檢測以觸發工具回應壓縮（`OpenAIProvider.ts`）

### OpenAI NotYetImplemented TODOs

在 `openai-oauth.spec.ts` 中發現多個 `NotYetImplemented` 測試：
- `handleTokenRefresh not yet implemented` (Line 391)
- `handleRefreshFailure not yet implemented` (Line 420)
- `handleInvalidTokenFormat not yet implemented` (Line 756)
- `handleNetworkError not yet implemented` (Line 815)
- `performEndToEndOAuthTest not yet implemented` (Line 847)
- `testMigrationScenario not yet implemented` (Line 877)

---

## 🧪 測試覆蓋率與缺口

### 測試統計摘要

| 指標 | 數量 |
|:---|:---|
| **總測試文件數** | 601 |
| - TypeScript (*.test.ts, *.spec.ts) | 590 |
| - JavaScript (*.test.js) | 11 |
| **跳過的測試數** | 106 (it.skip, describe.skip) |
| **測試中的 TODO** | 75 |

### 測試覆蓋區域

#### Packages/core
- **Providers**：
  - OpenAI、Gemini、Multi-provider orchestration
  - Stateless vs stateful testing
  - Bucket failover and token estimation
- **Tools**：
  - 幾乎每個工具都有對應的 .test.ts 文件
  - ls, grep, read-file, edit, shell
  - MCP integration tests
- **Policy & Runtime**：
  - Policy engine tests
  - Agent runtime state tests

#### Packages/cli
- UI 組件測試（Ink-based）
- Command handlers
- Configuration management

#### Integration-tests/
- 多沙箱環境測試
- E2E tests（oauth2.e2e.test.ts, todo-continuation.e2e.test.js）
- Regression guards

### 模特定別深度分析

#### Packages/core/src/tools/
**覆蓋率**：**High**
- 幾乎每個工具都有單元測試
- 高質量的測試覆蓋

#### Packages/core/src/providers/
**覆蓋率**：**High**
- 詳細的 provider 測試
- 狀態管理測試

#### AST Tools and Migration
**覆蓋率**：**Active**
- 專用遷移測試
- Legacy OAuth migration
- Settings migration
- ApprovalMode-to-Policy migration

### 測試 TODOs 與技術債（樣本）

| File | Line | TODO Description |
|:---|:---|:---|
| `coreToolScheduler.test.ts` | 1302 | Fix tests for parallel tool execution in YOLO mode |
| `client.test.ts` | 3618 | Re-enable when `updateModel` method is implemented |
| `settings.test.ts` | 2348 | `needsMigration` and `migrateDeprecatedSettings` not yet implemented |
| `setupGithubCommand.test.ts` | 57 | Re-enable tests when command is adapted for llxprt |
| `stdin-context.test.ts` | 32 | Fix failure in sandbox mode (Docker/Podman) |

### E2E 測試狀態摘要

**Capabilities**：
- 使用 Vitest 進行 integration tests
- 自定義 "Sandbox" 基礎設施
- 支援 `LLXPRT_SANDBOX=docker`, `podman`, 或 `false` (local)

**關鍵 E2E Suites**：
- `oauth2.e2e.test.ts`：驗證完整 OAuth 流程
- `todo-continuation.e2e.test.js`：驗證 agent 行為跨回合
- `replace.test.ts`：（目前跳過）測試文件內容替換可靠性

**Regression Guards**：
- `regression-guards.test.ts`：防止 runtime state 和 configuration 的破壞性變更

### 缺失測試覆蓋建議

1. **Unskip Core Logic**：
   - 優先解除 `CoreToolScheduler` 中的測試
   - `client.test.ts` 中並行執行和回合限制相關測試
   - 對 agent 可靠性至關重要

2. **Implementation-Driven Tests**：
   - 處理 75 個待測試項
   - 特別是 "method implementation" 相關 TODOs
   - 模型列表、設置遷移等功能

3. **Cross-Platform E2E**：
   - Windows 測試標記為跳過或失敗
   - Windows 開發者的平等性缺口

4. **AST-Specific Testing**：
   - 如 `edit.ts` 演進為更複雜的代碼重構
   - 引入 AST-level 單元測試（使用 `tree-sitter` 或類似）

---

## 🚫 明確排除/已完成項目

### 已完成
- ✅ **Phase 4: 剩餘 Tabs 實作** - 已完成
  - [x] 移植 `TodoTab`
  - [x] 移植 `SystemTab`

- ✅ **Terminal Corruption Issue (Issue #26)** - 已完成
  - 使用 `fs.writeSync` 進行同步寫入
  - 對齊 SIGINT 處理器
  - 新增 SIGTERM、uncaughtException、unhandledRejection 處理

- ✅ **Profile Loading & UI Bug Fix** - 已完成
  - 修復 "Initializing..." 畫面的 UI bug

- ✅ **Dependency Migration** - 已完成
  - 將依賴移動到正確的 package 位置

- ✅ **UI Architecture Parity Analysis** - 部分完成
  - 移植了 gemini-cli 的高性能虛擬化和 UI 組件
  - 待驗證 ToolCall UI 組件的建置和 lint 通過

- ✅ **Screen Reader AppLayout** - 已實施
  - `ScreenReaderAppLayout.tsx` 已創建
  - SR 條件渲染已實施

### 明確排除
- ❌ **gemini-cli 完全同步**
  - 原因：llxprt-code 有自己的架構優勢（FlickerDetector 增強版）
  - 不需要 100% 複製 gemini-cli
  - 目標是**對齊核心優化**，非完全一致

---

## Hacks 與臨時解決方案

### 1. Ink Layout Retrieval Mock
**位置**：`src/ui/utils/ink-utils.ts`

**問題**：`getBoundingBox` 在核心 Ink 庫中不存在，使用了最佳化的 mock 實作

**待辦**：
- [ ] 調查正確的 Ink 佈局坐標檢索方法
- [ ] 取代 mock 實作為穩健的佈局檢索方法

---

### 2. Config Context Hack
**位置**：`packages/cli/src/config/config.ts` (Line 962)

**問題**：臨時 hack 用於傳遞 `contextFileName`，應該通過更好的依賴注入或狀態管理處理

**待辦**：
- [ ] 重構 contextFileName 傳遞邏輯
- [ ] 移除 "This is a bit of a hack" 註解

---

### 3. 待實作的 Notifications 組件

**問題**：計畫中提到的 `Notifications` 組件尚未實作

**發現**：
- `DialogManager.tsx` 計畫中有 Notifications
- 實際實施中沒有
- 可能已在 `DefaultAppLayout` 中處理

---

## 架構差異與上游同步問題

### 1. 與 gemini-cli 的主要差異
- **Settings Architecture**：上游遷移到嵌套設定 schema（V2）；llxprt-code 保留扁平設定以維持多提供商 UI 相容性
- **UI Parity**：DialogManager.tsx 列出四個未移植的組件：
  - `LoopDetectionConfirmation`
  - `ProQuotaDialog`
  - `ModelDialog`
  - `IdeTrustChangeDialog`
- **Subagents**：llxprt-code 使用自定義 subagent 架構，與上游的 `CodebaseInvestigator` 模式不相容

---

### provider實現間隙

**OpenAIProvider** (`packages/core/src/providers/openai/OpenAIProvider.ts`):
- [ ] Line 974: `TODO: Implement server tools for OpenAI provider`
- [ ] Line 984: `TODO: Implement server tool invocation for OpenAI provider`
- [ ] Line 4663: `TODO: Implement response parsing based on detected format`
- OpenAIProvider 缺少完整的 OAuth refresh 實作（在測試中標記為 `NotYetImplemented`）
- Tool ID 正規化 (`call_`) 處於臨時私有方法狀態

**AnthropicProvider**:
- [ ] Server tools 和 tool invocation TODO (類似 OpenAI)
- [ ] Tool ID 正規化 (`toolu_`) 處於臨時私有方法狀態

**GeminiProvider**:
- ✅ Server tools 已實作 (`web_search`, `web_fetch`)
- [ ] GeminiOAuthProvider 處於過渡狀態，橋接新介面到舊版 Google OAuth 基礎設施

**OpenRouter Support**:
- 沒有專門的 OpenRouter provider。支援是通過 400 錯誤檢測和激進的工具響應壓縮在 OpenAIProvider 中「黑進來的」

---

### 2. 架構「Hardening」不一致性
- 專案正在進行 **Stateless Hardening** (`PLAN-20251023-STATELESS-HARDENING`) 的中間階段
- AnthropicProvider 和 GeminiProvider 已大幅重構為無狀態
- OpenAIProvider 仍然是「熱點」的狀態邏輯和模型特定的條件 hacks（例如 Kimi 和 Mistral 特定的工具 ID 正規化）

---

### 3. 臨時 Hacks & Mocks
- **硬編碼模型**：Gemini 和 Anthropic provider 在 OAuth 激活時退回到硬編碼模型列表，因為 `models.list` 端點通常在 OAuth tokens 時失敗
- **Ink Stubbing**：測試工具依賴於 `ink-stub`，表明終端機 UI 整合測試的局限性
- **Tool ID Mapping**：`call_` (OpenAI)、`toolu_` (Anthropic) 和 `hist_tool_` (內部歷史) 之間的正規化是通過每個 provider 中的臨時私有方法處理，而不是 core 中的統一服務

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
**來源**：多個會話的 `.resolved` 文件存在但 task.md 未更新

**具體任務**：
- [ ] 驗證 E2E 測試修復通過
- [ ] 驗證 UI 穩定性修復生效
- [ ] 確認無迴歸
- [ ] 更新 task.md 以反映實際狀態

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

## 關鍵會話參考

### 重要會話目錄（按優先級排序）

**🔴 高優先級（Critical Issues）**：
- **`d94ee6dd-4f45-490b-92df-dc7c98f0e078`** - LLXPRT-4 虛擬化代碼審查（關鍵架構缺陷，DO NOT MERGE）
- **`a23b76fd-8e45-4fba-a290-640871f0ea9a`** - Debugging Runtime Crash and UI Layout
- **`1121a3ee-459c-40b2-b86f-7b86564a1cb3`** - Static Architecture 實作與相關任務（性能優化核心）
- **`223c9831-d817-4a30-a16c-52bfa9085b18`** - 專案狀態報告與 E2E 遷移分析（Integration Pending）

**🟡 中優先級（Architecture & Refactoring）**：
- **`be07420c-f019-439b-bfaf-171328c12583`** - AST-Grep 遷移任務
- **`3ab59064-4305-4ec2-a0d3-4ec372aee44c`** - Refining AST tools and build config（基礎設施負債）
- **`db9177a6-5a0e-4aed-ab83-8ec071b1078c`** - UI Architecture Parity Analysis
- **`3a428465-4482-42ed-8f08-452a32fa2b7c`** - SettingsDialog 優化

**🟢 低優先級（Enhancements & Documentation）**：
- **`7b2770fe-5b28-4a7a-a72d-4cdb7a593ebc`** - UI 對齊與修復任務
- **`7248c104-3e66-4f17-946a-472790e39773`** - Code Comment Reinforcement 規則創建
- **`7906414f-3dc1-4452-9b96-13cf2108257e`** - Shopify App Template 架構設計
- **`f54f70aa-8304-4e71-88c1-c2970ef637d1`** - MCP 實作比較

### Opencode Session Files
- `/home/soulx7010201/MyLLMNote/llxprt-code/Opencode/add233c5043264d47ecc6d3339a383f41a241ae8/`
  - 包含多個 JSON 會話檔案（最後修改：2026-01-31）
  - 主要用於 OpenCode 框架的會話管理元數據

---

## 下一步行動建議

**立即行動**（本日/本週）：
1. 🚨 Debug 'Range is not defined' Crash - 優先級最高，阻塞系統穩定性
2. 🔧 修復虛擬化架構缺陷 - DO NOT MERGE 關鍵問題
3. 📋 開始階段 A：系統化 Memoization
4. ✅ 驗證 ToolCall UI 組件建置通過

**短期行動**（1-2 週）：
5. 完成階段 B：代碼清理與架構債務
6. 修復 TODO Tab 布局
7. 清理基礎設施負債（fast-glob 等）
8. 整合 E2E Fiber-Recorder 測試（Integration Pending）
9. 性能測試驗證

**長期行動**（視需求）：
10. 階段 C：增強功能與測試
11. 階段 D：核心重構（AST-Grep）
12. 統一 OpenAI Provider 實施
13. Code Comment Reinforcement 規則
14. Shopify App Template 架構

---

## 報告生成信息
**生成時間**：2026-02-04
**審查範圍**：
- ~/MyLLMNote/llxprt-code/results.md (原有報告)
- ~/MyLLMNote/llxprt-code/Antigravity/（27 個會話目錄）
- ~/MyLLMNote/llxprt-code/Opencode/（JSON 會話檔案）
- ~/MyLLMNote/openclaw-workspace/repos/llxprt-code/（原始碼目錄）
- 4 個並行背景 Explore Agent 的綜合分析結果
- 來源碼中 TODO/FIXME/HACK 標記的全面掃描（13 條關鍵發現）

**更新內容**：
- ✅ 保留所有原有任務與發現
- ✅ 新增 5 個並行背景代理調查結果
- ✅ 詳細列出所有 13 條源碼關鍵 TODO/FIXME 標記
- ✅ Provider 架構不一致性深度分析
- ✅ 測試覆蓋率統計（601 測試文件，106 跳過測試，75 測試 TODO）
- ✅ Antigravity 會話完成狀態分析（16 個會話有未完成任務）
- ✅ 更新優先級與執行順序建議
- ✅ 驗證 Git 狀態（clean，最新提交：07b8f13b6）
- ✅ 確認 staticAreaMaxItemHeight 已實施
- ✅ 確認 useFlickerDetector 無重複調用問題

**關鍵發現**：
1. 虛擬化架構缺陷（繞過）未被列為最高優先級修復（應該是）
2. 多個基礎設施負債（fast-glob, MCP 比較）已記錄
3. 配置介面缺口（getCustomExcludes）已列入待辦
4. 16 個會話有未完成任務，部分已有 `.resolved` 文件但 `task.md` 未更新
5. E2E 測試強化（Fiber-Recorder）狀態為 Integration Pending
6. OpenAI Provider 有 6 個 `NotYetImplemented` OAuth 測試
7. 多個 OpenAI 實現存在架構重複和碎片化
8. 601 個測試文件中，106 個測試被跳過，75 個 TODO 待處理
