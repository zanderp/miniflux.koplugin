--[[--
Internal flag: set when user presses ★ Toggle bookmark in the end-of-entry dialog.
When they reopen the menu and press Return to Miniflux or Close, we skip auto-delete.
Cleared after we use it.
--]]
return { toggled = false }
