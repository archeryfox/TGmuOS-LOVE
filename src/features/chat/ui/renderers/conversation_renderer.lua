-- src/features/chat/ui/renderers/conversation_renderer.lua
-- Extracted from chat_screen.lua - draws the conversation (messages)

local ui = require("src.shared.ui.ui_kit")
local helpers = require("src.features.chat.ui.chat_screen_helpers")
local wrapped_lines = helpers.wrapped_lines
local draw_circle_image = helpers.draw_circle_image
local draw_text_lines = helpers.draw_text_lines
local conversation_items = helpers.conversation_items

local conversation_renderer = {}

function conversation_renderer.draw(ms, chat, left_width, right_width, h)
    local f = ms.fonts
    local colors = ui.colors
    local panel_x = left_width
    local panel_w = right_width

    ui.rect(panel_x, HEADER_HEIGHT, panel_w, CHAT_HEADER_HEIGHT, colors.header)
    local profile_user_id = ms.tg:private_chat_user_id(chat)
    if profile_user_id then
        ms.tg:ensure_user(profile_user_id)
        ui.text(ms.tg:user_status_text(profile_user_id), panel_x + 20, HEADER_HEIGHT + 40, f.tiny, colors.muted)
    else
        ui.text("Открыть профиль", panel_x + 20, HEADER_HEIGHT + 40, f.tiny, colors.muted)
    end
    ui.text(ui.fit(chat.title or "Chat", f.subtitle, panel_w - 48), panel_x + 20, HEADER_HEIGHT + 12, f.subtitle, colors.text)

    local area_x = panel_x
    local area_y = HEADER_HEIGHT + CHAT_HEADER_HEIGHT
    local area_w = panel_w
    local area_h = h - area_y - INPUT_HEIGHT

    ms.conv_area_x, ms.conv_area_y = area_x, area_y
    ms.conv_area_w, ms.conv_area_h = area_w, area_h
    ms.nav_messages = {}
    ms.nav_pos = {}

    ui.rect(area_x, area_y, area_w, area_h, colors.bg)

    local messages = ms.tg:get_messages(chat.id)
    local search_loading = false
    if ms.search_active and ms.search_query ~= "" then
        local search_results = ms.tg.dialog_search_results and ms.tg.dialog_search_results[chat.id]
        search_loading = search_results == false or ms.tg.dialog_search_query[chat.id] ~= ms.search_query
        messages = type(search_results) == "table" and search_results or {}
    end
    local items = conversation_items(messages)
    if #messages == 0 then
        local empty_label = ms.search_active and ms.search_query ~= "" and "Сообщения не найдены" or "Нет сообщений"
        if ms.search_active and ms.tg.dialog_search_error then
            empty_label = "Ошибка поиска: " .. ms.tg.dialog_search_error
        end
        ui.printf(empty_label, area_x, area_y + area_h / 2 - 20, area_w, "center", f.small, colors.muted)
    end

    local font = ms.fonts.normal
    local small = ms.fonts.small
    local padding = 10
    local max_bubble = math.floor(area_w * 0.85)
    local wrap_width = math.min(max_bubble - padding * 2, 280)
    local line_height = font:getHeight()
    local small_height = ms.fonts.small:getHeight()
    local heights = {}
    local total = 0

    for i, item in ipairs(conversation_items(ms.tg:get_messages(chat.id))) do
        if item.date_label then
            heights[i] = 28
            total = total + heights[i] + 6
        elseif item.messages then
            local count = #item.messages
            local cols = math.min(3, count)
            local gap = 3
            local cell = math.max(48, math.floor((max_bubble - padding * 2 - gap * (cols - 1)) / cols))
            local rows = math.ceil(count / cols)
            local author_height = ms:outgoing(item.messages[1]) and 0 or small:getHeight() + 2
            heights[i] = padding * 2 + author_height + rows * cell + gap * (rows - 1) + small_height + 4
            local reactions = helpers.merge_message_reactions(item.messages)
            local reaction_rows = helpers.reaction_rows(reactions, ms.fonts.tiny, max_bubble - padding * 2)
            heights[i] = heights[i] + #reaction_rows * 22
            total = total + heights[i] + 6
        else
            local message = item.message
            local author_height = 0
            if not ms:outgoing(message) then
                author_height = ms.fonts.small:getHeight() + 2
            end
            local image, image_width, image_height = ms:photo_geometry(message, max_bubble, padding)
            local is_sticker = false
            local is_animation = false
            local is_video = false
            local animation_label = ""
            local sticker_emoji = ""
            local video_label = ""
            if not image then
                local simg, sw, sh, semoji = ms:sticker_geometry(message, max_bubble, padding)
                if simg then
                    image, image_width, image_height, sticker_emoji = simg, sw, sh, semoji
                    is_sticker = true
                end
            end
            if not image then
                local aimg, aw, ah, alabel = ms:animation_geometry(message, max_bubble, padding)
                if aimg then
                    image, image_width, image_height, animation_label = aimg, aw, ah, alabel
                    is_animation = true
                end
            end
            if not image then
                local vimg, vw, vh, vlabel = ms:video_geometry(message, max_bubble, padding)
                if vimg then
                    image, image_width, image_height, video_label = vimg, vw, vh, vlabel
                    is_video = true
                end
            end
            local height
            if image then
                local caption = (is_sticker or is_animation or is_video) and "" or ms:photo_caption(message)
                local _, caption_lines = ms.fonts.normal:getWrap(caption, image_width)
                local caption_height = caption ~= "" and (#caption_lines * line_height + 4) or 0
                height = padding * 2 + author_height + image_height + caption_height + small:getHeight() + 2
            elseif is_sticker and sticker_emoji ~= "" then
                local emoji_font = ms.fonts.subtitle
                local _, emoji_lines = emoji_font:getWrap(sticker_emoji, wrap_width)
                local emoji_line_count = math.max(1, #emoji_lines)
                height = padding * 2 + author_height + emoji_line_count * emoji_font:getHeight() + ms.fonts.small:getHeight() + 2
            elseif is_animation and animation_label ~= "" then
                local small_font = ms.fonts.small
                local _, label_lines = small_font:getWrap(animation_label, wrap_width)
                local label_line_count = math.max(1, #label_lines)
                height = padding * 2 + author_height + label_line_count * small_font:getHeight() + ms.fonts.small:getHeight() + 2
            elseif is_video and video_label ~= "" then
                local small_font = ms.fonts.small
                local _, label_lines = small_font:getWrap(video_label, wrap_width)
                local label_line_count = math.max(1, #label_lines)
                height = padding * 2 + author_height + label_line_count * small_font:getHeight() + ms.fonts.small:getHeight() + 2
            elseif message.content and message.content["@type"] == "messageAudio" then
                height = padding * 2 + author_height + 54 + ms.fonts.small:getHeight() + 2
            elseif message.content and message.content["@type"] == "messageVoiceNote" then
                height = padding * 2 + author_height + 38 + ms.fonts.small:getHeight() + 2
            elseif message.content and message.content["@type"] == "messageDocument" then
                local text = ms.tg:document_label(message)
                local lines = wrapped_lines(ms.fonts.normal, text, math.max(32, wrap_width - 28))
                height = padding * 2 + author_height + math.max(1, #lines) * line_height + ms.fonts.small:getHeight() + 2
            else
                local text = ms.tg:message_text(message)
                local lines = wrapped_lines(ms.fonts.normal, text, wrap_width)
                local line_count = math.max(1, #lines)
                height = padding * 2 + author_height + line_count * line_height + ms.fonts.small:getHeight() + 2
            end
            local reactions = helpers.reaction_rows(helpers.reaction_summary(message), ms.fonts.tiny, max_bubble - padding * 2)
            height = height + #reactions * 22
            local download_state = ms.tg:media_download_state(message)
            if download_state and download_state.status == "downloading" then
                height = height + 30
            end
            heights[i] = height
            total = total + height + 6
        end
    end

    ms.model.max_scroll = math.max(0, total - (h - (HEADER_HEIGHT + CHAT_HEADER_HEIGHT + INPUT_HEIGHT)))
    if ms.model.scroll > ms.model.max_scroll then ms.model.scroll = ms.model.max_scroll end
    if ms.model.scroll < 0 then ms.model.scroll = 0 end
    local history_state = ms.tg.history_state and ms.tg.history_state[chat.id]
    if history_state and history_state.stick_to_top then
        ms.model.scroll = ms.model.max_scroll
        history_state.stick_to_top = nil
    end

    love.graphics.setScissor(area_x, area_y, area_w, area_h)
    local y = area_y + area_h + ms.model.scroll
    ms.message_hits = {}
    ms.media_hits = {}
    ms.profile_hits = {}
    ms.hashtag_hits = {}

    for i = #items, 1, -1 do
        local item = items[i]
        if item.date_label then
            local date_height = 28
            y = y - date_height - 6
            if y + date_height >= area_y and y <= area_y + area_h then
                local label_w = ms.fonts.tiny:getWidth(item.date_label) + 22
                local label_x = area_x + (area_w - label_w) / 2
                ui.rect(label_x, y + 3, label_w, 22, ui.colors.header, 10)
                ui.printf(item.date_label, label_x, y + 6, label_w, "center", ms.fonts.tiny, ui.colors.muted)
            end
            if y < area_y - 100 then break end
        else
        local height = heights[i] or 60
        y = y - height - 6
        local nav_msg = item.messages and item.messages[1] or item.message
        if nav_msg then
            ms.nav_messages[#ms.nav_messages + 1] = nav_msg
            ms.nav_pos[nav_msg.id] = {y = y, h = height}
        end

        if y + height >= area_y and y <= area_y + area_h then
            if item.messages then
                ms:draw_album(item.messages, area_x, y, area_w, height, max_bubble, padding, small_height, ui.colors)
            else
                local hit = { message = item.message, x = area_x, y = y, w = area_w, h = height }
                table.insert(ms.message_hits, hit)
                ms:draw_message(item.message, area_x, y, area_w, height, max_bubble, padding, wrap_width, small_height, line_height, ui.colors, hit)
            end
            if nav_msg and ms.message_cursor_id == nav_msg.id then
                local c = ui.colors.accent
                ui.outline(area_x + 1, y + 1, area_w - 2, height - 2, {c[1], c[2], c[3], 0.9}, 6)
            end
        end
        if y < area_y - 100 then break end
        end
    end
    love.graphics.setScissor()

    local ordered = {}
    for index = #ms.nav_messages, 1, -1 do
        ordered[#ordered + 1] = ms.nav_messages[index]
    end
    ms.nav_messages = ordered
    if ms.message_cursor_id and not ms.nav_pos[ms.message_cursor_id] then
        ms.message_cursor_id = nil
    end
    if not ms.message_cursor_id and #ordered > 0 then
        ms.message_cursor_id = ordered[#ordered].id
    end

    ms.load_more_button = nil
    local history_state = ms.tg.history_state and ms.tg.history_state[chat.id]
    if history_state and not (ms.search_active and ms.search_query ~= "")
        and (history_state.loading or history_state.has_more or history_state.error)
        and ms.model.scroll >= ms.model.max_scroll - 12 then
        local button_w, button_h = 146, 28
        local button_x, button_y = area_x + (area_w - button_w) / 2, area_y + 6
        local label = history_state.loading and "Загрузка..."
            or history_state.error and "Повторить загрузку"
            or "Загрузить ещё"
        ui.rect(button_x, button_y, button_w, button_h, ui.colors.header, 8)
        ui.printf(label, button_x + 4, button_y + 6, button_w - 8, "center", ms.fonts.tiny,
            history_state.error and ui.colors.red or ui.colors.text)
        ms.load_more_button = {x = button_x, y = button_y, w = button_w, h = button_h}
    end

    ms:draw_input(panel_x, panel_w, h)
end

return conversation_renderer