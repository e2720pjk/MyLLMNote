# ToolCall UI Comparison and Alignment Plan

## Goal
Compare the ToolCall UI implementation in `llxprt-code-3` with `gemini-cli` to identify discrepancies and ensure feature parity and visual consistency.

## Analysis Steps

1.  **Component Comparison**:
    - Compare `ToolGroupMessage.tsx` (Container for multiple tool calls).
    - Compare `ToolMessage.tsx` (Individual tool call display).
    - Compare `ToolConfirmationMessage.tsx` (User confirmation UI).
    - Investigate missing components in `llxprt-code-3`: `ToolResultDisplay.tsx`, `ShellToolMessage.tsx`, `ToolShared.tsx`.

2.  **Visual & Functional Analysis**:
    - Check for layout differences (padding, margins, borders).
    - Check for color usage and theming.
    - Check for interaction handling (collapsing/expanding).
    - Check for content rendering (markdown support in tool results).

## Findings

1.  **Structure & Styling**:
    -   `gemini-cli` uses a **Sticky Header** design (`StickyHeader.tsx`) for tool calls, allowing headers to remain visible. `llxprt-code-3` uses a standard static layout.
    -   `gemini-cli` separates `ShellToolMessage` into its own component with interactive focus logic (`useMouseClick`, `ShellInputPrompt`). `llxprt-code-3` handles shell tools within `ToolMessage` with less interactivity.
    -   `gemini-cli` uses `ToolResultDisplay` for cleaner separation of concerns. `llxprt-code-3` inlines this logic.

2.  **Feature Differences**:
    -   `llxprt-code-3` has integrated **Todo Panel** logic (`deriveTodoCount`, `isTodoReadTool`, etc.) in `ToolGroupMessage`, which is absent in `gemini-cli`.
    -   `gemini-cli` supports **Output File** redirection messages, which `llxprt-code-3` ignores.

## Recommendations

To align with `gemini-cli`'s superior UI while retaining `llxprt-code-3`'s features:
1.  **Port `StickyHeader`**: Adopt the sticky header pattern for tool calls.
2.  **Extract `ToolResultDisplay`**: Refactor `llxprt-code-3` to use a dedicated component for result rendering.
3.  **Adopt `ShellToolMessage`**: Port the interactive shell tool message, integrating it with `llxprt-code-3`'s existing shell logic.
4.  **Preserve Todo Logic**: Ensure the Todo filtering and formatting logic in `ToolGroupMessage` is maintained during refactoring.

## Next Steps
1.  Report findings to user.
2.  Upon approval, begin porting `StickyHeader` and refactoring `ToolMessage`.
