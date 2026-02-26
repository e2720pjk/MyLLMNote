# llxprt-code 專案審查結果

**審查時間**: 2026-02-05 03:35:00 UTC
**審查範圍**: 全面深度審查（多探測器併行搜索 + 會話記錄分析 + 源碼庫調查）
**專案位置**: `~/MyLLMNote/llxprt-code/`
**源碼庫**: `~/MyLLMNote/openclaw-workspace/repos/llxprt-code/`

---

## 專案現況

**LLxprt Code** 是一個 **AI 驅動的 CLI 程式碼輔助工具**，採用 **TypeScript/Node.js monorepo** 架構，支援多種 LLM 提供商（Gemini、Qwen、Anthropic、OpenAI 可相容提供商）和本地模型。

### 當前狀態

| 指標 | 數值 |
|:-----|-----|
| **版本** | v0.7.0 |
| **Git 分支** | `opencode-dev` (最新提交: 07b8f13b6) |
| **會話記錄** | 29 個 Antigravity 會話 + 341 個 Opencode JSON 會話檔案 |
| **對齊度** | 85-90% (與 gemini-cli) |
| **性能提升** | +10.15% (目標：+30%，差距：+20%) |
| **建置狀態** | ✅ Build 通過 |
| **Lint 狀態** | ✅ Lint 通過 |
| **測試狀態** | ✅ 測試執行中 (601 個測試檔案，106 個跳過，75 個 TODO) |

### 專案架構

**Monorepo 組織**:
- `packages/core`: 核心引擎，處理 LLM providers、tool execution、orchestration
- `packages/cli`: CLI 主程式，實作終端 UI (Ink/React)
- `packages/a2a-server`: A2A 伺服器
- `packages/test-utils`: 測試工具
- `packages/ui`: UI 組件庫
- `packages/vscode-ide-companion`: VSCode extension

**渲染引擎**:
- **Static Mode**: 標準終端滾動回溯
- **Virtual Mode**: 優化的大型歷史記錄渲染（需要修復虛擬化缺陷）

### 近期變更 (Git 歷史)

```
07b8f13b6 - ci: update OpenCode model to glm-4.7-free
955638cc9 - Merge branch 'main' into opencode-dev
6b3e02824 - Merge pull request #949 (show-line-numbers feature)
c8eda13d3 - feat(core): add showLineNumbers to read_file/read_line_range
e40c645db - fix(sandbox): pause stdin before attach
d0d068029 - Fix podman sandbox TTY allocation
```

**主要進展**:
- ✅ **Static/Virtual 雙模式架構**: useRenderMode hook 與雙模式渲染
- ✅ **Screen Reader 支援**: ScreenReaderAppLayout 已實作
- ✅ **Tabs 基礎設施**: TabBar、TODO Tab、System Tab 已移植
- ✅ **showLineNumbers 功能**: read_file 和 read_line_range 支援行號顯示
- ✅ **Fiber-Recorder 集成**: 已安裝並導入測試環境

---

## 未完成任務

### 🔴 高優先級任務（阻塞性問題）

#### 1. 虛擬化架構關鍵缺陷 (CRITICAL) ⚠️ DO NOT MERGE ⚠️
**嚴重性**: **CRITICAL** - 破壞性架構缺陷

**三個關鍵缺陷確認**:
1. **Defect 1: 虛擬化繞過 (Virtualization Bypass)**
   - 位置: `packages/cli/src/ui/components/MainContent.tsx`
   - 問題: `pendingItems` 被組合成單一大區塊作為 `key: 'pending-streaming'` 傳遞給虛擬化列表
   - 影響: 50+ 工具調用渲染為單一大 React 組件，完全繞過虛擬化

2. **Defect 2: 脆弱顯示邏輯 (Fragile Display Logic)**
   - 位置: `MainContent.tsx`
   - 問題: `pending-streaming` 項目僅在 `streamingState === 'responding'` 時推送到列表
   - 影響: 如處於 `WaitingForConfirmation` 或 `Error` 狀態，`pendingHistoryItems` **會消失**

3. **Defect 3: 低劣高度估算 (Poor Height Estimation)**
   - 位置: `MainContent.tsx`
   - 問題: 硬編碼 `const getEstimatedItemHeight = () => 100`
   - 影響: 滾動上捲時的經典「跳動滾動」行為

**修復計畫**:
1. 扁平化 pending items（類似 `history` 的映射方式）
2. 修正渲染條件邏輯（應為 `pendingHistoryItems.length > 0`）
3. 實施動態高度估算

---

#### 2. Systematic Memoization（性能優化核心）
**時間估計**: 4-6 小時
**影響**: +20-30% 性能提升

| 組件 | React.memo | useMemo 機會 | 影響級別 |
|------|-----------|-------------|---------|
| **StatsDisplay** | ❌ MISSING | `computeSessionStats` | High |
| **ModelStatsDisplay** | ❌ MISSING | `activeModels` filtering | Medium |
| **CacheStatsDisplay** | ❌ MISSING | Cache calculation | Medium |
| **ToolStatsDisplay** | ❌ MISSING | `totalDecisions` reduce | Medium |
| **InputPrompt** | ❌ MISSING | `calculatePromptWidths`, `parseInputForHighlighting` | Medium |

---

#### 3. OpenAIProvider 關鍵功能缺失 (CRITICAL)

| 文件路徑 | 行 | 標記 | 上下文 |
|---------|---|------|--------|
| `OpenAIProvider.ts` | 974 | TODO | Server tools for OpenAI 完全未實作 |
| `OpenAIProvider.ts` | 984 | TODO | Server tool invocation for OpenAI 缺失 |
| `OpenAIProvider.ts` | 4663 | TODO | Tool response parsing 目前是佔位符 |
| `coreToolScheduler.test.ts` | 1302 | TODO | **Bug**: YOLO 模式並行工具執行違反順序要求 |

---

### 🟡 中優先級任務

#### 4. E2E 測試 Fiber-Recorder 遷移
**狀態**: Integration Pending - Library Verified

**待完成項**:
- Review analysis with user
- Run pilot tests with fiber-recorder
- Measure test execution time impact
- Verify no false positives in CI
- Document patterns and best practices

---

#### 5. AST-Grep 遷移（核心重構）
**目標**: 替換現有邏輯為 `@ast-grep/napi` 以加速程式碼分析

**待完成項**:
- Create Golden Master safety test (`packages/core/src/tools/tabby-edit.safety.test.ts`)
- Install `@ast-grep/napi` dependency
- Implement `validateASTSyntax` using `ast-grep`
- Refactor `extractDeclarations` to use `ast-grep`
- Refactor `findRelatedSymbols` to use `ast-grep`
- Verify with Golden Master and existing tests

---

#### 6. Refine AST Tools and Build Config 優化
**時間估計**: 2-3 小時

**待完成項**:
- Update `esbuild.config.js` externals（平台特定 externals 需要更動態的方法）
- Stabilize `zedIntegration.ts` tool result processing（確保正確處理所有潛在 `ToolResult` 形狀）
- Refactor `ast-edit.ts` for cross-platform support:
  - Replace `find` with `fast-glob` in `getWorkspaceFiles`
  - Support multiple extensions in `resolveImportPath`
- Verification and PR update

---

#### 7. MCP 實作比較
**狀態**: 部分完成

**已完成項**:
- ✅ 探索兩個 repo 的文件結構
- ✅ 比較 `smart-tree` 配置
- ✅ 比較 MCP connection 和 client 實作
- ✅ 比較 extension loading logic

**待完成項**:
- Locate MCP configuration files
- Compare `loadExtensions` in `packages/cli/src/config/extension.ts` (Old vs New)
- Compare `ExtensionStorage` in `packages/cli/src/config/storage.ts`
- Identify the cause of the issue
- Report findings to the user

---

### 🟢 低優先級任務

#### 8. Code Comment Reinforcement (CCR) 規則創建
**待執行**:
- Finalize `.agent-rules.md` (AI-facing)
- Create `PROJECT_RECIPE.md` (Infrastructure/CI recommendations)
- Verify with comprehensive example

---

#### 9. Shopify App Template 架構設計
**狀態**: 仍在規劃階段

**已完成項**:
- ✅ 解釋 Monorepo 概念和優勢
- ✅ 調查現有 Shopify/Remix 模板和方法
- ✅ 評估是否可以使用現有解決方案
- ✅ 解釋 Polyrepo vs Monorepo 權衡
- ✅ 評測 llxprt Tool

**待完成項**:
- Analyze Project Structure (package.json, app/root.tsx, app/routes)
- Analyze `app/shopify.server.ts` and `app/db.server.ts` for backend coupling
- Design Template Architecture
- Create Implementation Plan

---

## 待處理事項（技術債務）

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

```typescript
// TODO: This is a bit of a hack. The contextFileName should ideally be passed
```

**待辦**:
- 重構 contextFileName 傳遞邏輯
- 移除 "This is a bit of a hack" 註解

---

### 架構差異與 Provider 實施間隙

#### OpenAIProvider (`packages/core/src/providers/openai/OpenAIProvider.ts`):
- **Server tools TODO** (Line 974): `TODO: Implement server tools for OpenAI provider`
- **Server tool invocation TODO** (Line 984): `TODO: Implement server tool invocation for OpenAI provider`
- Tool response parsing 目前是佔位符 (Line 4663)
- OpenAIProvider 缺少完整的 OAuth refresh 實作
- Tool ID 正規化 (`call_`) 處於臨時私有方法狀態

**嚴重性**: Critical

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

### Configuration Interface Gap

**位置**: `packages/core/src/utils/ignorePatterns.ts`

**問題**:
- Line 167: `TODO: getCustomExcludes method needs to be implemented in Config interface`
- Line 202: `TODO: getCustomExcludes method needs to be implemented in Config interface`

**待辦**:
- 在 Config interface 中實作 `getCustomExcludes` 方法
- 移除 TODO 註解

---

### 測試債務

發現多個被跳過的測試:
- `OpenAIProvider.callResponses.stateless.test.ts` - 多個 skipped tests
- `OpenAIProvider.integration.test.ts` - 跳過全部集成測試
- `OpenAIProvider.responsesIntegration.test.ts` - 跳過全部 responses 集成測試
- `parseResponsesStream.test.ts` - 多個 skipped tests

---

### 94+ 個技術債標記

**總計**: 94 個 TODO/FIXME/HACK 標記在 TypeScript 檔案中

**高優先級分類**:
- **UI Components**: `DialogManager.tsx` — 多個未移植的對話框（4 個）、`useCommandCompletion.tsx:215` — 不當的補全範圍邏輯、`AppContainer.tsx:63` — IDE 集成目前中斷或未驗證、`KeypressContext.tsx:324` — 需要更健壯的 IME 感知輸入處理系統
- **Tools and Utilities**: `shell.ts:479` — `summarizeToolOutput` 需要適配 `ServerToolsProvider` 架構、`read-many-files.ts:90` — 文件截斷行為應通過 CLI 參數可配置、`todoContinuationService.ts:104` — 長時間運行的 todo continuation 缺少超時功能
- **Configuration and Settings**: `config.ts:962` — 標記為 "hack" 關於 `contextFileName` 的傳遞方式、`extension.ts:356` — 通過下載歸檔而非完整 `.git` 歷史優化擴展加載、`ignorePatterns.ts:167` — Config interface 中 `getCustomExcludes` 仍未實作
- **Testing Debt**: `packages/cli/tsconfig.json:29` — 在測試中抑制類型錯誤需要解決、多個測試被禁用/跳過，等待適配當前環境

---

## 重點記錄

### 關鍵架構調查結論

#### pendingHistory 欄位調查結論 ✅ 已完成
**調查結果**:
- ✅ `pendingHistory` 欄位**不存在**於當前實作中
- ✅ `pendingHistoryItems` **活躍使用**且對當前 UI 架構**至關重要**
- ✅ gemini-cli 根本沒有 `pendingHistory` 欄位，而是直接使用 `pendingHistoryItems`

**結論**: 無需進一步清潔，待辦事項可關閉

---

### Fiber-Recorder 整合方向確認需要
**核心問題**:
1. **Hook Conflicts**: fiber-recorder、react-devtools-core 和自訂攔截邏輯之間有競爭條件
2. **方向確認**: 需要確認目標是語意 React 樹錄製還是視覺終端錄製
3. **工具選擇**: 如果最終目標是「video playback」給 LLM，fiber-recorder 可能是錯誤層級

**建議**:
1. 確認目標：語意 React 樹錄製 vs. 視覺終端錄製
2. 如果堅持 Fiber，建議簡化 hook 注入並修復手動測試流程
3. 考慮替代方案：捕獲原始輸出流（Ansi/Xterm.js sequences）

---

## 建議執行順序

### 階段 A：臨界修復與核心優化（優先 - 本週）
**時間**: 8-10 小時

1. 🔧 **修復虛擬化架構缺陷** (3-4 小時)
   - 扁平化 pending items
   - 修正渲染條件邏輯
   - 實施動態高度估算

2. 📋 **系統化 Memoization** (4-6 小時)
   - 達到 +30% 性能目標

**預期成果**: ✅ 穩定性修復 + ✅ 性能達 +30% 目標 + ✅ 對齊度 90-95%

---

### 階段 B：代碼清理與架構債務（1-2 週內）
**時間**: 4-6 小時

3. Configuration Interface 實作 (1 小時)
4. 基礎設施負債清理 (2-3 小時)
5. MCP 實作比較完成 (1 小時)

**預期成果**: ✅ 代碼品質提升 + ✅ 架構穩健性 + ✅ 跨平台問題解決

---

### 階段 C：增強功能與測試（可選/未來）
**時間**: 6-8 小時

6. 移植缺失的 UI 組件
7. Provider Server Tools 統一
8. OpenAI Stateless Refactor
9. 統一 Tool ID 管理
10. 性能測試完善
11. 無障礙性測試
12. E2E 測試強化（確認方向後）

---

### 階段 D：核心重構（長期）

- 完成 AST-Grep 遷移
- 統一 OpenAI Provider 實作
- 創建 Code Comment Reinforcement 規則
- 設計並實施 Shopify App Template 架構

---

## 核心結論

**最緊急（本週處理）**:
1. **虛擬化架構缺陷** - DO NOT MERGE
2. **系統化 Memoization** - 達到 +30% 性能目標

**高優先級（2 週內）**:
3. **Configuration Interface** - getCustomExcludes 實作
4. **Infrastructure Debt** - fast-glob, resolveImportPath, esbuild externals
5. **OpenAI Provider Server Tools** - 實作缺失的功能 (Critical severity)

**中優先級（1 個月內）**:
6. **YOLO Mode Bug Fix** - 修正並行工具執行
7. **UI Dialog Migration** - 移植未移植的對話框
8. **MCP 實作比較** - 完成差異分析

**低優先級（未來）**:
9. **AST-Grep 遷移** - 核心重構
10. **Code Comment Reinforcement** - 規則創建
11. **Shopify App Template** - 架構設計

---

## 總結

- 專案整體進展良好，已實現關鍵架構（Tabs、Screen Reader、Fiber-Recorder base）
- 有 **多個會話** 包含未完成任務，總計約 **40-50 項** 待辦事項
- **1 個關鍵缺陷** 需要優先處理（虛擬化缺陷 - DO NOT MERGE）
- 數個 **技術債** 標記需要逐步清理（90+ 個 TODO/FIXME/HACK）
- 性能距離目標有 **20% 差距**，可透過 memoization 實現
- **601 個測試文件**，但有多個測試被跳過
- **lint 和 build** 都在正常運行
- 最近新增了 `showLineNumbers` 功能
- OpenCode 模型已更新至 glm-4.7-free

**關鍵發現**:
1. **虛擬化缺陷**是目前最關鍵的問題，直接影響 Virtual Mode 的正確性
2. **性能**距離目標仍有 20% 差距，系統化 Memoization 是關鍵
3. **技術債**主要集中在 OpenAIProvider 實作和 UI 組件移植
4. **測試覆蓋率**尚可，但有 106 個測試被跳過

**下次審查建議**: 完成階段 A 後重新評估，特別是虛擬化缺陷的修復情況以及性能優化的進展。
