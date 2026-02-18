--[[--
**Miniflux End of Book Module**

This module handles the end-of-book/end-of-entry dialog functionality that appears
when users reach the end of a Miniflux RSS entry. It provides navigation options,
status management, and local entry operations.

This module integrates with KOReader's event system by extending Widget and
overriding the ReaderStatus onEndOfBook behavior specifically for Miniflux entries.
--]]

local EventListener = require('ui/widget/eventlistener')
local UIManager = require('ui/uimanager')
local ButtonDialog = require('ui/widget/buttondialog')
local Notification = require('shared/widgets/notification')
local Device = require('device')
local util = require('util')
local _ = require('gettext')
local logger = require('logger')

local EntryPaths = require('domains/utils/entry_paths')
local EntryValidation = require('domains/utils/entry_validation')
local EntryMetadata = require('domains/utils/entry_metadata')

---@class MinifluxEndOfBook : EventListener
---@field miniflux Miniflux The main Miniflux plugin instance
---@field wrapped_method table The wrapped method object
local MinifluxEndOfBook = EventListener:extend({
    name = 'miniflux_end_of_book',
    wrapped_method = nil,
    miniflux = nil,
})

---Initialize the module and wrap the onEndOfBook method
function MinifluxEndOfBook:init()
    if self.miniflux and self.miniflux.ui and self.miniflux.ui.status then
        local reader_status = self.miniflux.ui.status

        self.wrapped_method = util.wrapMethod(reader_status, 'onEndOfBook', function(...)
            if self:shouldShowCustomDialog() then
                return self:showCustomEndOfBookDialog()
            else
                return self.wrapped_method:raw_method_call(...)
            end
        end)
    end
end

---Check if we should show custom dialog for miniflux entries
---@return boolean
function MinifluxEndOfBook:shouldShowCustomDialog()
    if
        not self.miniflux.ui
        or not self.miniflux.ui.document
        or not self.miniflux.ui.document.file
    then
        return false
    end

    local file_path = self.miniflux.ui.document.file
    -- Check if this is a miniflux HTML entry
    return file_path:match('/miniflux/') and file_path:match('%.html$')
end

---Show custom end of book dialog for miniflux entries
---@return boolean
function MinifluxEndOfBook:showCustomEndOfBookDialog()
    local file_path = self.miniflux.ui.document.file

    -- Extract entry ID from path and convert to number
    local entry_id_str = file_path:match('/miniflux/(%d+)/')
    local entry_id = entry_id_str and tonumber(entry_id_str)

    if entry_id then
        -- Show the end of entry dialog with entry info as parameter
        local entry_info = {
            file_path = file_path,
            entry_id = entry_id,
        }

        self:showDialog(entry_info)
        return true -- Handled by custom dialog
    end

    return false -- Should not happen if shouldShowCustomDialog works correctly
end

---Show end of entry dialog with navigation options
---@param entry_info table Entry information: entry_id (required), file_path (optional for local read), from_html_viewer (optional), on_return_to_browser (optional callback when opened from HTML viewer)
---@return table|nil Dialog reference for caller management or nil if failed
function MinifluxEndOfBook:showDialog(entry_info)
    if not entry_info or not entry_info.entry_id then
        logger.dbg('[Miniflux:EndOfBook] showDialog skipped: no entry_info or entry_id')
        return nil
    end
    logger.dbg('[Miniflux:EndOfBook] showDialog entry_id:', entry_info.entry_id)

    local from_html_viewer = entry_info.from_html_viewer or not entry_info.file_path or entry_info.file_path == ''

    if not self.miniflux or not self.miniflux.reader_entry_service then
        return nil
    end

    -- Get ReaderUI's DocSettings to read current status (includes optimistic updates)
    local doc_settings = self.miniflux.ui and self.miniflux.ui.doc_settings

    -- Load current metadata from doc_settings cache (not SDR) to see optimistic updates
    local metadata = doc_settings and doc_settings:readSetting('miniflux_entry')
    local sdr_metadata = not (metadata and metadata.status) and EntryMetadata.loadMetadata(entry_info.entry_id)

    -- Use status for business logic (fallback to SDR if doc_settings unavailable)
    local entry_status = (metadata and metadata.status) or (sdr_metadata and sdr_metadata.status) or 'unread'
    local entry_starred = (metadata and metadata.starred == true) or (sdr_metadata and sdr_metadata.starred == true) or false

    -- Re-read current starred/status at action time. If user toggled bookmark this session, skip auto-delete.
    local BookmarkToggledFlag = require('shared/bookmark_toggled_flag')
    local function getCurrentStarredAndStatus()
        if BookmarkToggledFlag.toggled then
            local meta = doc_settings and doc_settings:readSetting('miniflux_entry')
            local sdr = not (meta and meta.status) and EntryMetadata.loadMetadata(entry_info.entry_id)
            local status = (meta and meta.status) or (sdr and sdr.status) or 'unread'
            return true, status
        end
        local meta = doc_settings and doc_settings:readSetting('miniflux_entry')
        local sdr = not (meta and meta.status) and EntryMetadata.loadMetadata(entry_info.entry_id)
        local status = (meta and meta.status) or (sdr and sdr.status) or 'unread'
        local starred = (meta and meta.starred == true) or (sdr and sdr.starred == true) or false
        return starred, status
    end

    -- Helper function to navigate to entry with consistent parameters
    local function navigateToEntry(direction)
        local Navigation = require('features/reader/services/navigation_service')
        Navigation.navigateToEntry(entry_info, self.miniflux, { direction = direction })
    end

    -- Use utility functions for button text and callback
    local mark_button_text = EntryValidation.getStatusButtonText(entry_status)
    local mark_callback
    if EntryValidation.isEntryRead(entry_status) then
        mark_callback = function()
            self.miniflux.reader_entry_service:changeEntryStatus(
                entry_info.entry_id,
                'unread',
                doc_settings
            )
        end
    else
        mark_callback = function()
            self.miniflux.reader_entry_service:changeEntryStatus(
                entry_info.entry_id,
                'read',
                doc_settings
            )
        end
    end

    -- Declare dialog variable first for proper scoping in callbacks
    ---@type ButtonDialog
    local dialog
    local row2 = {
        {
            text = mark_button_text,
            callback = function()
                UIManager:close(dialog)
                mark_callback()
            end,
        },
        {
            text = _('★ Toggle bookmark'),
            callback = function()
                UIManager:close(dialog)
                local entry_id = entry_info.entry_id
                local miniflux = self.miniflux
                -- Defer toggle so dialog close completes first; run in pcall to avoid crashing the app
                UIManager:scheduleIn(0, function()
                    if not EntryValidation.isValidId(entry_id) then
                        Notification:warning(_('Cannot update bookmark: invalid entry ID'))
                        return
                    end
                    if not miniflux or not miniflux.entries then
                        Notification:warning(_('Cannot update bookmark'))
                        return
                    end
                    local ok, ret = pcall(function()
                        local r, e = miniflux.entries:toggleBookmark(entry_id)
                        return { result = r, err = e }
                    end)
                    if not ok then
                        Notification:warning(_('Failed to update bookmark'))
                        return
                    end
                    local err = type(ret) == 'table' and ret.err or nil
                    if err then
                        Notification:warning(err.message or _('Failed to update bookmark'))
                    else
                        Notification:success(_('Bookmark updated'))
                        -- Persist starred so Close / Return to Miniflux see it (including after reopening dialog).
                        BookmarkToggledFlag.toggled = true
                        if doc_settings then
                            local e = doc_settings:readSetting('miniflux_entry')
                            if e and e.entry_id == entry_id then
                                e.starred = not e.starred
                                doc_settings:saveSetting('miniflux_entry', e)
                                if doc_settings.flush then
                                    doc_settings:flush()
                                end
                                pcall(EntryMetadata.updateMetadata, entry_id, { starred = e.starred })
                            end
                        end
                    end
                end)
            end,
        },
    }
    if not from_html_viewer then
        table.insert(row2, 1, {
            text = _('⚠ Delete local entry'),
            callback = function()
                UIManager:close(dialog)
                if not EntryValidation.isValidId(entry_info.entry_id) then
                    Notification:warning(_('Cannot delete: invalid entry ID'))
                    return
                end
                local success = EntryPaths.deleteLocalEntry(entry_info.entry_id, { open_folder = false })
                if success then
                    local ReaderUI = require('apps/reader/readerui')
                    if ReaderUI.instance then
                        ReaderUI.instance:onClose()
                    end
                    UIManager:scheduleIn(0.15, function()
                        if self and self.miniflux then
                            pcall(function()
                                self:returnToBrowser()
                            end)
                        end
                    end)
                end
            end,
        })
    end
    local buttons = {
        {
            {
                text = _('← Previous'),
                callback = function()
                    UIManager:close(dialog)
                    local entry_id_to_delete
                    if not from_html_viewer then
                        local current_starred, current_status = getCurrentStarredAndStatus()
                        local auto_delete = self.miniflux.settings.auto_delete_read_on_close
                            and EntryValidation.isEntryRead(current_status)
                            and not current_starred
                        if auto_delete and EntryValidation.isValidId(entry_info.entry_id) then
                            entry_id_to_delete = entry_info.entry_id
                        end
                        BookmarkToggledFlag.toggled = false
                    end
                    if entry_info.on_before_navigate then
                        entry_info.on_before_navigate()
                    end
                    if self.miniflux then
                        navigateToEntry('previous')
                    end
                    if entry_id_to_delete then
                        UIManager:scheduleIn(0, function()
                            EntryPaths.deleteLocalEntry(entry_id_to_delete, { silent = true, always_remove_from_history = true })
                        end)
                    end
                end,
            },
            {
                text = _('Next →'),
                callback = function()
                    UIManager:close(dialog)
                    local entry_id_to_delete
                    if not from_html_viewer then
                        local current_starred, current_status = getCurrentStarredAndStatus()
                        local auto_delete = self.miniflux.settings.auto_delete_read_on_close
                            and EntryValidation.isEntryRead(current_status)
                            and not current_starred
                        if auto_delete and EntryValidation.isValidId(entry_info.entry_id) then
                            entry_id_to_delete = entry_info.entry_id
                        end
                        BookmarkToggledFlag.toggled = false
                    end
                    if entry_info.on_before_navigate then
                        entry_info.on_before_navigate()
                    end
                    if self.miniflux then
                        navigateToEntry('next')
                    end
                    if entry_id_to_delete then
                        UIManager:scheduleIn(0, function()
                            EntryPaths.deleteLocalEntry(entry_id_to_delete, { silent = true, always_remove_from_history = true })
                        end)
                    end
                end,
            },
        },
        row2,
        (function()
            -- row3: Return to Miniflux (when we have a return path), Close (normal mode), Cancel
            local row3 = {
                {
                    text = _('Cancel'),
                    callback = function()
                        UIManager:close(dialog)
                    end,
                },
            }
            local has_return_to_browser = from_html_viewer and entry_info.on_return_to_browser
            -- Use shared module so reader (which may load a separate plugin copy) sees the same context as main.
            local BrowserContext = require('shared/browser_context')
            local ctx = BrowserContext.context
            local has_browser_context = not from_html_viewer and ctx and ctx.type

            -- ⌂ Return to Miniflux: HTML viewer uses callback; normal mode closes reader then refresh listing
            if has_return_to_browser then
                table.insert(row3, 1, {
                    text = _('⌂ Return to Miniflux'),
                    callback = function()
                        UIManager:close(dialog)
                        entry_info.on_return_to_browser()
                    end,
                })
            elseif has_browser_context then
                table.insert(row3, 1, {
                    text = _('⌂ Return to Miniflux'),
                    callback = function()
                        UIManager:close(dialog)
                        local current_starred, current_status = getCurrentStarredAndStatus()
                        local LastReturnedEntry = require('shared/last_returned_entry')
                        LastReturnedEntry.entry_id = entry_info.entry_id
                        LastReturnedEntry.is_read = EntryValidation.isEntryRead(current_status)
                        LastReturnedEntry.is_starred = current_starred
                        BookmarkToggledFlag.toggled = false
                        local ReaderUI = require('apps/reader/readerui')
                        if ReaderUI.instance then
                            ReaderUI.instance:onClose()
                        end
                        -- Refresh the listing when returning so it shows updated state (e.g. starred, read).
                        UIManager:scheduleIn(0.2, function()
                            local MainInstance = require('shared/main_instance')
                            local miniflux = MainInstance.main_instance
                            if miniflux and miniflux.browser then
                                pcall(function()
                                    miniflux.browser:refreshCurrentViewData()
                                end)
                                UIManager:setDirty('all', 'full')
                            end
                        end)
                    end,
                })
            end

            -- Close: available in both flows (HTML viewer and normal). Opens KOReader home; in dialog applies auto-delete when setting on.
            table.insert(row3, 1, {
                text = _('Close'),
                callback = function()
                    UIManager:close(dialog)
                    local entry_id = entry_info.entry_id
                    local current_starred, current_status = getCurrentStarredAndStatus()
                    local auto_delete = self.miniflux.settings.auto_delete_read_on_close
                        and EntryValidation.isEntryRead(current_status)
                        and not current_starred
                    BookmarkToggledFlag.toggled = false
                    if from_html_viewer then
                        -- HTML viewer: close the viewer first (return to browser), then open KOReader home.
                        if entry_info.on_return_to_browser then
                            entry_info.on_return_to_browser()
                        end
                        UIManager:scheduleIn(0.15, function()
                            if auto_delete and EntryValidation.isValidId(entry_id) then
                                EntryPaths.deleteLocalEntry(entry_id, { silent = true, always_remove_from_history = true })
                            end
                            EntryPaths.openKoreaderHomeFolder()
                        end)
                    else
                        -- Normal (downloaded) flow: close reader then open home; optional auto-delete.
                        if auto_delete and EntryValidation.isValidId(entry_id) then
                            local ReaderUI = require('apps/reader/readerui')
                            if ReaderUI.instance then
                                ReaderUI.instance:onClose()
                            end
                            UIManager:scheduleIn(0.15, function()
                                EntryPaths.deleteLocalEntry(entry_id, { silent = true, always_remove_from_history = true })
                                EntryPaths.openKoreaderHomeFolder()
                            end)
                        else
                            EntryPaths.openKoreaderHomeFolder()
                        end
                    end
                end,
            })
            return row3
        end)(),
    }

    -- Create dialog and assign to the pre-declared variable
    dialog = ButtonDialog:new({
        name = 'miniflux_end_of_entry',
        title = _("You've reached the end of the entry.\nWhat would you like to do?"),
        title_align = 'center',
        buttons = buttons,
    })

    -- Enhance dialog with physical key handlers for navigation (inline)
    if Device:hasKeys() then
        -- Add key event handlers to the dialog
        ---@diagnostic disable: inject-field
        dialog.key_events = dialog.key_events or {}

        -- Navigate to previous entry (logical "back" direction)
        dialog.key_events.NavigatePrevious = {
            { Device.input.group.PgBack }, -- Page back buttons
            event = 'NavigateTo',
            args = 'previous',
        }

        -- Navigate to next entry (logical "forward" direction)
        dialog.key_events.NavigateNext = {
            { Device.input.group.PgFwd }, -- Page forward buttons
            event = 'NavigateTo',
            args = 'next',
        }
    end

    ---@param direction 'previous'|'next' # Direction of where to navigate
    -- selene: allow(shadowing)
    ---@diagnostic disable: inject-field
    function dialog:onNavigateTo(direction)
        UIManager:close(dialog)
        local entry_id_to_delete
        if not from_html_viewer then
            local current_starred, current_status = getCurrentStarredAndStatus()
            local auto_delete = self.miniflux.settings.auto_delete_read_on_close
                and EntryValidation.isEntryRead(current_status)
                and not current_starred
            if auto_delete and EntryValidation.isValidId(entry_info.entry_id) then
                entry_id_to_delete = entry_info.entry_id
            end
            BookmarkToggledFlag.toggled = false
        end
        if entry_info.on_before_navigate then
            entry_info.on_before_navigate()
        end
        navigateToEntry(direction)
        if entry_id_to_delete then
            UIManager:scheduleIn(0, function()
                EntryPaths.deleteLocalEntry(entry_id_to_delete, { silent = true, always_remove_from_history = true })
            end)
        end
        return true
    end

    -- Show dialog and return reference for caller management
    UIManager:show(dialog)
    return dialog
end

---Return to the browser view where the user was before opening this entry.
---Populates browser paths so the back button works (see PR #62 review).
---When browser/plugin were closed for the reader, re-show plugin first and reset browser state so X closes cleanly.
---Uses shared main_instance when in reader context (reader's plugin instance has no .browser in stack).
function MinifluxEndOfBook:returnToBrowser()
    logger.dbg('[Miniflux:EndOfBook] returnToBrowser')
    local MainInstance = require('shared/main_instance')
    local miniflux = MainInstance.main_instance or self.miniflux
    if not miniflux or not miniflux.browser then
        logger.dbg('[Miniflux:EndOfBook] returnToBrowser: no main miniflux or browser')
        return
    end
    local was_closed = not UIManager:isWidgetShown(miniflux)
    if was_closed then
        logger.dbg('[Miniflux:EndOfBook] returnToBrowser: re-showing plugin first')
        UIManager:show(miniflux)
    end
    -- Always reset browser state when returning from reader so X closes cleanly (no stale overlay/paths).
    miniflux.browser.paths = {}
    miniflux.browser.current_overlay = nil

    local context = miniflux:getBrowserContext()

    if not context or not context.type then
        logger.dbg('[Miniflux:EndOfBook] returnToBrowser: no context, opening main')
        miniflux.browser:open()
        return
    end
    logger.dbg('[Miniflux:EndOfBook] returnToBrowser context:', context.type, context.id or context.search or '')

    local view_name
    local nav_context
    local nav_state

    if context.type == 'feed' then
        table.insert(miniflux.browser.paths, { from = 'main', to = 'feeds' })
        nav_state = { from = 'feeds', to = 'feed_entries' }
        view_name = 'feed_entries'
        nav_context = { feed_id = context.id }
    elseif context.type == 'category' then
        table.insert(miniflux.browser.paths, { from = 'main', to = 'categories' })
        nav_state = { from = 'categories', to = 'category_entries' }
        view_name = 'category_entries'
        nav_context = { category_id = context.id }
    elseif context.type == 'unread' then
        nav_state = { from = 'main', to = 'unread_entries' }
        view_name = 'unread_entries'
    elseif context.type == 'starred' then
        nav_state = { from = 'main', to = 'starred_entries' }
        view_name = 'starred_entries'
    elseif context.type == 'search' and context.search then
        nav_state = { from = 'main', to = 'search_entries', context = { search = context.search } }
        view_name = 'search_entries'
        nav_context = { search = context.search }
    elseif context.type == 'local' then
        nav_state = { from = 'main', to = 'local_entries' }
        view_name = 'local_entries'
    else
        view_name = 'main'
    end

    miniflux.browser:navigate({
        view_name = view_name,
        context = nav_context,
        pending_nav_state = nav_state,
    })

    -- The reader created a separate plugin instance; it may still be on the stack. Close it so we're left with the main instance's browser only (otherwise X closes the wrong one and the other stays).
    local reader_plugin = self.miniflux
    if reader_plugin and reader_plugin ~= miniflux and UIManager:isWidgetShown(reader_plugin) then
        logger.dbg('[Miniflux:EndOfBook] returnToBrowser: closing reader plugin instance')
        UIManager:close(reader_plugin)
    end
end

---Cleanup method - revert the wrapped method
function MinifluxEndOfBook:onCloseWidget()
    if self.wrapped_method then
        self.wrapped_method:revert()
        self.wrapped_method = nil
    end
end

return MinifluxEndOfBook
