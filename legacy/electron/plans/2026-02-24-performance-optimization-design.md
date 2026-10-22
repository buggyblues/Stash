# Stash Performance Optimization Design

## Background

Stash is an Electron-based clipboard manager for macOS. Users report noticeable paste delay (1s+) when selecting items from the panel. A comprehensive code audit identified 10 performance issues across 4 categories.

## Approach

Targeted fixes for the 10 highest-impact issues. No architectural rewrites. Low risk, high reward.

## Issues & Fixes

### Category 1: Paste Flow (Critical)

**Problem 1: Dynamic imports on every paste**
- `await import('electron')` and `require('child_process')` execute on every paste in `clipboard:pasteItem` and `widget:pasteItem` handlers
- File: `src/main/index.ts` lines 75-76, 302-303
- Fix: Move `clipboard` to top-level import, move `child_process` to top-level require

**Problem 2: Excessive setTimeout delays**
- 100ms + 50ms hardcoded delays in paste flow
- File: `src/main/index.ts` lines 83, 93
- Fix: Reduce to 30ms + 20ms (macOS window switch needs ~20ms)

**Problem 3: execSync blocks main process**
- `execSync` for osascript calls blocks the Electron event loop
- File: `src/main/index.ts` lines 86-88, 94-96
- Fix: Replace `execSync` with `exec` (async) for osascript calls; move `incrementUseCount` to after paste completes

### Category 2: Search & Data Loading

**Problem 4: Search has no debounce**
- `SearchBar.onChange` calls `store.search()` on every keystroke, triggering IPC to main process
- File: `src/renderer/src/components/Panel/SearchBar.tsx` line 30
- Fix: Add 300ms debounce to search input

**Problem 8: Fuse.js instance recreated every render**
- `useSearch` hook creates `new Fuse(items, fuseOptions)` on every render
- File: `src/renderer/src/hooks/useSearch.ts` line 18
- Fix: Wrap in `useMemo`, only rebuild when `items` changes

**Problem 10: Full data reload on every panel show**
- `onPanelShown` calls `loadItems()` unconditionally
- File: `src/renderer/src/App.tsx` lines 20-23
- Fix: Skip reload if items already loaded and data is fresh (or only load incremental new items)

### Category 3: Rendering Performance

**Problem 5: ClipboardItem lacks React.memo**
- Every parent re-render causes all visible list items to re-render
- File: `src/renderer/src/components/Panel/ClipboardItem.tsx`
- Fix: Wrap with `React.memo`

**Problem 6: onMouseEnter triggers cascading re-renders**
- `setSelectedIndex(index)` on mouse enter causes store update, re-rendering all items
- File: `src/renderer/src/components/Panel/ClipboardItem.tsx` line 157
- Fix: Use `useRef` for hover tracking instead of store state, or isolate selectedIndex with Zustand selector

**Problem 7: Shiki highlighter recreated on every mount**
- `CodePreview` creates a new Shiki highlighter each time it mounts
- File: `src/renderer/src/components/Preview/CodePreview.tsx`
- Fix: Create module-level Shiki singleton, initialize once and reuse

### Category 4: Background Process

**Problem 9: osascript runs on every clipboard poll regardless of change**
- ClipboardMonitor polls every 500ms, running osascript to get frontmost app even when clipboard content hasn't changed
- File: `src/main/clipboard/monitor.ts`
- Fix: Check clipboard hash first, only run osascript when content actually changes

## Expected Results

- Paste delay: 1s+ → ~50-80ms
- Search responsiveness: immediate improvement from debounce
- List scrolling: smoother from memo + hover optimization
- CPU usage: reduced from eliminating unnecessary osascript calls
- Panel open speed: faster from conditional data loading

## Files to Modify

1. `src/main/index.ts` - Paste flow optimization (Problems 1, 2, 3)
2. `src/renderer/src/components/Panel/SearchBar.tsx` - Search debounce (Problem 4)
3. `src/renderer/src/hooks/useSearch.ts` - Fuse.js caching (Problem 8)
4. `src/renderer/src/App.tsx` - Conditional data loading (Problem 10)
5. `src/renderer/src/components/Panel/ClipboardItem.tsx` - React.memo + hover fix (Problems 5, 6)
6. `src/renderer/src/components/Preview/CodePreview.tsx` - Shiki singleton (Problem 7)
7. `src/main/clipboard/monitor.ts` - Conditional osascript (Problem 9)
