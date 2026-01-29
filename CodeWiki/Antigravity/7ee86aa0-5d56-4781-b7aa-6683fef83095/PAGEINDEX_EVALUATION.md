# PageIndex Evaluation & Data Schema Definition

## 1. The Verdict
**No, PageIndex does NOT replace the CPG (Code Property Graph).**
*   **CPG** maps **Code Logic** (Function A *calls* Function B).
*   **PageIndex** maps **Document Structure** (Section 1 *contains* Subsection 1.1).

**However, it is CRITICAL for the "Chat" Application.**
Instead of "Chunking" your generated documentation, you should use `PageIndex` to create a **Reasoning Tree** of the docs. This allows the Chatbot to navigate your docs like a human (Table of Contents -> Section) rather than just keyword searching.

---

## 2. Integration Strategy
We integrate `PageIndex` at **Layer 3 (The View/Index)**.

| Layer | Technology | Role | Data Shape |
| :--- | :--- | :--- | :--- |
| **Layer 1** | **CGR/Joern** | **The Code Graph** | `Calls`, `Inherits`, `Imports` |
| **Layer 2** | **AutoMem** | **The Semantic Map** | `Relates_To`, `Explains`, `History` |
| **Layer 3** | **PageIndex** | **The Doc Index** | `Parent_Of`, `Section_Order`, `Summary` |

**Value Add:**
*   **Current CodeWiki:** Generates a Flat Markdown. RAG is hard.
*   **With PageIndex:** Generates a **Tree-Structured Markdown Index**. RAG is precise.

---

## 3. Pre-defined Data Fields (POC Schema)

You asked for pre-defined fields to ensure testing effectiveness. Here is the **Unified Schema** merging CodeWiki, AutoMem, and PageIndex concepts.

### A. The "Code Node" (Layer 1 - CPG)
*Source: Source Code Parser*
```json
{
  "id": "urn:cw:src/auth/login.py:func:authenticate",
  "type": "FUNCTION",
  "signature": "def authenticate(user, pass)",
  "metrics": { "complexity": 5, "loc": 20 },
  "relationships": [
    { "type": "CALLS", "target": "urn:cw:src/db:func:query" }
  ]
}
```

### B. The "Semantic Node" (Layer 2 - AutoMem)
*Source: LLM Analysis*
```json
{
  "id": "urn:cw:src/auth/login.py:func:authenticate",
  "summary": "Validates user credentials against DB.",
  "tags": ["auth", "security", "critical"],
  "intent_history": [
    { "commit": "a1b2", "intent": "Added rate limiting", "date": "2024-01-01" }
  ],
  "embeddings": [0.1, 0.5, ...]
}
```

### C. The "Doc Tree Node" (Layer 3 - PageIndex)
*Source: Documentation Generator + PageIndex*
*This explains WHERE this content lives in the generated Manual.*
```json
{
  "node_id": "0042",
  "title": "Authentication Service",
  "level": 2,
  "parent_id": "0010",
  "path": "Architecture > Services > Auth",
  "content_ref": "urn:cw:src/auth/login.py:func:authenticate",
  "section_summary": "This section details the login flow...",
  "sub_nodes": ["0043", "0044"]
}
```

## 4. Recommendation for POC
1.  **Don't force PageIndex to do Code Analysis.** Use it for what it's built for: **Document Indexing**.
2.  **Pipeline:**
    *   Step 1: CodeWiki generates `Project_Manual.md`.
    *   Step 2: `PageIndex` parses `Project_Manual.md` -> `page_index_tree.json`.
    *   Step 3: Chatbot uses `page_index_tree.json` to answer questions.

This keeps your architecture clean and leverages the strength of each tool.
