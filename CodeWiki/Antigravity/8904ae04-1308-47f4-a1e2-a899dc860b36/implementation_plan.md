# Fix Reported Issues Plan

## User Review Required

> [!IMPORTANT]
> I am implementing two bug fixes reported during the Joern integration work:
> 1. `str_replace_editor` parameter validation error (view_range as string).
> 2. `TreeSitterTSAnalyzer` clustering warning due to ID mismatch.

## Proposed Changes

### Agent Tools

#### [MODIFY] [str_replace_editor.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki/codewiki/src/be/agent_tools/str_replace_editor.py)
- Support `view_range` provided as a string (e.g., `"[1, 50]"`) by the LLM.
- Use Pydantic `BeforeValidator` to parse string to list of integers.

### Clustering Logic

#### [MODIFY] [cluster_modules.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki/codewiki/src/be/cluster_modules.py) [NEW]
- Implement short-name to full-ID fuzzy matching in `format_potential_core_components`.
- This ensures that if the LLM returns short class names instead of full component IDs, the clustering logic can still resolve them.

## Verification Plan

### Automated Tests
- Run `codewiki generate` on a repo with TypeScript files to verify analyzer registration.
- Verify `str_replace_editor` doesn't throw validation errors when `view_range` is a string.
