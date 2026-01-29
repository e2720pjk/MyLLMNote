# POC Implementation Plan: Code Intelligence Verification

This plan is optimized for an **autonomous agent** to execute. It focuses on validating the "Structure-First" approach using a dedicated POC workspace.

---

## 1. Setup Phase
*   **Target Directory**: `.sisyphus/poc/`
*   **Target Project for Analysis**: `CodeWiki-2/codewiki/src` (Self-hosting analysis).
*   **Goal**: Create a portable, script-based pipeline that avoids modifying the core repo.

---

## 2. Component Implementation (L1/L2 Analyzer)

### Task 1: The CPG Blueprint Script (`poc_blueprint.py`)
*   **Input**: A directory of source code.
*   **Action**: Execute **Joern** to generate the Code Property Graph (CPG).
    *   **Data Extraction**: Extract JSON export from Joern CPG.
    *   **Nodes**: Methods, Variables, Calls, Data Flows.
    *   **Edges**: `REACH_DEFS`, `CALL`, `CONTROL_STRUCTURE`.
*   **Output**: `blueprint.json` (The CPG "Ground Truth").
*   **Rationale**: Unlike AST (which only shows code "shapes"), CPG shows **Logic Flow**. This is vital to verify that the LLM didn't just write the correct function *name*, but also the correct *data handling logic*. 

### Task 2: The Context Generator (`poc_context.py`)
*   **Input**: `blueprint.json`.
*   **Action**: Transform the graph into a **Structural Reasoning Tree** (PageIndex format).
    *   Inject high-level "Purpose" placeholders (to be filled by an agent or hardcoded for the test).
*   **Output**: `page_index_context.json`.

---

## 3. The "Generation & Verification" Loop

### Task 3: The LLM Prompt Experiment
*   **Action**: Provide the `page_index_context.json` to an agent.
*   **Prompt**: "Based on this blueprint, implement a new module `poc_demo.py` that satisfies all listed dependencies and interfaces."
*   **Save Output**: `generated_code.py`.

### Task 4: The Deterministic Verifier (`poc_verify.py`)
*   **Input**: `generated_code.py` + `blueprint.json`.
*   **Action**:
    1.  Parse `generated_code.py` using **Joern**.
    2.  Check for **Required Logic Edges** (e.g., does Input A reach Hook B?).
    3.  Compare sub-graphs for logic equivalence.
*   **Output**: Console Report (`PASS` / `FAIL: Logical path to Hook X is missing or broken`).

---

## 4. Execution Roadmap (For Agent)

1.  [ ] **Prepare Workspace**: Create `.sisyphus/poc/` and install `tree-sitter`, `networkx`.
2.  [ ] **Run Analysis**: Execute `poc_blueprint.py` on `CodeWiki-2` to get the reference data.
3.  [ ] **Generate Tree**: Run `poc_context.py` to create the reasoning context.
4.  [ ] **Simulate/Run Task**: Ask another agent (or yourself) to "Write a module based on this JSON context".
5.  [ ] **Verify**: Run `poc_verify.py` on the result.
6.  [ ] **Report**: Summarize the "Zero-Hallucination" success rate.

---

## 5. Risks & Guardrails
*   **Parsing Depth**: Focus only on "Exports" and "Calls" for the POC to keep it simple.
*   **Language Support**: Start with **Python-only** for the script verification logic.
