-- src/features/chat/ui/input/context_menu_handler.lua
-- Extracted from chat_screen_input.lua - handles context menus

local ui = require("src.shared.ui.ui_kit")

local context_menu_handler = {}

function context_menu_handler.activate_context_item(ms, cm, item)
    if not item then return end
    if cm.chat then
        if item.action == "mute_chat" then
            ms.tg:set_chat_muted(cm.chat.id, true)
        elseif item.action == "unmute_chat" then
            ms.tg:set_chat_muted(cm.chat.id, false)
        elseif item.action == "archive_chat" then
            ms.tg:archive_chat(cm.chat.id, true)
        elseif item.action == "unarchive_chat" then
            ms.tg:archive_chat(cm.chat.id, false)
        elseif item.action == "leave_chat" then
            ms.tg:leave_chat(cm.chat.id)
        end
        ms.context_menu = nil
        return
    end
    if item.action == "copy" then
        local text = cm.message.content and cm.message.content.text and cm.message.content.text.text or ""
        if text ~= "" then love.system.setClipboardText(text) end
    elseif item.action == "forward" then
        ms.selected_messages[cm.message.id] = cm.message
        ms.forward_from_chat_id = cm.message.chat_id or ms.tg.current_chat_id
        ms.forward_mode = true
    elseif item.action == "play_media" then
        ms.tg:request_media_playback(cm.message)
    elseif item.action == "stop_media" then
        ms.tg:stop_media_playback(cm.message)
    elseif item.action == "pin" or item.action == "unpin" then
        local chat_id = ms.tg.current_chat_id
        local msg_id = cm.message and cm.message.id
        if chat_id and msg_id then
            ms.tg:set_message_pinned(chat_id, msg_id, item.action == "pin")
        end
    elseif item.action == "delete" then
        local chat_id = ms.tg.current_chat_id
        local msg_id = cm.message and cm.message.id
        if chat_id and msg_id then
            ms.tg:delete_messages(chat_id, {msg_id}, false)
        end
    elseif item.action == "delete_all" then
        local chat_id = ms.tg.current_chat_id
        local msg_id = cm.message and cm.message.id
        if chat_id and msg_id then
            ms.tg:delete_messages(chat_id, {msg_id}, true)
        end
    elseif item.action == "edit" then
        ms.edit_mode = true
        ms.edit_message = cm.message
        ms.edit_input = cm.message.content and cm.message.content.text and cm.message.content.text.text or ""
    elseif item.action == "write_to_author" then
        if item.sender_id then
            ms.tg:open_private_chat(item.sender_id)
        end
    elseif item.action == "download_photo_hires" then
        if ms.tg.ensure_photo_hires then
            ms.tg:ensure_photo_hires(cm.message)
        end
    elseif item.action == "open_my_profile" then
        if ms.wants_profile_self ~= nil then
            ms.wants_profile_self = true
        end
    elseif item.action == "open_sticker_pack" then
        if ms.tg.open_sticker_set then
            ms.tg:open_sticker_set(cm.message)
        end
    elseif item.action == "open_sticker_pack_from_link" then
        if item.link and ms.tg.open_sticker_set_by_link then
            ms.tg:open_sticker_set_by_link(item.link)
        end
    elseif item.action == "view_fullscreen" then
        ms.fullscreen_media = {message = cm.message, index = 1, playing = false}
    elseif item.action == "download_sticker" then
        local sticker = cm.message.content and cm.message.content.sticker
        local file = sticker and sticker.sticker
        if file and file.id and ms.tg.add_proxy == nil then
            local entry = ms.tg.stickers and ms.tg.stickers[file.id]
            if not entry or not entry.download_requested then
                if entry then entry.download_requested = true; entry.status = "downloading" end
                ms.tg:send({
                    ["@type"] = "downloadFile",
                    file_id = file.id,
                    priority = 1,
                    offset = 0,
                    limit = 0,
                    synchronous = false,
                }, "sticker:" .. tostring(file.id))
            end
        end
    elseif item.action == "react" then
        ms.reaction_target = cm.message
    end
end

function context_menu_handler.open_message_context_menu(ms, message)
    if ms.keyboard then ms.keyboard.visible = false end
    local pos = ms.nav_pos and ms.nav_pos[message.id]
    local x = 120
    if ms.conv_area_x and ms.conv_area_w then
        x = ms.conv_area_x + (ms.conv_area_w - 240) / 2
    end
    local y = pos and pos.y or 160
    ms.context_menu = {
        x = x, y = y, message = message,
        items = ms:context_menu_items(message),
        index = 1,
    }
end

function context_menu_handler.open_chat_context_menu(ms, chat)
    local row = ms.model.selected - (ms.model.list_offset or 0)
    local y = HEADER_HEIGHT + (row - 1) * ITEM_HEIGHT
    ms.context_menu = {
        x = 116,
        y = math.max(HEADER_HEIGHT, math.min(y, ui.height() - 80)),
        chat = chat,
        items = ms:chat_context_menu_items(chat),
    }
end

function context_menu_handler.draw_context_menu(ms, f, colors, w, h)
    if not ms.context_menu then return end
    local cm = ms.context_menu
    local count = #(cm.items or {})
    local menu_w, item_h = 220, 36
    local menu_h = count * item_h + 16
    local x = math.min(cm.x or 120, w - menu_w - 16)
    local y = math.min(cm.y or 160, h - menu_h - 16)

    ui.rect(x - 8, y - 8, menu_w + 16, menu_h + 16, ui.colors.panel, 8)
    ui.outline(x - 8, y - 8, menu_w + 16, menu_h + 16, ui.colors.accent, 8)

    for index, item in ipairs(cm.items) do
        local item_y = y + (index - 1) * 36
        local sel = index == (cm.index or 1)
        ui.rect(x, item_y, menu_w, 32, sel and ui.colors.accent or ui.colors.panel_alt, 6)
        ui.outline(x, item_y, menu_w, 32, sel and ui.colors.text or ui.colors.muted, 6)
        ui.text(item.label, x + 12, item_y + 6, ms.fonts.normal, sel and ui.colors.bg or ui.colors.text)
    end
end

function context_menu_handler.handle_key(ms, key)
    if not ms.context_menu then return false end
    local cm = ms.context_menu
    local count = #(cm.items or {})
    if key == "up" then
        cm.index = math.max(1, (cm.index or 1) - 1)
    elseif key == "down" then
        cm.index = math.min(count, (cm.index or 1) + 1)
    elseif key == "return" or key == "kpenter" then
        local item = cm.items and cm.items[cm.index or 1]
        ms.context_menu = nil
        ms:activate_context_item(cm, item)
    elseif key == "escape" or key == "b" then
        ms.context_menu = nil
    end
    return true
end

function context_menu_handler.mousepressed(ms, x, y, button)
    if not ms.context_menu then return false end
    local cm = ms.context_menu
    local count = #(cm.items or {})
    local menu_w, item_h = 220, 36
    local menu_h = count * item_h + 16
    local x = math.min(cm.x or 120, ui.width() - menu_w - 16)
    local y = math.min(cm.y or 160, ui.height() - menu_h - 16)

    if x >= x and x <= x + menu_w and y >= y and y <= y + menu_h then
        local index = math.floor((y - y) / item_h) + 1
        if index >= 1 and index <= count then
            cm.index = index
            local item = cm.items[index]
            ms.context_menu = nil
            ms:activate_context_item(cm, item)
            return true
        end
    end
    -- Click outside closes menu
    ms.context_menu = nil
    return true
end

function context_menu_handler.update(ms, dt)
    -- No-op for now
end

return context_menu_handler