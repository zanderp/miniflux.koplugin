local UIManager = require('ui/uimanager')
local Notification = require('shared/widgets/notification')
local _ = require('gettext')

-- **Use HTML reader** - When ON, open the article URL in the system/HTML browser
-- (no download). When OFF, download entry then open in KOReader reader.
local UseHtmlReader = {}

---Get the menu item
---@param settings MinifluxSettings Settings instance
---@return table Menu item configuration
function UseHtmlReader.getMenuItem(settings)
    return {
        text_func = function()
            return settings.use_html_reader and _('Use HTML reader - ON')
                or _('Use HTML reader - OFF')
        end,
        help_text = _('Open article URL in system browser (no download). When OFF, download then open in reader.'),
        keep_menu_open = true,
        sub_item_table_func = function()
            return {
                {
                    text = _('ON') .. (settings.use_html_reader and ' ✓' or ''),
                    keep_menu_open = true,
                    callback = function(touchmenu_instance)
                        settings.use_html_reader = true
                        Notification:info(_('Entries will open in system browser (no download)'))
                        UIManager:scheduleIn(0.5, function()
                            touchmenu_instance:backToUpperMenu()
                        end)
                    end,
                },
                {
                    text = _('OFF') .. (not settings.use_html_reader and ' ✓' or ''),
                    keep_menu_open = true,
                    callback = function(touchmenu_instance)
                        settings.use_html_reader = false
                        Notification:success(_('Entries will be downloaded then opened'))
                        UIManager:scheduleIn(0.5, function()
                            touchmenu_instance:backToUpperMenu()
                        end)
                    end,
                },
            }
        end,
    }
end

return UseHtmlReader
