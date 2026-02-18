--[[--
Holds a reference to the "main" Miniflux plugin instance (the one that opened
the browser from the menu). Used by the reader's end-of-book module to return
to the browser when the reader's plugin instance has no .browser in the stack.
--]]

return {
    ---@type table|nil Miniflux plugin instance that opened the browser (set in main.lua onReadMinifluxEntries)
    main_instance = nil,
}
