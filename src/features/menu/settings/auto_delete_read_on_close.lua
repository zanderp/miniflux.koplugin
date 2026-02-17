local UIManager = require('ui/uimanager')
local Notification = require('shared/widgets/notification')
local _ = require('gettext')

-- **Auto-delete read on close** - When enabled, local copy is deleted when you
-- navigate away or close a read entry.
local AutoDeleteReadOnClose = {}

---Get the menu item
---@param settings MinifluxSettings Settings instance
---@return table Menu item configuration
function AutoDeleteReadOnClose.getMenuItem(settings)
    return {
        text_func = function()
            return settings.auto_delete_read_on_close and _('Auto-delete read on close - ON')
                or _('Auto-delete read on close - OFF')
        end,
        help_text = _('Delete local copy when closing or leaving a read entry'),
        keep_menu_open = true,
        sub_item_table_func = function()
            return {
                {
                    text = _('ON') .. (settings.auto_delete_read_on_close and ' ✓' or ''),
                    keep_menu_open = true,
                    callback = function(touchmenu_instance)
                        settings.auto_delete_read_on_close = true
                        settings:save()
                        Notification:success(_('Read entries will be removed from device when you close or leave them'))
                        UIManager:scheduleIn(0.5, function()
                            touchmenu_instance:backToUpperMenu()
                        end)
                    end,
                },
                {
                    text = _('OFF') .. (not settings.auto_delete_read_on_close and ' ✓' or ''),
                    keep_menu_open = true,
                    callback = function(touchmenu_instance)
                        settings.auto_delete_read_on_close = false
                        settings:save()
                        Notification:success(_('Read entries will stay on device until you delete them'))
                        UIManager:scheduleIn(0.5, function()
                            touchmenu_instance:backToUpperMenu()
                        end)
                    end,
                },
            }
        end,
    }
end

return AutoDeleteReadOnClose
