local ButtonDialog = require('ui/widget/buttondialog')
local UIManager = require('ui/uimanager')
local StorageUtils = require('domains/utils/storage_utils')
local _ = require('gettext')
local T = require('ffi/util').template

-- **Storage info** - Report storage usage and link to cleanup options.
local StorageInfo = {}

---Get the menu item
---@return table Menu item configuration
function StorageInfo.getMenuItem()
    return {
        text = _('Storage info'),
        help_text = _('View storage usage and cleanup options'),
        keep_menu_open = true,
        callback = function()
            StorageInfo.showDialog()
        end,
    }
end

function StorageInfo.showDialog()
    local stats = StorageUtils.getStorageStats()
    local total_str = StorageUtils.formatSize(stats.total_bytes)
    local image_str = StorageUtils.formatSize(stats.image_bytes)
    local text = T(
        _('Downloaded entries: %1\nTotal size: %2\nImages: %3 (%4)'),
        stats.entry_count,
        total_str,
        stats.image_count,
        image_str
    )

    local dialog = ButtonDialog:new({
        title = _('Miniflux storage'),
        title_align = 'center',
        text = text,
        buttons = {
            {
                {
                    text = _('Close'),
                    callback = function()
                        UIManager:close(dialog)
                    end,
                },
            },
        },
    })
    UIManager:show(dialog)
end

return StorageInfo
