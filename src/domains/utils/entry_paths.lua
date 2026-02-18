local DataStorage = require('datastorage')
local Device = require('device')
local LuaSettings = require('luasettings')
local lfs = require('libs/libkoreader-lfs')
local ReaderUI = require('apps/reader/readerui')
local FileManager = require('apps/filemanager/filemanager')
local Files = require('shared/files')
local _ = require('gettext')
local logger = require('logger')

-- **Entry Path Utilities** - Pure filesystem and path operations for entries
-- Handles directory structures, file paths, and basic file operations
local EntryPaths = {}

---Get the base download directory for all entries.
---Uses custom path from settings if set (issue #57), otherwise default <data>/miniflux/.
---@return string Download directory path (with trailing slash)
function EntryPaths.getDownloadDir()
    local settings = LuaSettings:open(DataStorage:getSettingsDir() .. '/miniflux.lua')
    local custom = settings:readSetting('download_dir', '')
    if custom and type(custom) == 'string' and custom:match('%S') then
        return custom:gsub('/+$', '') .. '/'
    end
    return ('%s/%s/'):format(DataStorage:getFullDataDir(), 'miniflux')
end

---Get the local directory path for a specific entry
---@param entry_id number Entry ID
---@return string Entry directory path
function EntryPaths.getEntryDirectory(entry_id)
    return EntryPaths.getDownloadDir() .. tostring(entry_id) .. '/'
end

---Get the local HTML file path for a specific entry
---@param entry_id number Entry ID
---@return string HTML file path
function EntryPaths.getEntryHtmlPath(entry_id)
    return EntryPaths.getEntryDirectory(entry_id) .. 'entry.html'
end

---Check if file path is a miniflux entry (under current download dir, ends with /entry.html)
---@param file_path string File path to check
---@return boolean true if miniflux entry, false otherwise
function EntryPaths.isMinifluxEntry(file_path)
    if not file_path then
        return false
    end
    local base = EntryPaths.getDownloadDir()
    if file_path:sub(1, #base) ~= base then
        return false
    end
    return file_path:match('/(%d+)/entry%.html$') ~= nil
end

---Extract entry ID from miniflux file path
---@param file_path string File path to check
---@return number|nil entry_id Entry ID or nil if not a miniflux entry
function EntryPaths.extractEntryIdFromPath(file_path)
    if not file_path then
        return nil
    end
    local base = EntryPaths.getDownloadDir()
    if file_path:sub(1, #base) ~= base then
        return nil
    end
    local rest = file_path:sub(#base + 1)
    local entry_id_str = rest:match('^(%d+)/') or rest:match('^(%d+)/entry%.html$')
    return entry_id_str and tonumber(entry_id_str)
end

---Check if an entry is downloaded (has HTML file)
---@param entry_id number Entry ID
---@return boolean downloaded True if entry is downloaded locally
function EntryPaths.isEntryDownloaded(entry_id)
    local html_file = EntryPaths.getEntryHtmlPath(entry_id)
    return lfs.attributes(html_file, 'mode') == 'file'
end

---Delete a local entry and its files
---@param entry_id number Entry ID
---@param opts? {silent?: boolean, open_folder?: boolean} Optional: silent = true skips notification and folder; open_folder = false skips only opening folder
---@return boolean success True if deletion succeeded
function EntryPaths.deleteLocalEntry(entry_id, opts)
    opts = opts or {}
    logger.dbg('[Miniflux:EntryPaths] deleteLocalEntry entry_id:', entry_id)
    local _ = require('gettext')
    local Notification = require('shared/widgets/notification')
    local FFIUtil = require('ffi/util')

    local entry_dir = EntryPaths.getEntryDirectory(entry_id)
    local html_path = EntryPaths.getEntryHtmlPath(entry_id)
    local ok = FFIUtil.purgeDir(entry_dir)

    if ok then
        -- Remove entry directory if empty (including empty hidden subdirs; closes #60, PR #63)
        Files.removeEmptyDirectory(entry_dir)
        -- Remove from KOReader history so we don't leave broken entries
        pcall(function()
            local ReadHistory = require('readhistory')
            ReadHistory:fileDeleted(html_path)
        end)
        -- Invalidate download cache for this entry
        local MinifluxBrowser = require('features/browser/miniflux_browser')
        MinifluxBrowser.deleteEntryInfoCache(entry_id)
        logger.dbg(
            '[Miniflux:EntryPaths] Invalidated download cache after deleting entry',
            entry_id
        )
        if not opts.silent then
            Notification:success(_('Local entry deleted successfully'))
        end
        if opts.open_folder ~= false and not opts.silent then
            EntryPaths.openMinifluxFolder()
        end
        return true
    else
        logger.dbg('[Miniflux:EntryPaths] deleteLocalEntry failed entry_id:', entry_id, 'purgeDir result:', ok)
        if not opts.silent then
            Notification:error(_('Failed to delete local entry: ') .. tostring(ok))
        end
        return false
    end
end

---Open the Miniflux folder in file manager
---@return nil
function EntryPaths.openMinifluxFolder()
    local download_dir = EntryPaths.getDownloadDir()

    if ReaderUI.instance then
        ReaderUI.instance:onClose()
    end

    if FileManager.instance then
        FileManager.instance:reinit(download_dir)
    else
        FileManager:showFiles(download_dir)
    end
end

---Open the KOReader home folder in file manager (same as file manager "home").
---Uses G_reader_settings home_dir, or Device.home_dir if unset or invalid.
---@return nil
function EntryPaths.openKoreaderHomeFolder()
    if ReaderUI.instance then
        ReaderUI.instance:onClose()
    end

    local home_dir = G_reader_settings and G_reader_settings:readSetting('home_dir')
    if not home_dir or lfs.attributes(home_dir, 'mode') ~= 'directory' then
        home_dir = Device.home_dir
    end
    if not home_dir then
        -- Fallback: filemanagerutil.getDefaultDir() if available
        local ok, filemanagerutil = pcall(require, 'apps/filemanager/filemanagerutil')
        if ok and filemanagerutil and filemanagerutil.getDefaultDir then
            home_dir = filemanagerutil.getDefaultDir()
        end
    end
    home_dir = home_dir or lfs.currentdir()

    if FileManager.instance then
        FileManager.instance:reinit(home_dir)
    else
        FileManager:showFiles(home_dir)
    end
end

return EntryPaths
