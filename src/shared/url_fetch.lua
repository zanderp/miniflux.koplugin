--[[--
Fetch a URL body as a string (for in-app HTML viewer, etc.).
--]]

local http = require('socket.http')
local ltn12 = require('ltn12')
local socket = require('socket')
local socketutil = require('socketutil')

local UrlFetch = {}

local MAX_BODY_SIZE = 2 * 1024 * 1024 -- 2 MB
local DEFAULT_TIMEOUT = 30

---Fetch URL and return body as string
---@param url string Full URL to fetch
---@param opts? { timeout?: number, max_size?: number, headers?: table, referer?: string } Optional headers and referer (e.g. for Reddit images)
---@return string|nil body, string|nil error
function UrlFetch.fetch(url, opts)
    opts = opts or {}
    local max_size = opts.max_size or MAX_BODY_SIZE
    local timeout = opts.timeout or DEFAULT_TIMEOUT
    local default_headers = { ['User-Agent'] = 'KOReader/1.0 (Miniflux)' }
    local headers = opts.headers and (function()
        local h = {}
        for k, v in pairs(default_headers) do h[k] = v end
        for k, v in pairs(opts.headers) do h[k] = v end
        return h
    end)() or (function()
        local h = {}
        for k, v in pairs(default_headers) do h[k] = v end
        return h
    end)()
    if opts.referer and opts.referer ~= '' then
        headers['Referer'] = opts.referer
    end

    local response_body = {}
    local request = {
        url = url,
        method = 'GET',
        headers = headers,
        sink = ltn12.sink.table(response_body),
    }

    socketutil:set_timeout(timeout * 1000, timeout * 1000)
    local code, resp_headers, status = socket.skip(1, http.request(request))
    socketutil:reset_timeout()

    if resp_headers == nil then
        return nil, 'network_error'
    end
    if code ~= 200 then
        return nil, 'http_' .. tostring(code)
    end

    local body = table.concat(response_body)
    if #body > max_size then
        return nil, 'too_large'
    end
    return body, nil
end

return UrlFetch
