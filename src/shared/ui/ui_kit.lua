-- src/shared/ui/ui_kit.lua — FSD shared UI kit
local utf8 = require("utf8")
local ui = {}

ui.colors = {
    bg = {0.09, 0.12, 0.17},
    panel = {0.13, 0.17, 0.23},
    panel_alt = {0.16, 0.21, 0.28},
    header = {0.11, 0.15, 0.21},
    accent = {0.20, 0.58, 0.90},
    accent_dark = {0.14, 0.42, 0.68},
    text = {0.93, 0.95, 0.97},
    muted = {0.58, 0.65, 0.73},
    green = {0.35, 0.90, 0.48},
    red = {0.98, 0.35, 0.35},
    yellow = {1.00, 0.80, 0.25},
    white = {1, 1, 1},
}

local fonts = {}
local ui_scale = 0.9

local function load_font(path, size)
    local scale_size = math.floor(size * ui_scale)
    local ok, font = pcall(love.graphics.newFont, path, scale_size)
    if ok and font then
        return font
    end
    return love.graphics.newFont(scale_size)
end

local function is_emoji(cp)
    return (cp >= 0x1F600 and cp <= 0x1F64F) or
           (cp >= 0x1F300 and cp <= 0x1F5FF) or
           (cp >= 0x1F680 and cp <= 0x1F6FF) or
           (cp >= 0x1F1E0 and cp <= 0x1F1FF) or
           (cp >= 0x2600 and cp <= 0x26FF) or
           (cp >= 0x2700 and cp <= 0x27BF) or
           (cp >= 0x1F900 and cp <= 0x1F9FF) or
           (cp >= 0x1FA00 and cp <= 0x1FAFF) or
           (cp == 0x200D) or
           (cp >= 0xFE00 and cp <= 0xFE0F) or
           (cp == 0x20E3)
end

local function emoji_font_for(font)
    if font == fonts.normal then return fonts.emoji_normal end
    if font == fonts.small then return fonts.emoji_small end
    if font == fonts.tiny then return fonts.emoji_tiny end
    return fonts.emoji_normal
end

function ui.load_fonts(scale)
    if scale == nil then
        local w, h = love.graphics.getDimensions()
        ui_scale = math.min(w / 640, h / 480)
        if ui_scale < 0.5 then ui_scale = 0.5 end
        if ui_scale > 2.0 then ui_scale = 2.0 end
    else
        ui_scale = scale
    end
    local path = "fonts/AdwaitaSans-Regular.ttf"
    if not love.filesystem.getInfo(path) then
        path = nil
    end

    fonts.title = load_font(path, 26)
    fonts.subtitle = load_font(path, 19)
    fonts.normal = load_font(path, 16)
    fonts.small = load_font(path, 14)
    fonts.tiny = load_font(path, 12)
    fonts.mono = load_font("fonts/JetBrainsMono_SemiBold.ttf", 13)
    fonts.emoji_normal = load_font("fonts/TwitterColorEmoji-SVGinOT.ttf", 16)
    fonts.emoji_small = load_font("fonts/TwitterColorEmoji-SVGinOT.ttf", 14)
    fonts.emoji_tiny = load_font("fonts/TwitterColorEmoji-SVGinOT.ttf", 12)
    fonts.bold = load_font("fonts/AdwaitaSans-Bold.ttf", 16) or fonts.normal
    fonts.italic = load_font("fonts/AdwaitaSans-Italic.ttf", 16) or fonts.normal
    fonts.bold_italic = load_font("fonts/AdwaitaSans-BoldItalic.ttf", 16) or fonts.normal
    return fonts
end

function ui.get_scale()
    return ui_scale
end

function ui.set_scale(scale)
    ui_scale = scale
end

function ui.width()    return love.graphics.getWidth() end
function ui.height()   return love.graphics.getHeight() end

function ui.set_color(color, alpha)
    if not color then
        love.graphics.setColor(1, 1, 1, alpha or 1)
        return
    end
    love.graphics.setColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

function ui.clear(color)
    ui.set_color(color or ui.colors.bg)
    love.graphics.rectangle("fill", 0, 0, ui.width(), ui.height())
    ui.set_color(ui.colors.white)
end

function ui.rect(x, y, w, h, color, radius)
    ui.set_color(color)
    if radius then
        love.graphics.rectangle("fill", x, y, w, h, radius, radius)
    else
        love.graphics.rectangle("fill", x, y, w, h)
    end
    ui.set_color(ui.colors.white)
end

function ui.outline(x, y, w, h, color, radius)
    ui.set_color(color)
    if radius then
        love.graphics.rectangle("line", x, y, w, h, radius, radius)
    else
        love.graphics.rectangle("line", x, y, w, h)
    end
    ui.set_color(ui.colors.white)
end

function ui.text(text, x, y, font, color)
    ui.set_color(color or ui.colors.text)
    local f = font or fonts.normal
    local ef = fonts.emoji_normal and emoji_font_for(f) or nil
    if ef then
        local cur_x = x
        local run_start = 1
        local run_is_emoji = nil
        local t = type(text)=="string" and text or tostring(text or "")
        for i, cp in utf8.codes(t) do
            local cp_emoji = is_emoji(cp)
            if run_is_emoji == nil then
                run_is_emoji = cp_emoji
            elseif run_is_emoji ~= cp_emoji then
                local run_text = t:sub(run_start, i - 1)
                love.graphics.setFont(run_is_emoji and ef or f)
                love.graphics.print(run_text, cur_x, y)
                cur_x = cur_x + (run_is_emoji and ef or f):getWidth(run_text)
                run_start = i
                run_is_emoji = cp_emoji
            end
        end
        if run_start <= #t then
            local run_text = t:sub(run_start)
            love.graphics.setFont(run_is_emoji and ef or f)
            love.graphics.print(run_text, cur_x, y)
        end
    else
        love.graphics.setFont(f)
        love.graphics.print(text or "", x, y)
    end
    ui.set_color(ui.colors.white)
end

function ui.printf(text, x, y, limit, align, font, color)
    ui.set_color(color or ui.colors.text)
    local f = font or fonts.normal
    if not text or text == "" then
        ui.set_color(ui.colors.white)
        return
    end
    local ok, _, lines = pcall(function() return f:getWrap(text, limit) end)
    if not ok or type(lines) ~= "table" or #lines == 0 then
        love.graphics.setFont(f)
        love.graphics.print(text or "", x, y)
        ui.set_color(ui.colors.white)
        return
    end
    local line_h = f:getHeight()
    for i, line in ipairs(lines) do
        local line_y = y + (i - 1) * line_h
        if align == "center" then
            local lw = f:getWidth(line)
            local lx = x + math.max(0, (limit - lw) / 2)
            ui.text(line, lx, line_y, f, color)
        elseif align == "right" then
            local lw = f:getWidth(line)
            local lx = x + math.max(0, limit - lw)
            ui.text(line, lx, line_y, f, color)
        else
            ui.text(line, x, line_y, f, color)
        end
    end
    ui.set_color(ui.colors.white)
end

function ui.first_char(text)
    if not text or text == "" then return "?" end
    local byte = string.byte(text, 1)
    if byte < 0x80 then return string.sub(text, 1, 1)
    elseif byte < 0xE0 then return string.sub(text, 1, 2)
    elseif byte < 0xF0 then return string.sub(text, 1, 3)
    end
    return string.sub(text, 1, 4)
end

function ui.remove_last_utf8(text)
    if not text or text == "" then return "" end
    local index = #text
    while index > 0 do
        local byte = string.byte(text, index)
        if byte < 0x80 or byte >= 0xC0 then break end
        index = index - 1
    end
    if index <= 0 then return "" end
    return string.sub(text, 1, index - 1)
end

function ui.fit(text, font, max_width)
    if not text or text == "" then return "" end
    local ok, _, lines = pcall(font.getWrap, font, text, max_width)
    if ok and lines and #lines > 0 then
        local first = lines[1]
        if #lines > 1 then first = first .. "..." end
        return first
    end
    return text
end

-- Simple, low-overhead markdown segment parser.
-- Returns a list of segments: {text=..., bold=..., italic=..., code=..., link=..., url=...}
-- Supported inline syntax: **bold**, *italic*, `code`, [text](url)
function ui.parse_markdown(text)
    local segments = {}
    if type(text) ~= "string" or text == "" then
        return segments
    end
    local i = 1
    local n = #text
    local plain = ""
    local function flush_plain()
        if plain ~= "" then
            segments[#segments + 1] = { text = plain }
            plain = ""
        end
    end
    local ok = pcall(function()
        while i <= n do
            -- bold: **text**
            if text:sub(i, i + 1) == "**" then
                local j = text:find("%*%*", i + 2)
                if j then
                    flush_plain()
                    segments[#segments + 1] = { text = text:sub(i + 2, j - 1), bold = true }
                    i = j + 2
                else
                    plain = plain .. text:sub(i, i)
                    i = i + 1
                end
            -- code: `text`
            elseif text:sub(i, i) == "`" then
                local j = text:find("`", i + 1)
                if j then
                    flush_plain()
                    segments[#segments + 1] = { text = text:sub(i + 1, j - 1), code = true }
                    i = j + 1
                else
                    plain = plain .. text:sub(i, i)
                    i = i + 1
                end
            -- link: [text](url)
            elseif text:sub(i, i) == "[" then
                local cb = text:find("]", i + 1)
                if cb and text:sub(cb + 1, cb + 1) == "(" then
                    local cp = text:find(")", cb + 2)
                    if cp then
                        flush_plain()
                        segments[#segments + 1] = {
                            text = text:sub(i + 1, cb - 1),
                            link = true,
                            url = text:sub(cb + 2, cp - 1),
                        }
                        i = cp + 1
                    else
                        plain = plain .. text:sub(i, i)
                        i = i + 1
                    end
                else
                    plain = plain .. text:sub(i, i)
                    i = i + 1
                end
            -- italic: *text* (single *, not part of **)
            elseif text:sub(i, i) == "*" and text:sub(i + 1, i + 1) ~= "*" then
                local j = text:find("%*", i + 1)
                if j then
                    flush_plain()
                    segments[#segments + 1] = { text = text:sub(i + 1, j - 1), italic = true }
                    i = j + 1
                else
                    plain = plain .. text:sub(i, i)
                    i = i + 1
                end
            else
                plain = plain .. text:sub(i, i)
                i = i + 1
            end
        end
        flush_plain()
    end)
    if not ok or #segments == 0 then
        return { { text = text } }
    end
    return segments
end

-- Render markdown segments with wrapping, applying bold/italic/code/link styling.
function ui.printf_markdown(text, x, y, limit, align, font, color)
    local segments = ui.parse_markdown(text)
    local f = font or fonts.normal
    local bold_font = fonts.bold or f
    local italic_font = fonts.italic or f
    local bold_italic_font = fonts.bold_italic or f
    local code_font = fonts.mono or f
    local link_color = color and { color[1], color[2], color[3], color[4] or 1 } or nil
    if link_color then
        link_color[1], link_color[2], link_color[3] = ui.colors.accent[1], ui.colors.accent[2], ui.colors.accent[3]
    end
    local line_h = f:getHeight()

    -- Build a list of per-segment wrapped lines with style info
    local lines = {}
    local line_idx = 0
    local function emit_line(line_text, seg)
        lines[#lines + 1] = { text = line_text, seg = seg }
    end

    local cur_x = x
    local remaining = limit
    local cur_seg = nil
    local cur_buf = ""

    local function flush_buf()
        if cur_buf ~= "" then
            emit_line(cur_buf, cur_seg)
        end
        cur_buf = ""
    end

    for _, seg in ipairs(segments) do
        local seg_font = f
        if seg.code then seg_font = code_font
        elseif seg.bold and seg.italic then seg_font = bold_italic_font
        elseif seg.bold then seg_font = bold_font
        elseif seg.italic then seg_font = italic_font end

        local seg_text = seg.text
        local seg_len = #seg_text
        local pos = 1
        while pos <= seg_len do
            -- Try to fit as much of seg_text as possible into remaining width
            local chunk = seg_text:sub(pos)
            local w = seg_font:getWidth(chunk)
            if w <= remaining or cur_buf == "" then
                -- Whole chunk fits (or buf empty)
                if cur_buf ~= "" then cur_buf = cur_buf .. chunk end
                cur_buf = cur_buf .. chunk
                pos = seg_len + 1
            else
                -- Binary-ish scan: find longest prefix that fits
                local lo, hi = 1, seg_len - pos + 1
                local best = 0
                while lo <= hi do
                    local mid = math.floor((lo + hi) / 2)
                    local test = seg_text:sub(pos, pos + mid - 1)
                    if seg_font:getWidth(test) <= remaining then
                        best = mid
                        lo = mid + 1
                    else
                        hi = mid - 1
                    end
                end
                if best > 0 then
                    local test = seg_text:sub(pos, pos + best - 1)
                    if cur_buf ~= "" then cur_buf = cur_buf .. test end
                    cur_buf = cur_buf .. test
                    pos = pos + best
                end
                flush_buf()
                cur_x = x
                remaining = limit
                -- Continue on next line
                if pos <= seg_len then
                    -- Chunk still doesn't fit even on empty line: force one char
                    local c = seg_text:sub(pos, pos)
                    cur_buf = cur_buf .. c
                    pos = pos + 1
                    flush_buf()
                    cur_x = x
                    remaining = limit
                end
            end
            remaining = remaining - seg_font:getWidth(cur_buf)
            cur_x = cur_x + seg_font:getWidth(cur_buf)
            flush_buf()
        end
    end
    flush_buf()

    -- Draw lines
    local line_y = y
    for _, ln in ipairs(lines) do
        local seg = ln.seg
        local ln_font = f
        local ln_color = color or ui.colors.text
        if seg then
            if seg.code then ln_font = code_font
            elseif seg.bold and seg.italic then ln_font = bold_italic_font
            elseif seg.bold then ln_font = bold_font
            elseif seg.italic then ln_font = italic_font end
            if seg.link then ln_color = link_color or ui.colors.accent end
        end
        love.graphics.setFont(ln_font)
        ui.set_color(ln_color)
        local lx = x
        if align == "center" then
            local lw = ln_font:getWidth(ln.text)
            lx = x + math.max(0, (limit - lw) / 2)
        elseif align == "right" then
            local lw = ln_font:getWidth(ln.text)
            lx = x + math.max(0, limit - lw)
        end
        love.graphics.print(ln.text, lx, line_y)
        line_y = line_y + line_h
    end
    ui.set_color(ui.colors.white)
end

function ui.fonts() return fonts end

return ui