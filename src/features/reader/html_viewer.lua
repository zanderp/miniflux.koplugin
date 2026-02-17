--[[--
In-app HTML viewer using KOReader's HtmlBoxWidget.
Fetches a URL and displays the HTML without opening an external browser.
Works on all devices (including Kindle).
--]]

local Device = require('device')
local Geom = require('ui/geometry')
local UIManager = require('ui/uimanager')
local Notification = require('shared/widgets/notification')
local UrlFetch = require('shared/url_fetch')
local _ = require('gettext')

local HtmlViewer = {}

local DEFAULT_FONT_SIZE = 22

---Show article URL in an in-app HtmlBoxWidget (no external browser).
---@param url string Article URL to fetch and display
---@param title string|nil Optional title for the viewer
function HtmlViewer.showUrl(url, title)
    if not url or url == '' then
        Notification:error(_('No URL provided'))
        return
    end

    local loading = Notification:info(_('Loading…'))
    local body, err = UrlFetch.fetch(url, { timeout = 25, max_size = 2 * 1024 * 1024 })
    loading:close()

    if err then
        if err == 'network_error' then
            Notification:error(_('Network error'))
        elseif err == 'too_large' then
            Notification:error(_('Page too large'))
        else
            Notification:error(_('Failed to load page'))
        end
        return
    end

    if not body or #body == 0 then
        Notification:error(_('Empty page'))
        return
    end

    local Screen = Device.screen
    local dimen = Geom:new{
        w = Screen:getWidth(),
        h = Screen:getHeight(),
    }

    local HtmlBoxWidget = require('ui/widget/htmlboxwidget')
    local html_box = HtmlBoxWidget:new{ dimen = dimen }

    local ok, set_err = pcall(function()
        html_box:setRawContent(body, 'html', DEFAULT_FONT_SIZE, nil)
    end)
    if not ok then
        Notification:error(_('Could not display page'))
        return
    end

    -- Close on Back so user can dismiss the viewer
    html_box.key_events = html_box.key_events or {}
    html_box.key_events.Close = { { Device.input.group.Back } }
    function html_box:onClose()
        UIManager:close(self)
        return true
    end

    -- Optional: when user taps a link, we could show external link dialog or fetch that URL
    html_box.html_link_tapped_callback = function(link)
        if link and link.uri and link.uri ~= '' then
            if Device.openLink and not (Device.isKindle or Device.isKobo or Device.isPocketBook) then
                UIManager:close(html_box)
                Device:openLink(link.uri)
            else
                Notification:info(_('Link: ') .. (link.uri:sub(1, 50)) .. (link.uri:len() > 50 and '…' or ''))
            end
        end
    end

    UIManager:show(html_box)
end

return HtmlViewer
