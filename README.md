# Miniflux Plugin for KOReader

A KOReader plugin that lets you read RSS entries from a [Miniflux](https://miniflux.app/) server on your e-reader, online or offline.

## Features

- **Browse**: Feeds, categories, unread, **starred** (bookmarks), and **search** entries from your Miniflux server.
- **Read**: Download entries (with optional images) for offline reading, or use the **HTML reader** setting to open in-app without saving (when enabled).
- **Navigate**: Next/previous entry from the end-of-entry dialog. In the **HTML reader**, **Return to Miniflux** restores your previous view; in the **normal** (downloaded) viewer, **Close** opens the KOReader home folder and Back/Home leaves the reader.
- **Status & bookmarks**: Mark read/unread; **star/unstar** entries (Miniflux bookmark API). Sync runs when online.
- **Storage**: Custom **download location** (pick or create a folder). **Delete** single or selected entries. **Clear all** downloaded entries. **Auto-delete read on close** option to remove local copy when you leave a read entry.
- **E-ink**: Optional image proxy for e-ink-friendly scaling.
- **Reliable close**: In normal flow the document viewer opens on top of the plugin; when you return (Home / Back to Miniflux) and press **X**, the plugin and browser close in one step with a full repaint so you return to KOReader’s UI without a stuck screen.
- **HTML viewer** (Use HTML reader): In-app viewer with reflow to screen width, mobile User-Agent for readable layouts, and print-version request when supported.

## Installation

1. Download the [latest release](https://github.com/AlgusDark/miniflux.koplugin/releases/latest).
2. Unzip and copy the **miniflux.koplugin** folder into KOReader’s plugin directory.
3. Enable the plugin in KOReader.

## Usage

1. **Settings** (Miniflux → Settings): Set server URL and API token. Optionally set download location, entries limit, sort order, mark-as-read on open, auto-delete read on close, HTML reader, and clear all downloads.
2. **Read entries**: Open “Read entries” to see Unread, Starred, Feeds, Categories, Search, and Local (downloaded).
3. **Search** (issue [#31](https://github.com/AlgusDark/miniflux.koplugin/issues/31)): Use “Search” from the main list, enter a term, and open results from the Miniflux API.
4. **Starred**: Open “Starred” to see bookmarked entries. Use “★ Toggle bookmark” in the end-of-entry dialog to star/unstar.
5. **Download**: Tap an entry to download and open it. Long-press to enter selection mode and batch download.
6. **Return / Close**: In the **HTML reader** end-of-entry dialog, “Return to Miniflux” closes the viewer and returns to the same list. In the **normal** (downloaded) viewer, “Close” opens the KOReader home folder in the file manager; use Back/Home to leave the reader.
7. **Storage** (Settings): **Storage info** shows entry count, total size, image count/size. **Delete by date range** (1 week / 1 month / 3 months / 6 months), **Delete all images (keep text)**, **Image recovery** (re-download missing images).
8. **Prefetch** (Settings → Prefetch next entries): Set count (0–5), then “From Unread” or “From Starred” to download the next N undownloaded entries.

## Development Status

### ✅ Core Features

- [x] **Feed and Category Browsing**
  - [x] List feeds and categories from Miniflux
  - [x] Navigate by feed/category
- [x] **Entry Management**
  - [x] Browse by feed, category, unread, **starred**, and **search**
  - [x] Download entries (text + optional images) for offline reading
  - [x] Context-aware next/previous and return to browser
- [x] **Status & Bookmarks**
  - [x] Mark entries read/unread
  - [x] **Star/unstar entries** (PUT /v1/entries/:id/bookmark)
  - [x] Auto-mark as read when opening (optional)
  - [x] Batch mark as read when offline
- [x] **Offline**
  - [x] Full offline reading of downloaded entries
  - [x] Local file management and custom download location

### 🚧 Storage Management

- [x] **Bulk Entry Deletion**
  - [x] Delete selected entries
  - [x] **Clear all downloaded entries** (Settings)
  - [x] **Delete by date range** (1 week, 1 month, 3 months, 6 months)
  - [x] **Storage info** (entry count, total size, image count/size)
- [x] **Selective Image Management**
  - [x] **Delete all images** while keeping entry text (Settings)
  - [x] **Image storage statistics** (in Storage info)

### 🔄 Background Operations

- [x] **Prefetching**
  - [x] Configurable prefetch count (0, 1, 2, 3, 5); “Prefetch from Unread” / “Prefetch from Starred”
- [x] **Image Recovery**
  - [x] Re-download missing images for all downloaded entries (Settings)

### 📊 Enhanced Reading Experience

- [x] **Search and Organization**
  - [x] **Full-text search** (Miniflux API `search` query; issue #31)
  - [x] **Starred entries** list and toggle bookmark
- [x] **Reading options**
  - [x] **Auto-delete read on close** (optional)
  - [x] **Use HTML reader** setting (experimental; download vs in-app HTML)
  - [ ] **Return to Miniflux in normal (downloaded) mode** — Not implemented; normal mode has Close (KOReader home) and Cancel; Return to Miniflux is only in the HTML reader.

## Technical Details

- **API**: Uses Miniflux REST API (entries, feeds, categories, bookmark toggle, search).
- **Modular layout**: API layer, domains (entries, feeds, categories), browser UI, reader integration.
- **Offline-first**: Works without network for downloaded entries; status and bookmark changes sync when online.

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
task build     # Build plugin for distribution
```

### Testing with KOReader

After `task build`, symlink `dist/miniflux.koplugin` into KOReader’s plugins directory and run KOReader with `-d` for debug logs; filter with `grep -E "Miniflux"` if needed.

## Contributing

Contributions are welcome: bug reports, feature ideas, pull requests, and documentation improvements.
