local _ = require('gettext')

-- Import settings components
local ServerConfig = require('features/menu/settings/server_config')
local Entries = require('features/menu/settings/entries')
local SortOrder = require('features/menu/settings/sort_order')
local SortDirection = require('features/menu/settings/sort_direction')
local IncludeImages = require('features/menu/settings/include_images')
local MarkAsReadOnOpen = require('features/menu/settings/mark_as_read_on_open')
local DownloadLocation = require('features/menu/settings/download_location')
local AutoDeleteReadOnClose = require('features/menu/settings/auto_delete_read_on_close')
local RemoveFromHistoryOnDelete = require('features/menu/settings/remove_from_history_on_delete')
local UseHtmlReader = require('features/menu/settings/use_html_reader')
local ClearAllDownloads = require('features/menu/settings/clear_all_downloads')
local DeleteByDateRange = require('features/menu/settings/delete_by_date_range')
local StorageInfo = require('features/menu/settings/storage_info')
local DeleteAllImages = require('features/menu/settings/delete_all_images')
local ImageRecovery = require('features/menu/settings/image_recovery')
local Prefetch = require('features/menu/settings/prefetch')
local CopyCss = require('features/menu/settings/copy_css')
local TestConnection = require('features/menu/settings/test_connection')
local ProxyImageDownloader = require('features/menu/settings/proxy_image_downloader')
local UpdateSettings = require('features/menu/settings/update_settings')
local ExportLogs = require('features/menu/settings/export_logs')

local Menu = {}

---Build the main menu structure for the Miniflux plugin
---@param plugin Miniflux The main plugin instance
---@return table menu_structure KOReader submenu structure
function Menu.build(plugin)
    return {
        text = _('Miniflux'),
        sub_item_table = {
            -- === BROWSER OPTIONS ===
            {
                text = _('Read entries'),
                help_text = _('Browse RSS entries'),
                callback = function()
                    plugin.browser:open()
                end,
            },
            {
                text = _('Sync status changes'),
                help_text = _('Sync pending changes (entries, feeds, categories)'),
                callback = function()
                    if plugin.sync_service then
                        -- Use KOReader's standard network handling (same as translate)
                        local NetworkMgr = require('ui/network/manager')
                        NetworkMgr:runWhenOnline(function()
                            -- Show sync dialog after ensuring online connectivity
                            plugin.sync_service:processAllQueues()
                        end)
                    end
                end,
            },

            -- === SETTINGS SUBMENU ===
            {
                text = _('Settings'),
                separator = true,
                sub_item_table = {
                    -- === CONNECTION SETTINGS ===
                    ServerConfig.getMenuItem(plugin.settings),
                    TestConnection.getMenuItem(plugin.entries),

                    -- === DISPLAY SETTINGS ===
                    Entries.getMenuItem(plugin.settings),
                    SortOrder.getMenuItem(plugin.settings),
                    SortDirection.getMenuItem(plugin.settings),
                    IncludeImages.getMenuItem(plugin.settings),
                    MarkAsReadOnOpen.getMenuItem(plugin.settings),
                    ProxyImageDownloader.getMenuItem(plugin.settings),
                    DownloadLocation.getMenuItem(plugin.settings),
                    AutoDeleteReadOnClose.getMenuItem(plugin.settings),
                    RemoveFromHistoryOnDelete.getMenuItem(plugin.settings),
                    UseHtmlReader.getMenuItem(plugin.settings),
                    ClearAllDownloads.getMenuItem(),
                    DeleteByDateRange.getMenuItem(),
                    StorageInfo.getMenuItem(),
                    DeleteAllImages.getMenuItem(),
                    ImageRecovery.getMenuItem(plugin.settings),
                    Prefetch.getMenuItem(plugin),
                    CopyCss.getMenuItem(plugin),

                    -- === UPDATE SETTINGS ===
                    UpdateSettings.getMenuItem(plugin),

                    -- === DEBUG ===
                    ExportLogs.getMenuItem(),
                },
            },
        },
    }
end

return Menu
