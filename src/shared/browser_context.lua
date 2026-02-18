--[[--
Stores the current browser context (feed, category, unread, etc.) in one place
so both the main plugin and the reader plugin instance see the same value.
Required because the reader may load a separate copy of the plugin class.
--]]

return {
    ---@type table|nil { type = string, id?: number, search?: string, ... } set when opening an entry from the plugin
    context = nil,
}
