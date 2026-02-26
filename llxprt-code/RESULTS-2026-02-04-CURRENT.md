# llxprt-code 專案審查結果
**審查時間**: 2026-02-04 17:00:48 UTC
**審查範圍**: 全面專案審查（並行多探測器搜索 + 文件分析）
**專案位置**: ~/MyLLMNote/llxprt-code/

---

## 專案現況

**llxprt-code** 是一個 **AI 驅動的 CLI 程式碼輔助工具**，採用 **TypeScript/Node.js monorepo** 架構，支援多種 LLM 提供商（Gemini、Anthropic、OpenAI 等）和本地模型。

### 當前狀態

| 指標 | 數值 |
|:-----|:-----|
| **Git 分支** | `main` (最新提交: e07cbec) |
| **會話記錄** | 29 個 Antigravity 會話 + 341 個 Opencode JSON 會話檔案 |
| **對齊度** | 85-90% (與 gemini-cli) |
| **性能提升** | +10.15% (目標：+30%，差距：+20%) |
| **未完成會話** | 16 個會話有 .resolved 檔案但 task.md 仍有未完成項 |

### 主要進展

- ✅ **Static/Virtual 雙模式架構**: useRenderMode hook 與雙模式渲染
- ✅ **Screen Reader 支援**: ScreenReaderAppLayout 已實作
- ✅ **Tabs 基礎設施**: TabBar、TODO Tab、System Tab 已移植
- ✅ **Terminal Corruption 修復**: 解決 Issue #26 (CTRL+C 退出問題)
- ✅ **Fiber-Recorder 集成**: 已安裝並導入測試環境

### 專案架構

- **Monorepo 組織**:
  - `packages/core`: 核心引擎，處理 LLM providers、tool execution、orchestration
  - `packages/cli`: CLI 主程式，實作終端 UI (Ink/React)
- **渲染引擎**:
  - **Static Mode**:標準終端滾動回溯
  - **Virtual Mode**: 優化的大型歷史記錄渲染（目前需要修復）
- **測試基礎**:
  - 單元測試: 601 個測試檔案
  - 跳過測試: 106 個
  - 測試 TODO: 75 個待處理

---

## 未完成任務

### 🔴 高優先級（阻塞性問題）

#### 1. 修復 'Range is not defined' 崩潰
**來源**: `a23b76fd-8e45-4fba-a290-640871f0ea9a/`
**狀態**: **根因已定位** - 待修復
**嚴重性**: **HIGH** - 運行時崩潰

**問題詳述**:
- **主要崩潰**: `packages/cli/src/ui/hooks/useMouseSelection.ts` line 243
```typescript
const range = selectionRangeRef.current ?? new Range();  // 💥 Range not defined in Node.js
```
- **根因**: `Range` 是瀏覽器 API，在 Node.js/Ink 環境中不存在
- **其他瀏覽器 API 風險**:
  - `ClipboardService.ts` 多處直接使用 `navigator.clipboard`、`document` API
  - 完全與 Node.js 不相容，會導致崩潰

**修復方案**:
1. 添加環境檢查 `if (typeof Range !== 'undefined')`
2. 使用 Ink 提供的 selection 機制或其他安全的替代方案

---

#### 2. 虛擬化架構關鍵缺陷 ⚠️ DO NOT MERGE ⚠️
**來源**: `d94ee6dd-4f45-490b-92df-dc7c98f0e078/`
**狀態**: **未修復** - 三個關鍵缺陷已確認
**嚴重性**: **CRITICAL** - 破壞性架構缺陷

**三個缺陷確認**:

1. **Defect 1: 虛擬化繞過 (Virtualization Bypass)**
   - **位置**: `packages/cli/src/ui/layouts/DefaultAppLayout.tsx` lines 203-224
   - **問題**: `pendingHistoryItems` 被組合成單一大區塊，作為 `key: 'pending'` 傳遞
   - **影響**: 50+ 工具調用渲染為單一大 React 組件，完全繞過虛擬化

2. **Defect 2: 脆弱顯示邏輯 (Fragile Display Logic)**
   - **位置**: `DefaultAppLayout.tsx` lines 206 & 466（雙重複製）
   - **問題**: 渲染邏輯在兩個路徑中重複，無狀態檢查
   - **影響**: 增加 UI 不一致風險

3. **Defect 3: 低劣高度估算 (Poor Height Estimation)**
   - **位置**: `DefaultAppLayout.tsx` 硬編碼 `estimatedHeight: 100`
   - **問題**: 固定高度估算導致跳動滾動和不正確的滾動條

---

#### 3. 系統化 Memoization（性能優化核心）
**來源**: `1121a3ee-459c-40b2-b86f-7b86564a1cb3/`
**時間估計**: 4-6 小時
**影響**: +20-30% 性能提升，達到目標 +30%

| 組件 | React.memo | useMemo 機會 | 影響級別 |
|------|-----------|-------------|---------|
| **StatsDisplay** | ❌ MISSING | `computeSessionStats` | High |
| **ModelStatsDisplay** | ❌ MISSING | `activeModels` filtering | Medium |
| **CacheStatsDisplay** | ❌ MISSING | Cache calculation | Medium |
| **ToolStatsDisplay** | ❌ MISSING | `totalDecisions` reduce | Medium |
| **InputPrompt** | ❌ MISSING | `calculatePromptWidths`, `parseInputForHighlighting` | Medium |

---

#### 4. OpenAIProvider 關鍵功能缺失
**嚴重性**: **Critical**

| 文件路徑 | 行 | 標記 | 上下文 |
|---------|---|------|--------|
| `packages/core/.../OpenAIProvider.ts` | 974 | TODO | Server tools for OpenAI 完全未實作 |
| `packages/core/.../OpenAIProvider.ts` | 984 | TODO | Server tool invocation for OpenAI 缺失 |
| `packages/core/.../OpenAIProvider.ts` | 4663 | TODO | Tool response parsing 目前是佔位符 |
| `packages/core/.../coreToolScheduler.test.ts` | 1302 | TODO | **Bug**: YOLO 模式並行工具執行違反順序要求 |

---

### 🟡 中優先級任務

#### 5. 基礎設施負債清理
**來源**: `3ab59064-4305-4ec2-a0d3-4ec372aee44c/`
**時間**: 2-3 小時

**發現**:
1. **esbuild.config.js externals** - 包含平台特定 externals，需要更動態的方法
2. **zedIntegration.ts tool result handling** - 需要確保正確處理所有潛在的 `ToolResult` 形狀
3. **跨平台問題**:
   - `scripts/analyze-stale-sessions.sh` (Line 23): 使用非跨平台的 `find` 命令
4. **resolvePath function** - 需要檢查是否需要支持多個擴展名

---

#### 6. 配置介面修補
**時間**: 1 小時

**具體任務**:
- 在 Config interface 中實作 `getCustomExcludes` 方法
- 移除 `ignorePatterns.ts` 中的 TODO 註解 (Line 167, 202)

---

#### 7. MCP 實作比較完成
**來源**: `f54f70aa-8304-4e71-88c1-c2970ef637d1/`
**狀態**: 2 個未完成任務

**待執行**:
- Compare `loadExtensions` in `packages/cli/src/config/extension.ts` (Old vs New)
- Compare `ExtensionStorage` in `packages/cli/src/config/storage.ts`
- Identify the cause of the issue
- Report findings to the user

---

#### 8. SettingsDialog 優化（Scheme 3）
**來源**: `3a428465-4482-42ed-8f08-452a32fa2b7c/`
**狀態**: 實作計畫已制定，待執行

---

#### 9. TODO Tab 布局修復
**來源**: `1121a3ee-459c-40b2-b86f-7b86564a1cb3/`

**待執行任務**:
- Investigate and Refine TODO Tab Integration
- Fix the "pushing up" layout issue in the TODO tab
- Verify TODO tab styling and layout stability

---

#### 10. AST-Grep 遷移（核心重構）
**來源**: `be07420c-f019-439b-bfaf-171328c12583/`
**目標**: 替換現有邏輯為 `@ast-grep/napi` 以加速程式碼分析

**待執行**:
- Create Golden Master safety test
- Install `@ast-grep/napi` dependency
- Implement `validateASTSyntax` using `ast-grep`
- Refactor `extractDeclarations` to use `ast-grep`
- Refactor `findRelatedSymbols` to use `ast-grep`
- Verify with Golden Master and existing tests

---

### 🟢 低優先級任務

#### 11. Code Comment Reinforcement (CCR) 規則創建
**來源**: `7248c104-3e66-4f17-946a-472790e39773/`

**待執行**:
- Finalize `.agent-rules.md` (AI-facing)
- Create `PROJECT_RECIPE.md` (Infrastructure/CI recommendations)
- Verify with comprehensive example

---

#### 12. Shopify App Template 架構設計
**來源**: `7906414f-3dc1-4452-9b96-13cf2108257e/`
**狀態**: 13 個未完成任務（仍在規劃階段）

**待執行**:
- Analyze Project Structure (package.json, app/root.tsx, app/routes)
- Design Template Architecture (Select Polyrepo, identify reusable UI components)
- Create Implementation Plan (Draft `implementation_plan.md`)

---

#### 13. E2E 測試強化 - Fiber-Recorder 遷移
**來源**: `223c9831-d817-4a30-a16c-52bfa9085b18/`
**狀態**: 🟡 Integration Pending - Library Verified

**待執行**:
- Run pilot tests with fiber-recorder
- Measure test execution time impact
- Check for false positives in CI
- Integrate to CI/CD pipeline
- Document patterns and best practices

---

## 待處理事項

### Hacks 與臨時解決方案

#### 1. Ink Layout Retrieval Mock
**位置**: `src/ui/utils/ink-utils.ts`

**問題**: `getBoundingBox` 在核心 Ink 庫中不存在，使用了最佳化的 mock 實作

**待辦**:
- 調查正確的 Ink 佈局坐標檢索方法
- 取代 mock 實作為穩健的佈局檢索方法

---

#### 2. Config Context Hack
**位置**: `packages/cli/src/config/config.ts` (Line 962)

**問題**: 臨時 hack 用於傳遞 `contextFileName`

**待辦**:
- 重構 contextFileName 傳遞邏輯
- 移除 "This is a bit of a hack" 註解

---

### 架構差異與 Provider 實施間隙

#### OpenAIProvider (`packages/core/src/providers/openai/OpenAIProvider.ts`):
- Server tools 和 tool invocation TODO（Line 974, 984）
- Tool response parsing 目前是佔位符（Line 4663）
- OpenAIProvider 缺少完整的 OAuth refresh 實作
- Tool ID 正規化 (`call_`) 處於臨時私有方法狀態

#### AnthropicProvider:
- Server tools 和 tool invocation TODO（類似 OpenAI）
- Tool ID 正規化 (`toolu_`) 處於臨時私有方法狀態

#### GeminiProvider:
- ✅ Server tools 已實作 (`web_search`, `web_fetch`)
- [ ] GeminiOAuthProvider 處於過渡狀態

#### OpenRouter Support:
- 沒有專門的 OpenRouter provider
- 支援是通過 400 錯誤檢測和激進的工具回應壓縮在 OpenAIProvider 中「黑進來的」

---

### 架構「Hardening」不一致性
- 專案正在進行 **Stateless Hardening** 的中間階段
- AnthropicProvider 和 GeminiProvider 已大幅重構為無狀態
- OpenAIProvider 仍然是「熱點」的狀態邏輯和模型特定的條件 hacks

---

### 230+ 個技術債標記
**總計**: 230+ 個 TODO/FIXME/HACK 標記
- packages/core: 128 個
- packages/cli: 109 個

**高優先級分類**:

**UI Components**:
- `DialogManager.tsx` — 多個未移植的對話框（4 個）
- `useCommandCompletion.tsx:215` — 不當的補全範圍邏輯
- `AppContainer.tsx:63` — IDE 集成目前中斷或未驗證
- `KeypressContext.tsx:324` — 需要更健壯的 IME 感知輸入處理系統

**Tools and Utilities**:
- `shell.ts:479` — `summarizeToolOutput` 需要適配 `ServerToolsProvider` 架構
- `read-many-files.ts:90` — 文件截斷行為應通過 CLI 參數可配置
- `todoContinuationService.ts:104` — 長時間運行的 todo continuation 缺少超時功能

**Configuration and Settings**:
- `config.ts:962` — 標記為 "hack" 關於 `contextFileName` 的傳遞方式
- `extension.ts:356` — 通過下載歸檔而非完整 `.git` 歷史優化擴展加載
- `ignorePatterns.ts:167` — Config interface 中 `getCustomExcludes` 仍未實作

**Testing Debt**:
- `packages/cli/tsconfig.json:29` — 在測試中抑制類型錯誤（#5691）需要解決
- 多個測試被禁用/跳過，等待適配當前環境

---

## 重點記錄

### 關鍵會話參考

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

**已完成或進行中**:
- `848a62d7` - Terminal Corruption Issue (Issue #26) - All tasks completed
- `e5d945a7` - Profile Loading & UI Bug Fix - All tasks completed
- `f4182ee1` - Dependency Migration - All tasks completed
- `d8053952` - Code Review: UI Architecture Parity Analysis - All tasks completed

---

### Ghost Tasks（狀態同步問題）

**16 個會話有 .resolved 檔案但 task.md 有未完成項**:

高優先級:
- `1121a3ee...` (4+ 個未完成，包含 Range crash)
- `a23b76fd...` (15 個未完成)

中優先級:
- `7906414f...` (13 個未完成，Shopify 模板)
- `f54f70aa...` (2 個未完成，MCP 實作比較)
- `3ab59064...` (4+ 個未完成)
- `223c9831...` (5 個未完成)

低優先級:
- `be07420c...` (6 個未完成，AST-grep)
- `848a62d7...` (4 個未完成)
- `b5bc4f6f...` (2 個未完成)
- `7248c104...` (3 個未完成)

---

### 建議執行順序

**階段 A：臨界修復與核心優化（優先 - 本週）**
**時間**: 8-10 小時

1. 🔧 **修復 'Range is not defined' Crash** (1-2 小時)
2. 🔧 **修復虛擬化架構缺陷** (3-4 小時)
3. 📋 **系統化 Memoization** (4-6 小時)

**預期成果**: ✅ 穩定性修復 + ✅ 性能達 +30% 目標 + ✅ 對齊度 90-95%

---

**階段 B：代碼清理與架構債務（1-2 週內）**
**時間**: 4-6 小時

4. TODO Tab 修復 (30 分鐘)
5. 基礎設施負債清理 (2-3 小時)
6. 配置介面修補 (1 小時)
7. MCP 實作比較完成 (1 小時)

**預期成果**: ✅ 代碼品質提升 + ✅ 架構穩健性 + ✅ 跨平台問題解決

---

**階段 C：增強功能與測試（可選/未來）**
**時間**: 6-8 小時

8. 移植缺失的 UI 組件（DialogManager）
9. Provider Server Tools 統一
10. OpenAI Stateless Refactor
11. 統一 Tool ID 管理
12. 性能測試完善（3-4 小時）
13. 無障礙性測試（2-3 小時）
14. E2E 測試強化

---

**階段 D：核心重構（長期）**

15. AST-Grep 遷移完成
16. 統一 OpenAI Provider 實施
17. Code Comment Reinforcement 規則
18. Shopify App Template 架構

---

### pendingHistory 欄位調查結論 ✅ 已完成

**調查結果**:
- ✅ `pendingHistory` 欄位**不存在**於當前實作中
- ✅ `pendingHistoryItems` **活躍使用**且對當前 UI 架構**至關重要**
- ✅ gemini-cli 根本沒有 `pendingHistory` 欄位，而是直接使用 `pendingHistoryItems`

**結論**: 無需進一步清潔，待辦事項可關閉

---

### 核心結論

**最緊急（本週處理）**:
1. **'Range is not defined' Runtime Crash** - `useMouseSelection.ts:243`, `ClipboardService.ts` 多處
2. **虛擬化架構缺陷** - `DefaultAppLayout.tsx` - DO NOT MERGE

**高優先級（2 週內）**:
3. **Systematic Memoization** - 達到 +30% 性能目標
4. **Configuration Interface Gap** - getCustomExcludes 實作
5. **Infrastructure Debt** - fast-glob, resolveImportPath, esbuild externals, `find` 命令

**中優先級（1 個月內）**:
6. **OpenAI Provider Server Tools** - 實作缺失的功能（Critical severity）
7. **YOLO Mode Bug Fix** - 修正並行工具執行（High severity）
8. **Security Warning** - yolo.toml 禁用安全檢查的風險
9. **UI Dialog Migration** - 移植 4 個未移植的對話框

---

**下次審查建議**: 完成階段 A 後重新評估
