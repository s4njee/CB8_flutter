# TODO — Ship CB8-Next as a Desktop App (macOS / Windows / Linux)

Turn the existing iOS-first Flutter app into a polished desktop application.
The platform scaffolds (`macos/`, `windows/`, `linux/`) already exist, and most
dependencies are desktop-ready. This list is ordered by phase; do Phase 0–2
before worrying about packaging.

## ✅ macOS status — runnable & verified (2026-06-26)
The macOS app now **builds, launches, and all three readers work natively**:
- Builds & runs to the library; Drift/sqlite + pdfium load; the library shell
  already adapts responsively (NavigationRail when wide / bottom bar when narrow).
- **Entitlements** fixed: added `network.client` + `files.user-selected.read-write`
  to Debug **and** Release (file_picker + dio now work in the sandbox).
- **CBZ** (archive+photo_view), **PDF** (pdfrx), **EPUB** all render & track progress.
- **EPUB on macOS** needed a workaround (see Phase 2): the WebView blocks the
  sibling-dir epub.js/jszip `<script>`s and ignores `transparentBackground`, so
  `epub_reader_screen.dart` injects the libs itself, drives the package's
  `readyToLoad`, and forces the dark background. Mode switches re-run it.
- **Keyboard nav** (←/→/Space/PageUp-Dn/Home/End/Esc) added to all readers via a
  shared `reader_keyboard.dart` (HardwareKeyboard handler, beats Scrollable focus).
- **Window**: min size + sensible default in `MainFlutterWindow.swift` (no collapse).

Remaining for a *shippable* macOS build: code-sign + notarize + `.dmg` (Phase 6),
macOS menu bar / fullscreen polish (Phase 4), drag-and-drop import (Phase 5).
Windows & Linux are untouched.

## Compatibility snapshot (from current `pubspec.yaml`)

| Concern | macOS | Windows | Linux | Notes |
|---|---|---|---|---|
| PDF reader (`pdfrx`) | ✅ | ✅ | ✅ | pdfium is cross-platform |
| CBZ reader (`archive` + `photo_view`) | ✅ | ✅ | ✅ | pure Dart + widgets |
| **EPUB reader** (`flutter_epub_viewer` → `flutter_inappwebview` 6.1.5) | ✅ WKWebView | ⚠️ WebView2 (runtime req.) | ❌ **unsupported** | **main blocker — see Phase 2** |
| DB (`drift` + `sqlite3_flutter_libs`) | ✅ | ✅ | ✅ | bundles sqlite3 |
| `dio` / cookies / secure_storage / shared_prefs | ✅ | ✅ | ✅* | *Linux secure_storage needs `libsecret` |
| `file_picker` | ✅ | ✅ | ✅ | native dialogs |

---

## Phase 0 — Baseline: build & run on each OS
- [ ] `flutter config --enable-macos-desktop --enable-windows-desktop --enable-linux-desktop`; confirm `flutter devices` lists each.
- [ ] `flutter run -d macos` — get the app launching to the library on macOS.
- [ ] `flutter run -d windows` and `-d linux` (on the respective machines/VMs); fix any compile/plugin-registration errors.
- [ ] Run `dart run build_runner build` (riverpod/drift codegen) and confirm it's wired into the build.
- [ ] Capture a per-OS "it launches + lists library" baseline before going further.

## Phase 1 — Native dependencies & data
- [ ] **SQLite**: verify Drift opens the DB + runs migrations on each OS (`sqlite3_flutter_libs` should bundle the native lib; confirm no "sqlite3 not found").
- [ ] **App data dir**: confirm `path_provider` resolves a sane per-OS support dir (`~/Library/Application Support`, `%APPDATA%`, `~/.local/share`) and that the **relative-path library resolution** (`resolveLibraryPath`) still works for imported files.
- [ ] **flutter_secure_storage on Linux**: requires `libsecret-1-dev` (build) + `libsecret`/a keyring at runtime — document the dependency and add graceful fallback if no keyring is present.
- [ ] **pdfium**: confirm `pdfrx` loads pdfium on each OS (it ships prebuilt binaries; verify on a real PDF).

## Phase 2 — EPUB reader on desktop (the blocker)
`flutter_inappwebview` declares **android/ios/macos/windows/web** — **no Linux**.
- [ ] **macOS**: test the existing EPUB reader (WKWebView). Likely works as-is — verify epub.js loads, page modes + progress work, and remote/local sources resolve.
- [ ] **Windows**: requires the **Edge WebView2 runtime** installed on the user's machine. Test; document the runtime prerequisite (and bundle the evergreen installer or detect+prompt).
- [ ] **Linux** (no webview): pick a strategy —
  - [ ] Option A: swap the EPUB engine for a non-WebView renderer on Linux (e.g. parse spine with `archive` + render reflowable HTML in Flutter, or evaluate a Dart/native epub renderer). Highest effort, best result.
  - [ ] Option B: gate EPUB behind `Platform.isLinux` with a clear "not supported on Linux yet" message; ship CBZ+PDF on Linux first.
  - [ ] Option C: use a system-webview plugin that supports Linux (WebKitGTK) if one is viable, behind a platform-conditional import.
- [ ] Abstract the EPUB reader behind an interface so the engine can differ per platform without touching callers.

## Phase 3 — Input adaptation (mouse + keyboard)
The readers are touch-first (`onTapUp` zones, swipe, pinch). Add desktop input:
- [ ] **Keyboard nav** (all readers): ←/→ or PageUp/PageDown = prev/next page; Space = next; Home/End = first/last; Esc = back. Use a `Shortcuts`/`Actions` or `Focus`+`KeyboardListener` wrapper.
- [ ] **Zoom**: Ctrl/Cmd + `+`/`-`/`0`, and Ctrl/Cmd + mouse-wheel for pinch-zoom equivalents (PDF/CBZ `photo_view`/pdfrx).
- [ ] **Scroll**: ensure mouse-wheel scrolls the vertical/scroll reader; show **scrollbars** (desktop users expect them — wrap lists in `Scrollbar`).
- [ ] **Click zones**: keep left/right-third click = page turn (works with mouse already), but add hover cursor affordances.
- [ ] **Right-click context menu**: map the existing long-press action sheet to right-click on cards.
- [ ] **Hover states** on cards/buttons (desktop expectation).

## Phase 4 — Window & responsive UX
- [ ] **Window management** (add `window_manager` or the new Flutter windowing): set min size (~800×600), sensible default size, app title; persist size/position across launches.
- [ ] **Responsive shell**: use a `NavigationRail`/sidebar on wide windows instead of the bottom `NavigationBar`; scale the library grid columns by width (already breakpoint-based — verify at desktop widths).
- [ ] **macOS menu bar**: add a `PlatformMenuBar` (File: Import…, Open…; View: reading modes, fullscreen; Help). Wire to existing actions.
- [ ] Remove/adjust mobile-only chrome (`SafeArea` top insets, status-bar padding) on desktop.
- [ ] Fullscreen / presentation mode for the reader.

## Phase 5 — File import on desktop
- [ ] Verify `file_picker` opens native file + folder dialogs on each OS (multi-select CBZ/PDF/EPUB; folder import).
- [ ] **Drag-and-drop**: add `desktop_drop` so users can drop files/folders onto the window to import.
- [ ] Consider a configurable library root on desktop (vs the app sandbox), since desktop users manage files directly.

## Phase 6 — Packaging, signing & distribution
- [ ] **App identity**: set product name, bundle/app id, version, and per-platform **icons** (macOS `.icns`, Windows `.ico`, Linux `.png` + `.desktop`).
- [ ] **macOS**: `flutter build macos`; set entitlements (network client, user-selected file read/write; decide sandbox vs not); **code-sign** with a Developer ID; **notarize**; package as `.dmg`.
- [ ] **Windows**: `flutter build windows`; package as **MSIX** (`msix` package) or an installer (Inno Setup); code-sign with an Authenticode cert; bundle/detect the **WebView2** runtime.
- [ ] **Linux**: `flutter build linux`; package as **AppImage** and/or **Flatpak**/Snap/`.deb`; declare runtime deps (`libsecret`, GTK, `libsqlite3`); ship a `.desktop` entry + icon.
- [ ] Decide distribution channels (direct download, Mac App Store?, MS Store, Flathub) — note: App Store sandboxing affects file access + may conflict with the EPUB webview.

## Phase 7 — Testing & CI
- [ ] Per-OS smoke test: import a CBZ/PDF/EPUB → cover appears → open → page through (mouse + keyboard) → progress persists on reopen.
- [ ] Server (hybrid) mode on desktop: add a CB8 connection, log in (cookie), browse, read, confirm progress sync.
- [ ] Window resize / multi-monitor / DPI-scaling sanity check on each OS.
- [ ] CI matrix: build macOS (on macOS runner), Windows (windows runner), Linux (ubuntu runner) on tag; attach artifacts.

## Phase 8 — Polish
- [ ] Keyboard-shortcut help/cheat-sheet; settings (default reading mode, theme, library location).
- [ ] App auto-update story (Sparkle/macOS, Squirrel/Windows, or just release notes).
- [ ] Crash/error reporting + logging to a per-OS log file.
- [ ] Accessibility pass (focus order, screen-reader labels) at desktop scale.

---

### Suggested order of attack
1. Phase 0 (get it launching everywhere) → 2. Phase 1 (data works) → 3. **Phase 2 EPUB** (the real risk; decide the Linux story early) → 4. Phase 3 + 4 (make it feel native) → 5. Phase 5 → 6. Phase 6 packaging → 7–8 testing/polish.

**Lowest-risk MVP:** ship **macOS first** (everything works, including EPUB via WKWebView), then Windows (add WebView2), then Linux (after solving the EPUB engine).
