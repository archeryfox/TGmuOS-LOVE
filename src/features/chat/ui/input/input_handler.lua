-- src/features/chat/ui/input/input_handler.lua
-- Extracted from chat_screen_input.lua - handles keypressed events

local ui = require("src.shared.ui.ui_kit")

local input_handler = {}

function input_handler.setup(ms)
    ms.r2_pressed = false
    ms.l2_pressed = false
end

function input_handler.keypressed(ms, key)
    if ms.keyboard and ms.keyboard.visible then
        if ms:handle_virtual_keyboard(key) then return end
    end
    if ms.tg.sticker_set_viewer then
        if key == "escape" then ms.tg.sticker_set_viewer = nil end
        return
    end
    if ms.context_menu then
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
        return
    end
    if ms.fullscreen_media then
        local fm = ms.fullscreen_media
        if key == "escape" then
            ms.fullscreen_media = nil
            ms.player_controls = nil
            ms.fullscreen_zoom = 1
            ms.fullscreen_pan_x = 0
            ms.fullscreen_pan_y = 0
        elseif key == "return" or key == "kpenter" then
            if fm.kind == "video" then
                local _, _, playing = ms.tg:media_playback_state(fm.message)
                if playing then
                    ms.tg:pause_media_playback(fm.message)
                else
                    ms.tg:request_media_playback(fm.message)
                end
            end
        elseif key == "up" then
            if fm.kind ~= "video" then
                if ms.r2_pressed then
                    ms.fullscreen_pan_y = (ms.fullscreen_pan_y or 0) + 20
                else
                    ms.fullscreen_zoom = math.min(6, (ms.fullscreen_zoom or 1) + 0.25)
                end
            end
        elseif key == "down" then
            if fm.kind ~= "video" then
                if ms.r2_pressed then
                    ms.fullscreen_pan_y = (ms.fullscreen_pan_y or 0) - 20
                else
                    ms.fullscreen_zoom = math.max(1, (ms.fullscreen_zoom or 1) - 0.25)
                end
            end
        elseif key == "left" then
            if fm.kind ~= "video" and ms.r2_pressed then
                ms.fullscreen_pan_x = (ms.fullscreen_pan_x or 0) + 20
            else
                ms:switch_fullscreen_media(-1)
            end
        elseif key == "right" then
            if fm.kind ~= "video" and ms.r2_pressed then
                ms.fullscreen_pan_x = (ms.fullscreen_pan_x or 0) - 20
            else
                ms:switch_fullscreen_media(1)
            end
        elseif key == "pageup" and fm.kind == "video" then
            local position = ms.tg:media_playback_state(fm.message)
            ms.tg:seek_media_playback(fm.message, math.max(0, (position or 0) - 5))
        elseif key == "pagedown" and fm.kind == "video" then
            local position, duration = ms.tg:media_playback_state(fm.message)
            ms.tg:seek_media_playback(fm.message, math.min(duration or 0, (position or 0) + 5))
        end
        return
    end
    if ms.edit_mode then
        if key == "escape" then
            ms.edit_mode = false
            ms.edit_message = nil
            ms.edit_input = ""
            return
        end
        if key == "return" or key == "kpenter" then
            if love.keyboard.isDown("lshift", "rshift") then
                ms.edit_input = ms.edit_input .. "\n"
                return
            end
            local chat_id = ms.tg.current_chat_id
            local msg_id = ms.edit_message and ms.edit_message.id
            if chat_id and msg_id and ms.tg:edit_message_text(chat_id, msg_id, ms.edit_input) then
                ms.edit_mode = false
                ms.edit_message = nil
                ms.edit_input = ""
            else
                return
            end
            return
        end
        if key == "backspace" then
            ms.edit_input = ui.remove_last_utf8(ms.edit_input)
            return
        end
        return
    end

    if key == "f" and love.keyboard.isDown("lctrl", "rctrl") then
        ms.search_active = true
        ms:set_search_query(ms.search_query, false)
        return
    end

    if ms.search_active then
        if key == "escape" then
            ms.search_active = false
            ms:set_search_query("", false)
        elseif key == "backspace" then
            ms:set_search_query(ui.remove_last_utf8(ms.search_query), false)
        elseif key == "return" or key == "kpenter" then
            ms:submit_search()
        end
        return
    end

    if ms.forward_mode then
        local chat_list = ms:get_visible_chat_list()
        if key == "up" then
            ms.model.selected = math.max(1, ms.model.selected - 1)
        elseif key == "down" then
            ms.model.selected = math.min(#chat_list, ms.model.selected + 1)
        elseif key == "pageup" then
            ms.model.selected = math.max(1, ms.model.selected - 5)
        elseif key == "pagedown" then
            ms.model.selected = math.min(#chat_list, ms.model.selected + 5)
        elseif key == "return" or key == "kpenter" or key == "a" then
            local chat = chat_list[ms.model.selected]
            local ids = {}
            for _, msg in pairs(ms.selected_messages) do
                table.insert(ids, msg.id)
            end
            table.sort(ids)
            if chat and ms.forward_from_chat_id and #ids > 0 then
                if not ms.tg:forward_messages(chat.id, ms.forward_from_chat_id, ids) then
                    return
                end
            end
            ms.forward_mode = false
            ms.forward_from_chat_id = nil
            ms.selected_messages = {}
        elseif key == "escape" or key == "b" then
            ms.forward_mode = false
            ms.forward_from_chat_id = nil
            ms.selected_messages = {}
        end
        return
    end

    -- Track R2/L2 for pan during zoom
    if key == "r2" then
        ms.r2_pressed = true
        return
    elseif key == "l2" then
        ms.l2_pressed = true
        return
    end

    if key == "l2" or key == "r2" then
        ms:switch_list(key == "l2" and -1 or 1)
        return
    end

    if key == "escape" then
        if ms.tg.current_chat_id then
            ms.tg:close_chat()
            ms.model.scroll = 0
        end
        return
    end

    if key == "return" or key == "kpenter" then
        if ms.tg.current_chat_id then
            if ms.model.input ~= "" then
                ms:send()
            else
                ms:activate_focused_message()
            end
        else
            local chat = ms.model:selected_chat()
            if chat then ms:select_chat(chat.id) end
        end
        return
    end

    if key == "backspace" then
        ms.model.input = ui.remove_last_utf8(ms.model.input)
        return
    end

    if key == "x" then
        if ms.tg.current_chat_id then
            local message = ms:focused_message()
            if message then ms:open_message_context_menu(message) end
        else
            ms.search_active = true
            ms:set_search_query(ms.search_query, false)
        end
        return
    end

    if key == "y" then
        if ms.tg.current_chat_id then
            local message = ms:focused_message()
            if message then
                if ms.selected_messages[message.id] then
                    ms.selected_messages[message.id] = nil
                else
                    ms.selected_messages[message.id] = message
                end
            end
        else
            ms:toggle_archive()
        end
        return
    end

    if key == "a" then
        if ms.tg.current_chat_id then
            local chat = ms.tg.chats_by_id[ms.tg.current_chat_id]
            local is_archived = chat and chat.chat_list and chat.chat_list["@type"] == "chatListArchive"
            ms.tg:archive_chat(ms.tg.current_chat_id, not is_archived)
        else
            ms:toggle_archive()
        end
        return
    end

    if key == "tab" then
        if ms.keyboard then ms.keyboard:toggle() end
        return
    end

    if ms.tg.current_chat_id then
        if key == "up" then
            ms:move_message_cursor(-1)
        elseif key == "down" then
            ms:move_message_cursor(1)
        elseif key == "left" then
            ms:move_message_cursor(-5)
        elseif key == "right" then
            ms:move_message_cursor(5)
        elseif key == "pageup" then
            local step = (ms.conv_area_h or 300) * 0.9
            ms.model.scroll = math.min(ms.model.max_scroll, ms.model.scroll + step)
        elseif key == "pagedown" then
            local step = (ms.conv_area_h or 300) * 0.9
            ms.model.scroll = math.max(0, ms.model.scroll - step)
        elseif key == "a" then
            local chat = ms.tg.chats_by_id[ms.tg.current_chat_id]
            local is_archived = chat and chat.chat_list and chat.chat_list["@type"] == "chatListArchive"
            ms.tg:archive_chat(ms.tg.current_chat_id, not is_archived)
        end
    else
        if key == "a" then
            ms:toggle_archive()
        elseif key == "up" then
            ms.model.selected = math.max(1, ms.model.selected - 1)
        elseif key == "down" then
            ms.model.selected = math.min(#ms:get_visible_chat_list(), ms.model.selected + 1)
        elseif key == "pageup" then
            ms.model.selected = math.max(1, ms.model.selected - 5)
        elseif key == "pagedown" then
            ms.model.selected = math.min(#ms:get_visible_chat_list(), ms.model.selected + 5)
        end
    end
end

function input_handler.keyreleased(ms, key)
    if key == "r2" then
        ms.r2_pressed = false
    elseif key == "l2" then
        ms.l2_pressed = false
    end
end

return input_handler