-- src/features/chat/ui/renderers/media_renderer.lua
-- Extracted from chat_screen.lua - draws fullscreen media

local ui = require("src.shared.ui.ui_kit")
local helpers = require("src.features.chat.ui.chat_screen_helpers")
local draw_circle_image = helpers.draw_circle_image

local media_renderer = {}

function media_renderer.draw(ms, w, h)
    local fullscreen = ms.fullscreen_media
    if not fullscreen then return end
    local image
    local media_index = fullscreen.media_index or 1
    if fullscreen.video_note then
        image = ms.tg:video_note_image(fullscreen.message)
    elseif fullscreen.kind == "video" then
        image = ms.tg:video_image(fullscreen.message)
    elseif fullscreen.kind == "animation" then
        image = ms.tg:animation_image(fullscreen.message)
    else
        image = ms.tg:photo_image(fullscreen.message, media_index)
    end
    love.graphics.setColor(0, 0, 0, 0.88)
    love.graphics.rectangle("fill", 0, 0, w, h)
    if image then
        if fullscreen.video_note then
            local diameter = math.min(w - 48, h - 128)
            diameter = math.max(48, diameter)
            draw_circle_image(image, (w - diameter) / 2, math.max(16, (h - 88 - diameter) / 2), diameter)
        else
            local fit = math.min((w - 48) / image:getWidth(), (h - 112) / image:getHeight())
            local scale = fit * (ms.fullscreen_zoom or 1)
            local draw_w = image:getWidth() * scale
            local draw_h = image:getHeight() * scale
            local pan_x = ms.fullscreen_pan_x or 0
            local pan_y = ms.fullscreen_pan_y or 0
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(image, (w - draw_w) / 2 + pan_x, (h - draw_h) / 2 + pan_y, 0, scale, scale)
        end
    else
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Загрузка медиа…", 24, h / 2, w - 48, "center")
    end

    if fullscreen.kind == "video" or fullscreen.kind == "animation" then
        local position, duration, playing = ms.tg:media_playback_state(fullscreen.message)
        local panel_w = math.min(w - 40, 440)
        local panel_x = (w - panel_w) / 2
        local panel_y = h - 66
        ui.rect(panel_x, panel_y, panel_w, 52, {0.08, 0.09, 0.12, 0.96}, 8)

        local button_x, button_y = panel_x + 12, panel_y + 12
        love.graphics.setColor(1, 1, 1, 1)
        if playing then
            love.graphics.rectangle("fill", button_x + 7, button_y + 4, 4, 14)
            love.graphics.rectangle("fill", button_x + 15, button_y + 4, 4, 14)
        else
            love.graphics.polygon("fill", button_x + 7, button_y + 3, button_x + 7, button_y + 19, button_x + 21, button_y + 11)
        end

        local track_x = panel_x + 44
        local track_w = math.max(40, panel_w - 164)
        local track_y = panel_y + 20
        local progress = duration > 0 and math.min(1, math.max(0, position / duration)) or 0
        ui.rect(track_x, track_y, track_w, 5, {0.35, 0.37, 0.4}, 2)
        if progress > 0 then ui.rect(track_x, track_y, track_w * progress, 5, ui.colors.accent, 2) end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("fill", track_x + track_w * progress, track_y + 2.5, 5)

        local time_label = string.format("%d:%02d / %d:%02d",
            math.floor(position / 60), math.floor(position % 60),
            math.floor(duration / 60), math.floor(duration % 60))
        ui.text(time_label, track_x, panel_y + 34, ms.fonts.tiny, ui.colors.text)
        ms.player_controls = {
            button = {x = button_x, y = button_y, w = 28, h = 28},
            track = {x = track_x, y = track_y - 8, w = track_w, h = 30},
        }
    else
        ms.player_controls = nil
    end
    if fullscreen.kind ~= "video" and fullscreen.kind ~= "animation" then
        ui.text(string.format("↑/↓ — масштаб %d%%   ←/→ — медиа   R2+↑↓←→ — панорамирование   B — назад", math.floor((ms.fullscreen_zoom or 1) * 100)),
            24, h - 26, ms.fonts.tiny, ui.colors.muted)
    else
        ui.text("A — играть/пауза   ←/→ — медиа   L1/R1 — ±5с   B — назад",
            24, h - 26, ms.fonts.tiny, ui.colors.muted)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return media_renderer