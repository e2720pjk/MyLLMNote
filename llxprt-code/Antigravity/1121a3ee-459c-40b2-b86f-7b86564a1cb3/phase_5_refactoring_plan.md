# Phase 5: Simplified 4-Tab Structure Refactoring Plan

## 🎯 Core Objective
Refactor the UI to a simplified 4-Tab structure (`chat`, `debug`, `todo`, `system`), removing legacy overlay components (`DetailedMessagesDisplay`) and integrating their functionality into the dedicated tabs. This aligns with the "Simplified 4-Tab Structure" proposal.

## 📊 Feature Consolidation Strategy

| Tab | Primary Function | New Integration |
|-----|------------------|-----------------|
| **chat** | Chat Interface | Maintain existing; **No console info**; Header + Chat only |
| **debug** | Logs & Debug Info | **Integrate `SHOW_ERROR_DETAILS`**; Add MCP Status; **Full Console + Header**; Same Static strategy as Main |
| **todo** | Task Management | Show tool execution progress; pending task states |
| **system** | System Info | Add MCP Server Configuration & Statistics |

## 🏗️ Architectural Decisions: Rendering Strategy
1.  **MainChat**: strictly Header + Chat. **NO console logs**.
2.  **DebugTab**: Full Console (including `debug` level) + Header + MCP Status.
    - **Strategy**: Must align with MainChat's `Static` strategy.
    - **Implementation**: Needs access to the *same* `AppHeader` and shared rendering logic (e.g., `useStaticHistory` pattern) to prevent flicker/loss on switch.
3.  **Redraw Policy**:
    - Tab switching should behave like **Resize Events**: preserve `Static` history.
    - Prevent re-rendering of static items when switching tabs. Note: `Static` items in `Ink` are immutable once rendered, so "switching back" usually means re-rendering *history*. true alignment means using the same `staticKey` or preservation mechanism.

## 🔧 Implementation Plan

### Stage 1: Basic Cleanup & Event Management
**Goal**: Resolve key binding conflicts and unify navigation.
1.  **Fix TabBar Hint**: Update copy to `(Ctrl+O to switch)`.
2.  **Resolve Key Conflicts**:
    - repurpose `Ctrl+O` from `SHOW_ERROR_DETAILS` to `TAB_CYCLE`.
    - ensuring `TAB_CYCLE` is the sole owner of `Ctrl+O`.
3.  **Unified Event Management**:
    - Move `useKeypress` for tab cycling from `TabBar` to `AppContainer` (or a high-level manager) to ensure it works globally.

### Stage 2: State Migration & DebugTab Enhancement
**Goal**: Complete replacement for the legacy "Error Details" overlay & Align Rendering Strategy.
1.  **Rendering Alignment**:
    - **Add Header**: Integrate `AppHeader` into `DebugTab` (inside `Static` wrapper).
    - **Remove Filter**: DELETE `msg.type !== 'debug'` check. Show ALL messages.
    - **Static Logic**: Extract Static rendering logic (likely from `MainContent`) to be reusable or ensure `DebugTab` uses equivalent `Static` structure to maintain history visual consistency.
2.  **State Migration**:
    - Ensure `UIState` exposes all need header data (version, branch, etc.).
3.  **Migrate Functionality**:
    - **Align Style**: Adopt `MainChat`'s visual style (clean list), deprecating the bordered overlay style of `DetailedMessagesDisplay`.
    - **Retain Formatting**: Keep message coloring/icons for readability but formatted as list items.
4.  **MCP Status**: Add MCP Server Status section.

### Stage 3: MCP & System Integration & Real-time Updates
**Goal**: Surface dynamic MCP information.
1.  **System Tab**: Add "MCP Statistics" section.
2.  **Real-time Updates**:
    - Ensure `UIState` updates `mcpStatus` or `errorCount` trigger re-renders in `TabBar` indicators.
    - Add listener for MCP connection events if not present.

### Stage 4: Tab Status Indicators
**Goal**: Visual cues for tabs requiring attention.
1.  **Logic**:
    - `debug`: Active if `errorCount > 0`.
    - `system`: Active if MCP issues or system warnings exist.
    - `todo`: Active if pending tasks exist.
2.  **Implementation**: Update `TabBar` to render these indicators (e.g., `*` or color change).

### Stage 5: Code Cleanup
**Goal**: Remove obsolete code.
1.  **Delete**: `packages/cli/src/ui/components/DetailedMessagesDisplay.tsx`.
2.  **Remove**: `SHOW_ERROR_DETAILS` command and related state (`showErrorDetails`) from `AppContainer`.
3.  **Clean**: Remove unused imports and types.

## ⚠️ Risk Assessment
- **Debug Info Loss**: Critical to ensure `DebugTab` captures ALL info that `DetailedMessagesDisplay` did before deleting the latter.
- **User Habit**: Key binding change for `Ctrl+O` (from "Toggle Logs" to "Cycle Tabs") needs clear UI hint.

