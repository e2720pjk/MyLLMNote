# Task: Debugging Runtime Crash and UI Layout

- [ ] **Debug 'Range is not defined' Crash**
    - [x] Search for `Range` usage in codebase <!-- id: 3996 -->
    - [ ] Inspect `DebugProfiler.tsx` and related components for browser-specific APIs
    - [ ] Inspect dependencies for `Range` usage (likely `ink` or a visualization lib)
    - [ ] Reproduce crash locally if possible
    - [ ] Fix the `Range` error (polyfill or remove offending code)
- [ ] **Fix UI Layout Overlap**
    - [ ] Inspect `DefaultAppLayout.tsx` for Footer stacking context
    - [ ] Inspect `MainContent.tsx` height calculations
    - [ ] Fix overlap issue (likely z-index or flexbox sizing)
- [ ] **Refine E2E Tests**
    - [ ] Verify existing Todo test robustly checks tab switching
    - [ ] Add explicit check for "long chat" scenario and tool display correctness
    - [ ] Ensure `DEBUG=true` scenario is covered or at least doesn't crash
- [ ] **Final Verification**
    - [ ] Run full test suite and `preflight`
