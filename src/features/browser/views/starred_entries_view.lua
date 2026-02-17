--[[--
Starred Entries View for Miniflux Browser

Shows bookmarked/starred entries (Miniflux API: starred=true).
@module miniflux.browser.views.starred_entries_view
--]]

local EntriesView = require('features/browser/views/entries_view')
local _ = require('gettext')

local StarredEntriesView = {}

---@alias StarredEntriesViewConfig {entries: Entries, settings: MinifluxSettings, page_state?: number, onSelectItem: function}

---Complete starred entries view - returns view data for rendering
---@param config StarredEntriesViewConfig
---@return table|nil View data for browser rendering, or nil on error
function StarredEntriesView.show(config)
    local ViewUtils = require('features/browser/views/view_utils')

    local result, err = config.entries:getEntries({
        starred = true,
        order = config.settings.order,
        direction = config.settings.direction,
        limit = config.settings.limit,
        status = { 'unread', 'read' },
    }, {
        dialogs = {
            loading = { text = _('Loading starred entries...') },
            error = { text = _('Failed to load starred entries') },
        },
    })

    if err or not result then
        return nil
    end
    local entries = result.entries or {}

    local menu_items = EntriesView.buildItems({
        entries = entries,
        show_feed_names = true,
        hide_read_entries = false,
        onSelectItem = config.onSelectItem,
    })

    return {
        title = _('Starred Entries'),
        items = menu_items,
        page_state = config.page_state,
        subtitle = ViewUtils.buildSubtitle({
            count = #entries,
            item_type = 'entries',
        }),
    }
end

return StarredEntriesView
