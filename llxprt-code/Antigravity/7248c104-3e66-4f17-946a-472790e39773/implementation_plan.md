# Implementation Plan: CCR Multi-Layered Strategy

To ensure scalability, we will separate "AI behavior rules" from "Project-level engineering infrastructure."

## Proposed Changes

### Layer 1: Universal AI Rule (The "Mind")

#### [MODIFY] [.agent-rules.md](file:///Users/caishanghong/.gemini/antigravity/playground/distant-intergalactic/.agent-rules.md)
Keep this focused on AI behavior:
- **Segmented Logic**: Explain "Why/Relation" per block.
- **Log Ownership**: AI is responsible for maintaining the `## Change Log` header.
- **Pruning**: AI should actively clean up comments that become "obvious" or "redundant" after logic stabilizes.

### Layer 2: Project Infrastructure (The "System")

#### [NEW] [PROJECT_RECIPE.md](file:///Users/caishanghong/.gemini/antigravity/playground/distant-intergalactic/PROJECT_RECIPE.md)
A separate guide for human developers/architects:
- **CI/CD Integration**: Recommendations for linting `## Change Log`.
- **Git Hooks**: Automatically injecting hashes into the header.
- **Pruning Criteria**: Formal definitions of "Obsolete" (e.g., > 10 commits, logic removed).

## Strategic Advice

> [!TIP]
> **您的建議非常專業。我強烈建議「分開規劃」。**
> 
> 1. **通用規則 (The Rule)** 是給 AI 讀的「行為守則」，越精簡越好，強調 **「要做什麼」**。
> 2. **專案規劃 (The Infrastructure)** 是專案的「工程實踐」，強調 **「如何自動化與驗證」**。
> 
> 將 CI/CD 與 Git 整合放在專案層級，可以讓這個規則應用到不同的專案時（例如有些專案不跑 CI），AI 依然能維持註解品質。

## Verification Plan

### Manual Verification
- Output the finalized `.agent-rules.md` (AI behavioral instructions).
- Output the `PROJECT_RECIPE.md` (Engineering guidelines).
