--[[--
**Miniflux Plugin for KOReader**

This plugin provides integration with Miniflux RSS reader.
This main file acts as a coordinator, delegating to specialized modules.
--]]

local Geom = require('ui/geometry')
local WidgetContainer = require('ui/widget/container/widgetcontainer')
local FFIUtil = require('ffi/util')
local UIManager = require('ui/uimanager')
local lfs = require('libs/libkoreader-lfs')
local Dispatcher = require('dispatcher')
local _ = require('gettext')
local logger = require('logger')

local MinifluxAPI = require('api/miniflux_api')
local MinifluxSettings = require('shared/settings')
local Menu = require('features/menu/menu')
local DataStorage = require('datastorage')
local UpdateSettings = require('features/menu/settings/update_settings')
local UpdateService = require('shared/update_service')
local ReaderEntryService = require('features/reader/services/entry_service')
local QueueService = require('features/sync/services/queue_service')
local SyncService = require('features/sync/services/sync_service')
local HTTPCacheAdapter = require('shared/http_cache_adapter')

---@class Miniflux : WidgetContainer
---@field name string Plugin name identifier
---@field is_doc_only boolean Whether plugin is document-only
---@field download_dir string Full path to download directory
---@field settings MinifluxSettings Settings instance
---@field http_cache HTTPCacheAdapter Shared HTTP cache adapter instance
---@field api MinifluxAPI Miniflux-specific API instance
---@field feeds Feeds Feeds domain module
---@field categories Categories Categories domain module
---@field entries Entries Entries domain module
---@field reader_entry_service ReaderEntryService Reader entry service instance
---@field sync_service SyncService Sync orchestration service instance
---@field readerLink MinifluxReaderLink ReaderLink enhancement module instance
---@field subprocesses_pids table[] List of subprocess PIDs for cleanup
---@field subprocesses_collector boolean|nil Flag indicating if subprocess collector is active
---@field subprocesses_collect_interval number Interval for subprocess collection in seconds
---@field update_service UpdateService Update service instance for plugin updates
---@field browser MinifluxBrowser|nil Browser instance for UI navigation
---@field wrapped_onClose table|nil Wrapped ReaderUI onClose method for metadata preservation
---@field ui ReaderUI|nil ReaderUI instance when running in reader context
---@field version string Plugin version
local Miniflux = WidgetContainer:extend({
    name = 'miniflux',
    is_doc_only = false,
    settings = nil,
    subprocesses_pids = {},
    subprocesses_collector = nil,
    subprocesses_collect_interval = 10,
    browser_context = nil,
    download_dir = ('%s/%s/'):format(DataStorage:getFullDataDir(), 'miniflux'),
})

---Register a module with the plugin for event handling
---@param name string Module name
---@param module table Module instance
function Miniflux:registerModule(name, module)
    if name then
        self[name] = module
        module.name = 'miniflux_' .. name
    end
    table.insert(self, module) -- Add to widget hierarchy
end

---Return size for container. Registered modules are not widgets (no getSize), so we must not
---call WidgetContainer's getSize which assumes self[1] is a widget (avoids crash on repaint).
function Miniflux:getSize()
    if self.dimen then
        return self.dimen
    end
    for i = 1, #self do
        local child = self[i]
        if child and type(child.getSize) == 'function' then
            return child:getSize()
        end
    end
    return Geom:new({ x = 0, y = 0, w = 0, h = 0 })
end

---Paint container. Only paint children that are widgets (have getSize). Avoids crash when
---UIManager repaints after browser close (base WidgetContainer:paintTo calls self[1]:getSize()).
function Miniflux:paintTo(bb, x, y)
    for i = 1, #self do
        local child = self[i]
        if child and type(child.getSize) == 'function' and type(child.paintTo) == 'function' then
            local content_size = child:getSize()
            if content_size then
                child:paintTo(bb, x, y)
                return
            end
        end
    end
end

---Handle FlushSettings event from UIManager
function Miniflux:onFlushSettings()
    if self.settings.updated then
        logger.dbg('[Miniflux:Main] Writing settings to disk')
        self.settings:save()
        self.settings.updated = false
    end
end

---Initialize the plugin by setting up all components
---@return nil
function Miniflux:init()
    logger.info('[Miniflux:Main] Initializing plugin')

    self.settings = MinifluxSettings:new()
    logger.info('[Miniflux:Main] Settings initialized', MinifluxSettings)

    -- Use configured download directory (issue #57: custom download location)
    local EntryPaths = require('domains/utils/entry_paths')
    self.download_dir = EntryPaths.getDownloadDir()

    -- Create the directory if it doesn't exist
    if not lfs.attributes(self.download_dir, 'mode') then
        local success = lfs.mkdir(self.download_dir)
        if not success then
            logger.err('[Miniflux:Main] Failed to create download directory')
            return
        end
    end

    -- Create shared HTTP cache instance after settings
    self.http_cache = HTTPCacheAdapter:new({
        api_cache_ttl = self.settings.api_cache_ttl,
        db_name = 'miniflux_cache.sqlite',
    })

    -- Create update service instance (GitHub releases: zanderp/miniflux.koplugin)
    self.update_service = UpdateService:new({
        repo_owner = 'zanderp',
        repo_name = 'miniflux.koplugin',
        plugin_path = self.path,
        logger_prefix = 'Miniflux:',
    })

    -- Register MinifluxAPI as a module after settings initialization
    self:registerModule(
        'api',
        MinifluxAPI:new({
            api_token = self.settings.api_token,
            server_address = self.settings.server_address,
        })
    )

    -- Register domain modules using vertical slice architecture
    local Feeds = require('domains/feeds/feeds')
    local Categories = require('domains/categories/categories')
    local Entries = require('domains/entries/entries')

    self:registerModule('feeds', Feeds:new({ miniflux = self, http_cache = self.http_cache }))
    self:registerModule(
        'categories',
        Categories:new({ miniflux = self, http_cache = self.http_cache })
    )
    self:registerModule('entries', Entries:new({ miniflux = self, http_cache = self.http_cache }))

    -- Create services directly with proper dependency order
    self.sync_service = SyncService:new({
        entries = self.entries,
        feeds = self.feeds,
        categories = self.categories,
    })

    -- Register reader service as EventListener module for document events
    self:registerModule(
        'reader_entry_service',
        ReaderEntryService:new({
            settings = self.settings,
            feeds = self.feeds,
            categories = self.categories,
            entries = self.entries,
            miniflux_plugin = self,
        })
    )

    local MinifluxBrowser = require('features/browser/miniflux_browser')
    self.browser = MinifluxBrowser:new({
        title = _('Miniflux'),
        miniflux = self,
    })

    if self.ui and self.ui.document then
        local MinifluxReaderLink = require('features/reader/modules/miniflux_readerlink')
        self:registerModule('readerLink', MinifluxReaderLink:new({ miniflux = self }))

        local MinifluxEndOfBook = require('features/reader/modules/miniflux_end_of_book')
        self:registerModule('endOfBook', MinifluxEndOfBook:new({ miniflux = self }))
    end

    -- Register with KOReader menu system
    self.ui.menu:registerToMainMenu(self)

    -- Check for automatic updates if enabled
    self:checkForAutomaticUpdates()

    logger.info('[Miniflux:Main] Plugin initialization complete')
end

---Add Miniflux items to the main menu (called by KOReader).
---Used for both the file-manager main menu and the document reader menu.
---sorting_hint "tools" = direct under Tools (file manager); "main" = reader menu.
---@param menu_items table The main menu items table
---@return nil
function Miniflux:addToMainMenu(menu_items)
    menu_items.miniflux = Menu.build(self)
    if self.ui and self.ui.document then
        menu_items.miniflux.sorting_hint = 'main'
    else
        menu_items.miniflux.sorting_hint = 'tools'
    end
end

---Handle dispatcher events (method required by KOReader)
---@return nil
function Miniflux:onDispatcherRegisterActions()
    Dispatcher:registerAction('miniflux_read_entries', {
        category = 'none',
        event = 'ReadMinifluxEntries',
        title = _('Read Miniflux entries'),
        general = true,
    })
end

---Handle the read entries dispatcher event
---@return nil
function Miniflux:onReadMinifluxEntries()
    local MainInstance = require('shared/main_instance')
    MainInstance.main_instance = self -- so reader's end-of-book can return to this browser
    self.browser:open()
end

-- =============================================================================
-- HTTP CACHE MANAGEMENT
-- =============================================================================

function Miniflux:onMinifluxSettingsChange(payload)
    local key = payload.key
    local invalidating_keys = {
        [self.settings.Key.ORDER] = true,
        [self.settings.Key.DIRECTION] = true,
        [self.settings.Key.LIMIT] = true,
        [self.settings.Key.HIDE_READ_ENTRIES] = true,
    }

    if invalidating_keys[key] then
        self.http_cache:clear()
    end
end

function Miniflux:onMinifluxCacheInvalidate()
    logger.info('[Miniflux:Main] Cache invalidation event received')
    self.http_cache:clear()
    -- Clear main view counts cache so Back to main shows updated unread/read counts
    local MainView = require('features/browser/views/main_view')
    MainView._cached_counts = nil
end

-- =============================================================================
-- SUBPROCESS MANAGEMENT
-- =============================================================================

---Track a new subprocess PID for zombie cleanup
---@param pid number Process ID to track
function Miniflux:trackSubprocess(pid)
    if not pid then
        return
    end

    UIManager:preventStandby()
    table.insert(self.subprocesses_pids, pid)

    -- Start zombie collector if not already running
    if not self.subprocesses_collector then
        self.subprocesses_collector = true
        UIManager:scheduleIn(self.subprocesses_collect_interval, function()
            self:collectSubprocesses()
        end)
    end
end

---Collect finished subprocesses to prevent zombies
function Miniflux:collectSubprocesses()
    self.subprocesses_collector = nil

    if #self.subprocesses_pids > 0 then
        -- Check each subprocess and remove completed ones
        for i = #self.subprocesses_pids, 1, -1 do
            local pid = self.subprocesses_pids[i]
            if FFIUtil.isSubProcessDone(pid) then
                table.remove(self.subprocesses_pids, i)
                UIManager:allowStandby()
            end
        end

        -- If subprocesses still running, schedule next collection
        if #self.subprocesses_pids > 0 then
            self.subprocesses_collector = true
            UIManager:scheduleIn(self.subprocesses_collect_interval, function()
                self:collectSubprocesses()
            end)
        end
    end
end

---Terminate all background subprocesses
function Miniflux:terminateBackgroundJobs()
    if #self.subprocesses_pids > 0 then
        for i = 1, #self.subprocesses_pids do
            FFIUtil.terminateSubProcess(self.subprocesses_pids[i])
        end
        -- Processes will be cleaned up by next collectSubprocesses() call
    end
end

---Check if background jobs are running
---@return boolean true if subprocesses are running
function Miniflux:hasBackgroundJobs()
    return #self.subprocesses_pids > 0
end

-- =============================================================================
-- NETWORK EVENT HANDLERS
-- =============================================================================

---Handle network connected event - process all offline queues
function Miniflux:onNetworkConnected()
    logger.info('[Miniflux:Main] Network connected event received')
    -- Only process if SyncService is available (plugin initialized)
    if self.sync_service then
        -- Check if any queue has items before showing dialog
        local total_count = QueueService.getTotalQueueCount()
        logger.dbg('[Miniflux:Main] Queue items pending sync:', total_count)

        if total_count > 0 then
            -- Show sync dialog only if there are items to sync
            logger.info('[Miniflux:Main] Processing offline queues')
            self.sync_service:processAllQueues()
        end
        -- If all queues are empty, do nothing (silent)
    end
end

---Handle device suspend event - terminate background jobs to save battery
function Miniflux:onSuspend()
    logger.info('[Miniflux:Main] Device suspend event - terminating background jobs')
    self:terminateBackgroundJobs()
    -- Queue operations will be processed on next network connection
end

---Check for automatic updates if enabled and due
---@return nil
function Miniflux:checkForAutomaticUpdates()
    if not self.settings or not UpdateSettings.isUpdateCheckDue(self.settings) then
        return
    end

    local CheckUpdates = require('features/menu/settings/check_updates')
    CheckUpdates.checkForUpdates({
        show_no_update = false,
        settings = self.settings,
        update_service = self.update_service,
        current_version = self.version,
    })
end

---Handle Close key when plugin is top widget (e.g. after browser closed) so one X exits to KOReader.
function Miniflux:handleEvent(ev)
    if ev.type == 'Close' then
        UIManager:close(self)
        UIManager:setDirty(nil, 'full')
        return true
    end
end

---Handle widget close event - cleanup resources and instances.
---Closes browser and overlay only if still shown (browser may already have closed itself); defers
---cleanup so the event loop does not block (avoids lock when pressing X after returning from reader).
function Miniflux:onCloseWidget()
    logger.info('[Miniflux:Main] Plugin widget closing - cleaning up resources')

    -- Close browser/overlay only if still shown (pcall to avoid any close re-entry or error locking the UI).
    if self.browser then
        pcall(function()
            local overlay = self.browser.current_overlay
            self.browser.current_overlay = nil
            if overlay and UIManager:isWidgetShown(overlay) then
                UIManager:close(overlay)
            end
            if UIManager:isWidgetShown(self.browser) then
                UIManager:close(self.browser)
            end
        end)
    end

    -- Defer cleanup so we return immediately; do not block in onCloseWidget.
    UIManager:scheduleIn(0, function()
        if self.subprocesses_pids and #self.subprocesses_pids > 0 then
            self.subprocesses_pids = {}
        end
        if self.subprocesses_collector then
            UIManager:unschedule(function()
                self:collectSubprocesses()
            end)
            self.subprocesses_collector = nil
        end
        UIManager:setDirty('all', 'full')
    end)
end

function Miniflux:onMinifluxBrowserContextChange(payload)
    logger.info('[Miniflux:browser_context] Browser context changed:', payload.context)
    local BrowserContext = require('shared/browser_context')
    BrowserContext.context = payload.context
    Miniflux.browser_context = payload.context
end

function Miniflux:getBrowserContext()
    local BrowserContext = require('shared/browser_context')
    local ctx = BrowserContext.context or Miniflux.browser_context
    logger.info('[Miniflux:browser_context] Getting browser context:', ctx)
    return ctx
end

return Miniflux
