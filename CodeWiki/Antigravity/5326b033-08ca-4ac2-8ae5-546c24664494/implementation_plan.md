# Architecture Refinement for Joern-Driven Analysis

The initial integration of Joern was an "additive" enhance to the existing AST system. However, as the user noted, the true power of Joern lies in accurate graph analysis, which allows us to move away from hardcoded limits and heuristic clustering.

## Core Principle: Progressive Enhancement
The system must operate in two distinct modes:
1.  **Legacy Mode (AST-Only)**: Preserves original behavior, limits, and heuristics. Used when Joern is disabled or unavailable.
2.  **Enhanced Mode (Joern-Driven)**: Unlocks dynamic limits and graph-based clustering.

## Goals

1.  **Remove Hard Limits (Conditional)**: Replace `max_files=100` with dynamic graph traversal *only when Joern is available*.
2.  **Joern-Driven Clustering**: Use Joern's Call Graph for community detection instead of relying solely on LLM intuition.
3.  **Dynamic Context**: Feed LLMs with graph-enriched context.

## Proposed Architecture Changes

### 1. Unified Graph Construction (Joern-First)
*   **Logic Change**: In `AnalyzerFactory`, check for Joern availability.
*   **Fallback**: If Joern is unavailable, instantiate the legacy `AnalysisService` which respects `max_files` limits.

### 2. Graph-Based Module Clustering
*   **New Approach (Enhanced Mode)**:
    1.  **Extract Graph**: Get nodes and edges from Joern.
    2.  **Community Detection**: Use `networkx` to detect communities.
    3.  **LLM Refinement**: Ask LLM to name/describe these pre-calculated clusters.
*   **Legacy Fallback**: If `use_joern` is False, use the existing `cluster_modules` logic which:
    1.  Selects files based on heuristics.
    2.  Asks LLM to group them based on file paths/content.
    
### 3. Dynamic Analysis Parameters
*   **Enhanced Mode**:
    *   No hard file limit.
    *   Filter based on graph centrality (connected components).
*   **Legacy Mode**:
    *   Strict `max_files` limit (default 100) to prevent context overflow.

## Detailed Implementation Steps

### Phase 1: Uncapping & Graph Extraction (Immediate)
#### [MODIFY] [dependency_graphs_builder.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki/codewiki/src/be/dependency_analyzer/dependency_graphs_builder.py)
*   [ ] Modify logic: If `use_joern==True`, bypass `max_files` check. Else, enforce it.
*   [ ] Build NetworkX graph from Joern output for later steps.

### Phase 2: Graph-Based Clustering (New Feature)
#### [NEW] [graph_clustering.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki/codewiki/src/be/dependency_analyzer/graph_clustering.py)
*   Implement `cluster_graph(nodes, edges) -> module_tree`.
*   Use `networkx` for community detection.

#### [MODIFY] [cluster_modules.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki/codewiki/src/be/cluster_modules.py)
*   Add branch: 
    *   `if config.use_joern and graph_data_available: return graph_clustering_strategy(...)`
    *   `else: return legacy_llm_clustering(...)`

### Phase 3: Enriched Documentation
#### [MODIFY] [documentation_generator.py](file:///Users/caishanghong/Shopify/cli-tool/CodeWiki/codewiki/src/be/documentation_generator.py)
*   Improve context prompt with Joern data (callers, callees, data flow) if available.

## Verification
*   **Metric**: `metadata.json` should show `total_components` ~= Total Sources (with Joern).
*   **Compatibility Check**: Run with `--use-joern=False` and verify `max_files=100` and original behavior persists.
