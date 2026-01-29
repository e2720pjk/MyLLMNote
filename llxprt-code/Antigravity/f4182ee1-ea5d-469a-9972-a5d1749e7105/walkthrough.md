# Walkthrough - Fix Missing Dependencies in packages/core

I have moved the `cheerio`, `turndown`, and `node-fetch` dependencies from the root `package.json` to `packages/core/package.json` in `llxprt-code-4`.

## Changes

### Root
#### [MODIFY] [package.json](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-4/package.json)
- Removed `cheerio`, `turndown`, and `node-fetch`.

### Core Package
#### [MODIFY] [packages/core/package.json](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-4/packages/core/package.json)
- Added `cheerio`, `turndown`, and `node-fetch`.

## Verification Results

### Automated Tests
- Ran `npm install` to update `package-lock.json`.
- Ran `npm run build` in `packages/core` which completed successfully.

```bash
> @vybestack/llxprt-code-core@0.6.0 build
> node ../../scripts/build_package.js

Successfully copied files.
```
