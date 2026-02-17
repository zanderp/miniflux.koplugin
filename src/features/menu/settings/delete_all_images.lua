local ButtonDialog = require('ui/widget/buttondialog')
local UIManager = require('ui/uimanager')
local Notification = require('shared/widgets/notification')
local StorageUtils = require('domains/utils/storage_utils')
local _ = require('gettext')
local T = require('ffi/util').template

-- **Delete all images** - Remove image files from all entries, keep entry text (HTML).
local DeleteAllImages = {}

---Get the menu item
---@return table Menu item configuration
function DeleteAllImages.getMenuItem()
    return {
        text = _('Delete all images (keep text)'),
        help_text = _('Remove image files from all downloaded entries; entry text is kept'),
        keep_menu_open = true,
        callback = function()
            DeleteAllImages.showConfirmDialog()
        end,
    }
end

function DeleteAllImages.showConfirmDialog()
    local stats = StorageUtils.getStorageStats()
    if stats.entry_count == 0 then
        Notification:info(_('No downloaded entries'))
        return
    end
    if stats.image_count == 0 then
        Notification:info(_('No images to delete'))
        return
    end

    local confirm_dialog
    confirm_dialog = ButtonDialog:new({
        title = T(_('Delete %1 images from %2 entries?'), stats.image_count, stats.entry_count),
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
                    text = _('Delete images'),
                    callback = function()
                        UIManager:close(confirm_dialog)
                        local entries = StorageUtils.listEntriesWithDates()
                        local total_deleted = 0
                        for _, e in ipairs(entries) do
                            total_deleted = total_deleted + StorageUtils.deleteImagesInEntry(e.entry_id)
                        end
                        Notification:success(T(_('Deleted %1 image files'), total_deleted))
                    end,
                },
            },
        },
    })
    UIManager:show(confirm_dialog)
end

return DeleteAllImages
