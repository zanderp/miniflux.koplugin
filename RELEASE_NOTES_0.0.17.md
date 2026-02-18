# Release notes – Miniflux plugin 0.0.17

## Reader & navigation

- **HTML reader**: End-of-entry dialog shows **⌂ Return to Miniflux**; normal (downloaded) flow shows **Close** (opens KOReader home) and Cancel.
- **Close** in normal mode now opens the **KOReader home folder** (not the Miniflux folder) when leaving a downloaded entry.
- **Mark as read on open** now runs correctly when opening a downloaded entry (no longer relies on DocSettingsLoad).

## Settings

- **Use HTML reader** and **Auto-delete read on close** choices are now **persisted** correctly when toggled from the menu.
- New setting: **Remove from history when deleting** (default: ON). When enabled, manually deleting a local entry also removes it from KOReader’s read history so you don’t see “entry.html (deleted)” in history. Bulk delete and auto-delete on close **always** clean history regardless of this setting.

## Auto-delete & history

- **Auto-delete read on close** is respected in normal mode: when you tap **Close** at end-of-entry and the entry is read, the local copy is deleted and KOReader home is opened.
- **History cleanup**: When an entry is deleted (single, bulk, or auto-delete on close), the plugin removes it from KOReader’s read history so deleted entries don’t stay as dimmed items. Bulk delete and auto-delete on close always perform this cleanup; single “Delete local entry” uses the **Remove from history when deleting** setting.

## Other

- Internal cleanup and fixes for cache invalidation and folder opening behavior.
