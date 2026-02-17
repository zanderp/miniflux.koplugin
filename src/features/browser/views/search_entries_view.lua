--[[--
Search Entries View (issue #31)

Shows entries matching a search query via Miniflux API search param.
@module miniflux.browser.views.search_entries_view
--]]

local EntriesView = require('features/browser/views/entries_view')
local ViewUtils = require('features/browser/views/view_utils')
local _ = require('gettext')
local T = require('ffi/util').template

local SearchEntriesView = {}

---@alias SearchEntriesViewConfig {entries: Entries, settings: MinifluxSettings, page_state?: number, search: string, onSelectItem: function}

---Build view data for search (used for both success and error/empty cases so back always works)
local function buildSearchView(search, entries, subtitle_suffix)
    local menu_items = EntriesView.buildItems({
        entries = entries or {},
        show_feed_names = true,
        hide_read_entries = false,
        onSelectItem = function() end,
    })
    return {
        title = _('Search'),
        items = menu_items,
        page_state = nil,
        subtitle = subtitle_suffix or '',
    }
end

---Show entries matching search query. Always returns a view so back navigates to main (never nil).
---@param config SearchEntriesViewConfig
---@return table View data for browser rendering
function SearchEntriesView.show(config)
    local search = config.search and config.search:match('^%s*(.-)%s*$') or ''
    if search == '' then
        return buildSearchView(search, {}, _('Enter a search term'))
    end

    local result, err = config.entries:getEntries({
        search = search,
        order = config.settings.order,
        direction = config.settings.direction,
        limit = config.settings.limit,
        status = config.settings.hide_read_entries and { 'unread' } or { 'unread', 'read' },
    }, {
        dialogs = {
            loading = { text = _('Searching...') },
            error = { text = _('Search failed') },
        },
    })

    if err or not result then
        return buildSearchView(search, {}, _('Search failed'))
    end
    local entries = result.entries or {}

    local menu_items = EntriesView.buildItems({
        entries = entries,
        show_feed_names = true,
        hide_read_entries = config.settings.hide_read_entries,
        onSelectItem = config.onSelectItem,
    })

    return {
        title = _('Search'),
        items = menu_items,
        page_state = config.page_state,
        subtitle = T(_('"%1" (%2)'), search, #entries),
    }
end

return SearchEntriesView
