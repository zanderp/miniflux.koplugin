local ButtonDialog = require('ui/widget/buttondialog')
local UIManager = require('ui/uimanager')
local Notification = require('shared/widgets/notification')
local EntryPaths = require('domains/utils/entry_paths')
local Files = require('shared/files')
local lfs = require('libs/libkoreader-lfs')
local FFIUtil = require('ffi/util')
local _ = require('gettext')
local T = require('ffi/util').template

-- **Clear all downloads** - Remove all downloaded Miniflux entries from the device.
local ClearAllDownloads = {}

---Get the menu item
---@return table Menu item configuration
function ClearAllDownloads.getMenuItem()
    return {
        text = _('Clear all downloaded entries'),
        help_text = _('Delete all Miniflux entries from this device'),
        keep_menu_open = true,
        callback = function()
            ClearAllDownloads.showConfirmDialog()
        end,
    }
end

---Show confirmation then purge download directory
function ClearAllDownloads.showConfirmDialog()
    local base_dir = EntryPaths.getDownloadDir()
    local count = 0
    local attr = lfs.attributes(base_dir, 'mode')
    if attr == 'directory' then
        for name in lfs.dir(base_dir) do
            if name ~= '.' and name ~= '..' and tonumber(name) then
                count = count + 1
            end
        end
    end

    if count == 0 then
        Notification:info(_('No downloaded entries to clear'))
        return
    end

    local confirm_dialog
    confirm_dialog = ButtonDialog:new({
        title = T(_('Delete all %1 downloaded entries?'), count),
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
                    text = _('Delete all'),
                    callback = function()
                        UIManager:close(confirm_dialog)
                        local deleted = 0
                        for name in lfs.dir(base_dir) do
                            if name ~= '.' and name ~= '..' then
                                local id = tonumber(name)
                                if id then
                                    local path = base_dir .. name
                                    if lfs.attributes(path, 'mode') == 'directory' then
                                        FFIUtil.purgeDir(path)
                                        Files.removeEmptyDirectory(path)
                                        deleted = deleted + 1
                                    end
                                end
                            end
                        end
                        local MinifluxBrowser = require('features/browser/miniflux_browser')
                        MinifluxBrowser.clearEntriesInfoCache()
                        Notification:success(T(_('Cleared %1 entries'), deleted))
                    end,
                },
            },
        },
    })
    UIManager:show(confirm_dialog)
end

return ClearAllDownloads
