-- src/features/messages/ui/message_bubble.lua — отрисовка одного сообщения (пузырь)
local ui = require("src.shared.ui.ui_kit")
local message_bubble = {}

function message_bubble.draw(self, message, area_x, y, area_w, height, max_bubble, padding, wrap_width, small_height, line_height, colors, tg, fonts)
    self.tg = tg
    local sender = message and message.sender_id
    local outgoing = sender and sender["@type"] == "messageSenderUser" and tg.me and sender.user_id == tg.me.id

    local text = tg:message_text(message)
    local image, image_width, image_height = tg:photo_image(message)
    local is_sticker = false
    local is_animation = false
    local animation_label = ""
    local sticker_emoji = ""

    if not image then
        local simg, sw, sh, semoji = self:sticker_geometry(message, max_bubble, padding)
        if simg then
            image, image_width, image_height, sticker_emoji = simg, sw, sh, semoji
            is_sticker = true
        end
    end
    if not image then
        local aimg, aw, ah, alabel = self:animation_geometry(message, max_bubble, padding)
        if aimg then
            image, image_width, image_height, animation_label = aimg, aw, ah, alabel
            is_animation = true
        end
    end

    local caption = (is_sticker or is_animation) and "" or (image and self:photo_caption(message) or "")
    local bubble_w
    local draw_bubble_bg = not (is_sticker or is_animation)

    if image then
        local _, caption_lines = fonts.normal:getWrap(caption, image_width)
        local caption_width = 0
        for _, line in ipairs(caption_lines or {}) do
            caption_width = math.max(caption_width, fonts.normal:getWidth(line))
        end
        bubble_w = image_width + padding * 2
    else
        local _, lines = fonts.normal:getWrap(text, wrap_width)
        local max_line = 0
        for _, line in ipairs(lines or {}) do
            local line_w = fonts.normal:getWidth(line)
            -- Safety: if line visually exceeds wrap_width (e.g. emoji width), force re-wrap
            if line_w > wrap_width then
                local _, relines = fonts.normal:getWrap(text, wrap_width * 0.75)
                lines = relines
                max_line = 0
                for _, l in ipairs(relines or {}) do
                    max_line = math.max(max_line, fonts.normal:getWidth(l))
                end
            else
                max_line = math.max(max_line, line_w)
            end
        end
        bubble_w = math.min(max_bubble, math.max(96, max_line + padding * 2))
    end

    local x = outgoing and (area_x + area_w - bubble_w - 18) or (area_x + 18)
    if draw_bubble_bg then
        if outgoing then
            ui.rect(x, y, bubble_w, height, colors.accent_dark, 10)
        else
            ui.rect(x, y, bubble_w, height, colors.panel_alt, 10)
        end
    end

    local text_y = y + padding
    if not outgoing then
        ui.text(tg:sender_name(message), x + padding, text_y, fonts.small, colors.accent)
        text_y = text_y + small_height + 2
    end

    if image then
        local scale = image_width / image:getWidth()
        love.graphics.draw(image, x + padding, text_y, 0, scale, scale)
        text_y = text_y + image_height + 4
        if caption ~= "" then
            ui.printf(caption, x + padding, text_y, image_width, "left", fonts.normal, colors.text)
        end
    elseif is_animation and animation_label ~= "" then
        ui.printf(animation_label, x + padding, text_y, wrap_width, "left", fonts.small, colors.muted)
    else
        ui.printf(text, x + padding, text_y, wrap_width, "left", fonts.normal, colors.text)
    end

    local time_text = os.date("%H:%M", message.date or 0)
    ui.text(time_text, x + bubble_w - padding - fonts.tiny:getWidth(time_text), y + height - padding - fonts.tiny:getHeight(), fonts.tiny, colors.muted)
end

function message_bubble:sticker_geometry(message, max_bubble, padding)
    local image, width, height = self.tg and self.tg:sticker_image(message) or nil
    local emoji = ""
    local content = message and message.content
    if content and content["@type"] == "messageSticker" then
        emoji = content.sticker and content.sticker.emoji or ""
    end
    if not image or not width or not height or width <= 0 or height <= 0 then
        return nil, nil, nil, emoji
    end
    local max_width = math.max(48, math.floor((max_bubble - padding * 2) / 3))
    local scale = math.min(1, max_width / width)
    return image, math.floor(width * scale), math.floor(height * scale), emoji
end

function message_bubble:animation_geometry(message, max_bubble, padding)
    local content = message and message.content
    if not content or content["@type"] ~= "messageAnimation" then
        return nil, nil, nil, ""
    end
    local image, width, height = self.tg and self.tg:animation_image(message) or nil
    if not image or not width or not height or width <= 0 or height <= 0 then
        return nil, nil, nil, "[GIF]"
    end
    local max_width = math.max(48, math.floor((max_bubble - padding * 2) / 3))
    local scale = math.min(1, max_width / width)
    return image, math.floor(width * scale), math.floor(height * scale), ""
end

function message_bubble:photo_caption(message)
    local text = self.tg:message_text(message)
    if text == "[фото]" then return "" end
    return text
end

return message_bubble
