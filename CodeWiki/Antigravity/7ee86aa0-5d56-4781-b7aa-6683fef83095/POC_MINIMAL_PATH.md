# Minimum Viable POC: The "Data-First" Strategy

## 1. The Decision: Option 2 (Targeted Script) is the Winner.
**Why:**
*   **Option 1 (CodeWiki Refactor):** Too slow. You have to fight legacy code and integration tests just to test a hypothesis.
*   **Option 3 (PageIndex Refactor):** Too risky. You might break the reasoning engine while trying to hack the input.
*   **Option 2 (Script):** **Pure Speed.** We ignore all "System Architecture" and focus 100% on "Data Validation".

**The Hypothesis to Validate:**
*"Does feeding a CPG-structured Tree into an LLM actually enable better code navigation than flat RAG?"*

---

## 2. The Execution Plan (1-Week Sprint)

We build **Zero Software**. We build a **Data Pipeline Script**.

### Step 1: Target Selection
*   **Project:** `CodeWiki-2` (Self-hosting).
*   **Why:** We know the code. We know the questions ("Where is the graph clustering logic?").

### Step 2: The Generator Script (`poc_cpg_to_tree.py`)
This standalone script performs the "Assembler" role defined in `CODEWIKI_STRUCTURAL_RAG.md`.

*   **Input:** Source Code Directory (`/CodeWiki-2/src`).
*   **Process:**
    1.  **Level 1 (Modules):** Scan directories -> Create Root Nodes.
    2.  **Level 2 (Classes):** Regex/AST scan -> Create Branch Nodes.
    3.  **Level 3 (Functions):** Regex/AST scan -> Create Leaf Nodes (with code content).
    4.  **Enrichment:** (Simulated) Add hardcoded "Summary" strings for 5 key nodes to test retrieval.
*   **Output:** `codewiki_cpg_tree.json` (Formatted exactly like PageIndex expects).

### Step 3: The Validation (No Chatbot Required)
We don't even need to build a Chatbot UI. We use a **Notebook** or **Test Script**.

1.  **Load:** `PageIndex` library loads `codewiki_cpg_tree.json`.
2.  **Query:** "Explain how dependency clustering works."
3.  **Observe:**
    *   Does it traverse `src` -> `dependency_analyzer` -> `graph_clustering.py`?
    *   Or does it hallucinate?

---

## 3. Why this is "Shortest"
*   **No Database:** Just a JSON file.
*   **No API/Server:** Just a local Python script.
*   **No UI:** Just print statements.
*   **No Integration:** CodeWiki and PageIndex codebases remain untouched.

**Outcome:**
If this script works, you have **mathematical proof** that the architecture is valid. Then, and only then, do you spend months building the "Platform".
