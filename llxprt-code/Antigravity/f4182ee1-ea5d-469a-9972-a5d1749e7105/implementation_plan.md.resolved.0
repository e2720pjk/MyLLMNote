# Fix Missing Dependencies in packages/core

## Goal Description
Move `cheerio`, `turndown`, and `node-fetch` dependencies from the root `package.json` to `packages/core/package.json` where they are actually used. This ensures correct dependency management in the monorepo structure.

## Proposed Changes

### Root
#### [MODIFY] [package.json](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-4/package.json)
- Remove `cheerio`
- Remove `turndown`
- Remove `node-fetch`

### Core Package
#### [MODIFY] [packages/core/package.json](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-4/packages/core/package.json)
- Add `cheerio`
- Add `turndown`
- Add `node-fetch`

## Verification Plan

### Automated Tests
- Run `npm run build` in `packages/core` to ensure it builds correctly with the new dependencies.
- Run `npm run test` in `packages/core` to verify no regressions.
