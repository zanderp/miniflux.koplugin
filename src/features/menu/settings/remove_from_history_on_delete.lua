local UIManager = require('ui/uimanager')
local Notification = require('shared/widgets/notification')
local _ = require('gettext')

-- **Remove from history when deleting** - When ON, deleted entries (single, bulk, auto-delete on close)
-- are removed from KOReader's history so the history list is not polluted with broken links.
local RemoveFromHistoryOnDelete = {}

---Get the menu item
---@param settings MinifluxSettings Settings instance
---@return table Menu item configuration
function RemoveFromHistoryOnDelete.getMenuItem(settings)
    return {
        text_func = function()
            return settings.remove_from_history_on_delete and _('Remove from history when deleting - ON')
                or _('Remove from history when deleting - OFF')
        end,
        help_text = _('When ON, deleted entries are removed from KOReader history (single, bulk, and auto-delete on close).'),
        keep_menu_open = true,
        sub_item_table_func = function()
            return {
                {
                    text = _('ON') .. (settings.remove_from_history_on_delete and ' ✓' or ''),
                    keep_menu_open = true,
                    callback = function(touchmenu_instance)
                        settings.remove_from_history_on_delete = true
                        settings:save()
                        Notification:success(_('Deleted entries will be removed from KOReader history'))
                        UIManager:scheduleIn(0.5, function()
                            touchmenu_instance:backToUpperMenu()
                        end)
                    end,
                },
                {
                    text = _('OFF') .. (not settings.remove_from_history_on_delete and ' ✓' or ''),
                    keep_menu_open = true,
                    callback = function(touchmenu_instance)
                        settings.remove_from_history_on_delete = false
                        settings:save()
                        Notification:info(_('Deleted entries will stay in KOReader history (shown as deleted)'))
                        UIManager:scheduleIn(0.5, function()
                            touchmenu_instance:backToUpperMenu()
                        end)
                    end,
                },
            }
        end,
    }
end

return RemoveFromHistoryOnDelete
