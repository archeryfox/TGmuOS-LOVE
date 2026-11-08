local json = require("dkjson")
local HISTORY_PAGE_SIZE = 50
local MAX_MESSAGES_PER_CHAT = 500

local function prune_messages(chat_id, self_ref)
    local list = self_ref.messages[chat_id]
    if not list or #list <= MAX_MESSAGES_PER_CHAT then return end
    local keep = MAX_MESSAGES_PER_CHAT
    local pruned = {}
    for i = #list - keep + 1, #list do
        if i >= 1 then pruned[#pruned + 1] = list[i] end
    end
    self_ref.messages[chat_id] = pruned
end

return function(telegram)
    function telegram:message_text(message)
        local content = message and message.content
        if not content then
            return ""
        end
        local kind = content["@type"]
        if kind == "messageText" then
            local text = content.text
            return text and text.text or ""
        elseif kind == "messagePhoto" then
            local caption = content.caption and content.caption.text or ""
            if caption ~= "" then
                return caption
            end
            return "[фото]"
        elseif kind == "messageVideo" or kind == "messageVideoNote" then
            return kind == "messageVideoNote" and "[видеосообщение]" or "[видео]"
        elseif kind == "messageSticker" then
            local emoji = content.sticker and content.sticker.emoji or ""
            if emoji and emoji ~= "" then
                return emoji .. " стикер"
            end
            return "[стикер]"
        elseif kind == "messageVoiceNote" then
            local note = content.voice_note
            local duration = note and tonumber(note.duration)
            if duration and duration > 0 then
                return string.format("[голосовое · %d:%02d]", math.floor(duration / 60), math.floor(duration % 60))
            end
            return "[голосовое]"
        elseif kind == "messageDocument" then
            local doc = content.document
            if doc then
                local mime = doc.mime_type or ""
                local fname = doc.file_name or ""
                if mime:match("^video/") or fname:match("%.webm$") or fname:match("%.tgs$") then
                    return "[стикер]"
                end
            end
            return "[файл]"
        elseif kind == "messageAudio" then
            return self:document_label(message)
        elseif kind == "messageAnimation" then
            return "[GIF]"
        end
        return "[сообщение]"
    end

    function telegram:document_label(message)
        local content = message and message.content
        if not content then return "Файл" end
        local kind = content["@type"]
        local document = kind == "messageDocument" and content.document
        local audio = kind == "messageAudio" and content.audio
        local metadata = document or audio
        if not metadata then return "Файл" end
        local name = tostring(metadata.file_name or "")
        if name == "" and audio then
            name = tostring(audio.title or "")
            if audio.performer and audio.performer ~= "" then
                name = name ~= "" and (name .. " — " .. audio.performer) or tostring(audio.performer)
            end
        end
        if name == "" then name = audio and "Музыка" or "Документ" end
        if not name:match("%.[%w]+$") then
            local extensions = {
                ["application/pdf"] = ".pdf",
                ["application/zip"] = ".zip",
                ["application/x-rar-compressed"] = ".rar",
                ["application/msword"] = ".doc",
                ["application/vnd.openxmlformats-officedocument.wordprocessingml.document"] = ".docx",
                ["application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"] = ".xlsx",
                ["text/plain"] = ".txt",
                ["audio/mpeg"] = ".mp3",
                ["audio/mp3"] = ".mp3",
                ["audio/mp4"] = ".m4a",
                ["audio/x-m4a"] = ".m4a",
                ["audio/aac"] = ".aac",
                ["audio/flac"] = ".flac",
                ["audio/x-flac"] = ".flac",
                ["audio/ogg"] = ".ogg",
                ["application/ogg"] = ".ogg",
                ["audio/opus"] = ".opus",
                ["audio/wav"] = ".wav",
                ["audio/x-wav"] = ".wav",
                ["audio/vnd.wave"] = ".wav",
                ["audio/webm"] = ".webm",
                ["audio/x-ms-wma"] = ".wma",
                ["audio/midi"] = ".mid",
                ["audio/x-midi"] = ".mid",
                ["video/mp4"] = ".mp4",
            }
            name = name .. (extensions[metadata.mime_type] or "")
        end
        return name
    end

    function telegram:sender_name(message)
        local sender = message and message.sender_id
        if not sender then
            return "Неизвестный"
        end
        if sender["@type"] == "messageSenderUser" then
            if self.me and sender.user_id == self.me.id then
                return "Вы"
            end
            self:ensure_user(sender.user_id)
            return self:user_name(sender.user_id)
        elseif sender["@type"] == "messageSenderChat" then
            return self:chat_title(sender.chat_id)
        end
        return "Неизвестный"
    end

    function telegram:get_messages(chat_id)
        return self.messages[chat_id] or {}
    end

    function telegram:open_chat(chat_id)
        self.current_chat_id = chat_id
        if not chat_id then
            return
        end
        for index = #(self.notifications or {}), 1, -1 do
            if self.notifications[index].chat_id == chat_id then
                table.remove(self.notifications, index)
            end
        end
        self.history_state[chat_id] = {
            loading = true,
            has_more = true,
            generation = 1,
        }
        local chat = self.chats_by_id[chat_id] or self.archive_chats_by_id[chat_id]
        local last = chat and chat.last_message
        self.messages[chat_id] = last and {last} or {}
        if last then
            self:ensure_photo(last)
            self:ensure_sticker(last)
            self:ensure_animation(last)
            self:ensure_video(last)
            self:ensure_voice_note(last)
            self:ensure_audio(last)
            self:ensure_video_note(last)
        end
        self:send({["@type"] = "openChat", chat_id = chat_id})
        self:send({
            ["@type"] = "getChatHistory",
            chat_id = chat_id,
            from_message_id = last and last.id or 0,
            offset = 0,
            limit = HISTORY_PAGE_SIZE,
            only_local = false,
        }, "history:" .. tostring(chat_id))
    end

    function telegram:load_more_history(chat_id)
        if not chat_id then return false end
        local state = self.history_state[chat_id]
        local messages = self.messages[chat_id] or {}
        if not state or state.loading or not state.has_more then return false end
        local oldest_id = messages[1] and messages[1].id
        if not oldest_id then
            local chat = self.chats_by_id[chat_id] or self.archive_chats_by_id[chat_id]
            oldest_id = chat and chat.last_message and chat.last_message.id or 0
        end
        state.generation = (state.generation or 0) + 1
        state.loading = true
        state.error = nil
        state.requested_oldest_id = oldest_id
        self:send({
            ["@type"] = "getChatHistory",
            chat_id = chat_id,
            from_message_id = oldest_id,
            offset = 0,
            limit = HISTORY_PAGE_SIZE,
            only_local = false,
        }, "history_more:" .. tostring(chat_id) .. ":" .. tostring(state.generation))
        return true
    end

     function telegram:close_chat()
        local chat_id = self.current_chat_id
        self.current_chat_id = nil
        if chat_id then
            for _, msg in ipairs(self.messages[chat_id] or {}) do
                pcall(self.pause_media_playback, self, msg)
            end
            self:send({["@type"] = "closeChat", chat_id = chat_id})
        end
    end

    function telegram:send_sticker(chat_id, sticker)
        if not chat_id or not sticker then return end
        local file = sticker.sticker or sticker
        local file_id = file and file.id
        if not file_id then return end
        -- Ensure the sticker file is downloaded locally first
        local fl = file["local"] or {}
        if not (fl.is_downloading_completed and fl.path and fl.path ~= "") then
            self.pending_sticker_send = {chat_id = chat_id, sticker = sticker}
            self:load_sticker_file(file)
            return
        end
        local fl = file["local"] or {}
        local input_file
        if fl.is_downloading_completed and fl.path and fl.path ~= "" then
            local sz = 0
            local f = io.open(fl.path, "rb")
            if f then sz = f:seek("end") or 0; f:close() end
            input_file = {["@type"] = "inputFileLocal", path = fl.path, expected_size = sz}
        elseif file.remote and file.remote.id and file.remote.id ~= "" then
            input_file = {["@type"] = "inputFileRemote", id = file.remote.id}
        else
            input_file = {["@type"] = "inputFileId", id = file_id}
        end
        self:send({
            ["@type"] = "sendMessage",
            chat_id = chat_id,
            input_message_content = {
                ["@type"] = "inputMessageSticker",
                sticker = {
                    ["@type"] = "inputSticker",
                    sticker = input_file,
                    width = (sticker.width or file.width or 512),
                    height = (sticker.height or file.height or 512),
                },
                emoji = sticker.emoji or "",
            },
        })
    end

    function telegram:send_document(chat_id, path)
        if not chat_id or not path then return end
        self:send({
            ["@type"] = "sendMessage",
            chat_id = chat_id,
            input_message_content = {
                ["@type"] = "inputMessageDocument",
                document = {
                    ["@type"] = "inputDocument",
                    document = {
                        ["@type"] = "inputFileLocal",
                        path = path,
                        expected_size = (function()
                            local f = io.open(path, "rb")
                            if not f then return 0 end
                            local sz = f:seek("end")
                            f:close()
                            return sz or 0
                        end)(),
                    },
                },
                caption = {["@type"] = "formattedText", text = ""},
            },
        })
    end

    function telegram:send_photo(chat_id, path)
        if not chat_id or not path then return end
        self:send({
            ["@type"] = "sendMessage",
            chat_id = chat_id,
            input_message_content = {
                ["@type"] = "inputMessagePhoto",
                photo = {
                    ["@type"] = "inputPhoto",
                    photo = {
                        ["@type"] = "inputFileLocal",
                        path = path,
                        expected_size = (function()
                            local f = io.open(path, "rb")
                            if not f then return 0 end
                            local sz = f:seek("end")
                            f:close()
                            return sz or 0
                        end)(),
                    },
                    width = 0,
                    height = 0,
                },
                caption = {["@type"] = "formattedText", text = ""},
                width = 0,
                height = 0,
            },
        })
    end

    function telegram:send_message(chat_id, text)
        if not chat_id or not text or text == "" then
            return
        end
        self:send({
            ["@type"] = "sendMessage",
            chat_id = chat_id,
            input_message_content = {
                ["@type"] = "inputMessageText",
                text = {
                    ["@type"] = "formattedText",
                    text = text,
                    entities = {},
                },
            },
        })
    end

    function telegram:mark_chat_viewed(chat_id, messages)
        if not chat_id then return end
        local seen = self.viewed_message_ids[chat_id]
        if not seen then
            seen = {}
            self.viewed_message_ids[chat_id] = seen
        end
        local ids = {}
        for _, message in ipairs(messages or self.messages[chat_id] or {}) do
            local id = message and message.id
            if id and not seen[id] then
                seen[id] = true
                ids[#ids + 1] = id
            end
        end
        if #ids == 0 then return end
        self:send({
            ["@type"] = "viewMessages",
            chat_id = chat_id,
            message_ids = ids,
            force_read = false,
        }, "view:" .. tostring(chat_id) .. ":" .. tostring(ids[#ids]))
        local chat = self.chats_by_id[chat_id] or self.archive_chats_by_id[chat_id]
        if chat and (chat.unread_count or 0) ~= 0 then
            chat.unread_count = 0
            if self.archive_chats_by_id[chat_id] then
                self:rebuild_archive_chats()
            else
                self:rebuild_chats()
            end
            self:rebuild_filter_chats()
        end
    end

    function telegram:send_typing(chat_id)
        if not chat_id then return end
        local now = love.timer.getTime()
        local last = self.typing_sent_at[chat_id]
        if last and now - last < 4 then return end
        self.typing_sent_at[chat_id] = now
        self:send({
            ["@type"] = "sendChatAction",
            chat_id = chat_id,
            action = {["@type"] = "chatActionTyping"},
        }, "typing:" .. tostring(chat_id))
    end

    function telegram:forward_messages(to_chat_id, from_chat_id, message_ids)
        if not to_chat_id or not from_chat_id or not message_ids or #message_ids == 0 then
            return false
        end
        self.action_error = ""
        self.action_status = "Пересылаю сообщения..."
        self:send({
            ["@type"] = "forwardMessages",
            chat_id = to_chat_id,
            from_chat_id = from_chat_id,
            message_ids = message_ids,
            options = {
                ["@type"] = "messageSendOptions",
                disable_notification = false,
                from_background = false,
                scheduling_state = json.null,
            },
            send_copy = false,
            remove_caption = false,
            only_preview = false,
        }, "forward:" .. tostring(to_chat_id) .. ":" .. tostring(from_chat_id))
        return true
    end

    function telegram:set_message_pinned(chat_id, message_id, pinned)
        if not chat_id or not message_id then return false end
        self.action_error = ""
        self.action_status = pinned and "Закрепляю сообщение..." or "Открепляю сообщение..."
        if pinned then
            self:send({
                ["@type"] = "pinChatMessage",
                chat_id = chat_id,
                message_id = message_id,
                disable_notification = false,
                only_for_self = false,
            }, "pin:" .. tostring(chat_id) .. ":" .. tostring(message_id))
        else
            self:send({
                ["@type"] = "unpinChatMessage",
                chat_id = chat_id,
                message_id = message_id,
            }, "unpin:" .. tostring(chat_id) .. ":" .. tostring(message_id))
        end
        return true
    end

    function telegram:delete_messages(chat_id, message_ids, revoke)
        if not chat_id or not message_ids or #message_ids == 0 then
            return
        end
        self:send({
            ["@type"] = "deleteMessages",
            chat_id = chat_id,
            message_ids = message_ids,
            revoke = revoke or false,
        }, "delete:" .. tostring(chat_id))
    end

    function telegram:edit_message_text(chat_id, message_id, text)
        if not chat_id or not message_id or not text or text == "" then
            self.action_error = "Текст сообщения не может быть пустым"
            self.action_status = ""
            return false
        end
        self.action_error = ""
        self.action_status = "Сохраняю изменения..."
        self:send({
            ["@type"] = "editMessageText",
            chat_id = chat_id,
            message_id = message_id,
            input_message_content = {
                ["@type"] = "inputMessageText",
                text = {
                    ["@type"] = "formattedText",
                    text = text,
                    entities = {},
                },
            },
        }, "edit:" .. tostring(chat_id) .. ":" .. tostring(message_id))
        return true
    end

    function telegram:set_message_reaction(chat_id, message_id, emoji)
        if not chat_id or not message_id then return false end
        self.action_error = ""
        self.action_status = (emoji and emoji ~= "") and ("Реакция " .. emoji) or "Убираю реакцию..."
        local reaction = {}
        if emoji and emoji ~= "" then
            reaction[1] = {["@type"] = "reactionTypeEmoji", emoji = emoji}
        end
        self:send({
            ["@type"] = "setMessageReactions",
            chat_id = chat_id,
            message_id = message_id,
            reaction = reaction,
            is_big = false,
        }, "reaction:" .. tostring(chat_id) .. ":" .. tostring(message_id))
        return true
    end

    function telegram:submit_password(password)
        if not password or password == "" then
            return
        end
        self:send({
            ["@type"] = "checkAuthenticationPassword",
            password = password,
        }, "password")
    end

    function telegram:handle_history(response)
        local extra = response["@extra"] or ""
        local chat_id, generation = extra:match("^history_more:(%-?%d+):(%d+)$")
        local is_more = chat_id ~= nil
        chat_id, generation = tonumber(chat_id), tonumber(generation)
        if not chat_id then
            chat_id = tonumber(extra:match("^history:(%-?%d+)$"))
        end
        if not chat_id then
            return
        end
        local state = self.history_state[chat_id]
        if not state then
            state = {loading = false, has_more = true, generation = 1}
            self.history_state[chat_id] = state
        end
        if is_more and (generation ~= state.generation or not state.loading) then return end
        local previous_ids = {}
        local by_id = {}
        for _, message in ipairs(self.messages[chat_id] or {}) do
            by_id[message.id] = message
            previous_ids[message.id] = true
        end
        local new_count = 0
        for _, message in ipairs(response.messages or {}) do
            if not previous_ids[message.id] then new_count = new_count + 1 end
            by_id[message.id] = message
        end
        local list = {}
        for _, message in pairs(by_id) do
            list[#list + 1] = message
        end
        table.sort(list, function(a, b)
            return (a.id or 0) < (b.id or 0)
        end)
        self.messages[chat_id] = list
        state.loading = false
        state.error = nil
        state.has_more = new_count > 0 and #(response.messages or {}) >= HISTORY_PAGE_SIZE
        state.oldest_id = list[1] and list[1].id or nil
        if is_more and self.current_chat_id == chat_id then
            state.stick_to_top = true
            -- remember the top (oldest) message of the newly loaded page so the
            -- cursor can land on the first new message instead of the bottom one
            state.new_page_top_id = list[1] and list[1].id or nil
        end
        for _, message in ipairs(list) do
            if message.sender_id and message.sender_id["@type"] == "messageSenderUser" then
                self:ensure_user(message.sender_id.user_id)
                self:ensure_user_photo(message.sender_id.user_id)
            end
            self:ensure_photo(message)
            self:ensure_sticker(message)
            self:ensure_animation(message)
            self:ensure_video(message)
            self:ensure_video_note(message)
            self:ensure_voice_note(message)
            self:ensure_audio(message)
        end
        if self.current_chat_id == chat_id then
            self:mark_chat_viewed(chat_id, list)
        end
    end

    function telegram:handle_new_message(message)
        if not message or not message.chat_id then
            return
        end
        if message.sender_id and message.sender_id["@type"] == "messageSenderUser" then
            self:ensure_user(message.sender_id.user_id)
            self:ensure_user_photo(message.sender_id.user_id)
        end

        local chat = self.chats_by_id[message.chat_id] or self.archive_chats_by_id[message.chat_id]
        local sender = message.sender_id
        local from_me = sender and sender["@type"] == "messageSenderUser"
            and self.me and sender.user_id == self.me.id
        if not from_me and not message.is_outgoing
            and self.current_chat_id ~= message.chat_id
            and not self:is_chat_muted(chat) then
            self:push_notification({
                chat_id = message.chat_id,
                title = (chat and chat.title) or self:sender_name(message),
                text = self:message_text(message),
                created = love.timer.getTime(),
            })
            if love.system and love.system.vibrate then
                pcall(love.system.vibrate, 0.2)
            end
        end

        if self.current_chat_id == message.chat_id then
            self:ensure_photo(message)
            self:ensure_sticker(message)
            self:ensure_animation(message)
            self:ensure_video(message)
            self:ensure_video_note(message)
            self:ensure_voice_note(message)
            self:ensure_audio(message)
            local list = self.messages[message.chat_id] or {}
            local replaced = false
            for i, existing in ipairs(list) do
                if existing.id == message.id then
                    list[i] = message
                    replaced = true
                    break
                end
            end
            if not replaced then
                list[#list + 1] = message
            end
            table.sort(list, function(a, b)
                return (a.id or 0) < (b.id or 0)
            end)
            self.messages[message.chat_id] = list
            prune_messages(message.chat_id, self)
            self:mark_chat_viewed(message.chat_id, {message})
        end

        if chat and (not chat.last_message or (message.id or 0) >= (chat.last_message.id or 0)) then
            chat.last_message = message
            if self.archive_chats_by_id[message.chat_id] then
                self:rebuild_archive_chats()
            else
                self:rebuild_chats()
            end
        end
    end

    function telegram:handle_send_succeeded(update)
        local old_id = update.old_message_id
        local message = update.message
        if not message or not message.chat_id then
            return
        end
        local list = self.messages[message.chat_id]
        if list then
            for i, existing in ipairs(list) do
                if existing.id == old_id then
                    list[i] = message
                    if self.current_chat_id == message.chat_id then
                        self:ensure_photo(message)
                        self:ensure_sticker(message)
                        self:ensure_animation(message)
                        self:ensure_video(message)
                        self:ensure_voice_note(message)
                        self:ensure_audio(message)
                        self:ensure_video_note(message)
                    end
                    return
                end
            end
        end
        self:handle_new_message(message)
    end

    function telegram:handle_message_content(update)
        local list = self.messages[update.chat_id]
        if not list then
            return
        end
        for _, message in ipairs(list) do
            if message.id == update.message_id then
                message.content = update.new_content
                self.action_error = ""
                self.action_status = "Сообщение изменено"
                if self.current_chat_id == update.chat_id then
                    self:ensure_photo(message)
                    self:ensure_sticker(message)
                    self:ensure_animation(message)
                    self:ensure_video(message)
                    self:ensure_voice_note(message)
                    self:ensure_audio(message)
                    self:ensure_video_note(message)
                end
                return
            end
        end
    end

    function telegram:handle_message_interaction_info(update)
        local chat_id, message_id = update.chat_id, update.message_id
        if not chat_id or not message_id then return end
        local function apply(message)
            if message and message.id == message_id then
                message.interaction_info = update.interaction_info
            end
        end
        for _, message in ipairs(self.messages[chat_id] or {}) do
            apply(message)
        end
        for _, message in ipairs(self.dialog_search_results[chat_id] or {}) do
            apply(message)
        end
        local chat = self.chats_by_id[chat_id] or self.archive_chats_by_id[chat_id]
        if chat then apply(chat.last_message) end
    end

    function telegram:handle_delete_messages(update)
        local list = self.messages[update.chat_id]
        if not list then
            return
        end
        local deleted = {}
        for _, id in ipairs(update.message_ids or {}) do
            deleted[id] = true
        end
        local kept = {}
        for _, message in ipairs(list) do
            if not deleted[message.id] then
                kept[#kept + 1] = message
            end
        end
        self.messages[update.chat_id] = kept
    end

end
