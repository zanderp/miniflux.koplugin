--[[--
Main View for Miniflux Browser

Complete React-style component for main screen display.
Handles data fetching, menu building, and UI rendering.

@module miniflux.browser.views.main_view
--]]

local _ = require('gettext')
local logger = require('logger')
local ViewUtils = require('features/browser/views/view_utils')
local EntryCollections = require('domains/utils/entry_collections')

local MainView = {}

-- Cache for async load: when we return main view without blocking, loadData runs in background and stores result here; next refresh uses it.
MainView._cached_counts = nil

---@alias MainViewConfig {miniflux: Miniflux, settings: MinifluxSettings, onSelectUnread: function, onSelectRead: function, onSelectFeeds: function, onSelectCategories: function, onSelectLocal: function, onSelectStarred: function, onSelectSearch: function}

---Complete main view component (React-style) - returns view data for browser rendering.
---Uses async load when online so the UI does not block (avoids hang when opening browser or pressing Back/X).
---@param config MainViewConfig
---@return table|nil View data for browser rendering, or nil on error
function MainView.show(config)
    local NetworkMgr = require('ui/network/manager')
    local UIManager = require('ui/uimanager')
    local is_online = NetworkMgr:isOnline()

    local local_entries = EntryCollections.getLocalEntries()
    local local_count = #local_entries

    local counts = nil
    if is_online then
        if MainView._cached_counts then
            counts = MainView._cached_counts
            MainView._cached_counts = nil
        else
            -- Return immediately with placeholder and load in background so we don't block (fixes X/Back hang)
            logger.dbg('[Miniflux:MainView] async load: returning placeholder, scheduling loadData')
            counts = {
                unread_count = 0,
                feeds_count = 0,
                categories_count = 0,
                starred_count = 0,
                read_count = 0,
            }
            local miniflux = config.miniflux
            local browser = miniflux and miniflux.browser
            UIManager:scheduleIn(0, function()
                if not miniflux then
                    logger.dbg('[Miniflux:MainView] async load: miniflux nil, skip')
                    return
                end
                local ok, loaded = pcall(MainView.loadData, miniflux, { silent = true })
                if not ok or not loaded or type(loaded) ~= 'table' then
                    logger.dbg('[Miniflux:MainView] async load: loadData failed or empty, ok:', ok)
                    return
                end
                MainView._cached_counts = loaded
                -- Only refresh if browser is still shown (user may have closed it)
                if browser and UIManager:isWidgetShown(browser) then
                    logger.dbg('[Miniflux:MainView] async load: refreshing current view')
                    local ok, _err2 = pcall(function()
                        browser:refreshCurrentViewData()
                    end)
                    if not ok then
                        logger.dbg('[Miniflux:MainView] async load: refreshCurrentViewData failed')
                        MainView._cached_counts = nil
                    end
                else
                    logger.dbg('[Miniflux:MainView] async load: browser not shown, skip refresh')
                end
            end)
        end
    end

    local main_items = MainView.buildItems({
        counts = counts,
        local_count = local_count,
        is_online = is_online,
        callbacks = {
            onSelectUnread = config.onSelectUnread,
            onSelectRead = config.onSelectRead,
            onSelectFeeds = config.onSelectFeeds,
            onSelectCategories = config.onSelectCategories,
            onSelectLocal = config.onSelectLocal,
            onSelectStarred = config.onSelectStarred,
            onSelectSearch = config.onSelectSearch,
        },
    })

    local title = _('Miniflux')
    local filter_subtitle = ViewUtils.buildFilterModeSubtitle(config.settings)

    return {
        title = title,
        items = main_items,
        page_state = nil,
        subtitle = filter_subtitle,
        is_root = true,
    }
end

---Load initial data needed for main screen using domain loader pattern
---@param miniflux Miniflux Plugin instance with domain modules
---@param opts? { silent?: boolean } If silent, do not show loading notification (e.g. when loading in background)
---@return table|nil result, string|nil error
function MainView.loadData(miniflux, opts)
    opts = opts or {}
    local Notification = require('shared/widgets/notification')
    local loading_notification = opts.silent and nil or Notification:info(_('Loading...'))

    -- Get unread count from entries domain
    local unread_count, unread_err = miniflux.entries:getUnreadCount()
    if unread_err then
        if loading_notification then loading_notification:close() end
        return nil, unread_err.message
    end
    ---@cast unread_count -nil

    -- Get feeds count from feeds domain
    local feeds_count, feeds_err = miniflux.feeds:getFeedCount()
    if feeds_err then
        if loading_notification then loading_notification:close() end
        return nil, feeds_err.message
    end
    ---@cast feeds_count -nil

    -- Get categories count from categories domain
    local categories_count, categories_err = miniflux.categories:getCategoryCount()
    if categories_err then
        if loading_notification then loading_notification:close() end
        return nil, categories_err.message
    end
    ---@cast categories_count -nil

    if loading_notification then loading_notification:close() end

    -- Starred count (bookmarked entries)
    local starred_result, _starred_err = miniflux.entries:getEntries({
        starred = true,
        limit = 1,
        order = miniflux.settings.order,
        direction = miniflux.settings.direction,
    })
    local starred_count = (starred_result and starred_result.total) or 0

    -- Read count
    local read_result, _read_err = miniflux.entries:getEntries({
        status = { 'read' },
        limit = 1,
        order = miniflux.settings.order,
        direction = miniflux.settings.direction,
    })
    local read_count = (read_result and read_result.total) or 0

    return {
        unread_count = unread_count or 0,
        feeds_count = feeds_count or 0,
        categories_count = categories_count or 0,
        starred_count = starred_count,
        read_count = read_count,
    }
end

---Build main menu items (internal helper)
---@param config {counts?: table, local_count: number, is_online: boolean, callbacks: table}
---@return table[] Menu items for main screen
function MainView.buildItems(config)
    local counts = config.counts
    local local_count = config.local_count
    local is_online = config.is_online
    local callbacks = config.callbacks

    local items = {}

    if is_online and counts then
        -- Online: Show all online options
        table.insert(items, {
            text = _('Unread'),
            mandatory = tostring(counts.unread_count or 0),
            callback = callbacks.onSelectUnread,
            item_key = 'unread', -- for long-press "Mark all as read" on main
        })
        table.insert(items, {
            text = _('Read'),
            mandatory = tostring(counts.read_count or 0),
            callback = callbacks.onSelectRead,
            item_key = 'read',
        })
        table.insert(items, {
            text = _('Starred'),
            mandatory = tostring(counts.starred_count or 0),
            callback = callbacks.onSelectStarred,
        })
        table.insert(items, {
            text = _('Feeds'),
            mandatory = tostring(counts.feeds_count or 0),
            callback = callbacks.onSelectFeeds,
        })
        table.insert(items, {
            text = _('Categories'),
            mandatory = tostring(counts.categories_count or 0),
            callback = callbacks.onSelectCategories,
        })
        table.insert(items, {
            text = _('Search'),
            mandatory = '',
            callback = callbacks.onSelectSearch,
        })
    end

    -- Always show Local option if local entries exist
    if local_count > 0 then
        table.insert(items, {
            text = _('Local'),
            mandatory = tostring(local_count),
            callback = callbacks.onSelectLocal,
        })
    end

    -- If offline and no local entries, show helpful message
    if not is_online and local_count == 0 then
        table.insert(items, {
            text = _('No offline content available'),
            mandatory = _('Connect to internet'),
            action_type = 'no_action',
        })
    end

    return items
end

return MainView
