# Deep Dive: The Logic of "Level 1 + Level 2" Architecture

You are asking the right questions. The value of this architecture isn't just "more data"—it's about moving from **"Guessing"** (LLM-based) to **"Knowing"** (Graph-based).

## 1. Why Split Level 1 & 2? (The "Speed vs. Truth" Trade-off)

You asked: *"Didn't we consider that Joern also includes AST? Is this just for speed?"*

**It is mostly about Physics (Speed & Memory), but also "Granularity".**

*   **Joern (The "Heavy Logic" Layer)**:
    *   **Cost**: Parsing a large repo into CPG (Code Property Graph) is CPU/RAM intensive. It builds AST + CDG (Control Dependency) + DDG (Data Dependency) all at once.
    *   **Use Case**: Deep analysis. *"Where does this variable go?"*
    *   **Cons**: You don't want to run this just to get a file list or call dependency structure for a quick search.

*   **Level 1 / CGR (The "Light Structure" Layer)**:
    *   **Cost**: Extremely cheap (Tree-sitter is ms/file).
    *   **Use Case**: Indexing. *"List all functions in class X."*
    *   **Why Keep It?**: If you force Joern to do everything, your "Doc Generation" pipeline becomes slow (minutes/hours). Level 1 gives you **instant feedback** and a "Skeleton" to hang Joern's heavy data on later (Lazy Loading).

**Verdict**: The split isn't just speed; it's **Operational Tiering**. Level 1 is your "Map"; Level 2 is the "Street View".

---

## 2. CodeWiki: What Content Does Level 2 Actually Add?

Currently, CodeWiki documents **"What the code *says*"** (Static).
With Level 2 (Joern), it can document **"What the code *does*"** (Behavioral).

| Feature | Current CodeWiki (LLM + AST) | Level 2 Enriched CodeWiki |
| :--- | :--- | :--- |
| **Side Effects** | "This function *might* save to DB (guessed from name)." | "This function **writes to Table `Users`** (via SQL injection sink)." |
| **Exceptions** | "May raise errors." | "Throws `ValueError` only when `x < 0`." |
| **Data Flow** | Invisible. | "Input `req.body` flows to `API Client`." |
| **Dependencies** | "Imports `boto3`." | "Actually uses `boto3.s3` but ignores `boto3.ec2`." |

**Value Add:** It transforms CodeWiki from a "Reader's Guide" into a **"Developer's Handbook"** containing proved behaviors.

---

## 3. Can This Replace "Randomness" & Enable Determinism?

**YES. This is the biggest win.**

Currently, your `documentation_generator.py` relies on the LLM to *interpret* code structure. The randomness comes from different LLM runs interpreting the "Context Window" differently.

**The "Data-First" Approach:**
1.  **Extract Facts (Deterministic):**
    *   Joern: "Function A calls B." (Fact)
    *   Joern: "Param X is nullable." (Fact)
    *   Joern: "Returns List<String>." (Fact)
2.  **Pass Facts to LLM:**
    *   Instead of prompting: *"Read this code and summarize it."* (High Variance)
    *   You prompt: *"Here are the FACTS about Function A. Write a prose description."* (Low Variance)

**Result:** The *content* (Information Gain) becomes fixed and deterministic. Only the *style* (wording) varies. You can effectively "lock" the documentation's accuracy.

---

## 4. Does This Enable "Chat" (LLM Interface)?

**Absolutely.**

If you implement the "Unified Knowledge Graph" (Level 1 + 2), you are building the perfect **RAG (Retrieval-Augmented Generation) Backend**.

*   **Current State:** LLM reads text files. It hallucinates if files are too big.
*   **Future State:**
    *   **User:** *"How does the `Payment` module handle errors?"*
    *   **System (Graph Query):**
        1.  Find `Payment` module (Level 1).
        2.  Trace all `try/catch` blocks in `Payment` (Level 2).
        3.  Find all `throw` statements reachable from `Payment` (Level 2).
    *   **LLM Response:** Fed with *exact* error handling paths, the LLM answers with 100% precision.

**Conclusion:**
You are not just building a "Doc Generator". You are building a **"Code Intelligence Platform"**. CodeWiki (Docs) and Chat (Q&A) are just two different *views* of the same underlying Graph Data.
