# Opencode Agent Interface

## 1. Environment & Availability

**CRITICAL**: `opencode` is a **system-level CLI tool**.
- **Verification**: `which opencode`

## 2. Role Definition

**Opencode** is your **Senior Technical Reviewer**.
- **You (Agent)**: Architect (Plan), Builder (Execute), Tester (Verify).
- **Opencode**: Auditor. Reviews your **Plan** before you build, and your **Results** after you finish.

## 3. Standard Agent Lifecycle & Review Points

You must integrate Opencode reviews at specific checkpoints in your workflow.

### Phase 1: Planning (The "Plan Check")
**Goal**: Validate the approach before writing code.
1.  **Draft**: Create `implementation_plan.md`.
    *   *Must include*: Proposed Changes & Verification Plan.
2.  **Review (MANDATORY)**:
    ```bash
    opencode run "Review the authenticity and solution quality of the following plan: [Paste content of implementation_plan.md]"
    ```
3.  **Refine**: Update the plan based on feedback.

### Phase 2: Execution
**Goal**: Implement the approved plan.
1.  **Execute**: Write code according to the *refined* plan.
    *   *Note*: You do this yourself. Do not delegate execution to Opencode.

### Phase 3: Verification (The "Result Check")
**Goal**: Prove it works.
1.  **Verify**: Run tests, check UI, etc.
2.  **Document**: Create `walkthrough.md`.
3.  **Review (Recommended)**:
    ```bash
    opencode run "Review the following verification results and confirm if the plan was successful: [Paste content of walkthrough.md]"
    ```

## 4. Summary of Commands

| Phase | Command | Content to Paste |
| :--- | :--- | :--- |
| **Planning** | `opencode run "Review plan: ..."` | `implementation_plan.md` |
| **Verification** | `opencode run "Review results: ..."` | `walkthrough.md` |
