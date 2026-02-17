--[[--
Storage utilities for Miniflux download directory: date-based filtering,
size reporting, image-only deletion, and image recovery.
--]]

local EntryPaths = require('domains/utils/entry_paths')
local EntryMetadata = require('domains/utils/entry_metadata')
local lfs = require('libs/libkoreader-lfs')
local _ = require('gettext')

local StorageUtils = {}

local SECONDS_PER_DAY = 24 * 60 * 60

---Parse ISO-8601 date string to unix seconds (simple: only YYYY-MM-DD or full ISO)
---@param iso_string string
---@return number|nil unix_secs
local function parseDateToUnix(iso_string)
    if not iso_string or type(iso_string) ~= 'string' then
        return nil
    end
    local y, m, d = iso_string:match('^(%d+)%-(%d+)%-(%d+)')
    if not y then
        return nil
    end
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not y or not m or not d then
        return nil
    end
    return os.time({ year = y, month = m, day = d, hour = 12, min = 0, sec = 0 })
end

---Collect entry IDs and optional metadata from download dir
---@return table[] list of { entry_id: number, published_at_unix: number|nil, dir_path: string }
function StorageUtils.listEntriesWithDates()
    local base = EntryPaths.getDownloadDir()
    local list = {}
    local attr = lfs.attributes(base, 'mode')
    if attr ~= 'directory' then
        return list
    end

    for name in lfs.dir(base) do
        if name ~= '.' and name ~= '..' then
            local id = tonumber(name)
            if id then
                local dir_path = base .. name .. '/'
                local html_file = dir_path .. 'entry.html'
                local published_unix = nil
                local meta = EntryMetadata.loadMetadata(id)
                if meta and meta.published_at then
                    published_unix = parseDateToUnix(meta.published_at)
                end
                if not published_unix then
                    local fattr = lfs.attributes(html_file, 'modification')
                    published_unix = fattr and fattr or os.time()
                end
                table.insert(list, {
                    entry_id = id,
                    published_at_unix = published_unix,
                    dir_path = dir_path,
                })
            end
        end
    end
    return list
end

---Entries older than threshold (seconds ago)
---@param entries table[] from listEntriesWithDates
---@param older_than_seconds number
---@return table[]
function StorageUtils.filterOlderThan(entries, older_than_seconds)
    local now = os.time()
    local out = {}
    for _, e in ipairs(entries) do
        if e.published_at_unix and (now - e.published_at_unix) >= older_than_seconds then
            table.insert(out, e)
        end
    end
    return out
end

---Total size in bytes of a directory (non-recursive for entry dir: files only)
---@param dir_path string
---@return number bytes
function StorageUtils.dirSize(dir_path)
    local total = 0
    local attr = lfs.attributes(dir_path, 'mode')
    if attr ~= 'directory' then
        return 0
    end
    for name in lfs.dir(dir_path) do
        if name ~= '.' and name ~= '..' then
            local path = dir_path .. name
            local a = lfs.attributes(path)
            if a then
                if a.mode == 'file' then
                    total = total + (a.size or 0)
                elseif a.mode == 'directory' then
                    -- SDR dir: sum files inside
                    for sub in lfs.dir(path) do
                        if sub ~= '.' and sub ~= '..' then
                            local sa = lfs.attributes(path .. '/' .. sub)
                            if sa and sa.mode == 'file' then
                                total = total + (sa.size or 0)
                            end
                        end
                    end
                end
            end
        end
    end
    return total
end

---Storage stats: entries count, total bytes, image bytes/count per entry dir (files that are not entry.html)
---@return table { entry_count: number, total_bytes: number, image_bytes: number, image_count: number }
function StorageUtils.getStorageStats()
    local entries = StorageUtils.listEntriesWithDates()
    local total_bytes = 0
    local image_bytes = 0
    local image_count = 0
    for _, e in ipairs(entries) do
        local dir_path = e.dir_path
        local attr = lfs.attributes(dir_path, 'mode')
        if attr == 'directory' then
            for name in lfs.dir(dir_path) do
                if name ~= '.' and name ~= '..' and name ~= 'entry.html' then
                    local path = dir_path .. name
                    local a = lfs.attributes(path)
                    if a and a.mode == 'file' then
                        local sz = a.size or 0
                        total_bytes = total_bytes + sz
                        image_bytes = image_bytes + sz
                        image_count = image_count + 1
                    end
                end
            end
            local html_path = dir_path .. 'entry.html'
            local ha = lfs.attributes(html_path)
            if ha and ha.mode == 'file' then
                total_bytes = total_bytes + (ha.size or 0)
            end
        end
    end
    return {
        entry_count = #entries,
        total_bytes = total_bytes,
        image_bytes = image_bytes,
        image_count = image_count,
    }
end

---Delete all image files in an entry dir (keep entry.html and SDR)
---@param entry_id number
---@return number deleted_count
function StorageUtils.deleteImagesInEntry(entry_id)
    local dir_path = EntryPaths.getEntryDirectory(entry_id)
    local count = 0
    local attr = lfs.attributes(dir_path, 'mode')
    if attr ~= 'directory' then
        return 0
    end
    for name in lfs.dir(dir_path) do
        if name ~= '.' and name ~= '..' and name ~= 'entry.html' then
            local path = dir_path .. name
            local a = lfs.attributes(path)
            if a and a.mode == 'file' then
                os.remove(path)
                count = count + 1
            end
        end
    end
    return count
end

---Re-download missing images for one entry using metadata images map
---@param entry_id number
---@param settings MinifluxSettings
---@return number re_downloaded_count
function StorageUtils.recoverImagesForEntry(entry_id, settings)
    local Images = require('features/browser/download/utils/images')
    local meta = EntryMetadata.loadMetadata(entry_id)
    if not meta or not meta.images or type(meta.images) ~= 'table' then
        return 0
    end
    local entry_dir = EntryPaths.getEntryDirectory(entry_id)
    local count = 0
    for filename, url in pairs(meta.images) do
        if type(url) == 'string' and url ~= '' then
            local filepath = entry_dir .. filename
            if not lfs.attributes(filepath, 'mode') or lfs.attributes(filepath, 'mode') ~= 'file' then
                local ok = Images.downloadImage({
                    url = url,
                    entry_dir = entry_dir,
                    filename = filename,
                    settings = settings,
                })
                if ok then
                    count = count + 1
                end
            end
        end
    end
    return count
end

---Human-readable size string
---@param bytes number
---@return string
function StorageUtils.formatSize(bytes)
    if bytes < 1024 then
        return bytes .. ' B'
    end
    if bytes < 1024 * 1024 then
        return string.format('%.1f KB', bytes / 1024)
    end
    return string.format('%.1f MB', bytes / (1024 * 1024))
end

return StorageUtils
