# CodeWiki Resilience Strategy: Resume, Retry, & Incremental

This document answers your questions on **Reliability** and **Efficiency**.

---

## 1. Current Status (The "Naive" Approach)
*What CodeWiki supports right now:*

*   **Avoid Re-analysis:** ✅ **Yes (Primitive).**
    *   Logic: `if os.path.exists("module.md"): return`
    *   *Flaw:* If source code changes, it still returns (Stale Data). It only resumes *missing* files.
*   **Resume on Crash:** ✅ **Yes (Primitive).**
    *   Logic: Because of the file check above, re-running the command skips completed files.
*   **Smart Rate Limiting:** ❌ **No.**
    *   Logic: Just simple `retries=3`. If quota runs out, it crashes hard.

---

## 2. The Target Strategy (The "Resilient" Approach)

### A. Incremental Updates (The "Smart Skip")
**Goal:** Only run if code actually changed.

**Mechanism: The Hash Map (`analysis_state.json`)**
We verify input integrity *before* consistency.

1.  **Calculate:** `current_hash = sha256(source_code + dependencies_signatures)`
2.  **Compare:**
    ```python
    last_state = load("analysis_state.json")
    if last_state[module].hash == current_hash and os.path.exists(module.md):
        skip()
    else:
        analyze()
    ```
3.  **Benefit:** Handles "Stale Docs". If you modify a file, the Hash mismatch triggers re-generation.

### B. Smart Resume (The "Transaction" Log)
**Goal:** Handle crashes without data corruption.

**Mechanism: The Progress Journal (`progress.jsonl`)**
Instead of just checking if `.md` exists (which might be half-written), we use a Journal.

1.  **Start:** Write `{"type": "START", "module": "auth", "timestamp": ...}`
2.  **Finish:** Write `{"type": "DONE", "module": "auth", "hash": ...}`
3.  **Resume Logic:**
    *   Read `progress.jsonl`.
    *   Rebuild `Set<CompletedModules>`.
    *   Only process modules NOT in the Set.

### C. Traffic Control (Rate Limits & "Graceful Wait")
**Goal:** "Smartly identify LLM limits."

**Mechanism: The `circuit_breaker` Module**
We wrap all LLM calls in a Guard.

```python
class TokenBucketGuard:
    def call_llm(self, prompt):
        try:
            return api.call(prompt)
        except RateLimitError as e:
            # Strategy: LONG WAIT or EXIT
            if e.retry_after > 600: # If wait > 10 mins
                 self.save_checkpoint() # Save state immediately
                 logger.error("Quota exhausted. Resuming allowed later.")
                 sys.exit(0) # Clean exit
            else:
                 time.sleep(e.retry_after) # Short wait
                 return self.call_llm(prompt)
```

---

## 3. Implementation Plan

1.  **Enhanced `ResumeManager` Class:**
    *   Replaces the simple `os.path.exists` check in `agent_orchestrator.py`.
    *   Reads/Writes `analysis_state.json`.

2.  **`LLMGuard` Decorator:**
    *   Wraps the `agent.run()` call.
    *   Handles the 429/Quota errors.
    *   Implements the "Save & Exit" strategy.

3.  **CLI Options:**
    *   `--force`: Ignore hash checks (Force re-run).
    *   `--resume`: Explicitly load last journal (Default behavior).
