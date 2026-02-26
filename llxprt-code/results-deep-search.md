# llxprt-code 專案審查結果 - Deep Search 版本

**審查時間**: 2026-02-05 01:41:00 UTC
**審查範圍**: 全面深度搜索審查（多背景代理並行探索 + 會話記錄完整分析）
**專案位置**: ~/MyLLMNote/llxprt-code/
**原始源碼位置**: ~/MyLLMNote/openclaw-workspace/repos/llxprt-code/

---

## 專案現況

**LLxprt Code** 是一個 **AI 驅動的 CLI 程式碼輔助工具**，採用 **TypeScript/Node.js monorepo** 架構，支援多種 LLM 提供商（Gemini、Qwen、Anthropic、OpenAI 可相容提供商）和本地模型。

### 當前狀態

| 指標 | 數值 |
|:-----|:-----|
| **版本** | v0.7.0 |
| **Git 分支** | `opencode-dev` (最新提交: 07b8f13b6) |
| **會話記錄** | 29 個 Antigravity 會話 + 341 個 Opencode JSON 會話檔案 |
| **未完成會話** | 15 個會話持有未完成項（共約 41 項待辦） |
| **已解析檔案** | 513 個 resolved/solved 檔案 |
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
- `packages/vscode-ide-companion`: VSCode extension

**渲染引擎**:
- **Static Mode**: 標準終端滾動回溯
- **Virtual Mode**: 優化的大型歷史記錄渲染（需要修復虛擬化缺陷）

### 關鍵特性

- ✅ 支援多個 LLM 提供商 (Gemini、Qwen、Anthropic、OpenAI 相容)
- ✅ 本地模型支援 (LM Studio、llama.cpp、Ollama)
- ✅ 子代理系統 (Subagents)
- ✅ MCP (Model Context Protocol) 整合
- ✅ Zed 編輯器整合
- ✅ Screen Reader 支援
- ✅ Tabs 基礎設施 (TODO Tab、System Tab)
- ✅ Fiber-Recorder 測試整合

### 近期變更 (Git 歷史)

```
07b8f13b6 - ci: update OpenCode model to glm-4.7-free
955638cc9 - Merge branch 'main' into opencode-dev
6b3e02824 - Merge pull request #949 (show-line-numbers feature)
dc0b70d36 - chore(core): format fixes
be602011d - test(core): improve showLineNumbers coverage
c8eda13d3 - feat(core): add showLineNumbers to read_file/read_line_range
e40c645db - fix(sandbox): pause stdin before attach
d0d068029 - Fix podman sandbox TTY allocation
```

---

## 未完成任務

### 🔴 高優先級任務（阻塞性問題）

#### 1. 虛擬化架構關鍵缺陷 ⚠️ DO NOT MERGE ⚠️
**會話**: `d94ee6dd-4f45-490b-92df-dc7c98f0e078`
**狀態**: Code review 進行中 - 三個關鍵缺陷已確認
**嚴重性**: **CRITICAL** - 破壞性架構缺陷

**三個缺陷確認**:

1. **Defect 1: 虛擬化繞過 (Virtualization Bypass)**
   - **位置**: `packages/cli/src/ui/layouts/DefaultAppLayout.tsx` lines 203-224
   - **問題**: `pendingHistoryItems` 被組合成單一大區塊，作為 `key: 'pending'` 傳遞給虛擬化列表
   - **影響**: 50+ 工具調用渲染為單一大 React 組件，完全繞過虛擬化

2. **Defect 2: 脆弱顯示邏�輯 (Fragile Display Logic)**
   - **位置**: `DefaultAppLayout.tsx` lines 206 & 466 (雙重複製)
   - **問題**: 渲染邏輯在兩個路徑中重複，無狀態檢查
   - **影響**: 增加 UI 不一致風險

3. **Defect 3: 低劣高度估算 (Poor Height Estimation)**
   - **位置**: 硬編碼多處 `estimatedHeight: 100`
   - **問題**: 固定高度估算導致跳動滾動和不正確的滾動條

---

#### 2. Issue #26 - Terminal Corruption & Synchronous Cleanup
**會話**: `848a62d7-51b3-4016-badd-81e6dba9ca30`
**嚴重性**: **HIGH**

**未完成項**:
- [ ] Investigate `gemini-cli` CTRL+C handling
- [ ] Compare `llxprt-code` vs `gemini-cli` implementations
- [ ] Refine implementation based on comparison
- [ ] Verify fix again

**已完成**:
- [x] Analyze Issue #26 details
- [x] Create Implementation Plan
- [x] Implement synchronous cleanup in `llxprt-code`

---

#### 3. UI 架構對比與驗證
**會話**: `db9177a6-5a0e-4aed-ab83-8ec071b1078c` (1 個未完成項)
**狀態**: ToolCall UI 組件已移植，待驗證

**未完成項**:
- [ ] Compile findings into a structured review report

**已完成工作**:
- ✅ Context Acquisition
- ✅ Change Analysis
- ✅ Review Execution
- ✅ Deep Dive Investigation

---

#### 4. Code Review - UI Architecture Parity Analysis
**會話**: `b5bc4f6f-ed6a-49f3-be16-95716b28257c`

**未完成項**:
- [/] Analyze file changes in `llxprt-code-4` regarding `MainChat` and virtualization logic
- [ ] Verify reported issues
- [ ] generate code review report

---

#### 5. 系統化 Memoization（性能優化核心）
**來源**: 事後分析，目標達到 +30% 性能
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

#### 6. OpenAIProvider 關鍵功能缺失
**嚴重性**: **Critical**

| 文件路徑 | 行 | 標記 | 上下文 |
|---------|---|------|--------|
| `packages/core/.../OpenAIProvider.ts` | 974 | TODO | Server tools for OpenAI 完全未實作 |
| `packages/core/.../OpenAIProvider.ts` | 984 | TODO | Server tool invocation for OpenAI 缺失 |
| `packages/core/.../OpenAIProvider.ts` | 4663 | TODO | Tool response parsing 目前是佔位符 |
| `packages/core/.../coreToolScheduler.test.ts` | 1302 | TODO | **Bug**: YOLO 模式並行工具執行違反順序要求 |

---

### 🟡 中優先級任務

#### 7. E2E 測試 Fiber-Recorder 遷移
**會話**: `223c9831-d817-4a30-a16c-52bfa9085b18` (5 個未完成項)
**狀態**: 🟡 Integration Pending - Library Verified，大部分實作已完成

**已完成項**:
- ✅ 分析現有 E2E 測試基礎設施
- ✅ 識別測試類別和驗證方法
- ✅ 評估 fiber-recorder 能力
- ✅ 定義混合方法策略
- ✅ Phase 1-4 已完成
- [/] Phase 5: Update component snapshot tests（部分完成）

**待完成項**:
- [ ] Review analysis with user
- [ ] Run pilot tests with fiber-recorder
- [ ] Measure test execution time impact
- [ ] Check for false positives in CI
- [ ] Verify no false positives in CI
- [ ] Document patterns and best practices

---

#### 8. AST-Grep 遷移（核心重構）
**會話**: `be07420c-f019-439b-bfaf-171328c12583` (6 個未完成項)
**目標**: 替換現有邏輯為 `@ast-grep/napi` 以加速程式碼分析

**已完成項**:
- ✅ 閱讀並分析遷移計畫文件
- ✅ 評估可行性和計畫品質
- ✅ 提供全面的反饋和建議

**待完成項**:
- [ ] Create Golden Master safety test (`packages/core/src/tools/tabby-edit.safety.test.ts`)
- [ ] Install `@ast-grep/napi` dependency
- [ ] Implement `validateASTSyntax` using `ast-grep`
- [ ] Refactor `extractDeclarations` to use `ast-grep`
- [ ] Refactor `findRelatedSymbols` to use `ast-grep`
- [ ] Verify with Golden Master and existing tests

---

#### 9. Refine AST Tools and Build Config 優化
**會話**: `3ab59064-4305-4ec2-a0d3-4ec372aee44c`
**時間估計**: 2-3 小時

**待完成項**:
- [/] Update `esbuild.config.js` externals（平台特定 externals 需要更動態的方法）
- [/] Stabilize `zedIntegration.ts` tool result processing（確保正確處理所有潛在 `ToolResult` 形狀）
- [/] Refactor `ast-edit.ts` for cross-platform support:
   - [ ] Replace `find` with `fast-glob` in `getWorkspaceFiles`
   - [ ] Support multiple extensions in `resolveImportPath`
- [ ] Verification and PR update

---

#### 10. MCP 實作比較
**會話**: `f54f70aa-8304-4e71-88c1-c2970ef637d1` (4 個未完成項)

**已完成項**:
- ✅ 探索兩個 repo 的文件結構
- ✅ 比較 `smart-tree` 配置
- ✅ 比較 MCP connection 和 client 實作
- ✅ 比較 extension loading logic

**待完成項**:
- [ ] Compare `loadExtensions` in `packages/cli/src/config/extension.ts` (Old vs New)
- [ ] Compare `ExtensionStorage` in `packages/cli/src/config/storage.ts`
- [ ] Identify the cause of the issue
- [ ] Report findings to the user

---

#### 11. Profile Loading Bug Fix
**會話**: `e5d945a7-e9f5-4d19-8785-f48e9c29963b` (1 個未完成項)

**待完成項**:
- [ ] Read `packages/cli/src/providers/aliases/chutes-ai.config`

**已完成**:
- [x] Check if `packages/cli/dist/index.js` exists
- [x] Search for "chutes" in the codebase
- [x] Verify `llxprt` command execution
- [x] Run `llxprt --profile-load chutes`
- [x] Answer user about capability
- [x] Run interactive mode test
- [x] Fix "Initializing..." stuck issue in `DefaultAppLayout.tsx`

---

#### 12. IME Ctrl+C, Deadlock & Terminal Leakage Fix
**會話**: `748703dc-f7d4-4b64-b0ac-a79c7a06d693` (多個未完成項)

---

### 🟢 低優先級任務

#### 13. Code Comment Reinforcement (CCR) 規則創建
**會話**: `7248c104-3e66-4f17-946a-472790e39773`

**待執行**:
- [ ] Finalize `.agent-rules.md` (AI-facing)
- [ ] Create `PROJECT_RECIPE.md` (Infrastructure/CI recommendations)
- [ ] Verify with comprehensive example

---

#### 14. Shoplift App Template 架構
**會話**: `7906414f-3dc1-4452-9b96-13cf2108257e` (13 個未完成項)
**狀態**: 仍在規劃階段

**已完成項**:
- ✅ 解釋 Monorepo 概念和優勢
- ✅ 調查現有 Shopify/Remix 模板和方法
- ✅ 評估是否可以使用現有解決方案
- ✅ 解釋 Polyrepo vs Monorepo 權衡
- ✅ 評測 llxprt Tool

**待完成項**:
- [ ] Analyze Project Structure (package.json, app/root.tsx, app/routes)
- [ ] Analyze `app/shopify.server.ts` and `app/db.server.ts` for backend coupling
- [ ] Design Template Architecture
- [ ] Create Implementation Plan

---

#### 15. 其他小任務
- `0a732cb1`, `cc881aa8`, `6910fce3`, `7a320a38`, `93f007cf`, `a0c75142`, `3a428465`, `7b2770fe`: 各種 UI 對齊和修復任務

---

## 待處理事項（技術債務）

### Hacks 與臨時解決方案

#### 1. Ink Layout Retrieval Mock
**位置**: `packages/cli/src/ui/utils/ink-utils.ts`

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

### 對比上次審查的變化 (2026-02-04)

**已完成的會話**:
- `a23b76fd` (Runtime Crash Debug) - 所有任務已完成 ✅
- `1121a3ee` (Debugging UI Instability) - 所有任務已完成 ✅
- 多個 UI 對齊和修復任務已完成

**新增會話**: 無新增 Antigravity 會話

**Git 變化**:
- 最新提交: `ci: update OpenCode model to glm-4.7-free`
- 新增功能: `showLineNumbers` for read_file/read_line_range

---

## 建議執行順序

**階段 A：臨界修復與核心優化（優先 - 本週）**
**時間**: 8-10 小時

1. 🔧 **修復虛擬化架構缺陷** (3-4 小時)
   - 扁平化 pending items in `DefaultAppLayout.tsx`
   - 修正渲染條件邏輯
   - 實施動態高度估算

2. 🔧 **完成 Issue #26 修復** (1-2 小時)
   - 調查 gemini-cli CTRL+C handling
   - 比較 implementations
   - Refine implementation
   - Verify fix

3. ✅ **驗證 ToolCall UI 組件** (30 分鐘)
   - 完成結構化的 review 編譯

4. 📋 **系統化 Memoization** (4-6 小時)
   - 達到 +30% 性能目標

**預期成果**: ✅ 穩定性修復 + ✅ 性能達 +30% 目標 + ✅ 對齊度 90-95%

---

**階段 B：代碼清理與架構債務（1-2 週內）**
**時間**: 4-6 小時

5. TODO Tab 修復 (30 分鐘)
6. 基礎設施負債清理 (2-3 小時)
7. 配置介面修補 (1 小時)
8. MCP 實作比較完成 (1 小時)

**預期成果**: ✅ 代碼品質提升 + ✅ 架構穩健性 + ✅ 跨平台問題解決

---

**階段 C：增強功能與測試（可選/未來）**
**時間**: 6-8 小時

9. 移植缺失的 UI 組件（DialogManager）
10. Provider Server Tools 統一
11. OpenAI Stateless Refactor
12. 統一 Tool ID 管理
13. 性能測試完善（3-4 小時）
14. 無障礙性測試（2-3 小時）
15. E2E 測試強化（確認方向後）

**預期成果**: ✅ 測試覆蓋率增強 + ✅ 性能達到目標

---

**階段 D：核心重構（長期）**
- 完成 AST-Grep 遷移
- 統一 OpenAI Provider 實作
- 創建 Code Comment Reinforcement 規則
- 設計並實施 Shopify App Template 架構

---

## 核心結論

**最緊急（本週處理）**:
1. **虛擬化架構缺陷** - `DefaultAppLayout.tsx` - DO NOT MERGE
2. **Issue #26 (Terminal Corruption)** - CTRL+C 退出問題需要最終修復
3. **安裝 eslint** - lint 命令無法執行 (已在環境中安裝)

**高優先級（2 週內）**:
4. **ToolCall UI 驗證** - 確保 build 和 lint 通過
5. **Configuration Interface** - 實作 `getCustomExcludes`
6. **Infrastructure Debt** - fast-glob, resolveImportPath, esbuild externals
7. **Systematic Memoization** - 達到 +30% 性能目標

**中優先級（1 個月內）**:
8. **OpenAI Provider Server Tools** - 實作缺失的功能 (Critical severity)
9. **YOLO Mode Bug Fix** - 修正並行工具執行 (High severity)

**低優先級（未來）**:
10. **AST-Grep 遷移** - 核心重構
11. **Code Comment Reinforcement** - 規則創建
12. **Shopify App Template** - 架構設計

---

**總結**:
- 專案整體進展良好，已實現關鍵架構（Tabs、Screen Reader、Fiber-Recorder base）
- 有 **15 個會話** 包含未完成任務，總計約 **41 項** 待辦事項（比上次減少 60+ 項）
- **1 個關鍵缺陷** 需要優先處理（虛擬化缺陷）
- **1 個 issue** 需要最終修復（Issue #26 Terminal Corruption）
- 數個 **技術債** 標記需要逐步清理（230+ 個 TODO/FIXME/HACK）
- 性能距離目標有 **20% 差距**，可透過 memoization 實現
- **601 個測試文件**，但有多個測試被跳過
- **lint 和 build** 都在正常運行

**下次審查建議**: 完成階段 A 後重新評估，特別是虛擬化缺陷的修復情況以及 Issue #26 的最終修復。
