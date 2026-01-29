# PR Analysis Pipeline: The "Spotlight" Strategy

## 1. The Challenge: "Cold Start" in CI
**Problem:** You need to compare `Main vs. PR` CPGs, but the project has **zero prior analysis**.
**Constraint:** Running a full Joern/CGR analysis on the entire repo (e.g., 50k lines) is too slow for a PR check (e.g., >10 mins).
**Solution:** We cannot analyze everything. We must analyze only the **"Blast Radius"**.

---

## 2. The Solution: "Spotlight" Analysis
We treat the codebase not as a Monolith, but as a Graph. We only need to generate the CPG for:
1.  **The Changed Files** (The Ground Zero).
2.  **The Direct Dependents** (The Blast Zone).

Everything else is treated as "External/Stub".

### The Workflow Diagram

```mermaid
graph TD
    A[PR Event] --> B{Git Diff}
    B -->|Modified Files| C[Dependency Scan]
    C -->|Identify Callers| D[Scope Definition]
    D --> E[Checkout MAIN]
    D --> F[Checkout PR]
    E --> G[Gen Partial CPG (Before)]
    F --> H[Gen Partial CPG (After)]
    G & H --> I[Graph Diff Analysis]
    I --> J[Report]
```

---

## 3. Pipeline Design Steps

### Step 1: Scope Detection (Fast)
*   **Tool:** `git diff --name-only origin/main...HEAD`
*   **Output:** `[src/auth/login.py, src/utils/hash.py]`

### Step 2: Impact Expansion (Fast Search)
Before running heavy CPG, we use lightweight tools to find *who uses these files*.
*   **Tool:** `ripgrep` (Regex) or `tree-sitter-cli` (AST Import Scan).
*   **Logic:**
    *   Find all files importing `src/auth/login`.
    *   Find all files importing `src/utils/hash`.
*   **Result:** `Scope = Changed_Files + Dependents` (e.g., 10 files total).

### Step 3: Dual-State Analysis (Parallel)
We perform the heavy analysis *twice*, but only on the small `Scope`.

*   **Action A (Baseline):**
    1.  `git checkout main`
    2.  `joern --parse-only {Scope_Files}`
    3.  Export `cpg_main.json`.
*   **Action B (Proposed):**
    1.  `git checkout pr_branch`
    2.  `joern --parse-only {Scope_Files}`
    3.  Export `cpg_pr.json`.

### Step 4: Semantic Diff
Now we compare the two micro-CPGs.
*   **Detect:**
    *   **New Flows:** Does Data A now define Data B?
    *   **Broken References:** Did a call in `Dependent` lose its target in `Changed`?
    *   **Signature Drift:** Did `login(u, p)` become `login(u, p, token)`?

---

## 4. POC Implementation Plan (Python)

We can build a `pr_spotlight.py` script.

### Tech Stack
*   **Git:** `GitPython`
*   **Dependency Scan:** `pydeps` or simple `ast` parsing (Python only for MVP).
*   **CPG Gen:** `joern-cli` (or our own internal AST parser if CGR based).
*   **Diff:** `networkx` isomorphism check or simple JSON diff.

### POC Logic (Pseudo-code)

```python
def run_spotlight(repo_path, pr_branch):
    # 1. Get Changed Files
    changed_files = git.diff("main", pr_branch)
    
    # 2. Find Dependents (Simple Grep for MVP)
    scope = set(changed_files)
    for file in changed_files:
        module_name = to_module(file)
        dependents = grep_codebase(repo_path, f"import {module_name}")
        scope.update(dependents)
        
    print(f"Spotlight Scope: {len(scope)} files (vs {total_files} in repo)")
    
    # 3. Analyze Baseline
    git.checkout("main")
    graph_main = generate_cpg(scope) # Only parses these files
    
    # 4. Analyze PR
    git.checkout(pr_branch)
    graph_pr = generate_cpg(scope)
    
    # 5. Report
    return compare_graphs(graph_main, graph_pr)
```

## 5. Value Proposition
*   **Speed:** Reduces analysis time from O(Repo) to O(PR Size).
*   **Focus:** Filters out "Noise". Code that wasn't touched and doesn't depend on touched code is irrelevant.
*   **Zero-State:** Requires no pre-existing database. Perfect for stateless CI runners.
