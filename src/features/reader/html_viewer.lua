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
local logger = require('logger')

local HtmlViewer = {}

local DEFAULT_FONT_SIZE = 22
local MIN_FONT_SIZE = 12
local MAX_FONT_SIZE = 40
local ZOOM_STEP = 4

---Inject viewport meta and CSS so content reflows to the visible area (no horizontal scroll).
---Inserts before </head> when present; otherwise appends to the start of the document.
---@param html string Raw HTML document
---@return string HTML with reflow viewport and styles
local function injectReflowCss(html)
    if not html or html == '' then
        return html
    end
    local reflow = [[
<meta name="viewport" content="width=device-width, initial-scale=1">
<style type="text/css">
body { max-width: 100% !important; box-sizing: border-box !important; overflow-wrap: break-word !important; }
img, video, iframe, embed, object { max-width: 100% !important; height: auto !important; }
table { max-width: 100% !important; table-layout: fixed !important; }
pre, code { max-width: 100% !important; overflow-x: auto !important; }
* { box-sizing: border-box !important; }
</style>
]]
    local head_close = html:find('</head>', 1, true)
    if head_close then
        return html:sub(1, head_close - 1) .. reflow .. html:sub(head_close)
    end
    -- No </head>: try inserting after <html> or at start
    local html_open = html:find('<html')
    if html_open then
        local after_tag = html:find('>', html_open, true)
        if after_tag then
            return html:sub(1, after_tag) .. '<head>' .. reflow .. '</head>' .. html:sub(after_tag + 1)
        end
    end
    return reflow .. html
end

---Return URL for print/reader version when possible to reduce payload and clutter on small devices.
---Appends ?print=1 or &print=1; many sites return a stripped page for this.
---@param url string Original article URL
---@return string URL to fetch (print version when supported)
local function urlForPrintView(url)
    if not url or url == '' then
        return url
    end
    if url:find('?') then
        return url .. '&print=1'
    end
    return url .. '?print=1'
end

---Show article URL in an in-app HtmlBoxWidget (no external browser).
---@param url string Article URL to fetch and display
---@param title string|nil Optional title for the viewer
---@param opts table|nil Optional: { parent_browser = Browser } to track overlay so browser can close it first and avoid hang
function HtmlViewer.showUrl(url, title, opts)
    logger.dbg('[Miniflux:HtmlViewer] showUrl', url and url:sub(1, 60) or 'nil')
    if not url or url == '' then
        Notification:error(_('No URL provided'))
        return
    end

    -- Prefer print version so we don't overload the small viewer (less ads, simpler layout).
    local fetch_url = urlForPrintView(url)

    -- Show loading and force a repaint so it is visible before the blocking fetch (some devices don't refresh until touch).
    local loading = Notification:info(_('Loading…'))
    UIManager:setDirty(nil, 'full')
    UIManager:scheduleIn(0, function()
        -- Request with mobile User-Agent so servers return mobile-optimized layout for better reading.
        local body, err = UrlFetch.fetch(fetch_url, {
            timeout = 25,
            max_size = 2 * 1024 * 1024,
            headers = { ['User-Agent'] = 'Mozilla/5.0 (Linux; Android 10; e-reader) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0 Mobile Safari/537.36' },
        })
        loading:close()

        if err then
            logger.dbg('[Miniflux:HtmlViewer] fetch failed:', err)
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
            logger.dbg('[Miniflux:HtmlViewer] empty body')
            Notification:error(_('Empty page'))
            return
        end
        logger.dbg('[Miniflux:HtmlViewer] fetch ok, body size:', #body)

        local entry_data = opts and opts.entry_data
        local miniflux = opts and opts.miniflux
        if miniflux and miniflux.reader_entry_service and entry_data and entry_data.id then
            miniflux.reader_entry_service:performAutoMarkAsRead(
                entry_data.id,
                entry_data.status == 'read' and 'read' or 'unread'
            )
        end

        -- Reflow content to visible area (viewport + max-width so no horizontal scroll)
        body = injectReflowCss(body)

        local Screen = Device.screen
        local dimen = Geom:new{
            w = Screen:getWidth(),
            h = Screen:getHeight(),
        }

        local HtmlBoxWidget = require('ui/widget/htmlboxwidget')
        local html_box = HtmlBoxWidget:new{ dimen = dimen }

        html_box.raw_body = body
        html_box.current_font_size = DEFAULT_FONT_SIZE
        local ok = pcall(function()
            html_box:setRawContent(body, 'html', html_box.current_font_size, nil)
        end)
        if not ok then
            logger.dbg('[Miniflux:HtmlViewer] setRawContent failed')
            Notification:error(_('Could not display page'))
            return
        end

        -- So setDirty targets this widget when we scroll
        html_box.dialog = html_box

        ---True if html_box is still valid (document not torn down); avoids crash when event or repaint fires after close/suspend.
        local function html_box_valid()
            return html_box and html_box.document
        end

        -- Guard paintTo so repaint (e.g. after suspend) doesn't call _render when document is nil
        local orig_paintTo = html_box.paintTo
        if orig_paintTo then
            function html_box:paintTo(bb, x, y)
                if not self.document then
                    logger.dbg('[Miniflux:HtmlViewer] paintTo skipped (document nil)')
                    return
                end
                return orig_paintTo(self, bb, x, y)
            end
        end

        ---Re-layout with new font size (zoom). Call after changing html_box.current_font_size.
        local function applyZoom()
            if not html_box_valid() then return end
            pcall(function()
                html_box:setRawContent(html_box.raw_body, 'html', html_box.current_font_size, nil)
            end)
            html_box:freeBb()
            html_box:_render()
            UIManager:setDirty(html_box.dialog or html_box, 'ui')
        end

        -- Close (Back), scroll down (PgFwd), scroll up (PgBack) so user can exit and scroll
        html_box.key_events = html_box.key_events or {}
        html_box.key_events.Close = { { Device.input.group.Back } }
        html_box.key_events.ScrollDown = { { Device.input.group.PgFwd } }
        html_box.key_events.ScrollUp = { { Device.input.group.PgBack } }

        local parent_browser = opts and opts.parent_browser
        function html_box:onClose()
            logger.dbg('[Miniflux:HtmlViewer] onClose')
            if parent_browser and parent_browser.current_overlay == self then
                parent_browser.current_overlay = nil
            end
            UIManager:close(self)
            return true
        end

        ---Show the same end-of-entry dialog as when finishing a local read (if we have entry_data + miniflux).
        local function showEndOfEntryDialog()
            if not entry_data or not entry_data.id or not miniflux then
                return false
            end
            local MinifluxEndOfBook = require('features/reader/modules/miniflux_end_of_book')
            local eob = MinifluxEndOfBook:new({ miniflux = miniflux })
            local on_return = html_box._close_viewer
            local entry_info = {
                entry_id = entry_data.id,
                from_html_viewer = true,
                on_return_to_browser = type(on_return) == 'function' and on_return or nil,
                on_before_navigate = type(on_return) == 'function' and on_return or nil,
            }
            return eob:showDialog(entry_info) ~= nil
        end

        function html_box:onScrollDown()
            if not html_box_valid() then return false end
            if self.page_number < self.page_count then
                self:setPageNumber(self.page_number + 1)
                self:freeBb()
                self:_render()
                UIManager:setDirty(self.dialog or self, 'ui')
                return true
            end
            -- At bottom: show end-of-entry menu (same as local read)
            if showEndOfEntryDialog() then
                return true
            end
            return false
        end

        function html_box:onScrollUp()
            if not html_box_valid() then return false end
            if self.page_number > 1 then
                self:setPageNumber(self.page_number - 1)
                self:freeBb()
                self:_render()
                UIManager:setDirty(self.dialog or self, 'ui')
                return true
            end
            return false
        end

        function html_box:onZoomIn()
            if not html_box_valid() then return false end
            if self.current_font_size < MAX_FONT_SIZE then
                self.current_font_size = math.min(MAX_FONT_SIZE, self.current_font_size + ZOOM_STEP)
                applyZoom()
                return true
            end
            return false
        end

        function html_box:onZoomOut()
            if not html_box_valid() then return false end
            if self.current_font_size > MIN_FONT_SIZE then
                self.current_font_size = math.max(MIN_FONT_SIZE, self.current_font_size - ZOOM_STEP)
                applyZoom()
                return true
            end
            return false
        end

        -- Touch: swipe up/down = scroll; swipe east/west = zoom; tap top-right to close.
        -- HtmlBoxWidget is an InputContainer, so we register zones and ges_events on it and show it directly (no wrapper)
        -- so that it receives touch events on devices where a wrapper would block or not get gestures.
        if Device:isTouchDevice() then
            local GestureRange = require('ui/gesturerange')
            html_box.ges_events = html_box.ges_events or {}
            html_box.ges_events.Swipe = {
                GestureRange:new{
                    ges = 'swipe',
                    range = function() return html_box.dimen end,
                },
            }
            function html_box:onSwipe(_, ges)
                if ges.direction == 'north' then
                    return self:onScrollDown()
                elseif ges.direction == 'south' then
                    return self:onScrollUp()
                elseif ges.direction == 'east' then
                    return self:onZoomIn()
                elseif ges.direction == 'west' then
                    return self:onZoomOut()
                end
                return false
            end
            -- Close zone: top-right (X). Register before full-screen tap so close takes precedence.
            html_box:registerTouchZones({
                {
                    id = 'html_viewer_close',
                    ges = 'tap',
                    screen_zone = { ratio_x = 0.78, ratio_y = 0, ratio_w = 0.22, ratio_h = 0.14 },
                    handler = function()
                        if parent_browser and parent_browser.current_overlay == html_box then
                            parent_browser.current_overlay = nil
                        end
                        UIManager:close(html_box)
                        return true
                    end,
                },
                {
                    id = 'html_viewer_swipe',
                    ges = 'swipe',
                    screen_zone = { ratio_x = 0, ratio_y = 0, ratio_w = 1, ratio_h = 1 },
                    handler = function(ges)
                        if not html_box_valid() then return false end
                        return html_box:onSwipe(nil, ges)
                    end,
                },
                {
                    id = 'html_viewer_tap',
                    ges = 'tap',
                    screen_zone = { ratio_x = 0, ratio_y = 0, ratio_w = 1, ratio_h = 1 },
                    overrides = { 'html_viewer_close' },
                    handler = function(ges)
                        if not html_box_valid() then return false end
                        if html_box.onTapText then
                            return html_box:onTapText(nil, ges)
                        end
                        return false
                    end,
                },
            })
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

        -- Show html_box directly so it receives touch (HtmlBoxWidget is InputContainer). No wrapper so touch reaches it.
        local function doClose()
            if parent_browser and parent_browser.current_overlay == html_box then
                parent_browser.current_overlay = nil
            end
            -- Defer close so we exit the event handler first; then force repaint so browser draws cleanly (avoids artefacts/crash).
            UIManager:scheduleIn(0, function()
                if UIManager:isWidgetShown(html_box) then
                    UIManager:close(html_box)
                end
                UIManager:setDirty(nil, 'full')
            end)
        end
        html_box._close_viewer = doClose
        -- Close key (Back): doClose and clear overlay
        local orig_handleEvent = html_box.handleEvent
        if orig_handleEvent then
            html_box.handleEvent = function(self, ev)
                if ev.type == 'Close' then
                    doClose()
                    return true
                end
                if not html_box_valid() then return false end
                return orig_handleEvent(self, ev)
            end
        end

        -- When closed by Home/system, clear overlay so browser X does not hang
        local orig_onCloseWidget = html_box.onCloseWidget
        html_box.onCloseWidget = function(self)
            logger.dbg('[Miniflux:HtmlViewer] onCloseWidget, clearing overlay')
            if parent_browser and parent_browser.current_overlay == html_box then
                parent_browser.current_overlay = nil
            end
            if orig_onCloseWidget then orig_onCloseWidget(self) end
        end

        if parent_browser then
            parent_browser.current_overlay = html_box
        end

        -- When opening a link in external browser, close the viewer
        local orig_link_cb = html_box.html_link_tapped_callback
        html_box.html_link_tapped_callback = function(link)
            if orig_link_cb then orig_link_cb(link) end
            if link and link.uri and Device.openLink and not (Device.isKindle or Device.isKobo or Device.isPocketBook) then
                doClose()
            end
        end

        UIManager:show(html_box)
        -- Force full repaint so the whole viewer is drawn (avoids only a "square" visible until user scrolls).
        UIManager:setDirty(html_box, 'full')
    end)
end

return HtmlViewer
