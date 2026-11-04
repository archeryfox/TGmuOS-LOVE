local ui = {}

local fonts = {}

function ui.loadFonts()
    -- Приоритет: JetBrainsMono (поддерживает кириллицу), затем AdwaitaSans
    local paths = {
        "fonts/JetBrainsMono_SemiBold.ttf",
        "fonts/AdwaitaSans-Regular.ttf",
        "JetBrainsMono_SemiBold.ttf",
        "AdwaitaSans-Regular.ttf",
        "/home/kyle/.local/share/fonts/j/JetBrainsMono_SemiBold.ttf",
        "/usr/share/fonts/adwaita-sans-fonts/AdwaitaSans-Regular.ttf",
        love.filesystem.getWorkingDirectory() .. "/fonts/JetBrainsMono_SemiBold.ttf",
        love.filesystem.getWorkingDirectory() .. "/JetBrainsMono_SemiBold.ttf",
    }

    local fontPath = nil
    for _, p in ipairs(paths) do
        local info = love.filesystem.getInfo(p)
        if info then
            fontPath = p
            print("Font found: " .. p)
            break
        end
        local f = io.open(p, "r")
        if f then
            f:close()
            fontPath = p
            print("Font found (io): " .. p)
            break
        end
    end

    if not fontPath then
        print("WARNING: No custom font found, using default")
    end

    local function load(p, size)
        if p then
            local ok, font = pcall(love.graphics.newFont, p, size)
            if ok and font then
                print("Loaded font: " .. p .. " size=" .. size)
                return font
            end
            print("Failed to load font: " .. p)
        end
        local defaultFont = love.graphics.newFont(size)
        print("Using default font, size=" .. size)
        return defaultFont
    end

    fonts.title = load(fontPath, 24)
    fonts.subtitle = load(fontPath, 18)
    fonts.normal = load(fontPath, 16)
    fonts.small = load(fontPath, 14)
    fonts.tiny = load(fontPath, 12)
    return fonts
end

function ui.getFonts()
    return fonts
end

function ui.clear(color)
    if color then
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    else
        love.graphics.setColor(0.12, 0.16, 0.22, 1)
    end
    love.graphics.rectangle("fill", 0, 0, 640, 480)
    love.graphics.setColor(1, 1, 1, 1)
end

function ui.drawText(text, x, y, font, color, limit, align)
    if not font and fonts.normal then font = fonts.normal end
    if color then
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    end
    if limit and align then
        love.graphics.printf(text or "", x, y, limit, align)
    else
        love.graphics.print(text or "", x, y)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function ui.rect(x, y, w, h, color, r)
    if color then
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    end
    if r then
        love.graphics.rectangle("fill", x, y, w, h, r, r)
    else
        love.graphics.rectangle("fill", x, y, w, h)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function ui.outline(x, y, w, h, color, r)
    if color then
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    end
    if r then
        love.graphics.rectangle("line", x, y, w, h, r, r)
    else
        love.graphics.rectangle("line", x, y, w, h)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return ui
