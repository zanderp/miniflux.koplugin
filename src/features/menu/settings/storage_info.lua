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
    local ok, stats = pcall(StorageUtils.getStorageStats)
    if not ok or not stats then
        local err_dialog = ButtonDialog:new({
            title = _('Miniflux storage'),
            title_align = 'center',
            buttons = { { { text = _('Close'), callback = function() UIManager:close(err_dialog) end } } },
        })
        UIManager:show(err_dialog)
        return
    end

    local total_str = StorageUtils.formatSize(stats.total_bytes or 0)
    local image_str = StorageUtils.formatSize(stats.image_bytes or 0)
    local body = T(
        _('Downloaded entries: %1\nTotal size: %2\nImages: %3 (%4)'),
        tostring(stats.entry_count or 0),
        total_str,
        tostring(stats.image_count or 0),
        image_str
    )
    -- Title and body in one: ButtonDialog may not render separate text on all platforms
    local title = _('Miniflux storage') .. '\n\n' .. body

    local dialog = ButtonDialog:new({
        title = title,
        title_align = 'center',
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
        tap_close_callback = function()
            UIManager:close(dialog)
        end,
    })
    UIManager:show(dialog)
end

return StorageInfo
