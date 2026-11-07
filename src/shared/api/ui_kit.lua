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
local ui_scale = 1.0

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
    ui_scale = scale or 1.0
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

function ui.fonts() return fonts end

return ui
