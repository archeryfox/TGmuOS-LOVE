local ui = require("src.shared.ui.ui_kit")
local helpers = require("src.features.chat.ui.chat_screen_helpers")

return function(messenger_screen, layout)
    local HEADER_HEIGHT = layout.HEADER_HEIGHT
    local CHAT_HEADER_HEIGHT = layout.CHAT_HEADER_HEIGHT
    local INPUT_HEIGHT = layout.INPUT_HEIGHT
    local ITEM_HEIGHT = layout.ITEM_HEIGHT
    local REACTION_EMOJIS = layout.REACTION_EMOJIS
    local REACTION_COLUMNS = layout.REACTION_COLUMNS

    -- Gamepad trigger state tracking
    messenger_screen.r2_pressed = false
    messenger_screen.r2_pan_mode = false
    messenger_screen.l2_pressed = false

    function messenger_screen:send()
        local chat = self.model:current_chat()
        if chat and self.model.input ~= "" then
            self.tg:send_message(chat.id, self.model.input)
            self.model.input = ""
            self.model.scroll = 0
        end
    end

    function messenger_screen:cursor_index()
        local nav = self.nav_messages or {}
        if not self.message_cursor_id then return #nav end
        for index, message in ipairs(nav) do
            if message.id == self.message_cursor_id then return index end
        end
        return #nav
    end

    function messenger_screen:focused_message()
        local nav = self.nav_messages or {}
        return nav[self:cursor_index()]
    end

    function messenger_screen:ensure_message_visible(message_id)
        local pos = self.nav_pos and self.nav_pos[message_id]
        local area_y, area_h = self.conv_area_y, self.conv_area_h
        if not pos or not area_y or not area_h then return end
        local top, bottom = pos.y, pos.y + pos.h
        local delta = 0
        if top < area_y then
            delta = area_y - top
        elseif bottom > area_y + area_h then
            delta = (area_y + area_h) - bottom
        end
        if delta ~= 0 then
            self.model.scroll = math.max(0, math.min(self.model.max_scroll, self.model.scroll + delta))
        end
    end

    function messenger_screen:move_message_cursor(delta)
        local nav = self.nav_messages or {}
        if #nav == 0 then return end
        local index = math.max(1, math.min(#nav, self:cursor_index() + delta))
        self.message_cursor_id = nav[index].id
        self:ensure_message_visible(nav[index].id)
    end

    function messenger_screen:scroll_chat(dir)
        local now = love.timer.getTime()
        local base = 25
        if self.scroll_dir == dir and self.scroll_hold_start then
            local hold = now - self.scroll_hold_start
            local accel = math.min(1 + hold * 4, 12)
            base = base * accel
        else
            self.scroll_dir = dir
            self.scroll_hold_start = now
        end
        self.model.scroll = math.max(0, math.min(self.model.max_scroll or 0, (self.model.scroll or 0) + base * dir))
    end

    function messenger_screen:keyboard_preview()
        if self.edit_mode then
            return "Редактирование: " .. (self.edit_input or "")
        elseif self.search_active then
            return "Поиск: " .. (self.search_query or "")
        elseif self.tg.current_chat_id then
            return "Ввод: " .. (self.model.input or "")
        end
        return ""
    end

    function messenger_screen:keyboard_text(text)
        if not text or text == "" then return end
        if self.edit_mode then
            self.edit_input = (self.edit_input or "") .. text
            if self.tg.current_chat_id then self.tg:send_typing(self.tg.current_chat_id) end
        elseif self.search_active then
            self:set_search_query(self.search_query .. text, false)
        elseif self.tg.current_chat_id then
            self.model.input = self.model.input .. text
            self.tg:send_typing(self.tg.current_chat_id)
        end
    end

    function messenger_screen:keyboard_backspace()
        if self.edit_mode then
            self.edit_input = ui.remove_last_utf8(self.edit_input)
        elseif self.search_active then
            self:set_search_query(ui.remove_last_utf8(self.search_query), false)
        elseif self.tg.current_chat_id then
            self.model.input = ui.remove_last_utf8(self.model.input)
        end
    end

    function messenger_screen:keyboard_enter()
        if self.edit_mode then
            local chat_id = self.tg.current_chat_id
            local msg_id = self.edit_message and self.edit_message.id
            if chat_id and msg_id and self.tg:edit_message_text(chat_id, msg_id, self.edit_input) then
                self.edit_mode = false
                self.edit_message = nil
                self.edit_input = ""
            end
        elseif self.search_active then
            self:submit_search()
            if self.keyboard then self.keyboard.visible = false end
        elseif self.tg.current_chat_id then
            if self.model.input ~= "" then
                self:send()
            else
                self.keyboard.visible = false
            end
        end
    end

    function messenger_screen:open_sticker_pack_list()
        if not self.tg.installed_sticker_sets or #self.tg.installed_sticker_sets == 0 then
            self.tg:load_installed_sticker_sets()
        end
        local items = {}
        if self.tg.installed_sticker_sets == nil then
            self.tg:load_installed_sticker_sets()
            items[#items + 1] = {label = "Загрузка стикерпаков…", action = nil}
        else
            for _, set in ipairs(self.tg.installed_sticker_sets or {}) do
                local title = set.title or set.name or "Стикерпак"
                items[#items + 1] = {label = title, action = "open_sticker_pack_by_name", name = set.name}
            end
            if #items == 0 then
                items[#items + 1] = {label = "Нет установленных стикерпаков", action = nil}
            end
        end
        items[#items + 1] = {label = "Открыть по ссылке", action = "open_sticker_pack_by_link", name = ""}
        self.context_menu = {
            x = 120,
            y = 160,
            items = items,
            index = 1,
        }
        self.menu_anim = 0
        if self.keyboard then self.keyboard.visible = false end
    end

    function messenger_screen:open_file_browser(path)
        path = path or "/mnt/mmc/MUOS/screenshot/"
        -- normalize
        if path:sub(-1) ~= "/" then path = path .. "/" end
        local files = {}
        local ok, iter = pcall(love.filesystem.getDirectoryItems, path)
        -- love.filesystem only sees save dir; use io.popen ls instead
        local handle = io.popen("ls -1pa " .. "'" .. path:gsub("'", "'\\''") .. "' 2>/dev/null")
        if handle then
            for line in handle:lines() do
                if line ~= "" and line ~= "./" and line ~= "../" then
                    local is_dir = line:sub(-1) == "/"
                    local name = is_dir and line:sub(1, -2) or line
                    files[#files+1] = {name = name, is_dir = is_dir, path = path .. name}
                end
            end
            handle:close()
        end
        -- sort: dirs first, then files
        table.sort(files, function(a, b)
            if a.is_dir ~= b.is_dir then return a.is_dir end
            return a.name:lower() < b.name:lower()
        end)
        -- add parent dir entry if not root
        if path ~= "/" then
            table.insert(files, 1, {name = "..", is_dir = true, path = path:match("^(.*/)[^/]+/$") or "/"})
        end
        self.file_browser = {path = path, files = files, focus = 1, scroll = 0}
        if self.keyboard then self.keyboard.visible = false end
    end

    function messenger_screen:open_text_preview(path)
        local lines = {}
        local fh = io.open(path, "r")
        if fh then
            for line in fh:lines() do lines[#lines + 1] = line end
            fh:close()
        end
        self.text_preview = {loading = false, lines = lines, scroll = 0, message = nil, path = path}
    end

    function messenger_screen:handle_virtual_keyboard(key)
        if key == "f1" then
            self:open_sticker_pack_list()
            return true
        end
        local handled, result = self.keyboard:keypressed(key)
        if not handled then return false end
        if result then
            if result.kind == "text" then
                self:keyboard_text(result.text)
            elseif result.kind == "backspace" then
                self:keyboard_backspace()
            elseif result.kind == "enter" then
                self:keyboard_enter()
            elseif result.kind == "stickers" then
                self:open_sticker_pack_list()
            elseif result.kind == "files" then
                self:open_file_browser("/mnt/mmc/MUOS/screenshot/")
            end
        end
        return true
    end

    function messenger_screen:open_message_context_menu(message)
        if self.keyboard then self.keyboard.visible = false end
        local pos = self.nav_pos and self.nav_pos[message.id]
        local x = 120
        if self.conv_area_x and self.conv_area_w then
            x = self.conv_area_x + (self.conv_area_w - 240) / 2
        end
        local y = pos and pos.y or 160
        self.context_menu = {
            x = x, y = y, message = message,
            items = self:context_menu_items(message),
            index = 1,
        }
        self.menu_anim = 0
    end

    function messenger_screen:open_reaction_menu(message)
        if self.keyboard then self.keyboard.visible = false end
        local chosen = {}
        for _, reaction in ipairs(helpers.reaction_summary(message)) do
            if reaction.chosen then chosen[reaction.emoji] = true end
        end
        local items = {}
        for _, emoji in ipairs(REACTION_EMOJIS) do
            items[#items + 1] = {emoji = emoji, chosen = chosen[emoji] == true}
        end
        self.reaction_menu = {message = message, items = items, index = 1}
        self.menu_anim = 0
    end

    function messenger_screen:activate_focused_message()
        local message = self:focused_message()
        if not message then return end
        local content = message.content or {}
        local kind = content["@type"]
        if kind == "messagePhoto" then
            self.fullscreen_media = {message = message, kind = "photo"}
            self.fullscreen_zoom = 0.5
            self.fullscreen_zoom_target = 1.0
            self.fullscreen_zoom_start = love.timer.getTime()
            self.fullscreen_zoom_start_val = 0.5
        self.fullscreen_drag_start = nil
            self.fullscreen_pan_x = 0
            self.fullscreen_pan_y = 0
            self.fullscreen_pan_target_x = nil
            self.fullscreen_pan_target_y = nil
            if self.tg.ensure_photo_hires then self.tg:ensure_photo_hires(message) end
        elseif kind == "messageVideo" or kind == "messageVideoNote" then
            self.fullscreen_media = {message = message, kind = "video", video_note = kind == "messageVideoNote"}
            self.fullscreen_zoom = 0.5
            self.fullscreen_zoom_target = 1.0
            self.fullscreen_zoom_start = love.timer.getTime()
            self.fullscreen_zoom_start_val = 0.5
        self.fullscreen_drag_start = nil
            self.tg:request_media_playback(message)
        elseif kind == "messageAnimation" or kind == "messageSticker" then
            -- GIF/video/sticker playback via context menu ("Воспроизвести"); fullscreen
            -- for animations was removed per user request (moved to context menu)
            local _, _, entry = self.tg:media_file_for_message(message)
            if entry and entry.playing then
                self.tg:stop_media_playback(message)
            else
                self.tg:request_media_playback(message)
            end
        else
            self:open_message_context_menu(message)
        end
    end

    function messenger_screen:media_nav_list()
        local list = {}
        local source = self.nav_messages or {}
        if self.tg.current_chat_id then
            local messages = self.tg:get_messages(self.tg.current_chat_id)
            if messages and #messages > 0 then source = messages end
        end
        for _, message in ipairs(source) do
            local kind = message.content and message.content["@type"]
            if kind == "messagePhoto" then
                -- Expand photo albums into individual media items
                if message.content and message.content.photos then
                    for i, _ in ipairs(message.content.photos) do
                        list[#list + 1] = {message = message, media_index = i, media_kind = "photo"}
                    end
                else
                    list[#list + 1] = {message = message, media_index = 1, media_kind = "photo"}
                end
            elseif kind == "messageVideo" then
                list[#list + 1] = {message = message, media_index = 1, media_kind = "video"}
            elseif kind == "messageVideoNote" then
                list[#list + 1] = {message = message, media_index = 1, media_kind = "video_note"}
            elseif kind == "messageAnimation" then
                list[#list + 1] = {message = message, media_index = 1, media_kind = "animation"}
            end
        end
        return list
    end

    function messenger_screen:switch_fullscreen_media(delta)
        local fm = self.fullscreen_media
        if not fm then return end
        local list = self:media_nav_list()
        if #list == 0 then return end
        local index = 1
        for i, item in ipairs(list) do
            if item.message.id == fm.message.id and (item.media_index or 1) == (fm.media_index or 1) then
                index = i
                break
            end
        end
        local new_index = math.max(1, math.min(#list, index + delta))
        if new_index == index then return end
        local item = list[new_index]
        if fm.kind == "video" then
            self.tg:stop_media_playback(fm.message)
        end
        local kind = item.media_kind
        if kind == "video" or kind == "video_note" then
            self.fullscreen_media = {message = item.message, kind = "video", video_note = kind == "video_note", media_index = item.media_index}
            self.tg:request_media_playback(item.message)
        elseif kind == "animation" then
            self.fullscreen_media = {message = item.message, kind = "photo", media_index = item.media_index}
        else
            self.tg:ensure_photo(item.message)
            self.fullscreen_media = {message = item.message, kind = "photo", media_index = item.media_index}
            if self.tg.ensure_photo_hires then self.tg:ensure_photo_hires(item.message) end
            self.fullscreen_pan_x = 0
            self.fullscreen_pan_y = 0
            self.fullscreen_pan_target_x = nil
            self.fullscreen_pan_target_y = nil
        end
self.fullscreen_zoom = 1.2
        self.fullscreen_drag_start = nil
        self.fullscreen_pan_x = 0
        self.fullscreen_pan_y = 0
        self.player_controls = nil
        self.message_cursor_id = item.message.id
        self:ensure_message_visible(item.message.id)
    end

    function messenger_screen:activate_context_item(cm, item)
        if not item then return end
        if cm.chat then
            if item.action == "mute_chat" then
                self.tg:set_chat_muted(cm.chat.id, true)
            elseif item.action == "unmute_chat" then
                self.tg:set_chat_muted(cm.chat.id, false)
            elseif item.action == "archive_chat" then
                self.tg:archive_chat(cm.chat.id, true)
            elseif item.action == "unarchive_chat" then
                self.tg:archive_chat(cm.chat.id, false)
            elseif item.action == "leave_chat" then
                self.tg:leave_chat(cm.chat.id)
            end
            self.context_menu = nil
            return
        end
        if item.action == "copy" then
            local text = cm.message.content and cm.message.content.text and cm.message.content.text.text or ""
            if text ~= "" then love.system.setClipboardText(text) end
        elseif item.action == "react" then
            self:open_reaction_menu(cm.message)
        elseif item.action == "forward" then
            self.selected_messages[cm.message.id] = cm.message
            self.forward_from_chat_id = cm.message.chat_id or self.tg.current_chat_id
            self.forward_mode = true
        elseif item.action == "play_media" then
            self.tg:request_media_playback(cm.message)
        elseif item.action == "stop_media" then
            self.tg:stop_media_playback(cm.message)
        elseif item.action == "view_fullscreen" then
            local msg = cm.message
            local kind = "photo"
            local media_index = 1
            if msg and msg.content then
                local ct = msg.content["@type"]
                if ct == "messageVideo" then kind = "video"
                elseif ct == "messageVideoNote" then kind = "video_note"
                elseif ct == "messageSticker" then kind = "sticker"
                elseif ct == "messageAnimation" then kind = "animation"
                elseif ct == "messagePhoto" then
                    local photos = msg.content.photos
                    if photos and #photos > 0 then
                        media_index = #photos
                    end
                end
            end
            self.fullscreen_media = {message = msg, video_note = (kind == "video_note"), kind = kind, media_index = media_index}
            self.fullscreen_zoom = 1.2
        self.fullscreen_drag_start = nil
            self.fullscreen_pan_x = 0
            self.fullscreen_pan_y = 0
        elseif item.action == "open_sticker_pack_by_name" then
            if item.name then
                self.tg:open_sticker_set_by_name(item.name)
            end
        elseif item.action == "open_sticker_pack_by_link" then
            -- Prompt for link via text input
            self.sticker_link_input = ""
            self.sticker_link_mode = true
        elseif item.action == "open_sticker_pack" then
            if not self.tg:open_sticker_set(cm.message) then
                self.tg.action_error = "Не удалось открыть стикерпак"
            end
        elseif item.action == "download_sticker" then
            self.tg:ensure_sticker(cm.message)
            self.tg.action_status = "Загрузка стикера..."
        elseif item.action == "pin" or item.action == "unpin" then
            local chat_id = self.tg.current_chat_id
            local msg_id = cm.message and cm.message.id
            if chat_id and msg_id then
                self.tg:set_message_pinned(chat_id, msg_id, item.action == "pin")
            end
        elseif item.action == "delete" then
            local chat_id = self.tg.current_chat_id
            local msg_id = cm.message and cm.message.id
            if chat_id and msg_id then
                self.tg:delete_messages(chat_id, {msg_id}, false)
            end
        elseif item.action == "delete_all" then
            local chat_id = self.tg.current_chat_id
            local msg_id = cm.message and cm.message.id
            if chat_id and msg_id then
                self.tg:delete_messages(chat_id, {msg_id}, true)
            end
        elseif item.action == "edit" then
            self.edit_mode = true
            self.edit_message = cm.message
            self.edit_input = cm.message.content and cm.message.content.text and cm.message.content.text.text or ""
        elseif item.action == "write_to_author" then
            local sender_id = item.sender_id
            if sender_id then
                self.tg:open_private_chat(sender_id)
            end
        end
    end

    function messenger_screen:keypressed(key)
        if self.keyboard and self.keyboard.visible then
            if self:handle_virtual_keyboard(key) then return end
        end
        -- Media player bar controls (when media is playing and not fullscreen)
        if self.tg.now_playing and not self.fullscreen_media then
            local np = self.tg.now_playing
            if key == "return" or key == "kpenter" or key == "a" then
                local _, _, playing = self.tg:media_playback_state(np)
                if playing then self.tg:pause_media_playback(np)
                else self.tg:request_media_playback(np) end
                return
            elseif key == "left" then
                local pos, dur = self.tg:media_playback_state(np)
                self.tg:seek_media_playback(np, math.max(0, (pos or 0) - 10))
                return
            elseif key == "right" then
                local pos, dur = self.tg:media_playback_state(np)
                self.tg:seek_media_playback(np, math.min(dur or 0, (pos or 0) + 10))
                return
            elseif key == "escape" or key == "b" then
                self.tg:pause_media_playback(np)
                self.tg.now_playing = nil
                return
            end
        end
        if self.file_browser then
            local fb = self.file_browser
            local files = fb.files or {}
            if key == "escape" or key == "b" then
                self.file_browser = nil
                return
            end
            if #files == 0 then return end
            if key == "up" then
                fb.focus = math.max(1, (fb.focus or 1) - 1)
            elseif key == "down" then
                fb.focus = math.min(#files, (fb.focus or 1) + 1)
            elseif key == "a" or key == "return" or key == "kpenter" then
                local sel = files[fb.focus or 1]
                if sel then
                    if sel.is_dir then
                        self:open_file_browser(sel.path)
                    elseif sel.name:match("%.txt$") or sel.name:match("%.log$") or sel.name:match("%.md$") or sel.name:match("%.json$") or sel.name:match("%.lua$") then
                        self:open_text_preview(sel.path)
                    elseif self.tg.current_chat_id then
                        local ext = sel.name:match("%.([^%.]+)$")
                        ext = ext and ext:lower() or ""
                        if ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "gif" or ext == "webp" then
                            self.tg:send_photo(self.tg.current_chat_id, sel.path)
                        else
                            self.tg:send_document(self.tg.current_chat_id, sel.path)
                        end
                        self.tg.action_status = "Отправка файла…"
                        self.file_browser = nil
                    else
                        self.tg.action_error = "Откройте чат для отправки"
                        self.file_browser = nil
                    end
                end
            elseif key == "pageup" then
                fb.focus = math.max(1, (fb.focus or 1) - 10)
            elseif key == "pagedown" then
                fb.focus = math.min(#files, (fb.focus or 1) + 10)
            end
            return
        end
        if key == "f" and self.tg.current_chat_id and not self.keyboard.visible then
            self:open_file_browser("/mnt/mmc/MUOS/screenshot/")
            return
        end
        if self.text_preview then
            local tp = self.text_preview
            if key == "escape" or key == "b" then
                self.text_preview = nil
                return
            elseif key == "up" then
                tp.scroll = math.max(0, (tp.scroll or 0) - 1)
                return
            elseif key == "down" then
                tp.scroll = (tp.scroll or 0) + 1
                return
            elseif key == "pageup" then
                tp.scroll = math.max(0, (tp.scroll or 0) - 10)
                return
            elseif key == "pagedown" then
                tp.scroll = (tp.scroll or 0) + 10
                return
            end
            return
        end
        if self.tg.sticker_set_viewer then
            if self.sticker_fullscreen_image then
                if key == "escape" or key == "b" then
                    self.sticker_fullscreen_image = nil
                    self.sticker_fullscreen_sticker = nil
                elseif key == "x" and self.tg.current_chat_id and self.sticker_fullscreen_sticker then
                    self.tg:send_sticker(self.tg.current_chat_id, self.sticker_fullscreen_sticker)
                    self.sticker_fullscreen_image = nil
                    self.sticker_fullscreen_sticker = nil
                end
                return
            end
            local pack = self.tg.sticker_set_viewer
            if pack and not pack.loading and not pack.error and pack.stickers and #pack.stickers > 0 then
                local width, height = ui.width(), ui.height()
                local panel_w = math.min(width - 48, 760)
                local panel_h = math.min(height - 48, 620)
                local grid_w = panel_w - 32
                local grid_h = panel_h - 92
                local columns = math.max(1, math.floor(grid_w / 112))
                local rows_per_page = math.max(1, math.floor(grid_h / 116))
                local row_count = math.ceil(#pack.stickers / columns)
                local max_scroll = math.max(0, row_count - rows_per_page)
                pack.focus = pack.focus or 1
                if key == "left" then
                    pack.focus = math.max(1, pack.focus - 1)
                elseif key == "right" then
                    pack.focus = math.min(#pack.stickers, pack.focus + 1)
                elseif key == "up" or key == "kp8" then
                    pack.focus = math.max(1, pack.focus - columns)
                elseif key == "down" or key == "kp2" then
                    pack.focus = math.min(#pack.stickers, pack.focus + columns)
                elseif key == "pageup" then
                    pack.focus = math.max(1, pack.focus - columns * rows_per_page)
                    pack.scroll = math.max(0, (pack.scroll or 0) - rows_per_page)
                elseif key == "pagedown" then
                    pack.focus = math.min(#pack.stickers, pack.focus + columns * rows_per_page)
                    pack.scroll = math.min(max_scroll, (pack.scroll or 0) + rows_per_page)
                elseif key == "a" or key == "return" or key == "kpenter" or key == "x" then
                    if key == "x" then
                        local sticker = pack.stickers[pack.focus]
                        local file = sticker and sticker.sticker
                        local entry = file and self.tg.stickers and self.tg.stickers[file.id]
                        local img = entry and (entry.image or (entry.frames and entry.frames[1]))
                        if img then
                            self.sticker_fullscreen_image = img
                            self.sticker_fullscreen_sticker = sticker
                        end
                    else
                        if self.tg.current_chat_id then
                            local sticker = pack.stickers[pack.focus]
                            if sticker then
                                self.tg:send_sticker(self.tg.current_chat_id, sticker)
                                self.tg.action_status = "Отправка стикера…"
                            else
                                self.tg.action_error = "Нет текущего чата"
                            end
                        else
                            self.tg.action_error = "Откройте чат для отправки"
                        end
                    end
                end
                -- keep focus visible
                local focus_row = math.floor((pack.focus - 1) / columns)
                local scroll = pack.scroll or 0
                if focus_row < scroll then pack.scroll = focus_row end
                if focus_row >= scroll + rows_per_page then pack.scroll = focus_row - rows_per_page + 1 end
                pack.scroll = math.max(0, math.min(max_scroll, pack.scroll or 0))
            end
            if key == "y" then
                self.tg.sticker_set_viewer = nil
                self.sticker_fullscreen_image = nil
                self.sticker_fullscreen_sticker = nil
                if self.keyboard then
                    self.keyboard.visible = true
                    self.keyboard.mode = "text"
                    self.keyboard.lang = "ru"
                    self.keyboard:_sync_layout()
                end
                return
            end
            if key == "escape" or key == "b" then self.tg.sticker_set_viewer = nil end
            return
        end
        if (key == "p" or key == "m") and not self.tg.current_chat_id then
            self.wants_profile_self = true
            return
        end
        if self.sticker_link_mode then
            if key == "return" or key == "kpenter" or key == "a" then
                local link = self.sticker_link_input
                self.sticker_link_input = ""
                self.sticker_link_mode = false
                if link and link ~= "" then
                    self.tg:open_sticker_set_by_link(link)
                end
                return
            elseif key == "escape" or key == "b" then
                self.sticker_link_input = ""
                self.sticker_link_mode = false
                return
            elseif key == "backspace" then
                self.sticker_link_input = self.sticker_link_input:sub(1, -2)
                return
            end
            return
        end
        if self.reaction_menu then
            local menu = self.reaction_menu
            local count = #(menu.items or {})
            if key == "left" then
                menu.index = math.max(1, (menu.index or 1) - 1)
            elseif key == "right" then
                menu.index = math.min(count, (menu.index or 1) + 1)
            elseif key == "up" then
                menu.index = math.max(1, (menu.index or 1) - REACTION_COLUMNS)
            elseif key == "down" then
                menu.index = math.min(count, (menu.index or 1) + REACTION_COLUMNS)
            elseif key == "return" or key == "kpenter" or key == "a" then
                local item = menu.items and menu.items[menu.index or 1]
                self.reaction_menu = nil
                if item and menu.message then
                    local chat_id = menu.message.chat_id or self.tg.current_chat_id
                    self.tg:set_message_reaction(chat_id, menu.message.id,
                        item.chosen and "" or item.emoji)
                end
            elseif key == "escape" or key == "b" then
                self.reaction_menu = nil
            end
            return
        end
        if self.context_menu then
            local cm = self.context_menu
            local count = #(cm.items or {})
            if key == "up" then
                cm.index = math.max(1, (cm.index or 1) - 1)
                cm.scroll = cm.scroll or 0
                if cm.index <= cm.scroll then cm.scroll = cm.index - 1 end
            elseif key == "down" then
                cm.index = math.min(count, (cm.index or 1) + 1)
                cm.scroll = cm.scroll or 0
                local max_visible = 12
                if cm.index > cm.scroll + max_visible then cm.scroll = cm.index - max_visible end
            elseif key == "return" or key == "kpenter" then
                local item = cm.items and cm.items[cm.index or 1]
                self.context_menu = nil
                self:activate_context_item(cm, item)
            elseif key == "escape" or key == "b" or key == "x" or key == "backspace" or key == "menu" then
                self.context_menu = nil
            end
            return
        end
        if self.fullscreen_media then
            local fm = self.fullscreen_media
            if key == "escape" then
                self.fullscreen_media = nil
                self.player_controls = nil
                self.fullscreen_zoom = 1.2
        self.fullscreen_drag_start = nil
                self.fullscreen_pan_x = 0
                self.fullscreen_pan_y = 0
                self.fullscreen_pan_target_x = nil
                self.fullscreen_pan_target_y = nil
                self.fullscreen_hint_time = nil
                self.r2_pan_mode = false
            elseif key == "return" or key == "kpenter" then
                if fm.kind == "video" then
                    local _, _, playing = self.tg:media_playback_state(fm.message)
                    if playing then
                        self.tg:pause_media_playback(fm.message)
                    else
                        self.tg:request_media_playback(fm.message)
                    end
                end
            elseif key == "up" then
                if fm.kind ~= "video" then
                    if self.r2_pan_mode then
                        self.fullscreen_pan_target_y = (self.fullscreen_pan_target_y or self.fullscreen_pan_y or 0) + 20
                    else
                        local cur = self.fullscreen_zoom or 1
                        local target = math.min(6, cur + 0.5)
                        self.fullscreen_zoom_target = target
                        self.fullscreen_zoom_start_val = cur
                        self.fullscreen_zoom_start = love.timer.getTime()
                    end
                end
            elseif key == "down" then
                if fm.kind ~= "video" then
                    if self.r2_pan_mode then
                        self.fullscreen_pan_target_y = (self.fullscreen_pan_target_y or self.fullscreen_pan_y or 0) - 20
                    else
                        local cur = self.fullscreen_zoom or 1
                        local target = math.max(0.5, cur - 0.5)
                        self.fullscreen_zoom_target = target
                        self.fullscreen_zoom_start_val = cur
                        self.fullscreen_zoom_start = love.timer.getTime()
                    end
                end
            elseif key == "left" then
                if fm.kind ~= "video" and self.r2_pan_mode then
                    self.fullscreen_pan_target_x = (self.fullscreen_pan_target_x or self.fullscreen_pan_x or 0) + 20
                else
                    self:switch_fullscreen_media(-1)
                end
            elseif key == "a" then
                if fm.kind ~= "video" and fm.kind ~= "video_note" then
                end
            elseif key == "right" then
                if fm.kind ~= "video" and self.r2_pan_mode then
                    self.fullscreen_pan_target_x = (self.fullscreen_pan_target_x or self.fullscreen_pan_x or 0) - 20
                else
                    self:switch_fullscreen_media(1)
                end
            elseif key == "pageup" and fm.kind == "video" then
                local position = self.tg:media_playback_state(fm.message)
                self.tg:seek_media_playback(fm.message, math.max(0, (position or 0) - 10))
            elseif key == "pagedown" and fm.kind == "video" then
                local position, duration = self.tg:media_playback_state(fm.message)
                self.tg:seek_media_playback(fm.message, math.min(duration or 0, (position or 0) + 10))
            elseif key == "r2" then
                self.r2_pan_mode = not self.r2_pan_mode
                return
            elseif key == "l2" then
                self.l2_pressed = true
            end
            return
        end
        if self.edit_mode then
            if key == "escape" then
                self.edit_mode = false
                self.edit_message = nil
                self.edit_input = ""
                return
            end
            if key == "return" or key == "kpenter" then
                if love.keyboard.isDown("lshift", "rshift") then
                    self.edit_input = self.edit_input .. "\n"
                    return
                end
                local chat_id = self.tg.current_chat_id
                local msg_id = self.edit_message and self.edit_message.id
                if chat_id and msg_id and self.tg:edit_message_text(chat_id, msg_id, self.edit_input) then
                    self.edit_mode = false
                    self.edit_message = nil
                    self.edit_input = ""
                else
                    return
                end
                return
            end
            if key == "backspace" then
                self.edit_input = ui.remove_last_utf8(self.edit_input)
                return
            end
            return
        end

        if key == "f" and love.keyboard.isDown("lctrl", "rctrl") then
            self.search_active = true
            self:set_search_query(self.search_query, false)
            return
        end

        if self.search_active then
            if key == "escape" or key == "b" or key == "x" or key == "menu" then
                self.search_active = false
                self:set_search_query("", false)
            elseif key == "backspace" then
                self:set_search_query(ui.remove_last_utf8(self.search_query), false)
            elseif key == "return" or key == "kpenter" then
                self:submit_search()
            end
            return
        end

        if self.forward_mode then
            local chat_list = self:get_visible_chat_list()
            if key == "up" then
                self.model.selected = math.max(1, self.model.selected - 1)
            elseif key == "down" then
                self.model.selected = math.min(#chat_list, self.model.selected + 1)
            elseif key == "pageup" then
                self.model.selected = math.max(1, self.model.selected - 5)
            elseif key == "pagedown" then
                self.model.selected = math.min(#chat_list, self.model.selected + 5)
            elseif key == "return" or key == "kpenter" or key == "a" then
                local chat = chat_list[self.model.selected]
                local ids = {}
                for _, msg in pairs(self.selected_messages) do
                    table.insert(ids, msg.id)
                end
                table.sort(ids)
                if chat and self.forward_from_chat_id and #ids > 0 then
                    if not self.tg:forward_messages(chat.id, self.forward_from_chat_id, ids) then
                        return
                    end
                end
                self.forward_mode = false
                self.forward_from_chat_id = nil
                self.selected_messages = {}
            elseif key == "escape" or key == "b" then
                self.forward_mode = false
                self.forward_from_chat_id = nil
                self.selected_messages = {}
            end
            return
        end

        if key == "l2" or key == "r2" then
            self:switch_list(key == "l2" and -1 or 1)
            return
        end

        -- Track R2/L2 for pan during zoom
        if key == "r2" then
            self.r2_pressed = true
            return
        elseif key == "l2" then
            self.l2_pressed = true
            return
        end

        if key == "escape" then
            if self.tg.current_chat_id then
                self.tg:close_chat()
                self.model.scroll = 0
            end
            return
        end

        if key == "pagedown" then
            if self.tg.current_chat_id then
                self.tg:load_more_history(self.tg.current_chat_id)
            end
            return
        end

        if key == "return" or key == "kpenter" then
            if self.tg.current_chat_id then
                if self.model.input ~= "" then
                    self:send()
                else
                    self:activate_focused_message()
                end
            else
                local chat = self.model:selected_chat()
                if chat then self:select_chat(chat.id) end
            end
            return
        end

        if key == "backspace" then
            self.model.input = ui.remove_last_utf8(self.model.input)
            return
        end

        if key == "x" then
            if self.tg.current_chat_id then
                local message = self:focused_message()
                if message then self:open_message_context_menu(message) end
            else
                self.search_active = true
                self:set_search_query(self.search_query, false)
            end
            return
        end

        if key == "y" then
            if self.tg.current_chat_id then
                local message = self:focused_message()
                if message then
                    if self.selected_messages[message.id] then
                        self.selected_messages[message.id] = nil
                    else
                        self.selected_messages[message.id] = message
                    end
                end
            else
                local chat = self.model:selected_chat()
                if chat then
                    local row = self.model.selected - (self.model.list_offset or 0)
                    local y = HEADER_HEIGHT + (row - 1) * ITEM_HEIGHT
                    self.context_menu = {
                        x = 116,
                        y = math.max(HEADER_HEIGHT, math.min(y, ui.height() - 80)),
                        chat = chat,
                        items = self:chat_context_menu_items(chat),
                    }
                    self.menu_anim = 0
                end
            end
            return
        end

        if self.tg.current_chat_id then
            if key == "up" then
                self:move_message_cursor(-1)
            elseif key == "down" then
                self:move_message_cursor(1)
            elseif key == "left" then
                self:scroll_chat(-1)
            elseif key == "right" then
                self:scroll_chat(1)
            elseif key == "pageup" then
                local step = (self.conv_area_h or 300) * 0.9
                self.model.scroll = math.min(self.model.max_scroll, self.model.scroll + step)
            elseif key == "pagedown" then
                local step = (self.conv_area_h or 300) * 0.9
                self.model.scroll = math.max(0, self.model.scroll - step)
            elseif key == "a" then
                local chat = self.tg.chats_by_id[self.tg.current_chat_id]
                local is_archived = chat and chat.chat_list and chat.chat_list["@type"] == "chatListArchive"
                self.tg:archive_chat(self.tg.current_chat_id, not is_archived)
            end
        else
            if key == "a" then
                self:toggle_archive()
            elseif key == "up" then
                self.model.selected = math.max(1, self.model.selected - 1)
            elseif key == "down" then
                self.model.selected = math.min(#self:get_visible_chat_list(), self.model.selected + 1)
            elseif key == "pageup" then
                self.model.selected = math.max(1, self.model.selected - 5)
            elseif key == "pagedown" then
                self.model.selected = math.min(#self:get_visible_chat_list(), self.model.selected + 5)
            end
        end
    end

    function messenger_screen:get_profile_target()
        if self.tg.current_chat_id then
            local chat = self.tg.chats_by_id[self.tg.current_chat_id] or self.tg.archive_chats_by_id[self.tg.current_chat_id]
            if chat then
                return chat.id, false, self.tg:private_chat_user_id(chat)
            end
        end
        local chat = self.model:selected_chat()
        if chat then
            return chat.id, false, self.tg:private_chat_user_id(chat)
        end
        return nil, false
    end

    function messenger_screen:textinput(text)
        if self.sticker_link_mode then
            self.sticker_link_input = self.sticker_link_input .. text
            return
        end
        if self.edit_mode then
            self.edit_input = self.edit_input .. text
            if self.tg.current_chat_id then self.tg:send_typing(self.tg.current_chat_id) end
        elseif self.search_active then
            self:set_search_query(self.search_query .. text, false)
        elseif self.tg.current_chat_id then
            self.model.input = self.model.input .. text
            self.tg:send_typing(self.tg.current_chat_id)
        end
    end

    function messenger_screen:wheelmoved(x, y)
        if self.fullscreen_media then
            local fm = self.fullscreen_media
            if fm.kind ~= "video" then
                local zoom = self.fullscreen_zoom or 1
                if y > 0 then
                    zoom = math.min(6, zoom + 0.25)
                else
                    zoom = math.max(1, zoom - 0.25)
                end
                self.fullscreen_zoom = zoom
                -- Recenter zoom toward mouse cursor
                local mx, my = love.mouse.getPosition()
                local w, h = ui.width(), ui.height()
                local img = self.tg:current_media_image()
                if img then
                    local iw, ih = img:getWidth(), img:getHeight()
                    local old_zoom = self.fullscreen_zoom or 1
                    local scale_factor = zoom / old_zoom
                    -- Adjust pan to zoom toward cursor position
                    local dx = (mx - w/2)
                    local dy = (my - h/2)
                    self.fullscreen_pan_x = (self.fullscreen_pan_x or 0) + dx * (1 - 1/scale_factor) * 0.5
                    self.fullscreen_pan_y = (self.fullscreen_pan_y or 0) + dy * (1 - 1/scale_factor) * 0.5
                end
                return
            end
        end
        if self.tg.sticker_set_viewer then
            local pack = self.tg.sticker_set_viewer
            if not pack.loading and not pack.error then
                local width, height = ui.width(), ui.height()
                local panel_w = math.min(width - 48, 760)
                local panel_h = math.min(height - 48, 620)
                local grid_w = panel_w - 32
                local grid_h = panel_h - 92
                local columns = math.max(1, math.floor(grid_w / 112))
                local cell_h = math.min(116, grid_w / columns)
                local rows_per_page = math.max(1, math.floor(grid_h / cell_h))
                local row_count = math.ceil(#(pack.stickers or {}) / columns)
                pack.scroll = math.max(0, math.min(math.max(0, row_count - rows_per_page), pack.scroll - y))
            end
            return
        end
    function messenger_screen:mousemoved(x, y, dx, dy)
        if self.fullscreen_media and self.fullscreen_drag_start then
            local fm = self.fullscreen_media
            if fm.kind ~= "video" then
                local img = self.tg:current_media_image()
                if img then
                    local iw, ih = img:getWidth(), img:getHeight()
                    local w, h = ui.width(), ui.height()
                    local scale = self.fullscreen_zoom or 1
                    local draw_w = iw * scale
                    local draw_h = ih * scale
                    if draw_w > w or draw_h > h then
                        self.fullscreen_pan_x = (self.fullscreen_pan_x or 0) + dx
                        self.fullscreen_pan_y = (self.fullscreen_pan_y or 0) + dy
                        if draw_w > w then
                            self.fullscreen_pan_x = math.max(w - draw_w, math.min(self.fullscreen_pan_x, 0))
                        else
                            self.fullscreen_pan_x = 0
                        end
                        if draw_h > h then
                            self.fullscreen_pan_y = math.max(h - draw_h, math.min(self.fullscreen_pan_y, 0))
                        else
                            self.fullscreen_pan_y = 0
                        end
                    end
                end
            end
        end
    end

    local left_width = math.floor(ui.width() * 0.30)
        local mx = love.mouse.getX()
        if mx < left_width then
            local visible = math.max(1, math.floor((ui.height() - HEADER_HEIGHT) / ITEM_HEIGHT))
            local chat_list = self:get_visible_chat_list()
            self.model.list_offset = math.max(0, math.min(#chat_list - visible, self.model.list_offset - y))
        elseif self.tg.current_chat_id then
            self.model.scroll = math.max(0, math.min(self.model.max_scroll, self.model.scroll + y * 48))
        end
    end

    function messenger_screen:mousepressed(x, y, button)
        if self.fullscreen_media then
            local fm = self.fullscreen_media
            if fm.kind ~= "video" then
                if button == 1 then
                    self.fullscreen_drag_start = {x = x, y = y, pan_x = self.fullscreen_pan_x or 0, pan_y = self.fullscreen_pan_y or 0}
                    return
                elseif button == 2 then
                    -- Right click: reset zoom
                    self.fullscreen_zoom = 1.2
                    self.fullscreen_pan_x = 0
                    self.fullscreen_pan_y = 0
                    self.fullscreen_drag_start = nil
                    return
                end
            end
        end
        if self.tg.sticker_set_viewer then
            if button == 1 then
                local width, height = ui.width(), ui.height()
                local panel_w = math.min(width - 48, 760)
                local panel_h = math.min(height - 48, 620)
                local panel_x, panel_y = (width - panel_w) / 2, (height - panel_h) / 2
                local close_x, close_y = panel_x + panel_w - 48, panel_y + 8
                if x >= close_x and x <= panel_x + panel_w and y >= close_y and y <= close_y + 44 then
                    self.tg.sticker_set_viewer = nil
                    self.sticker_fullscreen_image = nil
                    self.sticker_fullscreen_sticker = nil
                elseif x < panel_x or x > panel_x + panel_w or y < panel_y or y > panel_y + panel_h then
                    self.tg.sticker_set_viewer = nil
                    self.sticker_fullscreen_image = nil
                    self.sticker_fullscreen_sticker = nil
                else
                    -- click inside grid: select sticker for fullscreen preview
                    local grid_x, grid_y = panel_x + 16, panel_y + 58
                    local grid_w, grid_h = panel_w - 32, panel_h - 92
                    local columns = math.max(1, math.floor(grid_w / 112))
                    local cell_w = grid_w / columns
                    local cell_h = math.min(116, cell_w)
                    if x >= grid_x and x <= grid_x + grid_w and y >= grid_y and y <= grid_y + grid_h then
                        local col = math.floor((x - grid_x) / cell_w)
                        local row = math.floor((y - grid_y) / cell_h)
                        local pack = self.tg.sticker_set_viewer
                        local rows_per_page = math.max(1, math.floor(grid_h / cell_h))
                        local first_index = (pack.scroll or 0) * columns + 1
                        local idx = first_index + row * columns + col
                        if pack.stickers and idx >= 1 and idx <= #pack.stickers then
                            local sticker = pack.stickers[idx]
                            local file = sticker and sticker.sticker
                            local entry = file and self.tg.stickers and self.tg.stickers[file.id]
                            local img = entry and (entry.image or (entry.frames and entry.frames[1]))
                            if img then
                                self.sticker_fullscreen_image = img
                                self.sticker_fullscreen_sticker = sticker
                            end
                            pack.focus = idx
                        end
                    end
                end
            end
            return
        end
        if self.fullscreen_media then
            if button == 1 and (self.fullscreen_media.kind == "photo" or self.fullscreen_media.kind == "animation" or self.fullscreen_media.kind == "video") then
            end
            if button == 1 and self.fullscreen_media.kind == "video" then
                local controls = self.player_controls
                if controls then
                    local toggle = controls.button
                    if x >= toggle.x and x <= toggle.x + toggle.w and y >= toggle.y and y <= toggle.y + toggle.h then
                        local _, _, playing = self.tg:media_playback_state(self.fullscreen_media.message)
                        local _, _, entry = self.tg:media_file_for_message(self.fullscreen_media.message)
                        if playing then
                            self.tg:pause_media_playback(self.fullscreen_media.message)
                        elseif entry and entry.paused then
                            self.tg:resume_media_playback(self.fullscreen_media.message)
                        else
                            self.tg:request_media_playback(self.fullscreen_media.message)
                        end
                        return
                    end
                    local track = controls.track
                    if x >= track.x and x <= track.x + track.w and y >= track.y and y <= track.y + track.h then
                        local _, duration = self.tg:media_playback_state(self.fullscreen_media.message)
                        if duration > 0 then
                            local position = (x - track.x) / track.w * duration
                            self.tg:seek_media_playback(self.fullscreen_media.message, position)
                        end
                        return
                    end
                end
            end
            if button == 1 then
                self.fullscreen_media = nil
                self.player_controls = nil
            end
            return
        end
        if self.context_menu then
            local cm = self.context_menu
            local menu_w = 240
            local row_h = 24
            local menu_h = #cm.items * row_h + 12
            local mx2 = math.min(cm.x, ui.width() - menu_w - 8)
            local my2 = math.min(cm.y, ui.height() - menu_h - 8)
            if x >= mx2 and x <= mx2 + menu_w and y >= my2 and y <= my2 + menu_h then
                local index = math.floor((y - my2 - 6) / row_h) + 1
                self:activate_context_item(cm, cm.items[index])
            end
            self.context_menu = nil
            return
        end
        local w = ui.width()
        local h = ui.height()
        local left_width = math.floor(w * 0.30)
        if button == 2 then
            if x < left_width and y >= HEADER_HEIGHT then
                local index = self.model.list_offset + math.floor((y - HEADER_HEIGHT) / ITEM_HEIGHT) + 1
                local chat_list = self:get_visible_chat_list()
                local chat = chat_list[index]
                if chat then
                    self.model.selected = index
                    self.context_menu = {x = x, y = y, chat = chat, items = self:chat_context_menu_items(chat), index = 1}
                    self.menu_anim = 0
                end
                return
            elseif self.tg.current_chat_id then
            local now = love.timer.getTime()
            for _, hit in ipairs(self.message_hits or {}) do
                if x >= hit.x and x <= hit.x + hit.w and y >= hit.y and y <= hit.y + hit.h then
                    local same_msg = self.rmb_last_msg_id == hit.message.id
                    local quick = same_msg and (now - self.rmb_last_time) <= 0.35
                    if same_msg and quick then
                        self.rmb_click_count = self.rmb_click_count + 1
                    else
                        self.rmb_click_count = 1
                    end
                    self.rmb_last_msg_id = hit.message.id
                    self.rmb_last_time = now

                    if self.rmb_click_count == 1 then
                        -- Первый клик: только контекстное меню, без выделения
                        self.context_menu = {
                            x = x,
                            y = y,
                            message = hit.message,
                            items = self:context_menu_items(hit.message),
                        }
                        self.menu_anim = 0
                    elseif self.rmb_click_count == 2 then
                        -- Второй клик: выделить сообщение
                        self.selected_messages[hit.message.id] = hit.message
                    elseif self.rmb_click_count >= 3 then
                        -- Третий клик: снять выделение
                        self.selected_messages[hit.message.id] = nil
                        self.rmb_click_count = 0
                        self.context_menu = nil
                    end
                    return
                end
            end
            -- Клик мимо сообщения: сброс состояния
            self.rmb_last_msg_id = nil
            self.rmb_last_time = 0
            self.rmb_click_count = 0
        end
            return
        end
        if button ~= 1 then return end

        local load_more = self.load_more_button
        if load_more and x >= load_more.x and x <= load_more.x + load_more.w
            and y >= load_more.y and y <= load_more.y + load_more.h then
            if self.tg.current_chat_id then
                self.tg:load_more_history(self.tg.current_chat_id)
            end
            return
        end

        for _, tag_hit in ipairs(self.hashtag_hits or {}) do
            if x >= tag_hit.x and x <= tag_hit.x + tag_hit.w and y >= tag_hit.y and y <= tag_hit.y + tag_hit.h then
                self.search_active = true
                self:set_search_query(tag_hit.tag, true)
                self:submit_search()
                return
            end
        end

        for _, hit in ipairs(self.message_hits or {}) do
            if hit.voice and x >= hit.voice_x and x <= hit.voice_x + hit.voice_w
                and y >= hit.voice_y and y <= hit.voice_y + hit.voice_h then
                local _, _, entry = self.tg:media_file_for_message(hit.message)
                if entry and entry.playing then
                    self.tg:pause_media_playback(hit.message)
                elseif entry and entry.paused then
                    self.tg:resume_media_playback(hit.message)
                else
                    self.tg:request_media_playback(hit.message)
                end
                return
            end
        end

        for _, media_hit in ipairs(self.media_hits or {}) do
            local hit_x = media_hit.media_x or media_hit.x
            local hit_y = media_hit.media_y or media_hit.y
            local hit_w = media_hit.media_w or media_hit.w
            local hit_h = media_hit.media_h or media_hit.h
            local inside = x >= hit_x and x <= hit_x + hit_w and y >= hit_y and y <= hit_y + hit_h
            if inside and media_hit.media_circle then
                local dx, dy = x - (hit_x + hit_w / 2), y - (hit_y + hit_h / 2)
                inside = dx * dx + dy * dy <= (hit_w / 2) ^ 2
            end
            if inside then
                if media_hit.media_kind == "sticker" then
                    if media_hit.play_x and x >= media_hit.play_x and x <= media_hit.play_x + media_hit.play_w
                        and y >= media_hit.play_y and y <= media_hit.play_y + media_hit.play_h then
                        local _, _, entry = self.tg:media_file_for_message(media_hit.message)
                        if entry and entry.playing then
                            self.tg:stop_media_playback(media_hit.message)
                        else
                            self.tg:request_media_playback(media_hit.message)
                        end
                    elseif not self.tg:open_sticker_set(media_hit.message) then
                        self.tg:request_media_playback(media_hit.message)
                    end
                    return
                elseif media_hit.media_kind == "animation" then
                    local _, _, entry = self.tg:media_file_for_message(media_hit.message)
                    if entry and entry.playing then
                        self.tg:stop_media_playback(media_hit.message)
                    else
                        self.tg:request_media_playback(media_hit.message)
                    end
                    return
                elseif media_hit.media_kind == "audio" or media_hit.media_kind == "voice" then
                    local _, _, entry = self.tg:media_file_for_message(media_hit.message)
                    if entry and entry.playing then
                        self.tg:pause_media_playback(media_hit.message)
                    elseif entry and entry.paused then
                        self.tg:resume_media_playback(media_hit.message)
                    else
                        self.tg:request_media_playback(media_hit.message)
                    end
                    return
                end
                local now = love.timer.getTime()
                local last = self.last_media_click
                if last and last.message_id == media_hit.message.id and last.kind == media_hit.media_kind
                    and now - last.time <= 0.35 then
                    local content = media_hit.message.content or {}
                    local is_video = media_hit.media_kind == "video"
                    if media_hit.media_kind == "animation" and self.load_more_button then
                        local lb = self.load_more_button
                        if x >= lb.x and x <= lb.x + lb.w and y >= lb.y and y <= lb.y + lb.h
                            and self.tg.current_chat_id then
                            self.tg:load_more_history(self.tg.current_chat_id)
                            return
                        end
                    end
                    if is_video then
                        self.fullscreen_media = {
                            message = media_hit.message,
                            kind = media_hit.media_kind,
                            video_note = content["@type"] == "messageVideoNote",
                        }
                        self.fullscreen_zoom = 1.2
        self.fullscreen_drag_start = nil
                        if is_video then self.tg:request_media_playback(media_hit.message) end
                    end
                    self.last_media_click = nil
                else
                    self.last_media_click = {message_id = media_hit.message.id, kind = media_hit.media_kind, time = now}
                end
                return
            end
        end

        for _, profile_hit in ipairs(self.profile_hits or {}) do
            if x >= profile_hit.x and x <= profile_hit.x + profile_hit.w
                and y >= profile_hit.y and y <= profile_hit.y + profile_hit.h then
                self.wants_profile_user_id = profile_hit.user_id
                return
            end
        end

        -- Settings button (top-right corner)
        local settings_btn_w = 36
        local settings_btn_x = w - 20 - settings_btn_w
        if x >= settings_btn_x and x <= settings_btn_x + settings_btn_w and y >= 15 and y <= 41 then
            self.wants_settings = true
            return
        end

        if x < left_width and y >= HEADER_HEIGHT then
            local index = self.model.list_offset + math.floor((y - HEADER_HEIGHT) / ITEM_HEIGHT) + 1
            local chat_list = self:get_visible_chat_list()
            local chat = chat_list[index]
            if chat then
                self.model.selected = index
                if self.forward_mode and self.forward_from_chat_id then
                    local ids = {}
                    for _, msg in pairs(self.selected_messages) do
                        table.insert(ids, msg.id)
                    end
                    table.sort(ids)
                    if #ids > 0 then
                        if not self.tg:forward_messages(chat.id, self.forward_from_chat_id, ids) then
                            return
                        end
                    end
                    self.forward_mode = false
                    self.forward_from_chat_id = nil
                    self.selected_messages = {}
                    return
                else
                    self.model.input = ""
                    self:select_chat(chat.id)
                end
            end
            return
        end

        if self.tg.current_chat_id then
            if x >= left_width and y >= HEADER_HEIGHT and y < HEADER_HEIGHT + CHAT_HEADER_HEIGHT then
                self.wants_profile_chat_id = self.tg.current_chat_id
                return
            end
            local send_w = 96
            local input_x = left_width + 16
            local input_y = h - INPUT_HEIGHT + 16
            local input_w = w - left_width - 32 - send_w - 12
            if x >= input_x + input_w + 12 and x <= input_x + input_w + 12 + send_w
                and y >= input_y and y <= input_y + 42 then
                self:send()
            end
        end
    end

    function messenger_screen:keyreleased(key)
        if key == "r2" then
            self.r2_pressed = false
        elseif key == "l2" then
            self.l2_pressed = false
        elseif key == "up" or key == "down" then
            self.scroll_dir = nil
            self.scroll_hold_start = nil
        end
    end
end
