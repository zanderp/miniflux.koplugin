local ButtonDialog = require('ui/widget/buttondialog')
local UIManager = require('ui/uimanager')
local Notification = require('shared/widgets/notification')
local StorageUtils = require('domains/utils/storage_utils')
local _ = require('gettext')
local T = require('ffi/util').template

-- **Image recovery** - Re-download missing images for all downloaded entries.
local ImageRecovery = {}

---Get the menu item (needs settings for API/proxy when downloading)
---@param settings MinifluxSettings
---@return table Menu item configuration
function ImageRecovery.getMenuItem(settings)
    return {
        text = _('Image recovery'),
        help_text = _('Re-download missing images for downloaded entries'),
        keep_menu_open = true,
        callback = function()
            ImageRecovery.showConfirmDialog(settings)
        end,
    }
end

function ImageRecovery.showConfirmDialog(settings)
    local entries = StorageUtils.listEntriesWithDates()
    if #entries == 0 then
        Notification:info(_('No downloaded entries'))
        return
    end

    local confirm_dialog
    confirm_dialog = ButtonDialog:new({
        title = _('Re-download missing images for all entries?'),
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
                    text = _('Start'),
                    callback = function()
                        UIManager:close(confirm_dialog)
                        local total = 0
                        for _, e in ipairs(entries) do
                            total = total + StorageUtils.recoverImagesForEntry(e.entry_id, settings)
                        end
                        Notification:success(T(_('Recovered %1 images'), total))
                    end,
                },
            },
        },
    })
    UIManager:show(confirm_dialog)
end

return ImageRecovery
