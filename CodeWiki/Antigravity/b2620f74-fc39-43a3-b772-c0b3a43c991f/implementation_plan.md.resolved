# Rebase Conflict Resolution Plan

Resolve conflicts between `opencode-dev` (HEAD) and `hybrid-joern` (ff03648) branches.

## Proposed Changes

### Phase 1: Core Architecture

#### [MODIFY] [job.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki-2/codewiki/cli/models/job.py)
- Merge `GenerationOptions` docstring.
- Remove `use_joern` from `GenerationOptions` (it moves to `AnalysisOptions`).
- In `from_dict`, handle `analysis_options` if present.

#### [MODIFY] [config.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki-2/codewiki/src/config.py)
- Add `AnalysisOptions` import.
- Use `analysis_options` in `Config` class.
- Update `from_args` and `from_cli` to handle `use_joern` and convert to `AnalysisOptions`.

#### [MODIFY] [generate.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki-2/codewiki/cli/commands/generate.py)
- Keep all CLI flags including `--use-joern`.
- Update `generate_command` signature.
- Update docstring with examples.
- Correctly initialize `GenerationOptions` and `AnalysisOptions`.
- Pass `analysis_options` to `CLIDocumentationGenerator`.

#### [MODIFY] [doc_generator.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki-2/codewiki/cli/adapters/doc_generator.py)
- Update `__init__` parameter order.
- Remove unused `start_time`.
- Pass `analysis_options` when creating `BackendConfig`.

---

### Phase 2: Code Improvements

#### [MODIFY] [utils.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki-2/codewiki/src/utils.py)
- Update `save_json` to support `set` serialization.

#### [MODIFY] [cluster_modules.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki-2/codewiki/src/be/cluster_modules.py)
- Use standard imports and type hints.
- Merge clustering logic improvements and safety checks.

#### [MODIFY] [str_replace_editor.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki-2/codewiki/src/be/agent_tools/str_replace_editor.py)
- Use Pydantic `BeforeValidator` and `TypeAdapter`.
- Fix duplicate `tool()` calls.

#### [MODIFY] [analysis_service.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki-2/codewiki/src/be/dependency_analyzer/analysis/analysis_service.py)
- Merge file selection logic.

#### [MODIFY] [core.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki-2/codewiki/src/be/dependency_analyzer/models/core.py)
- Merge Joern-specific models (`CFGNode`, `CFGEdge`).
- Update `Node` and `Repository` models.

#### [MODIFY] [dependency_graphs_builder.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki-2/codewiki/src/be/dependency_analyzer/dependency_graphs_builder.py)
- Use `AnalyzerFactory` for initialization.
- Support `HybridAnalysisService` interface.

#### [MODIFY] [php.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki-2/codewiki/src/be/dependency_analyzer/analyzers/php.py)
- Use complete PHP primitives list.

## Verification Plan

### Automated Tests
- `python -m pytest test/`
- `bin/codewiki generate --help`

### Manual Verification
- Test `codewiki generate --use-joern` with a sample repo.
