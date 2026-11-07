-- src/entities/chat/ui/chat_item.lua — элемент списка чатов
local ui = require("src.shared.ui.ui_kit")
local chat_item = {}

local function draw_muted_icon(x, y, color)
    love.graphics.setColor(color)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(x, y - 5, x - 4, y - 1, x - 4, y + 3, x + 4, y + 3, x + 4, y - 1, x, y - 5)
    love.graphics.line(x - 2, y + 5, x + 2, y + 5)
    love.graphics.line(x - 7, y - 6, x + 7, y + 7)
    love.graphics.setLineWidth(1)
end

function chat_item.draw(self, chat, x, y, w, h, fonts, colors, is_selected, is_current)
    local bg = colors.panel
    if is_current then
        bg = colors.accent_dark
    elseif is_selected then
        bg = colors.panel_alt
    end
    ui.rect(x, y, w, h, bg, 0)

    local title = chat.title or ""
    local avatar_image, avatar_w, avatar_h = self.tg:chat_photo_image(chat.id)
    local avatar_x = x + 14
    local avatar_y = y + 14
    local avatar_size = 46
    local avatar_r = avatar_size / 2
    local cx = avatar_x + avatar_r
    local cy = avatar_y + avatar_r

    -- Круглая маска для аватарки
    love.graphics.stencil(function()
        love.graphics.circle("fill", cx, cy, avatar_r)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    if avatar_image then
        local scale = math.max(avatar_size / avatar_image:getWidth(), avatar_size / avatar_image:getHeight())
        local aw = avatar_image:getWidth() * scale
        local ah = avatar_image:getHeight() * scale
        local ax = avatar_x + (avatar_size - aw) / 2
        local ay = avatar_y + (avatar_size - ah) / 2
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(avatar_image, ax, ay, 0, scale, scale)
    else
        ui.rect(avatar_x, avatar_y, avatar_size, avatar_size, colors.accent, 0)
        local initial = ui.first_char(title)
        ui.printf(initial, avatar_x, avatar_y + 8, avatar_size, "center", fonts.normal, colors.text)
    end

    love.graphics.setStencilTest()

    local text_x = x + avatar_size + 28
    local text_w = w - text_x - 16
    local notification = chat.notification_settings or {}
    local muted = (tonumber(notification.mute_for) or 0) > 0
    local reserved = muted and 28 or 0
    ui.text(ui.fit(title, fonts.normal, text_w - 50 - reserved), text_x, y + 12, fonts.normal, colors.text)
    if muted then draw_muted_icon(x + w - 24, y + 42, colors.muted) end

    local last = chat.last_message
    local date = last and last.date or 0
    local time_text = os.date("%H:%M", date)
    ui.text(time_text, x + w - 16 - fonts.tiny:getWidth(time_text), y + 14, fonts.tiny, colors.muted)

    local preview = ""
    if last then
        preview = self.tg:message_text(last)
    end
    ui.text(ui.fit(preview, fonts.small, text_w - reserved), text_x, y + 38, fonts.small, colors.muted)

    local unread = chat.unread_count or 0
    if unread > 0 then
        local badge = tostring(unread)
        local badge_w = math.max(22, fonts.tiny:getWidth(badge) + 12)
        ui.rect(x + w - 16 - badge_w, y + 52, badge_w, 18, colors.accent, 9)
        ui.printf(badge, x + w - 16 - badge_w, y + 54, badge_w, "center", fonts.tiny, colors.text)
    end
end

return chat_item
