local json = require("dkjson")

return function(telegram)
    function telegram:handle_user(user)
        if user["@extra"] == "me" then
            self.me = user
            self.users[user.id] = user
            self:ensure_user_photo(user.id)
            if self.on_me then self.on_me(user) end
        else
            self.users[user.id] = user
            self.requested_users[user.id] = nil
            self:ensure_user_photo(user.id)
        end
    end

    function telegram:ensure_user(user_id)
        if user_id and not self.users[user_id] and not self.requested_users[user_id] then
            self.requested_users[user_id] = true
            self:send({["@type"] = "getUser", user_id = user_id}, "user:" .. tostring(user_id))
        end
    end

    function telegram:user_name(user_id)
        local user = self.users[user_id]
        if not user then
            return "User " .. tostring(user_id)
        end
        local first = user.first_name or ""
        local last = user.last_name or ""
        local name = (first .. " " .. last):gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then
            name = user.username or ("User " .. tostring(user_id))
        end
        return name
    end

    function telegram:private_chat_user_id(chat)
        if not chat then return nil end
        local chat_type = chat.type or {}
        if chat_type["@type"] == "chatTypePrivate" or chat_type["@type"] == "chatTypeSecret" then
            return chat_type.user_id
        end
        return nil
    end

    function telegram:chat_title(chat_id)
        local chat = self.chats_by_id[chat_id]
        if chat then
            return chat.title or ("Chat " .. tostring(chat_id))
        end
        return "Chat " .. tostring(chat_id)
    end

    function telegram:handle_new_chat(chat, chat_list)
        if not chat or not chat.id then
            return
        end
        local membership = chat_list or chat.chat_list
        local list_type = membership and membership["@type"]
        if not list_type and type(chat.positions) == "table" then
            for _, position in ipairs(chat.positions) do
                local position_type = position.list and position.list["@type"]
                if position_type == "chatListArchive" then
                    list_type = position_type
                    break
                elseif position_type == "chatListMain" then
                    list_type = position_type
                end
            end
        end
        if not list_type then
            if self.archive_chats_by_id[chat.id] then
                list_type = "chatListArchive"
            else
                list_type = "chatListMain"
            end
        end
        chat.chat_list = {["@type"] = list_type}
        local is_archive = list_type == "chatListArchive"
        if is_archive then
            self.chats_by_id[chat.id] = nil
            self.archive_chats_by_id[chat.id] = chat
        else
            self.archive_chats_by_id[chat.id] = nil
            self.chats_by_id[chat.id] = chat
            self.chats_loaded = true
        end
        self:rebuild_chats()
        self:rebuild_archive_chats()
        self:rebuild_filter_chats()
        self:ensure_chat_photo(chat.id)
    end

    function telegram:handle_chat_last_message(update)
        local chat = self.chats_by_id[update.chat_id] or self.archive_chats_by_id[update.chat_id]
        if not chat then
            return
        end
        chat.last_message = update.last_message
        if update.last_message and update.last_message.date then
            chat.unread_count = 0
        end
        self:rebuild_chats()
        self:rebuild_filter_chats()
    end

    function telegram:rebuild_chats()
        local list = {}
        for _, chat in pairs(self.chats_by_id) do
            if not (chat.chat_list and chat.chat_list["@type"] == "chatListArchive") then
                list[#list + 1] = chat
            end
        end
        table.sort(list, function(a, b)
            local a_date = a.last_message and a.last_message.date or 0
            local b_date = b.last_message and b.last_message.date or 0
            if a_date == b_date then
                return (a.id or 0) < (b.id or 0)
            end
            return a_date > b_date
        end)
        self.chats = list
    end

    function telegram:rebuild_archive_chats()
        local list = {}
        for _, chat in pairs(self.archive_chats_by_id) do
            if chat.chat_list and chat.chat_list["@type"] == "chatListArchive" then
                list[#list + 1] = chat
            end
        end
        table.sort(list, function(a, b)
            local a_date = a.last_message and a.last_message.date or 0
            local b_date = b.last_message and b.last_message.date or 0
            if a_date == b_date then
                return (a.id or 0) < (b.id or 0)
            end
            return a_date > b_date
        end)
        self.archive_chats = list
    end

    function telegram:rebuild_filter_chats()
        local lists = {}
        local function add(chat)
            if type(chat.positions) ~= "table" then return end
            local seen = {}
            for _, position in ipairs(chat.positions) do
                local list = position.list
                if list and list["@type"] == "chatListFilter" and list.chat_filter_id then
                    local id = list.chat_filter_id
                    if not seen[id] then
                        seen[id] = true
                        local bucket = lists[id]
                        if not bucket then
                            bucket = {}
                            lists[id] = bucket
                        end
                        bucket[#bucket + 1] = chat
                    end
                end
            end
        end
        for _, chat in pairs(self.chats_by_id) do add(chat) end
        for _, chat in pairs(self.archive_chats_by_id) do add(chat) end
        for _, bucket in pairs(lists) do
            table.sort(bucket, function(a, b)
                local a_date = a.last_message and a.last_message.date or 0
                local b_date = b.last_message and b.last_message.date or 0
                if a_date == b_date then
                    return (a.id or 0) < (b.id or 0)
                end
                return a_date > b_date
            end)
        end
        self.filter_chats = lists
    end

    function telegram:handle_chat_position(update)
        local chat = self.chats_by_id[update.chat_id] or self.archive_chats_by_id[update.chat_id]
        if not chat then return end
        local positions = {}
        local new_position = update.position
        local new_list = new_position and new_position.list
        local removed = new_position and (tonumber(new_position.order) or 0) == 0
        local function same_list(a, b)
            if not a or not b or a["@type"] ~= b["@type"] then return false end
            if a["@type"] == "chatListFilter" then
                return a.chat_filter_id == b.chat_filter_id
            end
            return true
        end
        for _, position in ipairs(chat.positions or {}) do
            if not same_list(position.list, new_list) then
                positions[#positions + 1] = position
            end
        end
        if new_position and not removed then
            positions[#positions + 1] = new_position
        end
        chat.positions = positions
        local list_type = new_list and new_list["@type"]
        if not removed and list_type == "chatListArchive" then
            chat.chat_list = {["@type"] = "chatListArchive"}
            self.chats_by_id[chat.id] = nil
            self.archive_chats_by_id[chat.id] = chat
        elseif not removed and list_type == "chatListMain" then
            chat.chat_list = {["@type"] = "chatListMain"}
            self.archive_chats_by_id[chat.id] = nil
            self.chats_by_id[chat.id] = chat
        end
        self:rebuild_chats()
        self:rebuild_archive_chats()
        self:rebuild_filter_chats()
    end

    function telegram:load_filter_chats(filter_id)
        filter_id = tonumber(filter_id)
        if not filter_id or self.filter_load_pending[filter_id] then return end
        self.filter_load_pending[filter_id] = true
        self:send({
            ["@type"] = "loadChats",
            chat_list = {["@type"] = "chatListFilter", chat_filter_id = filter_id},
        limit = 15,
    }, "loadFilterChats:" .. tostring(filter_id))
    end

    function telegram:load_archive_chats()
        if self.archive_loaded or self.archive_load_pending then
            return
        end
        self.archive_loaded = false
        self.archive_load_error = nil
        self:request_archive_chat_batch()
    end

    function telegram:request_archive_chat_batch()
        self.archive_load_pending = true
        self:send({
            ["@type"] = "loadChats",
            chat_list = {["@type"] = "chatListArchive"},
        limit = 15,
    }, "loadArchiveChats")
    end

    function telegram:search_chats(query)
        query = tostring(query or "")
        self.chat_search_generation = (self.chat_search_generation or 0) + 1
        self.chat_search_query = query
        self.search_chat_results = {}
        self.chat_search_error = nil
        if query == "" then return end
        self:send({
            ["@type"] = "searchChats",
            query = query,
            limit = 50,
        }, "chat_search:" .. tostring(self.chat_search_generation))
    end

    function telegram:search_public_chats(query)
        query = tostring(query or "")
        self.public_search_generation = (self.public_search_generation or 0) + 1
        local generation = self.public_search_generation
        self.public_search_query = query
        self.public_search_results = {}
        self.public_search_result_ids = {}
        self.public_search_detail_pending_ids = {}
        self.public_search_details_pending = 0
        self.public_search_error = nil
        self.public_search_user_pending = false
        self.public_search_pending = query ~= ""
        if query == "" then return end

        self:send({
            ["@type"] = "searchPublicChats",
            query = query,
        }, "public_search:" .. tostring(generation))

        local username = query:gsub("^@", "")
        if username:match("^[%w_]+$") and #username >= 5 and #username <= 32 then
            self.public_search_user_pending = true
            self:send({
                ["@type"] = "searchPublicChat",
                username = username,
            }, "public_user_search:" .. tostring(generation))
        end
    end

    function telegram:handle_public_search_chats(response)
        local generation = tonumber(tostring(response["@extra"] or ""):match("^public_search:(%d+)$"))
        if not generation or generation ~= self.public_search_generation then return end
        self.public_search_details_pending = 0
        self.public_search_detail_pending_ids = {}
        for _, chat_id in ipairs(response.chat_ids or {}) do
            local chat = self.chats_by_id[chat_id] or self.archive_chats_by_id[chat_id]
            if chat then
                if not self.public_search_result_ids[chat_id] then
                    self.public_search_results[#self.public_search_results + 1] = chat
                    self.public_search_result_ids[chat_id] = true
                end
            elseif not self.public_search_result_ids[chat_id] and not self.public_search_detail_pending_ids[chat_id] then
                self.public_search_detail_pending_ids[chat_id] = true
                self.public_search_details_pending = self.public_search_details_pending + 1
                self:send({
                    ["@type"] = "getChat",
                    chat_id = chat_id,
                }, "public_search_detail:" .. tostring(generation) .. ":" .. tostring(chat_id))
            end
        end
        self.public_search_pending = self.public_search_details_pending > 0
    end

    function telegram:handle_public_search_detail(chat)
        local generation, chat_id = tostring(chat["@extra"] or "")
            :match("^public_search_detail:(%d+):(%-?%d+)$")
        generation, chat_id = tonumber(generation), tonumber(chat_id)
        if not generation or generation ~= self.public_search_generation then return end
        if chat_id and self.public_search_detail_pending_ids[chat_id] then
            self.public_search_detail_pending_ids[chat_id] = nil
            self.public_search_details_pending = math.max(0, self.public_search_details_pending - 1)
            self.public_search_pending = self.public_search_details_pending > 0
        end
        if not chat_id or chat.id ~= chat_id then return end
        self.public_search_result_ids = self.public_search_result_ids or {}
        if self.public_search_result_ids[chat_id] then return end
        self.public_search_result_ids[chat_id] = true
        self.public_search_results[#self.public_search_results + 1] = chat
    end

    function telegram:handle_public_user_search(chat)
        local generation = tonumber(tostring(chat["@extra"] or ""):match("^public_user_search:(%d+)$"))
        if not generation or generation ~= self.public_search_generation then return end
        self.public_search_user_pending = false
        self.public_search_result_ids = self.public_search_result_ids or {}
        if not self.public_search_result_ids[chat.id] then
            self.public_search_result_ids[chat.id] = true
            self.public_search_results[#self.public_search_results + 1] = chat
        end
    end

    function telegram:handle_search_chats(response)
        local generation = tonumber(tostring(response["@extra"] or ""):match("^chat_search:(%d+)$"))
        if not generation or generation ~= self.chat_search_generation then return end
        local results = {}
        for _, chat_id in ipairs(response.chat_ids or {}) do
            local chat = self.chats_by_id[chat_id] or self.archive_chats_by_id[chat_id]
            if chat then
                results[#results + 1] = chat
            else
                self:send({
                    ["@type"] = "getChat",
                    chat_id = chat_id,
                }, "chat_search_detail:" .. tostring(generation) .. ":" .. tostring(chat_id))
            end
        end
        self.search_chat_results = results
    end

    function telegram:handle_search_chat_detail(chat)
        local extra = tostring(chat["@extra"] or "")
        local generation, chat_id = extra:match("^chat_search_detail:(%d+):(%-?%d+)$")
        generation, chat_id = tonumber(generation), tonumber(chat_id)
        if not generation or generation ~= self.chat_search_generation or not chat_id or chat.id ~= chat_id then
            return
        end
        local membership
        for _, position in ipairs(chat.positions or {}) do
            if position.list and position.list["@type"] then
                membership = position.list
                break
            end
        end
        self:handle_new_chat(chat, membership)
        self.search_chat_results[#self.search_chat_results + 1] = chat
    end

    function telegram:search_chat_messages(chat_id, query)
        if not chat_id then return end
        query = tostring(query or "")
        self.dialog_search_generation = self.dialog_search_generation or {}
        self.dialog_search_generation[chat_id] = (self.dialog_search_generation[chat_id] or 0) + 1
        self.dialog_search_query = self.dialog_search_query or {}
        self.dialog_search_results = self.dialog_search_results or {}
        self.dialog_search_error = nil
        self.dialog_search_query[chat_id] = query
        if query == "" then
            self.dialog_search_results[chat_id] = nil
            return
        end
        self.dialog_search_results[chat_id] = false
        self:send({
            ["@type"] = "searchChatMessages",
            chat_id = chat_id,
            query = query,
            sender_id = json.null,
            from_message_id = 0,
            offset = 0,
            limit = 50,
            filter = {["@type"] = "searchMessagesFilterEmpty"},
            message_thread_id = 0,
        }, "dialog_search:" .. tostring(chat_id) .. ":" .. tostring(self.dialog_search_generation[chat_id]))
    end

    function telegram:handle_dialog_search(response)
        local chat_id, generation = tostring(response["@extra"] or ""):match("^dialog_search:(%-?%d+):(%d+)$")
        chat_id, generation = tonumber(chat_id), tonumber(generation)
        if not chat_id or not generation or generation ~= (self.dialog_search_generation[chat_id] or 0) then
            return
        end
        local messages = response.messages or {}
        table.sort(messages, function(a, b)
            return (a.id or 0) < (b.id or 0)
        end)
        self.dialog_search_results[chat_id] = messages
        for _, message in ipairs(messages) do
            if message.sender_id and message.sender_id["@type"] == "messageSenderUser" then
                self:ensure_user(message.sender_id.user_id)
                self:ensure_user_photo(message.sender_id.user_id)
            end
            self:ensure_photo(message)
            self:ensure_sticker(message)
            self:ensure_animation(message)
            self:ensure_video(message)
            self:ensure_voice_note(message)
            self:ensure_audio(message)
            self:ensure_video_note(message)
        end
    end

    function telegram:archive_chat(chat_id, archive)
        if not chat_id then return false end
        self.action_error = ""
        self.action_status = archive and "Отправляю чат в архив..." or "Возвращаю чат из архива..."
        local chat = self.chats_by_id[chat_id] or self.archive_chats_by_id[chat_id]
        local target_list = {["@type"] = archive and "chatListArchive" or "chatListMain"}
        if chat then
            local previous_list = chat.chat_list
                or {["@type"] = self.archive_chats_by_id[chat_id] and "chatListArchive" or "chatListMain"}
            self.pending_archive_changes[chat_id] = {chat = chat, previous_list = previous_list}
            chat.chat_list = target_list
            self:handle_new_chat(chat, target_list)
        end
        self:send({
            ["@type"] = "addChatToList",
            chat_id = chat_id,
            chat_list = target_list,
        }, "archive:" .. tostring(chat_id) .. ":" .. tostring(archive))
        return true
    end

    function telegram:set_chat_muted(chat_id, muted)
        if not chat_id then return end
        self.action_error = ""
        self.action_status = muted and "Отключаю уведомления..." or "Включаю уведомления..."
        local notification_settings = {
            ["@type"] = "chatNotificationSettings",
            use_default_mute_for = false,
            mute_for = muted and 2147483647 or 0,
            use_default_sound = true,
            sound = "",
            use_default_show_preview = true,
            show_preview = true,
            use_default_disable_pinned_message_notifications = true,
            disable_pinned_message_notifications = false,
            use_default_disable_mention_notifications = true,
            disable_mention_notifications = false,
        }
        local chat = self.chats_by_id[chat_id] or self.archive_chats_by_id[chat_id]
        self.pending_chat_mute_settings[chat_id] = chat and chat.notification_settings or false
        if chat then chat.notification_settings = notification_settings end
        self:send({
            ["@type"] = "setChatNotificationSettings",
            chat_id = chat_id,
            notification_settings = notification_settings,
        }, "mute:" .. tostring(chat_id) .. ":" .. tostring(muted))
    end

    function telegram:load_profile_media(chat_id, category)
        local filters = {
            photos = "searchMessagesFilterPhoto",
            videos = "searchMessagesFilterVideo",
            files = "searchMessagesFilterDocument",
            links = "searchMessagesFilterUrl",
            music = "searchMessagesFilterAudio",
            voice = "searchMessagesFilterVoiceAndVideoNote",
        }
        local filter = filters[category]
        if not chat_id or not filter then return end
        self.profile_media[category] = self.profile_media[category] or {}
        self.profile_media[category][chat_id] = {loading = true, messages = {}}
        self:send({
            ["@type"] = "searchChatMessages",
            chat_id = chat_id,
            query = "",
            sender_id = json.null,
            from_message_id = 0,
            offset = 0,
            limit = 30,
            filter = {["@type"] = filter},
            message_thread_id = 0,
        }, "profile_media:" .. tostring(chat_id) .. ":" .. category)
    end

    function telegram:handle_profile_media(response)
        local extra = tostring(response["@extra"] or "")
        local chat_id, category = extra:match("^profile_media:(%-?%d+):([%w_]+)$")
        chat_id = tonumber(chat_id)
        if not chat_id or not category then return end
        self.profile_media[category] = self.profile_media[category] or {}
        local messages = response.messages or {}
        self.profile_media[category][chat_id] = {
            loading = false,
            total_count = tonumber(response.total_count) or #messages,
            messages = messages,
        }
        for _, message in ipairs(messages) do
            self:ensure_photo(message)
            if message.sender_id and message.sender_id["@type"] == "messageSenderUser" then
                self:ensure_user(message.sender_id.user_id)
                self:ensure_user_photo(message.sender_id.user_id)
            end
        end
    end

end
