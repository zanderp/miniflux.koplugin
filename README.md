# Miniflux Plugin for KOReader

A KOReader plugin that lets you read RSS entries from a [Miniflux](https://miniflux.app/) server on your e-reader, online or offline.

**Releases:** [zanderp/miniflux.koplugin](https://github.com/zanderp/miniflux.koplugin/releases)

## Features

### Browsing & lists

- **Main list**: Unread, **Read**, Starred, Feeds, Categories, Search, and Local (downloaded). Counts update after actions.
- **Read tab**: Browse all read entries (same order/limit as settings). Long-press **Read** on the main screen for “Remove all from read (up to 1000)”.
- **Unread**: Long-press **Unread** on the main screen for “Mark all as read (up to 1000)”. In the Unread list, first row “Mark all as read (up to 1000)” does the same. Batches of up to 1000; loading until the server responds.
- **Starred**: Bookmarked entries. **Search**: Full-text search via Miniflux API.
- **Feeds & categories**: Navigate by feed or category; mark feed/category as read from selection mode.

### Selection mode & bulk actions

- **Selection**: Long-press an entry or use the check icon to enter selection mode. **Select all** / **Deselect all**; then choose an action.
- **Mark as Read** / **Mark as Unread**: Apply to selected entries; list and main counts refresh after the server responds.
- **Remove**: Mark selected entries as removed on the server (and remove local copies if downloaded). Available in Unread, Read, Starred, feed, category, and search.
- **Download Selected** / **Delete Selected**: Shown when the selection has remote or local entries. Delete removes local files and cleans KOReader history.
- In the **Read** list, the selection menu omits “Mark as Read” (entries are already read); Mark as Unread and Remove remain.

### Reading & HTML viewer

- **Browse**: Feeds, categories, unread, read, starred, and search from your Miniflux server.
- **Read**: Download entries (with optional images) for offline reading, or use the **HTML reader** setting to open articles in-app without saving.
- **HTML viewer**: In-app reader with reflow to screen width, mobile User-Agent for readable layouts, and print-version request when supported. Works on all devices including Kindle. **Images**: The viewer was updated to include images in the in-app (print) preview: it fetches the page HTML, then fetches and inlines external images (up to a limit), sending a Referer so images load correctly; if some images don’t appear (e.g. over the limit or failed to load), use **download mode** with **Include images** for full offline content.
  - **Exit**: Tap **top right** to close the viewer.
  - **Scroll**: Vertical slide to scroll; **horizontal pan** to zoom.
  - **Navigation menu**: Scroll to the **bottom** for: **⌂ Return to Miniflux**, next/previous entry, bookmark, delete, etc.
- **Downloaded entries & images**: To see images in downloaded articles, enable **Include images** in Settings. Downloaded HTML uses a base URL so relative image paths resolve to the entry folder in the reader. Image downloads use a browser User-Agent and proper URL escaping (e.g. `&amp;` → `&`) so that referrer- or URL-sensitive hosts work correctly.
- **Links in downloaded entries**: Tap a link → **Open in HTML viewer**, **Open in browser** (where supported), or **Open image in viewer**. Follow links without leaving the plugin.
- **Navigation**: **← Previous** and **Next →** use the same auto-delete rule as Close/Return; bookmarked entries are never auto-deleted.

### Status, storage & sync

- **Status & bookmarks**: Mark read/unread; **star/unstar** (Miniflux bookmark API). Sync when online. **Mark as read on open** (optional).
- **Storage**: Custom **download location**. Delete single or selected entries; **clear all** downloaded entries. **Auto-delete read on close** (optional). **Bookmarked entries are never auto-deleted**. **Remove from history when deleting** (optional); bulk delete and auto-delete always clean KOReader history.
- **E-ink**: Optional image proxy for e-ink-friendly scaling. Reliable close with full repaint when leaving the reader.
- **More**: Prefetch next N entries (Unread or Starred), image recovery, delete by date range, storage info, delete all images (keep text). Settings persist.

### Menu & updates

- **Tools menu**: Plugin appears under **Tools** (when supported by KOReader) for quicker access.
- **Updates**: Check for updates from [zanderp/miniflux.koplugin](https://github.com/zanderp/miniflux.koplugin/releases) (Settings → Check for updates).

## Installation

1. Download the [latest release](https://github.com/zanderp/miniflux.koplugin/releases/latest) (e.g. `miniflux.koplugin-0.0.20.zip`).
2. Unzip and copy the **miniflux.koplugin** folder into KOReader’s plugin directory.
3. Enable the plugin in KOReader.

## Usage

1. **Settings** (Miniflux → Settings): Server URL and API token. Optional: download location, entries limit, sort order, mark-as-read on open, auto-delete read on close, HTML reader, remove from history when deleting, clear all downloads.
2. **Main list**: Open Miniflux from **Tools** to see Unread, Read, Starred, Feeds, Categories, Search, and Local.
3. **Mark all as read**: Long-press **Unread** on the main screen, or in the Unread list tap the first row “Mark all as read (up to 1000)”. Confirm; wait for the server; list and counts refresh.
4. **Remove all from read**: Long-press **Read** on the main screen, or in the Read list tap “Remove all from read (up to 1000)”. Confirm; wait for the server; list refreshes.
5. **Selection mode**: Long-press an entry (or use the check icon). Select all/deselect all, then **Mark as Read**, **Mark as Unread**, **Remove**, **Download Selected**, or **Delete Selected** (when applicable).
6. **Search**: Use Search from the main list; open results from the Miniflux API.
7. **Starred**: Open Starred; use **★ Toggle bookmark** in the end-of-entry dialog to star/unstar.
8. **Download**: Tap an entry to download and open. Long-press for selection mode and batch download.
9. **HTML viewer**: Tap **top right** to exit. Vertical slide to scroll; horizontal pan to zoom. Scroll to the **bottom** for the navigation menu.
10. **Storage** (Settings): Storage info, Delete by date range, Delete all images (keep text), Image recovery.
11. **Prefetch** (Settings → Prefetch next entries): Set count (0–5), then “From Unread” or “From Starred”.

## Development Status

### ✅ Core Features

- [x] **Feed and Category Browsing**
  - [x] List feeds and categories from Miniflux
  - [x] Navigate by feed/category
- [x] **Entry lists**
  - [x] Unread, **Read**, Starred, Feeds, Categories, Search, Local
  - [x] Counts refresh after bulk/selection actions
- [x] **Entry Management**
  - [x] Download entries (text + optional images) for offline reading
  - [x] Context-aware next/previous and return to browser
- [x] **Status & Bookmarks**
  - [x] Mark entries read/unread (single and selection)
  - [x] Star/unstar entries (Miniflux bookmark API)
  - [x] Auto-mark as read when opening (optional)
  - [x] Sync when online
- [x] **Offline**
  - [x] Full offline reading of downloaded entries
  - [x] Local file management and custom download location

### ✅ Bulk & selection actions

- [x] **Mark all as read (up to 1000)**
  - [x] Long-press Unread on main screen; confirm; loading until server responds
  - [x] First row in Unread list “Mark all as read (up to 1000)”
- [x] **Remove all from read (up to 1000)**
  - [x] Long-press Read on main screen; confirm; loading until server responds
  - [x] First row in Read list “Remove all from read (up to 1000)”
- [x] **Selection mode**
  - [x] Long-press or check icon; Select all / Deselect all
  - [x] Mark as Read / Mark as Unread on selected entries
  - [x] Remove selected (mark as removed on server; delete local copies)
  - [x] Download Selected / Delete Selected when applicable
  - [x] Read list: no “Mark as Read”; Mark as Unread and Remove available

### ✅ Storage management

- [x] **Bulk entry deletion**
  - [x] Delete selected entries (local)
  - [x] Clear all downloaded entries (Settings)
  - [x] Delete by date range (1 week, 1 month, 3 months, 6 months)
  - [x] Storage info (entry count, total size, image count/size)
- [x] **Selective image management**
  - [x] Delete all images (keep text) (Settings)
  - [x] Image storage statistics (in Storage info)

### ✅ Background & UX

- [x] **Cache & refresh**
  - [x] Cache invalidation after bulk/selection updates so counts and lists match the server
- [x] **Prefetching**
  - [x] Configurable prefetch count (0, 1, 2, 3, 5); Prefetch from Unread / Prefetch from Starred
- [x] **Image recovery**
  - [x] Re-download missing images for all downloaded entries (Settings)
- [x] **Menu & updates**
  - [x] Plugin in main Tools menu (when supported)
  - [x] Check for updates from GitHub (zanderp/miniflux.koplugin)

### ✅ Reading experience

- [x] **Search and organization**
  - [x] Full-text search (Miniflux API)
  - [x] Starred entries list and toggle bookmark
- [x] **Reading options**
  - [x] Auto-delete read on close (optional)
  - [x] Use HTML reader setting (download vs in-app HTML)
  - [x] Remove from history when deleting (optional)
  - [x] Return to Miniflux in downloaded mode; list refreshes so read/starred state is visible
  - [x] Bookmarked entries never auto-deleted
  - [x] Previous/Next and auto-delete rule consistent with Close/Return

## Technical details

- **API**: Miniflux REST API (entries, feeds, categories, bookmark, search, status updates).
- **Structure**: API layer, domains (entries, feeds, categories), browser UI, reader integration.
- **Offline-first**: Works without network for downloaded entries; status and bookmark changes sync when online.

## Release notes

See [RELEASE_NOTES.md](RELEASE_NOTES.md) for version history (e.g. 0.0.19).

## Development

### Nix (recommended)

```bash
direnv allow   # or: nix develop
# Tools: lua, selene, stylua, task
```

### Manual

```bash
cargo install stylua selene
```

### Commands

```bash
task check     # Lint and check
task fmt-fix   # Format with Stylua
task build    # Build plugin for distribution
```

### Testing with KOReader

After `task build`, symlink `dist/miniflux.koplugin` into KOReader’s plugins directory and run KOReader with `-d` for debug logs; filter with `grep -E "Miniflux"` if needed.

## Contributing

Contributions are welcome: [open an issue](https://github.com/zanderp/miniflux.koplugin/issues) or submit a pull request at [zanderp/miniflux.koplugin](https://github.com/zanderp/miniflux.koplugin).
