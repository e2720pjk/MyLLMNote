# Implementation Plan: .gitignore Support Refinement & README Simplification

This plan aims to refine the recently implemented `.gitignore` support by aligning the code style with the upstream codebase (restoring single quotes and proper spacing) and simplifying the documentation additions in `README.md` as requested.

## User Review Required

> [!IMPORTANT]
> I will be reverting many "formatting-only" changes (e.g., double quotes to single quotes) to match the existing codebase style. This will significantly reduce the diff size and make the actual logic changes clearer.

## Proposed Changes

### [Component] Core Logic & Backend

#### [MODIFY] [repo_analyzer.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki-1/codewiki/src/be/dependency_analyzer/analysis/repo_analyzer.py)
*   Restore single quotes and original import formatting.
*   Keep the `.gitignore` loading and matching logic.

#### [MODIFY] [analysis_service.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki-1/codewiki/src/be/dependency_analyzer/analysis/analysis_service.py)
*   Restore single quotes and original spacing.
*   Keep the parameter passing logic for `respect_gitignore`.

#### [MODIFY] [config.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki-1/codewiki/src/config.py)
*   Restore single quotes and original spacing.
*   Keep the `respect_gitignore` field and `from_cli` update.

---

### [Component] CLI Layer

#### [MODIFY] [config.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki-1/codewiki/cli/models/config.py)
*   Align with upstream formatting.
*   Ensure `respect_gitignore` is handled correctly in `to_dict`, `from_dict`, and `to_backend_config`.

#### [MODIFY] [config_manager.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki-1/codewiki/cli/config_manager.py)
*   Ensure the `save` method handles `respect_gitignore`.

#### [MODIFY] [config.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki-1/codewiki/cli/commands/config.py)
*   Refine the CLI options and display messages to be concise.

#### [MODIFY] [generate.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki-1/codewiki/cli/commands/generate.py)
*   Add `--respect-gitignore` option with concise help text.

---

### [Component] Documentation

#### [MODIFY] [README.md](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki-1/README.md)
*   Simplify the `.gitignore` section.
*   Add `--respect-gitignore` to the main option table.
*   Add a one-line example to the basic examples.
*   Provide a one-line prompt for execution order.

---

## Verification Plan

### Automated Tests
*   Run existing tests for RepoAnalyzer:
    ```bash
    pytest tests/test_repo_analyzer.py
    ```

### Manual Verification
1.  Check CLI help output:
    ```bash
    codewiki generate --help
    codewiki config set --help
    ```
2.  Verify config display:
    ```bash
    codewiki config show
    ```
3.  Test filtering (if possible in this environment):
    Create a dummy repo with `.gitignore` and run `codewiki generate --respect-gitignore --dry-run` (if dry-run exists) or just check if it correctly ignores files.
