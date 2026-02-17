local ButtonDialog = require('ui/widget/buttondialog')
local InputDialog = require('ui/widget/inputdialog')
local UIManager = require('ui/uimanager')
local Notification = require('shared/widgets/notification')
local EntryPaths = require('domains/utils/entry_paths')
local Files = require('shared/files')
local _ = require('gettext')
local T = require('ffi/util').template

-- **Download Location Settings** - Custom download directory for Miniflux entries (issue #57).
-- Allows choosing an existing folder or creating a new one inside a directory.
local DownloadLocation = {}

---Get display path (default label when using built-in default)
---@param path string Full path or empty
---@return string
local function displayPath(path)
    if not path or path == '' then
        return _('(Default: Miniflux data folder)')
    end
    return path
end

---Get the menu item for download location
---@param settings MinifluxSettings Settings instance
---@return table Menu item configuration
function DownloadLocation.getMenuItem(settings)
    return {
        text_func = function()
            local current = settings.download_dir or ''
            if current == '' then
                return T(_('Download location: %1'), _('Default'))
            end
            -- Show last path component or truncated path
            local short = current:match('([^/]+)/?$') or current
            if #current > 35 then
                short = '…' .. current:sub(-34)
            end
            return T(_('Download location: %1'), short)
        end,
        help_text = _('Choose where to save downloaded entries'),
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            DownloadLocation.showDialog(settings, function()
                if touchmenu_instance and touchmenu_instance.updateItems then
                    touchmenu_instance:updateItems()
                end
            end)
        end,
    }
end

---Show download location dialog with choose folder / create new / use default
---@param settings MinifluxSettings Settings instance
---@param refresh_callback? function Optional callback to refresh the menu after saving
---@return nil
function DownloadLocation.showDialog(settings, refresh_callback)
    local current_path = settings.download_dir or ''
    if current_path == '' then
        current_path = EntryPaths.getDownloadDir()
    end

    local function saveAndClose(path)
        settings.download_dir = path or ''
        Notification:success(_('Download location saved'))
        if refresh_callback then
            refresh_callback()
        end
    end

    local function openChooseDir(initial_path)
        local DownloadMgr = require('ui/downloadmgr')
        DownloadMgr:new({
            onConfirm = function(path)
                if path and path ~= '' then
                    saveAndClose(path:gsub('/+$', '') .. '/')
                end
            end,
        }):chooseDir(initial_path)
    end

    local function openCreateFolderDialog(parent_path)
        parent_path = parent_path or EntryPaths.getDownloadDir()
        local input_dialog
        input_dialog = InputDialog:new({
            title = _('New folder name'),
            input = '',
            input_hint = _('miniflux_entries'),
            buttons = {
                {
                    {
                        text = _('Cancel'),
                        id = 'close',
                        callback = function()
                            UIManager:close(input_dialog)
                        end,
                    },
                    {
                        text = _('Create'),
                        is_enter_default = true,
                        callback = function()
                            local name = input_dialog:getInputText()
                            if not name or name:match('^%s*$') then
                                Notification:warning(_('Please enter a folder name'))
                                return
                            end
                            name = name:gsub('^%s+', ''):gsub('%s+$', '')
                            if name == '' then
                                Notification:warning(_('Please enter a folder name'))
                                return
                            end
                            UIManager:close(input_dialog)
                            local new_path = parent_path:gsub('/+$', '') .. '/' .. name .. '/'
                            local ok, err = Files.createDirectory(new_path)
                            if ok then
                                saveAndClose(new_path)
                            else
                                Notification:error(_('Could not create folder: ') .. (err and err.message or tostring(err)))
                            end
                        end,
                    },
                },
            },
        })
        UIManager:show(input_dialog)
        input_dialog:onShowKeyboard()
    end

    local location_dialog
    location_dialog = ButtonDialog:new({
        title = T(_('Download location\n%1'), displayPath(current_path)),
        title_align = 'center',
        buttons = {
            {
                {
                    text = _('Choose folder'),
                    callback = function()
                        UIManager:close(location_dialog)
                        openChooseDir(current_path)
                    end,
                },
                {
                    text = _('Create new folder'),
                    callback = function()
                        UIManager:close(location_dialog)
                        -- Let user pick parent directory, then prompt for new folder name
                        local DownloadMgr = require('ui/downloadmgr')
                        DownloadMgr:new({
                            onConfirm = function(parent_path)
                                if parent_path and parent_path ~= '' then
                                    local with_slash = parent_path:gsub('/+$', '') .. '/'
                                    openCreateFolderDialog(with_slash)
                                end
                            end,
                        }):chooseDir(current_path)
                    end,
                },
            },
            {
                {
                    text = _('Use default'),
                    callback = function()
                        UIManager:close(location_dialog)
                        saveAndClose('')
                    end,
                },
                {
                    text = _('Close'),
                    callback = function()
                        UIManager:close(location_dialog)
                    end,
                },
            },
        },
    })
    UIManager:show(location_dialog)
end

return DownloadLocation
