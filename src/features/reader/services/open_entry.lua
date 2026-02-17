--[[--
**Entry Reader Service**

Handles opening miniflux entries with KOReader's ReaderUI. This service manages
the complete workflow of opening entries and context for entry navigation.

We do *not* close the browser/plugin when opening an entry: the stack stays
Plugin -> Browser -> Reader. When the user closes the reader (or uses "Return to
Miniflux" / "⌂ Read entries" from the end-of-entry dialog), they are back at the
browser and X closes normally. Re-showing closed widgets after the reader caused
bad state and stuck close.
--]]

local MinifluxEvent = require('shared/event')
local logger = require('logger')

local EntryPaths = require('domains/utils/entry_paths')
local EntryMetadata = require('domains/utils/entry_metadata')

---@class MinifluxContext
---@field type string Context type ("feed", "category", "global", "local")
---@field id? number Feed or category ID
---@field ordered_entries? table[] Ordered entries for navigation

---@class OpenEntryOptions
---@field context? MinifluxContext Navigation context for entry navigation
---@field miniflux? Miniflux Plugin instance (for mark-as-read on open)

---@class EntryReader
local EntryReader = {}

---Open a miniflux entry with ReaderUI
---@param file_path string Path to the entry HTML file to open
---@param opts? OpenEntryOptions Options for entry opening
---@return nil
function EntryReader.openEntry(file_path, opts)
    opts = opts or {}
    local context = opts.context
    logger.dbg('[Miniflux:EntryWorkflow] openEntry', file_path and file_path:match('[^/]+$') or file_path, 'context:', context and context.type or 'nil')

    if context then
        MinifluxEvent:broadcastMinifluxBrowserContextChange({ context = context })
    end

    -- Mark as read on open (normal/downloaded view): run here so it always fires regardless of DocSettingsLoad delivery
    local miniflux = opts.miniflux
    if miniflux and miniflux.reader_entry_service and file_path and EntryPaths.isMinifluxEntry(file_path) then
        local entry_id = EntryPaths.extractEntryIdFromPath(file_path)
        if entry_id then
            local meta = EntryMetadata.loadMetadata(entry_id)
            local status = (meta and meta.status) or 'unread'
            miniflux.reader_entry_service:performAutoMarkAsRead(entry_id, status)
        end
    end

    local ReaderUI = require('apps/reader/readerui')
    ReaderUI:showReader(file_path)
end

return EntryReader
