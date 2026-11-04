-- src/entities/message/ui/message_renderer.lua — рендеринг сообщения (пузырь + медиа)
local ui = require("src.shared.ui.ui_kit")

local message_renderer = {}

function message_renderer.draw_bubble(self, message, x, y, w, h, colors, outgoing)
    local draw_bg = not message:has_media() -- медиа без фона пузыря
    if draw_bg then
        if outgoing then
            ui.rect(x, y, w, h, colors.accent_dark, 10)
        else
            ui.rect(x, y, w, h, colors.panel_alt, 10)
        end
    end
end

function message_renderer.draw_sender(self, message, x, y, fonts, colors, outgoing)
    if not outgoing then
        local sender = message.sender_id
        local name = "Неизвестный"
        if sender and sender["@type"] == "messageSenderUser" then
            name = "Вы"
        end
        ui.text(name, x, y, fonts.small, colors.accent)
    end
end

function message_renderer.draw_text(self, message, x, y, w, fonts, colors)
    ui.printf(message:get_text(), x, y, w, "left", fonts.normal, colors.text)
end

function message_renderer.draw_time(self, message, x, y, w, h, fonts, colors, padding)
    padding = padding or 10
    local time_text = os.date("%H:%M", message.date or 0)
    ui.text(time_text, x + w - padding - fonts.tiny:getWidth(time_text),
            y + h - padding - fonts.tiny:getHeight(), fonts.tiny, colors.muted)
end

return message_renderer
