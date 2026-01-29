# The Verification Toolkit: Systemizing the Workflow

Yes, this workflow can (and should) be solidified into a **Universal Tool**.
This transforms the process from "Chatting with AI" to **"Graph-Driven Engineering"**.

---

## 1. The Tool Workflow: `codewiki-verify`

We define a 2-step pipeline that wraps the LLM interaction.

### Step 1: The Context Generator (`codewiki gen-context`)
*   **Input:** Source Path (e.g., `src/auth/login.py`).
*   **Action:**
    1.  Parse Code -> Generate CPG.
    2.  Extract **"Structural Contract"**:
        *   Dependencies (Imports).
        *   Public Interface (Signatures).
        *   Critical Calls (Hooks, DB).
*   **Output:** `context_bundle.json` (Structured Prompt).
    *   *Usage:* You paste this into the LLM. "Here is the context. Implement Feature X matching this structure."

### Step 2: The Skeleton Validator (`codewiki verify-skeleton`)
*   **Input:**
    *   `context_bundle.json` (The Truth).
    *   `generated_code.py` (The LLM Output).
*   **Action:**
    1.  Parse `generated_code.py` -> Generate Target Graph.
    2.  **Compare:** Does Target Graph satisfy the `Structural Contract` from Step 1?
        *   *Check 1:* Does it export `authenticate()`?
        *   *Check 2:* Does it call `usePreservedSearch`?
*   **Output:** `Pass` or `Fail: Missing Dependency 'usePreservedSearch'`.

---

## 2. Implementation Design (Python Toolkit)

We can build this as a standalone CLI tool `cw-toolkit`.

```python
# cw_toolkit/context.py
def generate_context(file_path):
    cpg = analyze_file(file_path)
    contract = extract_contract(cpg)
    return {
        "file": file_path,
        "contract": contract, # { "imports": [...], "exports": [...] }
        "prompt": f"Implement a file that satisfies these {len(contract)} constraints..."
    }

# cw_toolkit/verifier.py
def verify_skeleton(original_contract, generated_file):
    gen_cpg = analyze_file(generated_file)
    errors = []
    
    # Check Imports
    for imp in original_contract.imports:
        if imp not in gen_cpg.imports:
            errors.append(f"Missing Import: {imp}")
            
    # Check Calls
    for call in original_contract.required_calls:
        if call not in gen_cpg.calls:
            errors.append(f"Missing Logic: Must call {call}")
            
    return errors
```

---

## 3. The Value Loop
1.  **Preparation:** You run `gen-context` on the *Reference Implementation*.
2.  **Execution:** You tell LLM: "Generate requirements compliant with this Context."
3.  **Validation:** You save LLM output and run `verify-skeleton`.
4.  **Result:** Instant feedback loop. No human review needed for structural correctness.

## 4. Feasibility
*   **Complexity:** Low. We rely on standard AST parsers (`tree-sitter`) to extract imports/calls.
*   **Generalization:** High. Works for any language supported by Tree-sitter (JS/TS, Python, Java).
*   **Evolution:** This is your **automated test suite** for LLM generation.
