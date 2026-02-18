--[[--
Stores the last entry we returned from when user tapped "Return to Miniflux" in normal (downloaded) flow.
When they then press X at the listing, we use this to apply auto-delete read on close + history cleanup
before opening KOReader home (same behavior as the Close button in the end-of-entry dialog).
--]]

return {
    ---@type number|nil entry_id
    entry_id = nil,
    ---@type boolean whether that entry was read
    is_read = false,
    ---@type boolean whether that entry was bookmarked/starred (if true we do not auto-delete)
    is_starred = false,
}
