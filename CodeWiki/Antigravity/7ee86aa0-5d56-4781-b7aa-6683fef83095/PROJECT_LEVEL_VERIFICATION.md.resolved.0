# Project-Level Verification: Macro-Graph Isomorphism

To verify a "Whole Project" (e.g., Template Generation), we cannot just check one file. We must check the **Architecture**.

The solution is **Graph Isomorphism**. We treat the Project as a Graph where `Nodes = Files` and `Edges = Imports`.

---

## 1. The Verification Hierarchy

| Level | Scope | Method | Tool |
| :--- | :--- | :--- | :--- |
| **L1** | **Directory Structure** | File System Tree Match | `tree -J` comparison |
| **L2** | **File Dependencies** | Import Graph Isomorphism | `nx.is_isomorphic` |
| **L3** | **Internal Logic** | Function Spec Match | `cw-toolkit verify-skeleton` (batch) |

---

## 2. The L2 Algorithm: "Overlay Verification"

When you create a template, you rename things (e.g., `ShopifyApp` -> `{{AppName}}`). Exact text matching fails.
We use **Topological Matching**.

### Step 1: Generate Reference Graph (The "Skeleton")
We analyze the *Original Project* to build the `reference_project_graph.json`.
```json
{
  "nodes": [
    {"id": "A", "path": "src/routes/home.tsx", "type": "ROUTE"},
    {"id": "B", "path": "src/components/Provider.tsx", "type": "COMPONENT"}
  ],
  "edges": [
    {"source": "A", "target": "B", "type": "IMPORTS"}
  ]
}
```

### Step 2: Generate Target Graph
We analyze the *Generated Project* (even if it's broken).
```json
{
  "nodes": [
    {"id": "X", "path": "app/routes/home.tsx", "type": "ROUTE"}, # Path might vary slightly
    {"id": "Y", "path": "app/components/Provider.tsx", "type": "COMPONENT"}
  ],
  "edges": [
    {"source": "X", "target": "Y", "type": "IMPORTS"}
  ]
}
```

### Step 3: The Verification (Isomorphism)
We ask: **"Does the Target Graph look like the Reference Graph?"**
*   **Rule 1:** For every Node in Reference, there must be a corresponding Node in Target (mapped by fuzzy path matching).
*   **Rule 2:** If `Ref_A` imports `Ref_B`, then `Target_A` *must* import `Target_B`.

**Failure Case:**
*   LLM generates `home.tsx` and `Provider.tsx`.
*   But LLM *forgets* to add `import { Provider }` in `home.tsx`.
*   **Graph Check:** The edge `A->B` exists in Reference but `X->Y` is missing in Target.
*   **Result:** **FAIL: Broken Architecture.**

---

## 3. The Tool Implementation (`codewiki-verify-project`)

This is a wrapper around `cw-toolkit`.

```python
def verify_project(ref_dir, target_dir):
    # 1. Build Graphs
    ref_graph = build_project_graph(ref_dir)
    target_graph = build_project_graph(target_dir)
    
    # 2. Map Nodes (Heuristic: Path Suffix)
    node_map = match_nodes(ref_graph, target_graph)
    
    # 3. Check Edges
    errors = []
    for u, v in ref_graph.edges():
        target_u = node_map.get(u)
        target_v = node_map.get(v)
        
        if not target_u or not target_v:
            errors.append(f"Missing File: {u} or {v}")
            continue
            
        if not target_graph.has_edge(target_u, target_v):
            errors.append(f"Missing Dependency: {target_u} SHOULD import {target_v}")
            
    return errors
```

This validates the **Integrity of the Whole System**, not just individual file syntax.
