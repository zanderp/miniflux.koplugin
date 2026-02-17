local ButtonDialog = require('ui/widget/buttondialog')
local UIManager = require('ui/uimanager')
local Notification = require('shared/widgets/notification')
local EntryPaths = require('domains/utils/entry_paths')
local BatchDownloadEntriesWorkflow = require('features/browser/download/batch_download_entries_workflow')
local NetworkMgr = require('ui/network/manager')
local _ = require('gettext')
local T = require('ffi/util').template

-- **Prefetch** - Download the next N entries (from Unread or Starred) in the background.
local Prefetch = {}

---Get the menu item (needs plugin for entries + settings)
---@param plugin Miniflux
---@return table Menu item configuration
function Prefetch.getMenuItem(plugin)
    return {
        text_func = function()
            local n = plugin.settings.prefetch_count or 0
            if n == 0 then
                return _('Prefetch next entries (set count in submenu)')
            end
            return T(_('Prefetch next %1 entries'), n)
        end,
        help_text = _('Download next N entries from Unread or Starred list'),
        keep_menu_open = true,
        sub_item_table_func = function()
            local n = plugin.settings.prefetch_count or 0
            local items = {
                {
                    text = n == 0 and _('Prefetch count: 0 (off)') or T(_('Prefetch count: %1'), n),
                    keep_menu_open = true,
                    sub_item_table_func = function()
                        return {
                            { text = _('0 (off)'), keep_menu_open = true, callback = function(tm) plugin.settings.prefetch_count = 0; plugin.settings:save(); Notification:info(_('Prefetch: off')); if tm and tm.updateItems then tm:updateItems() end end },
                            { text = _('1'), keep_menu_open = true, callback = function(tm) plugin.settings.prefetch_count = 1; plugin.settings:save(); Notification:info(T(_('Prefetch count: %1'), 1)); if tm and tm.updateItems then tm:updateItems() end end },
                            { text = _('2'), keep_menu_open = true, callback = function(tm) plugin.settings.prefetch_count = 2; plugin.settings:save(); Notification:info(T(_('Prefetch count: %1'), 2)); if tm and tm.updateItems then tm:updateItems() end end },
                            { text = _('3'), keep_menu_open = true, callback = function(tm) plugin.settings.prefetch_count = 3; plugin.settings:save(); Notification:info(T(_('Prefetch count: %1'), 3)); if tm and tm.updateItems then tm:updateItems() end end },
                            { text = _('5'), keep_menu_open = true, callback = function(tm) plugin.settings.prefetch_count = 5; plugin.settings:save(); Notification:info(T(_('Prefetch count: %1'), 5)); if tm and tm.updateItems then tm:updateItems() end end },
                        }
                    end,
                },
            }
            if n > 0 then
                table.insert(items, {
                    text = _('From Unread'),
                    keep_menu_open = true,
                    callback = function()
                        Prefetch.run(plugin, 'unread', n)
                    end,
                })
                table.insert(items, {
                    text = _('From Starred'),
                    keep_menu_open = true,
                    callback = function()
                        Prefetch.run(plugin, 'starred', n)
                    end,
                })
            end
            return items
        end,
    }
end

---Run prefetch: fetch list, filter not-downloaded, take first N, batch download
---@param plugin Miniflux
---@param source 'unread'|'starred'
---@param n number
function Prefetch.run(plugin, source, n)
    if not NetworkMgr:isOnline() then
        Notification:warning(_('Prefetch requires network'))
        return
    end
    local entries, err
    if source == 'unread' then
        entries, err = plugin.entries:getUnreadEntries({
            dialogs = { loading = { text = _('Loading unread...') } },
        })
    else
        local result, err2 = plugin.entries:getEntries({
            starred = true,
            order = plugin.settings.order,
            direction = plugin.settings.direction,
            limit = plugin.settings.limit,
            status = { 'unread', 'read' },
        }, {
            dialogs = { loading = { text = _('Loading starred...') } },
        })
        if err2 or not result then
            err = err2
            entries = nil
        else
            entries = result.entries or {}
        end
    end
    if err or not entries then
        Notification:warning(_('Failed to load entries'))
        return
    end
    local to_download = {}
    for _, e in ipairs(entries) do
        if not EntryPaths.isEntryDownloaded(e.id) then
            table.insert(to_download, e)
            if #to_download >= n then
                break
            end
        end
    end
    if #to_download == 0 then
        Notification:info(_('No undownloaded entries in this list'))
        return
    end
    BatchDownloadEntriesWorkflow.execute({
        entry_data_list = to_download,
        settings = plugin.settings,
        completion_callback = function()
            Notification:success(T(_('Prefetched %1 entries'), #to_download))
        end,
    })
end

return Prefetch
