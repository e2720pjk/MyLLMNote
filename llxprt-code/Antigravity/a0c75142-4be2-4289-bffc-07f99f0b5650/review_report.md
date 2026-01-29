# Code Review: ASTEdit Tool Refactoring

## Summary
The refactoring successfully introduces the structure for Git-based Working Sets and Freshness Checks. However, there are **critical implementation gaps** regarding the exposure of this new context to the LLM and the completeness of the extracted signatures. The "Skeleton View" goal is not fully realized because the signatures (parameters/return types) are not captured or displayed, and the connected files are not shown in the preview output.

## Review Findings

### 🔴 Critical: Working Set Context Not Displayed
**Location**: `packages/core/src/tools/ast-edit.ts` (Lines 1620-1622)
**Issue**: The Walkthrough claims to provide relevant cross-file context, and the code collects it into `enhancedContext.connectedFiles`. However, the `editPreviewLlmContent` **only displays the count** of connected files, effectively hiding this context from the LLM.
**Suggestion**: Update `executePreview` to iterate over `enhancedContext.connectedFiles` and display the declarations (skeleton) for each file.
**Example**:
```typescript
// Proposed addition to editPreviewLlmContent array
...enhancedContext.connectedFiles?.map(file => [
  `file: ${path.relative(workspaceRoot, file.filePath)}`,
  ...file.declarations.map(d => `  - ${d.type}: ${d.name}`) // Note: See Suggestion 3 about signatures
]).flat() || [],
```

### 🟠 Important: Missing Unit Tests for Freshness & Git Logic
**Location**: `packages/core/src/tools/ast-edit.test.ts`
**Issue**: The current tests only cover module instantiation and AST extraction. There are no tests verifying:
1.  The **Freshness Check** logic (i.e., `calculateEdit` throwing `FILE_MODIFIED_CONFLICT`).
2.  The **RepositoryContextProvider** correctly parsing git output.
**Suggestion**: Add test cases that mock `getFileLastModified` to return a timestamp newer than `params.last_modified` and assert that the correct error is returned.

### 🟡 Suggestion: Insufficient Signature Information
**Location**: `packages/core/src/tools/ast-edit.ts` (Lines 322-335, 1630)
**Issue**: The current "Skeleton View" only provides the **name** and **type** (e.g., `function: myFunc`). It does **not** provide the parameters or return type, which dramatically reduces the utility of the context for the agent. The regex-based `extractFunctions` (Lines 1076+) captures this, but the primary `ASTQueryExtractor` (using ast-grep) does not seem to populate a "signature" field in `EnhancedDeclaration`.
**Suggestion**: Update `EnhancedDeclaration` to include a `signature` field (e.g., `(a: string): void`) and populate it in `ASTQueryExtractor`.

### 🟡 Suggestion: Git Command Robustness
**Location**: `packages/core/src/tools/ast-edit.ts` (Lines 445-451)
**Issue**: The `spawnSync` calls for git commands assume standard output format. While `encoding: 'utf-8'` is set, relying on string splitting by newline without handling potential filename encoding issues (e.g., spaces or non-ASCII chars in filenames, though rare in codebases) could be brittle.
**Suggestion**: Use `-z` (null terminator) for git commands (e.g., `git diff --name-only -z`) and split by `\0` for robustness.
