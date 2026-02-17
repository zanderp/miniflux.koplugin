local lfs = require('libs/libkoreader-lfs')
local Error = require('shared/error')

-- **Files** - Basic file utilities for common file operations like writing,
-- directory creation, and path manipulation.
local Files = {}

-- =============================================================================
-- BASIC FILE OPERATIONS
-- =============================================================================

---Remove trailing slashes from a string
---@param s string String to remove trailing slashes from
---@return string String with trailing slashes removed
function Files.rtrimSlashes(s)
    local n = #s
    while n > 0 and s:find('^/', n) do
        n = n - 1
    end
    return s:sub(1, n)
end

---Write content to a file
---@param file_path string Path to write to
---@param content string Content to write
---@return boolean|nil success, Error|nil error
function Files.writeFile(file_path, content)
    local file, errmsg = io.open(file_path, 'w')
    if not file then
        return nil, Error.new('Failed to open file for writing: ' .. (errmsg or 'unknown error'))
    end

    local success, write_errmsg = file:write(content)
    if not success then
        file:close()
        return nil, Error.new('Failed to write content: ' .. (write_errmsg or 'unknown error'))
    end

    file:close()
    return true, nil
end

---Create directory if it doesn't exist
---@param dir_path string Directory path to create
---@return boolean|nil success, Error|nil error
function Files.createDirectory(dir_path)
    if not lfs.attributes(dir_path, 'mode') then
        local success = lfs.mkdir(dir_path)
        if not success then
            return nil, Error.new('Failed to create directory')
        end
    end
    return true, nil
end

---Remove a directory only if it is empty (including after removing any empty
---subdirectories). Handles hidden subdirectories so that e.g. a cache dir
---containing only an empty .hidden/ subfolder is still removed (closes #60, PR #63).
---@param dir_path string Directory path (with or without trailing slash)
---@return boolean removed True if the directory was removed, false if it had content
function Files.removeEmptyDirectory(dir_path)
    local mode = lfs.attributes(dir_path, 'mode')
    if mode ~= 'directory' then
        return false
    end

    -- Normalize: ensure trailing slash for consistent path joins
    local path = dir_path:match('^(.*)/$') and dir_path or (dir_path .. '/')

    for name in lfs.dir(path) do
        if name ~= '.' and name ~= '..' then
            local full = path .. name
            local sub_mode = lfs.attributes(full, 'mode')
            if sub_mode == 'directory' then
                -- Recurse so empty (including hidden) subdirs are removed first
                Files.removeEmptyDirectory(full)
                -- If subdir still exists it had content; do not remove parent
                if lfs.attributes(full, 'mode') then
                    return false
                end
            else
                -- File or other: directory is not empty
                return false
            end
        end
    end

    -- All entries were subdirs and have been removed; directory is now empty
    local normalized = path:gsub('/$', '')
    lfs.rmdir(normalized)
    return true
end

return Files
