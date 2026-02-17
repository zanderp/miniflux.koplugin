local ButtonDialog = require('ui/widget/buttondialog')
local UIManager = require('ui/uimanager')
local Notification = require('shared/widgets/notification')
local Files = require('shared/files')
local StorageUtils = require('domains/utils/storage_utils')
local FFIUtil = require('ffi/util')
local lfs = require('libs/libkoreader-lfs')
local _ = require('gettext')
local T = require('ffi/util').template

local SECONDS_PER_DAY = 24 * 60 * 60
local RANGES = {
    { label = _('Older than 1 week'), days = 7 },
    { label = _('Older than 1 month'), days = 30 },
    { label = _('Older than 3 months'), days = 90 },
    { label = _('Older than 6 months'), days = 180 },
}

local DeleteByDateRange = {}

---Get the menu item
---@return table Menu item configuration
function DeleteByDateRange.getMenuItem()
    return {
        text = _('Delete by date range'),
        help_text = _('Remove entries older than 1 week, 1 month, 3 months, or 6 months'),
        keep_menu_open = true,
        callback = function()
            DeleteByDateRange.showDialog()
        end,
    }
end

function DeleteByDateRange.showDialog()
    local entries = StorageUtils.listEntriesWithDates()
    if #entries == 0 then
        Notification:info(_('No downloaded entries'))
        return
    end

    local buttons = {}
    for _, r in ipairs(RANGES) do
        local older_than = r.days * SECONDS_PER_DAY
        local to_delete = StorageUtils.filterOlderThan(entries, older_than)
        local count = #to_delete
        table.insert(buttons, {
            {
                text = count > 0 and T(_('%1 (%2 entries)'), r.label, count) or r.label,
                callback = function()
                    UIManager:close(dialog)
                    if count == 0 then
                        Notification:info(_('No entries in this range'))
                        return
                    end
                    DeleteByDateRange.confirmAndDelete(to_delete)
                end,
            },
        })
    end
    table.insert(buttons, {
        {
            text = _('Cancel'),
            callback = function()
                UIManager:close(dialog)
            end,
        },
    })

    local dialog
    dialog = ButtonDialog:new({
        title = _('Delete entries by date'),
        title_align = 'center',
        buttons = buttons,
    })
    UIManager:show(dialog)
end

function DeleteByDateRange.confirmAndDelete(entries_to_delete)
    local count = #entries_to_delete
    local confirm_dialog
    confirm_dialog = ButtonDialog:new({
        title = T(_('Delete %1 entries?'), count),
        title_align = 'center',
        buttons = {
            {
                {
                    text = _('Cancel'),
                    callback = function()
                        UIManager:close(confirm_dialog)
                    end,
                },
                {
                    text = _('Delete'),
                    callback = function()
                        UIManager:close(confirm_dialog)
                        local MinifluxBrowser = require('features/browser/miniflux_browser')
                        local deleted = 0
                        for _, e in ipairs(entries_to_delete) do
                            FFIUtil.purgeDir(e.dir_path)
                            Files.removeEmptyDirectory(e.dir_path)
                            MinifluxBrowser.deleteEntryInfoCache(e.entry_id)
                            deleted = deleted + 1
                        end
                        Notification:success(T(_('Deleted %1 entries'), deleted))
                    end,
                },
            },
        },
    })
    UIManager:show(confirm_dialog)
end

return DeleteByDateRange
