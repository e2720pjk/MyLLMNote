# AutoMem Integration Analysis

## 1. The Verdict
**Highly Recommended as a "Semantic Sidecar".**
AutoMem is excellent for "Conversational Memory" and "High-Level Insights," but it **cannot** replace the deep CGR/Joern graph for structural code analysis.

## 2. Fit Analysis

| Feature | CodeWiki Need | AutoMem Capability | Verdict |
| :--- | :--- | :--- | :--- |
| **Structure** | Exact dependency call graph (10k+ nodes). | Semantic Knowledge Graph (Concepts). | **Mismatch.** Keep CGR for Code Structure. |
| **Summaries** | "What does this module do?" (RAG). | Vector Store + Hybrid Search. | **Perfect Match.** Store `module_summaries` here. |
| **History** | "Why was this changed?" (Intent). | Time-aware Memory + Clustering. | **Perfect Match.** Store `history_index` here. |
| **Chat** | "Context-aware Q&A". | Multi-hop reasoning. | **Perfect Match.** Power the Chatbot. |

## 3. The "Hybrid Memory" Architecture

We should **not** force the AST into AutoMem. Instead, we use a **Tiered Storage**:

1.  **Tier 1: The "Code Database" (CGR/Joern)**
    *   Stores: AST, Call Graph, Data Flow.
    *   Query: "Find all callers of `foo`."
    *   Status: *Immutable Fact Store.*

2.  **Tier 2: The "Semantic Memory" (AutoMem)**
    *   Stores: Module Summaries, Commit Intents, User Conversations, Important Insights.
    *   Query: "Why do we use PostgreSQL?" or "What acts as the Auth provider?"
    *   Status: *Living/Evolving Memory.*

## 4. Specific Configuration for CodeWiki
To use AutoMem effectively, we must tune its "Consolidation Engine" to prevent data loss:

*   **Disable Decay for Code:**
    *   Code documentation shouldn't "fade" just because you haven't read it lately.
    *   *Config:* Set `base_decay_rate = 0.0` or mark all Code Memories as `protected=True`.
*   **Enable Clustering for History:**
    *   Use `cluster_similar_memories` to group Git Commits.
    *   *Benefit:* Auto-generates "Feature Timelines" from raw commit logs.

## 5. Integration Strategy (Option A: Sidecar)
I recommend **Option A (External Service)**.
*   **Why:** `consolidation.py` has complex dependencies (FalkorDB, Qdrant). Embedding it directly into the CodeWiki CLI would make the CLI bloated and hard to install.
*   **How:**
    *   CodeWiki CLI generates `summaries/*.json`.
    *   A new command `codewiki memory-sync` pushes these summaries to a running AutoMem instance.
    *   The Chat Interface queries AutoMem.
