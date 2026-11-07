-- src/shared/system/media_settings.lua — persistent media autoplay/autoload settings
local media_settings = {}

local settings = {
    autoplay_videos = false,
    autoplay_stickers = true,
    autoplay_animated_stickers = true,
    autoplay_images = true,
    autoplay_circles = false,
    autoload = true,
}

local function clamp(v) return v == true end

function media_settings.get(key)
    return settings[key] ~= false
end

function media_settings.set(key, v, persist)
    if settings[key] ~= nil then
        settings[key] = v == true
        if persist then media_settings.save() end
    end
    return settings[key]
end

function media_settings.toggle(key)
    if settings[key] ~= nil then
        settings[key] = not settings[key]
        media_settings.save()
    end
    return settings[key]
end

function media_settings.load()
    local ok, data = pcall(love.filesystem.read, "media_settings.conf")
    if ok and data then
        for key in pairs(settings) do
            local val = data:match(key .. "%s*=%s*([01])")
            if val then settings[key] = (val == "1") end
        end
    end
end

function media_settings.save()
    local lines = {}
    for key, val in pairs(settings) do
        lines[#lines + 1] = key .. "=" .. (val and "1" or "0")
    end
    pcall(love.filesystem.write, "media_settings.conf", table.concat(lines, "\n") .. "\n")
end

return media_settings
