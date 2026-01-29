# Merge and Integration Implementation Plan

This plan outlines the steps to resolve merge conflicts by adopting upstream configuration naming and structures while preserving local performance enhancements (LLM caching, performance tracking, Joern integration).

## Proposed Changes

### Core Configuration Layer

#### [MODIFY] [config.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki/codewiki/src/config.py)
- Unified naming: `max_token_per_module`, `max_token_per_leaf_module`.
- Added `max_tokens` (upstream).
- Retained `agent_instructions` logic (upstream).
- Integrated `AnalysisOptions` fields directly into `Config` or kept them appropriately mapped.
- Added performance fields: `enable_llm_cache`, `cache_size`, `agent_retries`, `use_joern`, `respect_gitignore`.

#### [MODIFY] [config.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki/codewiki/cli/models/config.py)
- Adopted upstream naming.
- Flat structure: `Configuration` now directly contains fields previously in `AnalysisOptions`.
- Preserved `AgentInstructions` integration.
- Updated `to_backend_config` to map new flat structure correctly.

#### [MODIFY] [config_manager.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki/codewiki/cli/config_manager.py)
- Updated `save` method signature to match new `Configuration` fields.
- Updated validation logic to handle new mandatory/optional fields.

### Subsequent Phases (To be detailed after Phase 1)
- Phase 2: CLI Commands (`config.py`, `generate.py`)
- Phase 3: Backend Logic (`llm_services.py`, `agent_orchestrator.py`, etc.)
- Phase 4: Data Layer (`ast_parser.py`, `doc_generator.py`)

## Verification Plan

### Automated Tests
- `pytest tests/test_config.py` (if exists)
- CLI verification: `codewiki config list`, `codewiki config set ...`

### Manual Verification
- Run documentation generation on a sample repo to ensure all config values are respected.
