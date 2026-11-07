-- src/features/chat/ui/input/cursor_nav.lua
-- Extracted from chat_screen_input.lua - cursor navigation in messages

local ui = require("src.shared.ui.ui_kit")

local cursor_nav = {}

function cursor_nav.setup(ms)
    ms.message_cursor_id = nil
    ms.nav_messages = {}
    ms.nav_pos = {}
end

function cursor_nav.focused_message(ms)
    local nav = ms.nav_messages or {}
    if not ms.message_cursor_id then return nav[#nav] end
    for index, message in ipairs(nav) do
        if message.id == ms.message_cursor_id then return message end
    end
    return nav[#nav]
end

function cursor_nav.move_message_cursor(ms, delta)
    local nav = ms.nav_messages or {}
    if #nav == 0 then return end
    local current = ms.message_cursor_id
    local index = #nav
    for i, msg in ipairs(nav) do
        if msg.id == current then index = i break end
    end
    local new_index = math.max(1, math.min(#nav, index + delta))
    if new_index ~= index then
        -- Update logical cursor immediately (for scroll targeting)
        ms.message_cursor_id = nav[new_index].id
        ms.message_cursor_target_id = nav[new_index].id
        ms:ensure_message_visible()
    end
end

function cursor_nav.ensure_message_visible(ms)
    if not ms.message_cursor_id then return end
    local pos = ms.nav_pos[ms.message_cursor_id]
    if not pos then return end
    local area_y = ms.conv_area_y or 0
    local area_h = ms.conv_area_h or 0
    local msg_y = pos.y
    local msg_h = pos.h
    if msg_y < ms.model.scroll then
        ms.model.scroll = msg_y
    elseif msg_y + msg_h > ms.model.scroll + ms.conv_area_h then
        ms.model.scroll = msg_y + msg_h - ms.conv_area_h
    end
    if ms.model.scroll < 0 then ms.model.scroll = 0 end
    if ms.model.scroll > ms.model.max_scroll then ms.model.scroll = ms.model.max_scroll end
end

function cursor_nav.update(ms, dt)
    -- No-op for now
end

function cursor_nav.get_profile_target(ms)
    if ms.tg.current_chat_id then
        local chat = ms.tg.chats_by_id[ms.tg.current_chat_id] or ms.tg.archive_chats_by_id[ms.tg.current_chat_id]
        if chat then
            return chat.id, false, ms.tg:private_chat_user_id(chat)
        end
    end
    local chat = ms.model:selected_chat()
    if chat then
        return chat.id, false, ms.tg:private_chat_user_id(chat)
    end
    return nil, false
end

return cursor_nav