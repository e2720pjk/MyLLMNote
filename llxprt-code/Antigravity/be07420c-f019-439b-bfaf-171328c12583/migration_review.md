# Review: Tree-Sitter to ast-grep Migration Plan

## Executive Summary
The plan to migrate from `tree-sitter` CLI to `@ast-grep/napi` is **highly recommended**. It will:
- **Simplify Deployment**: Eliminates the need for a system-level `tree-sitter` binary and complex child process spawning.
- **Improve Reliability**: `ast-grep` via NAPI is more robust than parsing stdout from a CLI tool.
- **Maintain Feature Parity**: `ast-grep` supports the same core set of languages.

However, the **validation strategy is currently insufficient** given the lack of coverage in `tabby-edit.test.ts`.

## 🚨 Critical Recommendations

### 1. "Golden Master" Testing (Priority: High)
Your current tests (`packages/core/src/tools/tabby-edit.test.ts`) only verify tool instantiation and do not cover `extractDeclarations` or `validateASTSyntax` logic. 
**Before migrating**, you must establish a baseline:
- Create a test ensuring `extractDeclarations` returns the correct symbols for sample files (TS, Python).
- Create a test for `validateASTSyntax` with known good/bad code.
- **Why**: Without this, you have no automated way to verify that `ast-grep` is extracting the same symbols as the old implementation.

### 2. Clarify `extractDeclarations` Implementation (Priority: Medium)
Step 2.4 says "Replace entire method with simplified version using ast-grep pattern matching" but does not provide the code.
- `extractDeclarations` is complex (functions, classes, variables, imports).
- **Action**: Draft the `ast-grep` patterns for at least one language (e.g., TypeScript) in the plan to ensure you know how to map `(function_declaration)` queries to `ast-grep` patterns (e.g., `function $NAME($$$) { $$$ }`).

### 3. Verify Language Support (Priority: Medium)
You list 15 languages in the `validateASTSyntax` map (lines 71-87).
- Verify that `@ast-grep/napi` exports `Lang` values for **all** of these, specifically `Html`, `Css`, `Yaml`, and `Json`.
- `ast-grep` core focuses on code; ensure the NAPI package includes the grammars for these data/markup languages.

## Feasibility Assessment
- **Feasibility**: ✅ **High**. The `napi` binding is the correct approach.
- **Complexity**: 🟡 **Medium**. The logic for `extractDeclarations` will be the hardest part to port correctly without regressions.
- **Performance**: 🟢 **Positive**. Removing `spawnSync` will reduce process overhead.

## Refined Checklist

- [ ] **[NEW]** Write a "snapshot" test for `extractDeclarations` using current implementation.
- [ ] Verify `@ast-grep/napi` `Lang` enum support for all 15 target languages.
- [ ] Update Step 2.4 in plan with concrete examples of `ast-grep` patterns for TypeScript/Python.
- [ ] Execute migration (Phase 1-4).
- [ ] Run the new snapshot test to verify parity.
