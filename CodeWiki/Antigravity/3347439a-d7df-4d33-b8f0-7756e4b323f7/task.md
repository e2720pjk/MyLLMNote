# Merge and Integration Task

## Phase 1: Core Configuration Layer [/]
- [ ] Update `codewiki/src/config.py` [/]
    - [ ] Adopt upstream naming: `max_token_per_module`, `max_token_per_leaf_module`
    - [ ] Add `max_tokens` field
    - [ ] Keep `agent_instructions` and its properties/methods
    - [ ] Integrate local performance fields: `enable_llm_cache`, `cache_size`, `agent_retries`, `use_joern`, etc.
- [ ] Update `codewiki/cli/models/config.py` [ ]
    - [ ] Adopt upstream naming
    - [ ] Integrate `AnalysisOptions` fields into `Configuration`
    - [ ] Keep `AgentInstructions` class and integration
- [ ] Update `codewiki/cli/config_manager.py` [ ]
    - [ ] Adjust parameter naming in `save`
    - [ ] Update configuration validation and conversion logic

## Phase 2: CLI Command Layer [ ]
- [ ] Update `codewiki/cli/commands/config.py` [ ]
- [ ] Update `codewiki/cli/commands/generate.py` [ ]

## Phase 3: Backend Business Layer [ ]
- [ ] Update `codewiki/src/be/agent_orchestrator.py` [ ]
- [ ] Update `codewiki/src/be/llm_services.py` [ ]
- [ ] Update `codewiki/src/be/prompt_template.py` [ ]
- [ ] Update `codewiki/src/be/cluster_modules.py` [ ]
- [ ] Update `codewiki/src/be/agent_tools/deps.py` [ ]
- [ ] Update `codewiki/src/be/agent_tools/generate_sub_module_documentations.py` [ ]
- [ ] Update `codewiki/src/be/agent_tools/str_replace_editor.py` [ ]

## Phase 4: Dependency Analysis Layer [ ]
- [ ] Update `codewiki/src/be/dependency_analyzer/ast_parser.py` [ ]
- [ ] Update `codewiki/src/be/dependency_analyzer/dependency_graphs_builder.py` [ ]
- [ ] Update `codewiki/cli/adapters/doc_generator.py` [ ]

## Verification [ ]
- [ ] Run linting and tests
- [ ] Verify CLI configuration commands
- [ ] Verify documentation generation with new config structure
