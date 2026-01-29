# Walkthrough: Tool Integration in `llxprt-code-2`

I have successfully integrated `CodeSearchTool` and `WebFetchTool` from `opencode` into `llxprt-code-2`.

## Changes

### New Tools
- **[CodeSearchTool](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/core/src/tools/codesearch.ts)**: Enables searching for code snippets and documentation via `mcp.exa.ai`.
- **[WebFetchTool](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/core/src/tools/webfetch.ts)**: Enables fetching and converting web content (HTML to Markdown/Text) directly using `node-fetch`, `turndown`, and `cheerio`. Registered as `DirectWebFetchTool` to coexist with the existing Gemini-based `WebFetchTool`.

### Configuration
- **[config.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/core/src/config/config.ts)**: Registered both tools in the `ToolRegistry`.
- **[tool-defaults.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/core/src/prompt-config/defaults/tool-defaults.ts)**: Added `TOOL_DEFAULTS` entries for `codesearch.md` and `webfetch.md` to ensure proper prompt configuration.

### Documentation
- **[codesearch.md](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/core/src/prompt-config/defaults/tools/codesearch.md)**: Added documentation for the Code Search tool.
- **[webfetch.md](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/core/src/prompt-config/defaults/tools/webfetch.md)**: Added documentation for the Web Fetch tool.

### Tabby-edit Porting
- **[tabby-edit.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/core/src/tools/tabby-edit.ts)**: Ported the `TabbyEditTool` and `TabbyReadFileTool`.
- **[tabby-edit.test.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/core/src/tools/tabby-edit.test.ts)**: Adapted unit tests to use `vitest`.
- **Output Fix**: Modified `TabbyEditTool` to return a user-friendly `FileDiff` object in preview mode instead of raw JSON, resolving truncation and readability issues.

### Sanitization
- Verified that all "opencode" references have been removed from the ported code and documentation to ensure a native tool design.

### Verification
I implemented comprehensive unit tests for both tools to ensure reliability and correct error handling.

- **[codesearch.test.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/core/src/tools/codesearch.test.ts)**: Verified API interaction, parameter validation, and error handling.
- **[webfetch.test.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/core/src/tools/webfetch.test.ts)**: Verified URL fetching, content conversion (HTML/Markdown), and error handling.

## Validation Results
All unit tests passed successfully.

```bash
✓ packages/core/src/tools/codesearch.test.ts (5 tests)
✓ packages/core/src/tools/webfetch.test.ts (5 tests)
```
