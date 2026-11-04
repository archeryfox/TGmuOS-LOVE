local ui = require("src.shared.ui.ui_kit")
local helpers = require("src.features.chat.ui.chat_screen_helpers")
local draw_circle_image = helpers.draw_circle_image
local decode_waveform = helpers.decode_waveform

return function(messenger_screen)
    function messenger_screen:draw_sender_avatar(user_id, name, x, y, size)
        if not user_id then return end
        self.tg:ensure_user_photo(user_id)
        local image = self.tg:user_photo_image(user_id)
        if image then
            draw_circle_image(image, x, y, size)
        else
            love.graphics.setColor(ui.colors.accent)
            love.graphics.circle("fill", x + size / 2, y + size / 2, size / 2)
            ui.printf(ui.first_char(name), x, y + 2, size, "center", self.fonts.tiny, ui.colors.text)
        end
    end

    function messenger_screen:draw_album(messages, area_x, y, area_w, height, max_bubble, padding, small_height, colors)
        local first = messages[1]
        local outgoing = self:outgoing(first)
        local cols = math.min(3, #messages)
        local gap = 3
        local cell = math.max(48, math.floor((max_bubble - padding * 2 - gap * (cols - 1)) / cols))
        local rows = math.ceil(#messages / cols)
        local grid_w = cols * cell + (cols - 1) * gap
        local grid_h = rows * cell + (rows - 1) * gap
        local bubble_w = grid_w + padding * 2
        local reactions = helpers.reaction_rows(
            helpers.merge_message_reactions(messages), self.fonts.tiny, max_bubble - padding * 2
        )
        bubble_w = math.min(max_bubble, math.max(
            bubble_w, helpers.reaction_rows_width(reactions) + padding * 2
        ))
        local x = outgoing and (area_x + area_w - bubble_w - 18) or (area_x + 28)
        ui.rect(x, y, bubble_w, height, outgoing and colors.accent_dark or colors.panel_alt, 10)

        local text_y = y + padding
        if not outgoing then
            local sender_id = first.sender_id and first.sender_id["@type"] == "messageSenderUser" and first.sender_id.user_id
            local sender = self.tg:sender_name(first)
            ui.text(ui.fit(sender, self.fonts.small, bubble_w - padding * 2),
                x + padding, text_y, self.fonts.small, colors.accent)
            self:draw_sender_avatar(sender_id, sender, x - 27, text_y, 22)
            if sender_id then
                self.profile_hits = self.profile_hits or {}
                self.profile_hits[#self.profile_hits + 1] = {
                    user_id = sender_id, x = x - 27, y = text_y, w = bubble_w + 27, h = small_height,
                }
            end
            text_y = text_y + small_height + 2
        end

        for index = 1, math.min(10, #messages) do
            local row = math.floor((index - 1) / cols)
            local col = (index - 1) % cols
            local cell_x = x + padding + col * (cell + gap)
            local cell_y = text_y + row * (cell + gap)
            ui.rect(cell_x, cell_y, cell, cell, colors.header, 4)
            local image = self.tg:photo_image(messages[index])
            if image then
                local scale = math.max(cell / image:getWidth(), cell / image:getHeight())
                local sw, sh = image:getWidth() * scale, image:getHeight() * scale
                local sx, sy, sw_clip, sh_clip = love.graphics.getScissor()
                love.graphics.setScissor(cell_x, cell_y, cell, cell)
                love.graphics.draw(image, cell_x + (cell - sw) / 2, cell_y + (cell - sh) / 2, 0, scale, scale)
                if sx then love.graphics.setScissor(sx, sy, sw_clip, sh_clip) else love.graphics.setScissor() end
            else
                ui.printf("Фото", cell_x, cell_y + cell / 2 - self.fonts.tiny:getHeight() / 2, cell, "center", self.fonts.tiny, colors.muted)
            end
            local hit = {message = messages[index], x = cell_x, y = cell_y, w = cell, h = cell, media = true, media_kind = "photo"}
            self.message_hits[#self.message_hits + 1] = hit
            self.media_hits[#self.media_hits + 1] = hit
        end
        helpers.draw_reaction_rows(
            reactions, x + padding, text_y + grid_h + 4, self.fonts.tiny, colors
        )
        local hit = {message = first, x = x, y = y, w = bubble_w, h = height}
        self.message_hits[#self.message_hits + 1] = hit
    end

    function messenger_screen:outgoing(message)
        local sender = message and message.sender_id
        return sender and sender["@type"] == "messageSenderUser" and self.tg.me and sender.user_id == self.tg.me.id
    end

    function messenger_screen:format_time(timestamp)
        if not timestamp or timestamp <= 0 then return "" end
        local now = os.time()
        if os.date("%Y-%m-%d", timestamp) == os.date("%Y-%m-%d", now) then
            return os.date("%H:%M", timestamp)
        end
        return os.date("%d.%m", timestamp)
    end

    function messenger_screen:format_bytes(bytes)
        bytes = math.max(0, tonumber(bytes) or 0)
        if bytes >= 1024 * 1024 then
            return string.format("%.1f MB", bytes / (1024 * 1024))
        end
        return string.format("%.0f KB", bytes / 1024)
    end

    function messenger_screen:photo_geometry(message, max_bubble, padding)
        local image, width, height = self.tg:photo_image(message)
        if not image or not width or not height or width <= 0 or height <= 0 then return nil end
        local max_width = math.max(96, max_bubble - padding * 2)
        local scale = math.min(1, max_width / width)
        return image, math.floor(width * scale), math.floor(height * scale)
    end

    function messenger_screen:photo_caption(message)
        local text = self.tg:message_text(message)
        if text == "[фото]" then return "" end
        return text
    end

    function messenger_screen:sticker_geometry(message, max_bubble, padding)
        local image, width, height = self.tg:sticker_image(message)
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

    function messenger_screen:animation_geometry(message, max_bubble, padding)
        local content = message and message.content
        if not content or content["@type"] ~= "messageAnimation" then
            return nil, nil, nil, ""
        end
        local image, width, height = self.tg:animation_image(message)
        if not image or not width or not height or width <= 0 or height <= 0 then
            return nil, nil, nil, "[GIF]"
        end
        local max_width = math.max(48, math.floor((max_bubble - padding * 2) / 3))
        local scale = math.min(1, max_width / width)
        return image, math.floor(width * scale), math.floor(height * scale), ""
    end

    function messenger_screen:video_geometry(message, max_bubble, padding)
        local content = message and message.content
        if not content or (content["@type"] ~= "messageVideo" and content["@type"] ~= "messageVideoNote") then
            return nil, nil, nil, ""
        end
        local image, width, height = self.tg:video_image(message)
        if not image or not width or not height or width <= 0 or height <= 0 then
            return nil, nil, nil, "[видео]"
        end
        if content["@type"] == "messageVideoNote" then
            local diameter = math.max(48, math.min(190, max_bubble - padding * 2))
            local scale = math.min(1, diameter / math.max(width, height))
            diameter = math.max(48, math.floor(math.max(width, height) * scale))
            return image, diameter, diameter, ""
        end
        local max_width = math.max(48, math.floor((max_bubble - padding * 2) / 3))
        local scale = math.min(1, max_width / width)
        return image, math.floor(width * scale), math.floor(height * scale), ""
    end

    function messenger_screen:draw_voice_note(message, entry, x, y, width, colors)
        local note = message.content and message.content.voice_note or {}
        local samples = decode_waveform(note.waveform)
        local duration = tonumber(note.duration) or 0
        local playing = entry and entry.playing == true
        local progress = 0
        if playing and entry.audio_source then
            local ok, position = pcall(entry.audio_source.tell, entry.audio_source, "seconds")
            if ok and duration > 0 then progress = math.min(1, math.max(0, position / duration)) end
        end

        local center_y = y + 14
        love.graphics.setColor(colors.accent[1], colors.accent[2], colors.accent[3], 1)
        love.graphics.circle("fill", x + 13, center_y, 11)
        love.graphics.setColor(1, 1, 1, 1)
        if playing then
            love.graphics.rectangle("fill", x + 9, center_y - 5, 3, 10)
            love.graphics.rectangle("fill", x + 15, center_y - 5, 3, 10)
        else
            love.graphics.polygon("fill", x + 10, center_y - 6, x + 10, center_y + 6, x + 18, center_y)
        end

        local graph_x = x + 32
        local graph_w = math.max(24, width - 40)
        local count = math.min(48, math.max(1, math.floor(graph_w / 3)))
        local gap = 2
        local bar_w = math.max(1, (graph_w - gap * (count - 1)) / count)
        for index = 1, count do
            local sample_index = math.floor((index - 1) * #samples / count) + 1
            local amplitude = samples[sample_index] and samples[sample_index] / 31 or 0.3
            local bar_h = math.max(3, amplitude * 22)
            local ratio = index / count
            local color = ratio <= progress and colors.accent or colors.muted
            love.graphics.setColor(color[1], color[2], color[3], 0.9)
            love.graphics.rectangle("fill", graph_x + (index - 1) * (bar_w + gap), center_y - bar_h / 2, bar_w, bar_h, 1)
        end
        love.graphics.setColor(1, 1, 1, 1)
        local elapsed = playing and math.floor(progress * duration) or duration
        ui.text(string.format("%d:%02d", math.floor(elapsed / 60), elapsed % 60), graph_x, y + 27, self.fonts.tiny, colors.muted)
    end

    function messenger_screen:draw_music_track(message, entry, x, y, width, colors)
        local _, duration, playing = self.tg:media_playback_state(message)
        local position = entry and entry.play_position or 0
        if entry and entry.audio_source then
            local ok, current = pcall(entry.audio_source.tell, entry.audio_source, "seconds")
            if ok then position = tonumber(current) or position end
        end
        local progress = duration > 0 and math.min(1, math.max(0, position / duration)) or 0
        local center_y = y + 15
        love.graphics.setColor(colors.accent[1], colors.accent[2], colors.accent[3], 1)
        love.graphics.circle("fill", x + 13, center_y, 11)
        love.graphics.setColor(1, 1, 1, 1)
        if playing then
            love.graphics.rectangle("fill", x + 9, center_y - 5, 3, 10)
            love.graphics.rectangle("fill", x + 15, center_y - 5, 3, 10)
        else
            love.graphics.polygon("fill", x + 10, center_y - 6, x + 10, center_y + 6, x + 18, center_y)
        end
        love.graphics.setColor(1, 1, 1, 1)
        local label = self.tg:document_label(message)
        ui.text(ui.fit(label, self.fonts.small, math.max(20, width - 38)),
            x + 32, y + 3, self.fonts.small, colors.text)
        local track_x, track_y, track_w = x + 32, y + 24, math.max(20, width - 40)
        ui.rect(track_x, track_y, track_w, 3, colors.muted, 2)
        if progress > 0 then
            ui.rect(track_x, track_y, track_w * progress, 3, colors.accent, 2)
        end
        local elapsed = math.floor(duration)
        if playing or position > 0 then elapsed = math.floor(position) end
        ui.text(string.format("%d:%02d", math.floor(elapsed / 60), elapsed % 60),
            track_x, y + 30, self.fonts.tiny, colors.muted)
        if entry and entry.audio_error then
            ui.text("Ошибка аудио", x + 78, y + 30, self.fonts.tiny, colors.red)
        end
    end

end
