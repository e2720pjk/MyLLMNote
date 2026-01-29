# Phase 3: TabBar Integration & Optimization Plan

## Goal
Port the TabBar functionality from `llxprt-code-3` to `llxprt-code`, integrating it with our optimized `Static/Virtual` rendering architecture to resolve performance and display issues found in the reference implementation.

## Architecture Analysis

### Current vs. Target Architecture

| Feature | Reference (llxprt-code-3) | Target (llxprt-code) | Benefit |
|---------|---------------------------|----------------------|---------|
| **State Management** | Separate `TabContext` | Integrated `UIStateContext` | Single source of truth, easier debugging |
| **Rendering Strategy** | Layout-level switching (`TabbedAppLayout`) | Component-level switching (`MainContent`) | Preserves `Static` history, prevents flickering |
| **History Rendering** | Re-mounts on tab switch | Persists in DOM (hidden) or conditional render | Smoother transitions, better performance |
| **Accessibility** | Basic | Integrated `ScreenReaderAppLayout` | Full SR support for tabs |

## Implementation Steps

### Step 1: UI State Extension
**File**: `packages/cli/src/ui/contexts/UIStateContext.tsx`

Add tab-related state to the global UI state:
```typescript
export type TabId = 'chat' | 'debug' | 'todo' | 'system';

interface UIState {
  // ... existing state
  activeTab: TabId;
  tabs: Array<{
    id: TabId;
    label: string;
    hasUpdates?: boolean;
  }>;
}

interface UIActions {
  // ... existing actions
  setActiveTab: (tabId: TabId) => void;
}
```

### Step 2: Component Porting & Adaptation
**Files**:
- `packages/cli/src/ui/components/TabBar.tsx` (New)
- `packages/cli/src/ui/components/tabs/*` (New)

**Adaptations**:
- **TabBar**: Port from reference, ensure it uses `ink` components correctly.
- **Tabs**: Create wrapper components for `Chat`, `Debug`, `Todo`, `System`.
  - `ChatTab`: Will wrap our existing `MainContent` logic (or `MainContent` becomes the tab manager).
  - *Decision*: `MainContent` should remain the main orchestrator. It will render `TabBar` at the top (below Header) and then conditionally render the content.

### Step 3: MainContent Refactoring
**File**: `packages/cli/src/ui/components/MainContent.tsx`

Refactor to support tabs while maintaining `Static` optimization:

```typescript
// Conceptual structure
export const MainContent = () => {
  const { activeTab } = useUIState();

  return (
    <Box flexDirection="column">
      <AppHeader />
      <TabBar />
      
      {/* Content Area */}
      {activeTab === 'chat' && (
        // Existing Chat Logic (Static/Virtual)
        <ChatView /> 
      )}
      
      {activeTab === 'debug' && <DebugView />}
      {activeTab === 'todo' && <TodoView />}
      {activeTab === 'system' && <SystemView />}
    </Box>
  );
};
```

**Crucial Optimization**:
For `ChatView` (which uses `Static`), we must ensure that switching tabs doesn't destroy the `Static` output if possible, or we accept that `Static` is for the *log* and tabs might be an overlay.
*Refinement*: In `gemini-cli` (and our target), `Static` is usually for the *chat log*. If we switch to 'Debug', the chat log shouldn't disappear from the terminal history.
*Strategy*:
- **Chat Tab**: Renders `Static` history + Pending items.
- **Other Tabs**: Render as a "fullscreen" overlay or replace the pending area?
- *Reference Check*: `llxprt-code-3` replaces the whole content.
- *Our Approach*: We will conditionally render the *active view*. For `Static` mode compatibility, when leaving 'Chat', we might need to "freeze" the history or just hide the pending area.
- *Simplest Robust Approach*: Conditional rendering. When returning to 'Chat', `Static` might re-print. To avoid this, we can use `display: none` style logic (Box `display="none"`) if Ink supports it (it handles it by not rendering children).
- *Better Approach*: Keep `UIState` persistent. When `Chat` mounts again, it restores from `history`.

### Step 4: Key Bindings
**File**: `packages/cli/src/ui/keyMatchers.ts`
Add key bindings for tab switching (Ctrl+1, Ctrl+2, etc., Ctrl+Tab).

### Step 5: Integration
**File**: `packages/cli/src/ui/AppContainer.tsx`
Ensure `MainContent` receives necessary props/context.

## Work Breakdown

1.  **State Management Setup** (UIStateContext)
2.  **TabBar Component Creation** (Porting)
3.  **Tab Views Creation** (Placeholders/Basic implementations)
4.  **MainContent Integration** (The core logic)
5.  **Key Binding Support**
6.  **Verification** (Flicker check, Performance check)

## Risk Assessment
- **Flickering**: Switching tabs might cause the entire terminal to clear/redraw.
  - *Mitigation*: Use `useFlickerDetector` and `historyRemountKey`.
- **State Loss**: Input buffer or scroll position might be lost on tab switch.
  - *Mitigation*: Store transient state in `UIStateContext` or use `display: none` equivalent (rendering null but keeping state).

## Next Step
Start with **Step 1: UI State Extension**.
