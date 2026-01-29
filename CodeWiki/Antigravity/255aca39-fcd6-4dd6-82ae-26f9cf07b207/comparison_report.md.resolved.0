# Tool Comparison Report: `opencode` vs `llxprt-code-2`

This report analyzes and compares the tool implementations found in `opencode/packages/opencode/src/tool` and `llxprt-code-2/packages/core/src/tools`.

## Executive Summary

*   **`opencode`** adopts a **functional, lightweight architecture**. Tools are defined using a `Tool.define` helper, focusing on simplicity and direct execution. It features advanced **AST-based shell security** (using Tree-sitter) and **remote AI code search** capabilities.
*   **`llxprt-code-2`** employs a **class-based, object-oriented architecture**. Tools extend `BaseDeclarativeTool`, emphasizing structure, type safety, and integration with a larger ecosystem (e.g., `MessageBus`, `Config`). It prioritizes **LLM context management** (token limiting, output filtering) and **robust local file operations**.

## Detailed Comparison

### 1. Architecture & Definition

| Feature | `opencode` | `llxprt-code-2` |
| :--- | :--- | :--- |
| **Paradigm** | Functional (`Tool.define`) | Object-Oriented (`class X extends BaseDeclarativeTool`) |
| **Discovery** | Directory scanning (`tool/*.{js,ts}`) | Registry with dynamic discovery & MCP support |
| **Metadata** | Zod schemas for parameters | JSON Schema (via Zod or direct object) |
| **Context** | `ctx` object (sessionID, abort signal) | `ToolInvocation` class, `Config`, `MessageBus` |

**Analysis:**
*   `opencode` is easier to extend for simple scripts.
*   `llxprt-code-2` provides a more rigorous framework suitable for complex applications with lifecycle management.

### 2. Shell / Bash Tool

| Feature | `opencode` (`bash.ts`) | `llxprt-code-2` (`shell.ts`) |
| :--- | :--- | :--- |
| **Execution** | `spawn` (Bun/Node) | `child_process.spawn` |
| **Security** | **High**: Uses `tree-sitter-bash` to parse commands and validate paths/commands against permissions. | **Medium**: Regex/heuristic checks (`isCommandAllowed`), warns on command substitution. |
| **Output Handling** | Captures stdout/stderr, truncates if too long. | **Advanced**: Token-based limiting (`limitOutputTokens`), output filtering (`grep`, `head`, `tail`). |
| **Permissions** | Granular (`allow`, `deny`, `ask`) based on AST analysis. | Config-based allowlist/denylist. |

**Analysis:**
*   `opencode` wins on **security** by understanding the command structure.
*   `llxprt-code-2` wins on **efficiency** by managing the LLM's context window through intelligent output filtering.

### 3. Editing Tool

| Feature | `opencode` (`edit.ts`) | `llxprt-code-2` (`edit.ts`, `smart-edit.ts`) |
| :--- | :--- | :--- |
| **Strategy** | **Multi-Strategy Replacer**: Tries multiple matching algorithms (exact, trimmed, whitespace-normalized, context-aware) to locate `old_string`. | **Smart Replacement**: Uses `applyReplacement` (likely similar fuzzy/smart matching) and validates paths. |
| **Parameters** | `file`, `old_string`, `new_string` | `file_path`, `instruction`, `old_string`, `new_string` |
| **Path Handling** | Basic resolution. | **Robust**: Auto-corrects relative paths, searches workspace for ambiguous paths. |

**Analysis:**
*   `opencode`'s "Replacer" chain is very resilient to minor LLM formatting errors.
*   `llxprt-code-2` emphasizes **user intent** (`instruction` param) and **path resolution** usability.

### 4. Search Tools

| Feature | `opencode` (`codesearch.ts`, `grep.ts`) | `llxprt-code-2` (`ripGrep.ts`) |
| :--- | :--- | :--- |
| **Local Search** | `grep` wrapper around `rg`. Custom output parsing. | `RipGrepTool` wrapper around `rg`. Structured `GrepMatch` results. |
| **Remote Search** | **Yes**: `CodeSearchTool` uses `mcp.exa.ai` for semantic code search. | **No**: Primarily local file search. |
| **Filtering** | Basic `include` pattern. | `include` glob, default excludes (`node_modules`, `.git`). |

**Analysis:**
*   `opencode` offers **semantic search** capabilities via external APIs, which is powerful for "how-to" queries.
*   `llxprt-code-2` provides a solid, standard `ripgrep` integration for codebase navigation.

### 5. Task & Todo Management

| Feature | `opencode` (`task.ts`, `todo.ts`) | `llxprt-code-2` (`task.ts`, `todo-store.ts`) |
| :--- | :--- | :--- |
| **Subagents** | Direct `Agent.get` and `Session.create`. | **Orchestrated**: Uses `SubagentOrchestrator` to manage subagent lifecycles and isolation. |
| **Todo Storage** | Simple in-memory or session-based. | **Persistent**: JSON files in `~/.llxprt/todos`. |
| **Task Tool** | Simple delegation. | Complex delegation with `goal_prompt`, `behaviour_prompts`, `tool_whitelist`, and `output_spec`. |

**Analysis:**
*   `llxprt-code-2` has a much more sophisticated **agent orchestration** system, allowing for constrained and structured subagent execution.

## Conclusion

*   **`opencode`** is ideal for a **lightweight, secure, and AI-augmented** CLI tool where quick scripting and security (AST parsing) are paramount.
*   **`llxprt-code-2`** is better suited for a **robust, production-grade agentic IDE** or platform, with strong focus on context management, subagent orchestration, and structured tool definitions.
