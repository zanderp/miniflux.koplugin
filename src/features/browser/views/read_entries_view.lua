--[[--
Read Entries View for Miniflux Browser

Shows read entries (Miniflux API: status=read).
@module miniflux.browser.views.read_entries_view
--]]

local EntriesView = require('features/browser/views/entries_view')
local _ = require('gettext')

local ReadEntriesView = {}

---@alias ReadEntriesViewConfig {entries: Entries, settings: MinifluxSettings, page_state?: number, onSelectItem: function, onRemoveAllFromRead?: function}

---Complete read entries view - returns view data for rendering
---@param config ReadEntriesViewConfig
---@return table|nil View data for browser rendering, or nil on error
function ReadEntriesView.show(config)
    local ViewUtils = require('features/browser/views/view_utils')

    local entries, err = config.entries:getReadEntries({
        dialogs = {
            loading = { text = _('Loading read entries...') },
            error = { text = _('Failed to load read entries') },
        },
    })

    if err then
        return nil
    end
    ---@cast entries -nil

    local menu_items = EntriesView.buildItems({
        entries = entries,
        show_feed_names = true,
        hide_read_entries = false,
        onSelectItem = config.onSelectItem,
    })

    if config.onRemoveAllFromRead and #entries > 0 then
        table.insert(menu_items, 1, {
            text = _('Remove all from read (up to 1000)'),
            mandatory = '',
            callback = config.onRemoveAllFromRead,
        })
    end

    return {
        title = _('Read Entries'),
        items = menu_items,
        page_state = config.page_state,
        subtitle = ViewUtils.buildSubtitle({
            count = #entries,
            item_type = 'entries',
        }),
    }
end

return ReadEntriesView
