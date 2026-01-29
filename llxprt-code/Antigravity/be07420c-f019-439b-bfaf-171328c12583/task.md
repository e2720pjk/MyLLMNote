# Task: Review Tree-sitter to ast-grep Migration Plan

- [x] Read and analyze `llxprt-code-2/docs/migration-tree-sitter-to-ast-grep.md` <!-- id: 0 -->
- [x] Read relevant performance reports if available (`llxprt-code-2/tools_performance_test/performance_report.md`) <!-- id: 1 -->
- [x] Assess feasibility and quality of the plan <!-- id: 2 -->
- [x] Provide comprehensive feedback and recommendations <!-- id: 3 -->

## Implementation: Tree-Sitter to ast-grep Migration <!-- id: 4 -->
- [ ] Create Golden Master safety test (`packages/core/src/tools/tabby-edit.safety.test.ts`) <!-- id: 5 -->
- [ ] Install `@ast-grep/napi` dependency <!-- id: 6 -->
- [ ] Implement `validateASTSyntax` using `ast-grep` <!-- id: 7 -->
- [ ] Refactor `extractDeclarations` to use `ast-grep` <!-- id: 8 -->
- [ ] Refactor `findRelatedSymbols` to use `ast-grep` <!-- id: 9 -->
- [ ] Verify with Golden Master and existing tests <!-- id: 10 -->

