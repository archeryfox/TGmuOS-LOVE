local json = require("dkjson")

local function log_to_file(self, message)
    local path = self.log_path or "log.txt"
    local handle = io.open(path, "a")
    if handle then
        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
        handle:write(string.format("[%s] %s\n", timestamp, message))
        handle:close()
    end
end

local telegram = {}
telegram.__index = telegram
require("src.shared.api.chat_methods")(telegram)
require("src.shared.api.message_methods")(telegram)
require("src.shared.api.media_methods")(telegram)
require("src.shared.api.media_avatars")(telegram)
require("src.shared.api.media_playback")(telegram)

function telegram.new()
    local self = setmetatable({}, telegram)
    self.worker = nil
    self.in_channel = love.thread.getChannel("td_in")
    self.out_channel = love.thread.getChannel("td_out")
    self.anim_in = love.thread.getChannel("anim_in")
    self.anim_out = love.thread.getChannel("anim_out")
    self.sequence = 0

    self.auth_state = "starting"
    self.ready = false
    self.closed = false
    self.qr_link = ""
    self.qr_requested_at = 0
    self.qr_request_pending = false
    self.qr_conflict = false
    self.password_hint = ""
    self.auth_error = ""
    self.action_status = ""
    self.action_error = ""
    self.proxy_added = false
    self.proxy_ready = false
    self.proxy_flat = false
    self.tdlib_parameters_nested = false
    self.encryption_key_sent = false

    self.me = nil
    self.users = {}
    self.requested_users = {}
    self.chats = {}
    self.chats_by_id = {}
    self.chats_loaded = false
    self.archive_chats = {}
    self.archive_chats_by_id = {}
    self.archive_loaded = false
    self.archive_load_pending = false
    self.archive_load_error = nil
    self.pending_archive_changes = {}
    self.profile_media = {}
    self.pending_chat_mute_settings = {}
    self.chat_search_generation = 0
    self.chat_search_query = ""
    self.search_chat_results = {}
    self.public_search_generation = 0
    self.public_search_query = ""
    self.public_search_results = {}
    self.public_search_result_ids = {}
    self.public_search_detail_pending_ids = {}
    self.public_search_details_pending = 0
    self.public_search_user_pending = false
    self.public_search_pending = false
    self.public_search_error = nil
    self.dialog_search_generation = {}
    self.dialog_search_query = {}
    self.dialog_search_results = {}
    self.chat_filters = {}
    self.filter_chats = {}
    self.filter_load_pending = {}
    self.messages = {}
    self.history_state = {}
    self.current_chat_id = nil
    self.viewed_message_ids = {}
    self.typing_sent_at = {}
    self.photos = {}
    self.photo_by_message = {}
    self.stickers = {}
    self.sticker_by_message = {}
    self.sticker_thumbnail_by_file = {}
    self.sticker_thumbnail_for_file = {}
    self.sticker_format_by_file = {}
    self.media_preview_by_file = {}
    self.sticker_set_generation = 0
    self.sticker_set_viewer = nil
    self.animations = {}
    self.animation_by_message = {}
    self.videos = {}
    self.video_by_message = {}
    self.voice_notes = {}
    self.voice_by_message = {}
    self.audios = {}
    self.audio_by_message = {}
    self.user_photos = {}
    self.user_photo_by_id = {}
    self.chat_photos = {}
    self.chat_photo_by_id = {}
        self.notifications = {}
        self.notifications_enabled = false

    self.on_ready = nil
    self.proxy_wait_start = nil
    return self
end

function telegram:user_status_text(user_id)
    if not user_id then return "" end
    self:ensure_user(user_id)
    local user = self.users[user_id]
    local status = user and user.status
    local kind = status and status["@type"]
    if kind == "userStatusOnline" then
        if (tonumber(status.expires) or 0) > os.time() then return "в сети" end
        return "недавно был(а) в сети"
    elseif kind == "userStatusOffline" then
        local was_online = tonumber(status.was_online) or 0
        if was_online > 0 then
            return "был(а) в сети " .. os.date("%d.%m %H:%M", was_online)
        end
    elseif kind == "userStatusRecently" then
        return "был(а) в сети недавно"
    elseif kind == "userStatusLastWeek" then
        return "был(а) в сети на этой неделе"
    elseif kind == "userStatusLastMonth" then
        return "был(а) в сети в этом месяце"
    elseif kind == "userStatusEmpty" then
        return "давно не был(а) в сети"
    end
    return "статус не указан"
end

function telegram:start(options)
    self.in_channel:clear()
    self.out_channel:clear()
    self.encryption_key_sent = false
    self.closed = false
    self.ready = false
    self.auth_state = "starting"
    self.qr_link = ""
    self.qr_request_pending = false
    self.qr_requested_at = 0
    self.proxy_confirmed = false
    self.worker = love.thread.newThread("threads/tdlib_worker.lua")
    self.worker:start()
    self.in_channel:push({
        type = "init",
        lib = options.lib,
        db = options.db,
        files = options.files,
        log = options.log,
    })
    self.options = options
    -- Add proxy IMMEDIATELY after worker init, before ANY TDLib requests
    if options.proxy and not self.proxy_added then
        self.proxy_added = true
        log_to_file(self, "TDLib: adding proxy...")
        self:add_proxy(options.proxy)
        log_to_file(self, "TDLib: proxy added, waiting for confirmation...")
        self.proxy_wait_start = love.timer.getTime()
    end
end

function telegram:send(request, extra)
    if request and request["@type"] == "downloadFile" then
        self.active_downloads = (self.active_downloads or 0) + 1
    end
    self.sequence = self.sequence + 1
    request["@extra"] = extra or ("req:" .. tostring(self.sequence))
    local encoded = json.encode(request)
    if encoded then
        self.in_channel:push({type = "send", req = encoded})
    end
    return request["@extra"]
end

function telegram:open_private_chat(user_id)
    self:send({
        ["@type"] = "createPrivateChat",
        user_id = user_id,
    }, "open_private_chat:" .. tostring(user_id))
end

function telegram:shutdown()
    if self.anim_in then
        self.anim_in:push({type = "quit"})
    end
    if self.anim_worker then
        pcall(self.anim_worker.wait, self.anim_worker, 1)
        self.anim_worker = nil
    end
    if not self.worker then
        return true
    end
    if not self.closed then
        self.in_channel:push({
            type = "send",
            req = json.encode({["@type"] = "close", ["@extra"] = "close"}),
        })
        local deadline = love.timer.getTime() + 2
        while not self.closed and love.timer.getTime() < deadline do
            self:poll()
            if not self.closed then love.timer.sleep(0.01) end
        end
        if not self.closed then
            return false, "TDLib did not confirm shutdown"
        end
    end
    self.in_channel:push({type = "quit"})
    local wait_ok, wait_error = pcall(self.worker.wait, self.worker)
    if not wait_ok then
        return false, tostring(wait_error)
    end
    local running_ok, running = pcall(self.worker.isRunning, self.worker)
    if running_ok and running then
        return false, "TDLib worker is still running"
    end
    self.worker = nil
    return true
end

function telegram:reset_account_state()
    for _, media in pairs({self.voice_notes, self.audios, self.videos, self.animations, self.stickers}) do
        for _, entry in pairs(media) do
            if entry.audio_source then pcall(entry.audio_source.stop, entry.audio_source) end
        end
    end
    self.me = nil
    self.users = {}
    self.requested_users = {}
    self.chats = {}
    self.chats_by_id = {}
    self.chats_loaded = false
    self.archive_chats = {}
    self.archive_chats_by_id = {}
    self.archive_loaded = false
    self.archive_load_pending = false
    self.archive_load_error = nil
    self.pending_archive_changes = {}
    self.profile_media = {}
    self.messages = {}
    self.history_state = {}
    self.current_chat_id = nil
    self.viewed_message_ids = {}
    self.typing_sent_at = {}
    self.photos = {}
    self.photo_by_message = {}
    self.stickers = {}
    self.sticker_by_message = {}
    self.sticker_thumbnail_by_file = {}
    self.sticker_thumbnail_for_file = {}
    self.sticker_format_by_file = {}
    self.media_preview_by_file = {}
    self.sticker_set_generation = 0
    self.sticker_set_viewer = nil
    self.animations = {}
    self.animation_by_message = {}
    self.videos = {}
    self.video_by_message = {}
    self.voice_notes = {}
    self.voice_by_message = {}
    self.audios = {}
    self.audio_by_message = {}
    self.user_photos = {}
    self.user_photo_by_id = {}
    self.chat_photos = {}
    self.chat_photo_by_id = {}
    self.pending_chat_mute_settings = {}
    self.chat_search_generation = 0
    self.chat_search_query = ""
    self.search_chat_results = {}
    self.public_search_generation = 0
    self.public_search_query = ""
    self.public_search_results = {}
    self.public_search_result_ids = {}
    self.public_search_detail_pending_ids = {}
    self.public_search_details_pending = 0
    self.public_search_user_pending = false
    self.public_search_pending = false
    self.public_search_error = nil
    self.dialog_search_generation = {}
    self.dialog_search_query = {}
    self.dialog_search_results = {}
    self.chat_filters = {}
    self.filter_chats = {}
    self.filter_load_pending = {}
    self.encryption_key_sent = false
    self.qr_link = ""
    self.qr_request_pending = false
    self.qr_conflict = false
    self.qr_requested_at = 0
    self.password_hint = ""
        self.notifications = {}
        self.notifications_enabled = false
end

function telegram:log_out()
    if not self.worker or not self.ready then
        self.action_error = "Нет активной авторизованной сессии"
        return false
    end
    self.action_error = ""
    self.action_status = "Выхожу из аккаунта..."
    self.logout_pending = true
    log_to_file(self, "TDLib: sending logOut request")
    self:send({["@type"] = "logOut"}, "log_out")
    return true
end

function telegram:request_qr()
    local now = love.timer.getTime()
    if self.qr_request_pending and now - self.qr_requested_at < 30 then
        return false
    end
    self.qr_request_pending = true
    self.qr_requested_at = love.timer.getTime()
    log_to_file(self, "TDLib: sending requestQrCodeAuthentication")
    self:send({
        ["@type"] = "requestQrCodeAuthentication",
        other_user_ids = {},
    }, "qr")
    return true
end

function telegram:push_notification(notice)
    if not self.notifications_enabled then return end
    self.notifications = self.notifications or {}
    self.active_downloads = self.active_downloads or 0
    self.max_concurrent_downloads = 3
    self.download_queue = self.download_queue or {}
    for index = #self.notifications, 1, -1 do
        if self.notifications[index].chat_id == notice.chat_id then
            table.remove(self.notifications, index)
        end
    end
    table.insert(self.notifications, 1, notice)
    while #self.notifications > 3 do
        table.remove(self.notifications)
    end
    -- Play notification sound
    pcall(function()
        if not self._notification_sound then
            local sample_rate = 44100
            local duration = 0.3
            local samples = sample_rate * duration
            local sound_data = love.sound.newSoundData(samples, sample_rate, 16, 1)
            for i = 0, samples - 1 do
                local t = i / sample_rate
                local decay = math.exp(-t * 8)
                local wave1 = math.sin(2 * math.pi * 523.25 * t) * 0.3
                local wave2 = math.sin(2 * math.pi * 659.25 * t) * 0.2
                local wave3 = math.sin(2 * math.pi * 783.99 * t) * 0.15
                local value = (wave1 + wave2 + wave3) * decay * 0.5
                sound_data:setSample(i, value)
            end
            self._notification_sound = love.audio.newSource(sound_data, "static")
        end
        if self._notification_sound then
            self._notification_sound:stop()
            self._notification_sound:play()
        end
    end)
end

function telegram:is_chat_muted(chat)
    local settings = chat and chat.notification_settings or {}
    return (tonumber(settings.mute_for) or 0) > 0
end

function telegram:update(dt)
    self:poll()
    -- Proxy confirmation waits asynchronously (non-blocking)
    if self.proxy_wait_start and not self.proxy_confirmed then
        if love.timer.getTime() - self.proxy_wait_start >= 2 then
            -- Fallback: force-confirm proxy after 2s if TDLib hasn't responded
            self.proxy_confirmed = true
            self.proxy_ready = true
            self.auth_error = ""
            self.proxy_wait_start = nil
            log_to_file(self, "TDLib: proxy confirmed via fallback (2s)")
        end
    end
    self:poll_media_decoder()
    local now = love.timer.getTime()
    for index = #self.notifications, 1, -1 do
        local notice = self.notifications[index]
        if not notice or now - (notice.created or now) >= 15 then
            table.remove(self.notifications, index)
        end
    end
    for _, entry in pairs(self.voice_notes) do
        if entry.playing and entry.audio_source then
            local ok, is_playing = pcall(entry.audio_source.isPlaying, entry.audio_source)
            if ok and not is_playing then
                entry.playing = false
                entry.autoplay = false
            end
        end
    end
    for _, entry in pairs(self.audios) do
        if entry.playing and entry.audio_source then
            local ok, is_playing = pcall(entry.audio_source.isPlaying, entry.audio_source)
            if ok and not is_playing then
                entry.playing = false
                entry.autoplay = false
            end
        end
    end
    for _, entry in pairs(self.videos) do
        if entry.playing and entry.audio_source then
            local ok, is_playing = pcall(entry.audio_source.isPlaying, entry.audio_source)
            if ok and not is_playing then
                entry.playing = false
                entry.autoplay = false
            end
        end
    end
    if self.auth_state == "authorizationStateWaitPhoneNumber" then
        local has_proxy = self.options and self.options.proxy
        if not has_proxy or self.proxy_ready then
            if self.qr_conflict and love.timer.getTime() - self.qr_requested_at >= 120 then
                self.qr_conflict = false
                self.qr_request_pending = false
            end
        end
    end
end

function telegram:poll()
    for _ = 1, 200 do
        local raw = self.out_channel:pop()
        if not raw then
            break
        end
        local ok, object = pcall(json.decode, raw)
        if ok and type(object) == "table" then
            self:handle(object)
        end
    end
end

function telegram:handle(object)
    local kind = object["@type"]
    if kind == "love_log" then
        log_to_file(self, "worker: " .. tostring(object.message))
        return
    end


    if kind == "updateAuthorizationState" then
        self:handle_authorization(object.authorization_state or {})
    elseif kind == "updateNewChat" then
        self:handle_new_chat(object.chat)
    elseif kind == "updateChatPhoto" then
        local chat = self.chats_by_id[object.chat_id] or self.archive_chats_by_id[object.chat_id]
        if chat then
            chat.photo = object.photo
            self.chat_photo_by_id[object.chat_id] = nil
            self:ensure_chat_photo(object.chat_id)
        end
    elseif kind == "updateChatChatList" then
        local chat = self.chats_by_id[object.chat_id] or self.archive_chats_by_id[object.chat_id]
        if chat then
            chat.chat_list = object.chat_list
            self:handle_new_chat(chat, object.chat_list)
            self.pending_archive_changes[object.chat_id] = nil
            self.action_status = "Список чатов обновлён"
        end
    elseif kind == "updateChatPosition" then
        self:handle_chat_position(object)
    elseif kind == "updateChatFilters" then
        self.chat_filters = object.chat_filters or {}
    elseif kind == "updateChatNotificationSettings" then
        local chat = self.chats_by_id[object.chat_id] or self.archive_chats_by_id[object.chat_id]
        if chat then chat.notification_settings = object.notification_settings end
        self.pending_chat_mute_settings[object.chat_id] = nil
    elseif kind == "updateUserStatus" then
        local user = self.users[object.user_id]
        if user then user.status = object.status end
    elseif kind == "updateChatLastMessage" then
        self:handle_chat_last_message(object)
    elseif kind == "updateChatTitle" then
        local chat = self.chats_by_id[object.chat_id] or self.archive_chats_by_id[object.chat_id]
        if chat then
            chat.title = object.title
            self:rebuild_chats()
        end
    elseif kind == "updateChatReadInbox" then
        local chat = self.chats_by_id[object.chat_id] or self.archive_chats_by_id[object.chat_id]
        if chat then
            chat.unread_count = object.unread_count or 0
        end
    elseif kind == "updateNewMessage" then
        self:handle_new_message(object.message)
    elseif kind == "updateMessageSendSucceeded" then
        self:handle_send_succeeded(object)
    elseif kind == "updateMessageContent" then
        self:handle_message_content(object)
    elseif kind == "updateMessageIsPinned" then
        for _, message in ipairs(self.messages[object.chat_id] or {}) do
            if message.id == object.message_id then
                message.is_pinned = object.is_pinned
                break
            end
        end
    elseif kind == "updateMessageInteractionInfo" then
        self:handle_message_interaction_info(object)
    elseif kind == "updateFile" then
        self:handle_file(object.file)
    elseif kind == "file" then
        self:handle_file(object)
    elseif kind == "updateDeleteMessages" then
        self:handle_delete_messages(object)
    elseif kind == "proxy" then
        log_to_file(self, "handle: received proxy update, extra=" .. tostring(object["@extra"]))
        if object["@extra"] == "proxy" then
            self.proxy_ready = true
            self.proxy_confirmed = true
            self.auth_error = ""
            log_to_file(self, "TDLib: proxy ready (proxy update)")
            if self.auth_state == "authorizationStateWaitPhoneNumber" then
                self:request_qr()
            end
        end
    elseif kind == "ok" then
        local retry_kind, retry_id = tostring(object["@extra"] or ""):match("^media_retry_delete:([%w_]+):(%-?%d+)$")
        if retry_kind then
            local fid = tonumber(retry_id)
            local entry = self:media_entry(retry_kind, fid)
            if entry then
                entry.status = "downloading"
                entry.decode_retries = (entry.decode_retries or 0)
                log_to_file(self, string.format("MEDIA: retry download %s id=%s", retry_kind, retry_id))
                self:send({
                    ["@type"] = "downloadFile",
                    file_id = fid,
                    priority = 8,
                    offset = 0,
                    limit = 0,
                    synchronous = false,
                }, "retry_dl:" .. retry_kind .. ":" .. retry_id)
            end
        end
        if object["@extra"] == "proxy" then
            self.proxy_ready = true
            self.proxy_confirmed = true
            self.auth_error = ""
            log_to_file(self, "TDLib: proxy ready (ok response)")
            if self.auth_state == "authorizationStateWaitPhoneNumber" then
                self:request_qr()
            end
        elseif object["@extra"] == "loadChats" then
            self.chats_loaded = true
        elseif object["@extra"] == "loadArchiveChats" then
            self.archive_load_pending = false
            self:request_archive_chat_batch()
        elseif tostring(object["@extra"] or ""):match("^loadFilterChats:") then
            local filter_id = tonumber(tostring(object["@extra"]):match("^loadFilterChats:(%-?%d+)$"))
            if filter_id then self.filter_load_pending[filter_id] = nil end
        elseif tostring(object["@extra"] or ""):match("^archive:") then
            self.action_error = ""
            self.action_status = "Действие выполнено"
            local chat_id = tonumber(tostring(object["@extra"]):match("^archive:(%-?%d+):"))
            if chat_id then self.pending_archive_changes[chat_id] = nil end
        elseif tostring(object["@extra"] or ""):match("^mute:") then
            self.action_error = ""
            self.action_status = "Настройки уведомлений изменены"
            local chat_id = tostring(object["@extra"]):match("^mute:(%-?%d+):")
            if chat_id then self.pending_chat_mute_settings[tonumber(chat_id)] = nil end
        elseif object["@extra"] == "log_out" then
            self.action_error = ""
            self.auth_error = ""
            self.action_status = "Ожидается авторизация..."
        end
    elseif kind == "user" then
        self:handle_user(object)
    elseif kind == "messages" then
        local extra = object["@extra"] or ""
        if extra:match("^profile_media:") then
            self:handle_profile_media(object)
        elseif extra:match("^forward:") then
            self.action_error = ""
            self.action_status = "Сообщения пересланы"
        elseif extra:match("^dialog_search:") then
            self:handle_dialog_search(object)
        else
            self:handle_history(object)
        end
    elseif kind == "chats" then
        local extra = tostring(object["@extra"] or "")
        if extra:match("^public_search:") then
            self:handle_public_search_chats(object)
        else
            self:handle_search_chats(object)
        end
    elseif kind == "chat" then
        local extra = tostring(object["@extra"] or "")
        if extra:match("^public_search_detail:") then
            self:handle_public_search_detail(object)
        elseif extra:match("^public_user_search:") then
            self:handle_public_user_search(object)
        elseif extra:match("^chat_search_detail:") then
            self:handle_search_chat_detail(object)
        else
            self:handle_new_chat(object)
        end
    elseif kind == "stickerSet" then
        self:handle_sticker_set(object)
    elseif kind == "stickerSets" then
        local extra = tostring(object["@extra"] or "")
        if extra == "installed_sticker_sets" then
            self.installed_sticker_sets = object.sets or object.sticker_sets or {}
        end
    elseif kind == "message" then
        local extra = tostring(object["@extra"] or "")
        if extra:match("^msgprobe:") then
            local pcall_ok, dump = pcall(function()
                local dkjson = require("dkjson")
                return dkjson.encode(object.content or {})
            end)
            log_to_file(self, string.format("MSGPROBE extra=%s content=%s", extra, tostring(dump or "encode-fail")))
        end
        if tostring(object["@extra"] or ""):match("^edit:") then
            self.action_error = ""
            self.action_status = "Сообщение изменено"
        end
        self:handle_new_message(object)
    elseif kind == "error" then
        local message = tostring(object.message or "TDLib error")
        local extra = tostring(object["@extra"] or "")
        log_to_file(self, string.format("TDLib error: code=%s extra=%s message=%s", tostring(object.code), extra, message))
        local qr_query_in_progress = extra == "qr"
            and message:find("Another authorization query has started", 1, true) ~= nil
        if object.code == 400 and extra == "tdlib_params"
            and not self.tdlib_parameters_nested
            and message:find("Parameters aren't specified", 1, true) then
            self.tdlib_parameters_nested = true
            self:send_tdlib_parameters()
            return
        end
        if object.code == 400 and extra == "proxy"
            and not self.proxy_flat
            and message:find("Proxy type must be non-empty", 1, true) then
            self.proxy_flat = true
            log_to_file(self, "TDLib: retrying addProxy with flat schema")
            if self.options and self.options.proxy then
                self:add_proxy(self.options.proxy)
            end
            return
        end
        local history_chat_id = tonumber(extra:match("^history_more:(%-?%d+):"))
            or tonumber(extra:match("^history:(%-?%d+)$"))
        if history_chat_id then
            local state = self.history_state[history_chat_id]
            if state then
                state.loading = false
                state.error = message
            end
        elseif extra:match("^profile_media:") then
            local chat_id, category = extra:match("^profile_media:(%-?%d+):([%w_]+)$")
            chat_id = tonumber(chat_id)
            self.profile_media[category] = self.profile_media[category] or {}
            self.profile_media[category][chat_id] = {loading = false, messages = {}, error = message}
        elseif extra:match("^chat_search:") then
            local generation = tonumber(extra:match("^chat_search:(%d+)$"))
            if generation == self.chat_search_generation then
                self.chat_search_error = message
                self.search_chat_results = {}
            end
        elseif extra:match("^public_search_detail:") then
            local generation, chat_id = extra:match("^public_search_detail:(%d+):(%-?%d+)$")
            generation, chat_id = tonumber(generation), tonumber(chat_id)
            if generation == self.public_search_generation and self.public_search_detail_pending_ids[chat_id] then
                self.public_search_detail_pending_ids[chat_id] = nil
                self.public_search_details_pending = math.max(0, self.public_search_details_pending - 1)
                self.public_search_pending = self.public_search_details_pending > 0
            end
        elseif extra:match("^sticker_set:") then
            local generation = tonumber(extra:match("^sticker_set:(%d+):"))
            if generation and generation == self.sticker_set_generation and self.sticker_set_viewer then
                self.sticker_set_viewer.loading = false
                self.sticker_set_viewer.error = message
            end
        elseif extra:match("^sticker_thumbnail:") or extra:match("^sticker:") then
            local file_id = tonumber(extra:match(":(%d+)$"))
            local entry = file_id and self.stickers[file_id]
            if entry then
                entry.status = "error"
                entry.download_requested = nil
                entry.download_error = message
            end
        elseif extra:match("^public_search:") then
            local generation = tonumber(extra:match(":(%d+)$"))
            if generation == self.public_search_generation then
                self.public_search_error = message
                self.public_search_pending = false
                self.public_search_results = {}
            end
        elseif extra:match("^public_user_search:") then
            local generation = tonumber(extra:match(":(%d+)$"))
            if generation == self.public_search_generation then
                self.public_search_user_pending = false
                if message ~= "USERNAME_NOT_OCCUPIED" and message ~= "USERNAME_INVALID" then
                    self.public_search_error = message
                end
            end
        elseif extra:match("^dialog_search:") then
            local chat_id = tonumber(extra:match("^dialog_search:(%-?%d+):"))
            if chat_id and self.dialog_search_generation[chat_id] then
                self.dialog_search_results[chat_id] = {}
                self.dialog_search_error = message
            end
        elseif extra:match("^audio:") then
            local file_id = tonumber(extra:match("^audio:(%d+)$"))
            local entry = file_id and self.audios[file_id]
            if entry then
                entry.status = "error"
                entry.audio_error = message
                entry.autoplay = false
            end
        elseif extra:match("^edit:") then
            self.action_error = message
            self.action_status = ""
        elseif extra == "log_out" then
            self.logout_pending = false
            self.action_error = message
            self.action_status = ""
        elseif extra == "qr" then
            if qr_query_in_progress then
                self.qr_request_pending = true
                self.qr_requested_at = love.timer.getTime()
                self.qr_conflict = true
                self.auth_error = ""
            else
                self.qr_request_pending = false
                self.qr_conflict = false
                self.action_error = message
            end
        elseif extra:match("^archive:") then
            self.action_error = message
            self.action_status = ""
            local chat_id = tonumber(extra:match("^archive:(%-?%d+):"))
            local change = chat_id and self.pending_archive_changes[chat_id]
            if change then
                local chat = change.chat
                chat.chat_list = change.previous_list
                self.pending_archive_changes[chat_id] = nil
                self:handle_new_chat(chat, change.previous_list)
            end
        elseif extra:match("^forward:") or extra:match("^mute:") then
            self.action_error = message
            self.action_status = ""
            local chat_id = tonumber(extra:match("^mute:(%-?%d+):"))
            if chat_id then
                local chat = self.chats_by_id[chat_id] or self.archive_chats_by_id[chat_id]
                local previous = self.pending_chat_mute_settings[chat_id]
                if chat and previous ~= nil then
                    chat.notification_settings = previous ~= false and previous or nil
                end
                self.pending_chat_mute_settings[chat_id] = nil
            end
        end
        if object.code == 401 then
            log_to_file(self, string.format("TDLib 401 unauthorized: extra=%s message=%s", tostring(object["@extra"] or ""), message))
            if self.auth_state ~= "authorizationStateWaitPhoneNumber" and not self.logout_pending then
                self.auth_error = message
            end
        elseif object["@extra"] == "loadChats" then
            self.chats_loaded = true
            if object.code ~= 404 then
                self.auth_error = message
            end
        elseif object["@extra"] == "loadArchiveChats" then
            self.archive_load_pending = false
            self.archive_loaded = true
            if object.code == 404 then
                self.archive_load_error = nil
            else
                self.archive_load_error = message
                self.auth_error = message
            end
        elseif tostring(object["@extra"] or ""):match("^loadFilterChats:") then
            local filter_id = tonumber(tostring(object["@extra"]):match("^loadFilterChats:(%-?%d+)$"))
            if filter_id then self.filter_load_pending[filter_id] = nil end
        elseif not qr_query_in_progress and (object["@extra"] == "me" or object["@extra"] == "qr"
            or object["@extra"] == "tdlib_params" or object["@extra"] == "password"
            or object["@extra"] == "proxy" or object["@extra"] == "encryption_key") then
            self.auth_error = message
        end
    elseif kind == "love_error" then
        self.auth_error = tostring(object.message or "TDLib worker error")
    end
end

function telegram:handle_file(file)
    if type(file) ~= "table" then return end
    local file_id = tonumber(file.id)
    if not file_id and type(file.file) == "table" then file_id = tonumber(file.file.id) end
    if not file_id then return end
    local kind, entry
    if self.user_photos[file_id] then
        kind, entry = "user_photo", self.user_photos[file_id]
    elseif self.chat_photos[file_id] then
        kind, entry = "chat_photo", self.chat_photos[file_id]
    elseif self.photos[file_id] then
        kind, entry = "photo", self.photos[file_id]
    elseif self.stickers[file_id] then
        kind, entry = "sticker", self.stickers[file_id]
    elseif self.animations[file_id] then
        kind, entry = "animation", self.animations[file_id]
    elseif self.videos[file_id] then
        kind, entry = "video", self.videos[file_id]
    elseif self.video_notes[file_id] then
        kind, entry = "video_note", self.video_notes[file_id]
    elseif self.voice_notes[file_id] then
        kind, entry = "voice", self.voice_notes[file_id]
    elseif self.audios[file_id] then
        kind, entry = "audio", self.audios[file_id]
    end
    if not entry then
    if file and file["@type"] == "file" then
        self.active_downloads = math.max(0, (self.active_downloads or 0) - 1)
    end
        local file_local0 = file["local"] or {}
        if file_local0.is_downloading_completed and file_local0.path and file_local0.path ~= "" then
            local preview = self.media_preview_by_file and self.media_preview_by_file[file_id]
            log_to_file(self, string.format("THUMB DONE: id=%s kind=%s", file_id, preview and preview.kind or "?"))
            if preview then
                self.media_preview_by_file[file_id] = nil
                local storage = self[preview.storage]
                if storage then
                    self:load_image(preview.owner, file_local0.path, storage)
                end
            end
        end
        return
    end
    if file and file["@type"] == "file" then
        self.active_downloads = math.max(0, (self.active_downloads or 0) - 1)
    end
    local file_local = file["local"] or {}
    if file_local.is_downloading_active then
        entry.status = "downloading"
    end
    log_to_file(self, string.format("FILE: %s id=%s active=%s done=%s", kind, file_id,
        tostring(file_local.is_downloading_active), tostring(file_local.is_downloading_completed)))
    local total_bytes = tonumber(file.size)
    if not total_bytes or total_bytes <= 0 then
        total_bytes = tonumber(file.expected_size)
    end
    if total_bytes and total_bytes > 0 then
        entry.total_bytes = total_bytes
    end
    local downloaded_size = tonumber(file_local.downloaded_size) or 0
    local downloaded_prefix = tonumber(file_local.downloaded_prefix_size) or 0
    entry.downloaded_bytes = math.max(downloaded_size, downloaded_prefix, entry.downloaded_bytes or 0)
    if entry.total_bytes and entry.total_bytes > 0 then
        entry.download_progress = math.min(1, entry.downloaded_bytes / entry.total_bytes)
    end
    if file_local.is_downloading_completed and file_local.path and file_local.path ~= "" then
        entry.downloaded_bytes = entry.total_bytes and entry.total_bytes > 0 and entry.total_bytes or entry.downloaded_bytes
        entry.download_progress = 1
        entry.source_path = file_local.path
        log_to_file(self, string.format("FILE DONE: %s id=%s path=%s", kind, file_id, file_local.path))
        if kind == "photo" then
            self:load_photo(file_id, file_local.path)
        elseif kind == "sticker" then
            if self.sticker_thumbnail_by_file[file_id] then
                self:load_sticker_thumbnail(file_id, file_local.path, self.sticker_thumbnail_by_file[file_id])
            else
                self:load_sticker(file_id, file_local.path)
            end
        elseif kind == "animation" then
            self:load_animation(file_id, file_local.path)
        elseif kind == "video" then
            self:load_video(file_id, file_local.path)
        elseif kind == "video_note" then
            self:load_video_note(file_id, file_local.path)
        elseif kind == "voice" then
            self:load_voice_note(file_id, file_local.path)
        elseif kind == "audio" then
            self:load_audio(file_id, file_local.path)
        elseif kind == "user_photo" then
            self:load_user_photo(file_id, file_local.path)
        elseif kind == "chat_photo" then
            self:load_chat_photo(file_id, file_local.path)
        end
        if entry.autoplay then
            if kind == "video" then
                self:queue_media_decode("video", file_id, file_local.path)
            elseif kind == "video_note" then
                self:queue_media_decode("video_note", file_id, file_local.path, false)
            elseif kind == "voice" then
                self:queue_audio_decode("voice", file_id, file_local.path, entry.duration)
            elseif kind == "audio" then
                self:queue_audio_decode("audio", file_id, file_local.path, entry.duration)
            elseif kind == "animation" then
                self:queue_media_decode("animation", file_id, file_local.path)
            elseif kind == "sticker"
                and (self.sticker_format_by_file[file_id] == "stickerFormatWebm"
                or self.sticker_format_by_file[file_id] == "stickerFormatTgs") then
                self:queue_media_decode("sticker", file_id, file_local.path)
            end
        end
    elseif file_local.is_downloading_active then
        entry.status = "downloading"
    end
end

function telegram:open_sticker_set(message)
    local content = message and message.content
    if not content or content["@type"] ~= "messageSticker" then
        return false
    end
    local sticker = content.sticker
    local set_id = sticker and sticker.set_id
    if not set_id then
        return false
    end
    self.sticker_set_generation = self.sticker_set_generation + 1
    local gen = self.sticker_set_generation
    self.sticker_set_viewer = {loading = true, error = nil, stickers = {}, title = sticker.set_name or ""}
    self:send({
        ["@type"] = "getStickerSet",
        sticker_set_id = set_id,
    }, "sticker_set:" .. tostring(gen) .. ":" .. tostring(set_id))
    return true
end

function telegram:open_sticker_set_by_name(name)
    if not name or name == "" then
        return false
    end
    self.sticker_set_generation = self.sticker_set_generation + 1
    local gen = self.sticker_set_generation
    self.sticker_set_viewer = {loading = true, error = nil, stickers = {}, title = name}
    self:send({
        ["@type"] = "searchStickerSet",
        name = name,
    }, "sticker_set:" .. tostring(gen) .. ":name:" .. name)
    return true
end

function telegram:load_installed_sticker_sets()
    self.installed_sticker_sets = self.installed_sticker_sets or {}
    self:send({
        ["@type"] = "getInstalledStickerSets",
        sticker_type = {["@type"] = "stickerTypeRegular"},
    }, "installed_sticker_sets")
    return true
end

function telegram:open_sticker_set_by_link(link)
    if not link or link == "" then return false end
    local name = link:match("addstickers/(.+)") or link:match("stickers/(.+)")
    if not name or name == "" then return false end
    name = name:gsub("[^%w_]", "")
    if name == "" then return false end
    return self:open_sticker_set_by_name(name)
end

function telegram:handle_sticker_set(object)
    local extra = tostring((object and object["@extra"]) or "")
    if extra:match("^sticker_set:") then
        local generation = tonumber(tostring(extra):match("^sticker_set:(%d+):"))
        if generation and generation == self.sticker_set_generation and self.sticker_set_viewer then
            self.sticker_set_viewer.loading = false
            self.sticker_set_viewer.error = nil
            self.sticker_set_viewer.title = object.title or self.sticker_set_viewer.title or ""
            self.sticker_set_viewer.name = object.name or self.sticker_set_viewer.name or ""
            self.sticker_set_viewer.stickers = object.stickers or self.sticker_set_viewer.stickers or {}
            self.sticker_set_viewer.thumbnail = object.thumbnail or self.sticker_set_viewer.thumbnail
            -- Запускаем загрузку/декод изображений стикеров из набора
            for _, sticker in ipairs(object.stickers or {}) do
                local file = sticker and sticker.sticker
                if file and file.id then
                    self:load_sticker_file(file)
                end
            end
        end
    end
end

function telegram:load_sticker_file(file)
    if not file or not file.id then return end
    local file_id = file.id
    local local_ = file.local or {}
    local entry = self.stickers[file_id]
    if not entry then
        entry = {status = "remote", format = self.sticker_format_by_file[file_id], autoplay = false}
        self.stickers[file_id] = entry
    end
    if local_.is_downloading_completed and local_.path and local_.path ~= "" then
        entry.source_path = local_.path
        local format = self.sticker_format_by_file[file_id]
        local is_animated = (format == "stickerFormatWebm" or format == "stickerFormatTgs")
            if is_animated then
                self.animation_by_message[file_id] = file_id
                if not self.animations[file_id] then self.animations[file_id] = {status = "remote", autoplay = true} end
                local anim_entry = self.animations[file_id]
                anim_entry.source_path = local_.path
                if not anim_entry.image then
                    local preview = self:convert_to_png(local_.path)
                    if preview then
                        self:load_image(file_id, preview, self.animations)
                        entry.image = anim_entry.image  -- mirror preview into stickers table for pack viewer
                    end
                end
                if not anim_entry.frames and not anim_entry.decode_requested then
                    self:queue_media_decode("sticker", file_id, local_.path)
                end
            end
            else
            if not entry.image then
                local converted = self:convert_to_png(local_.path)
                if converted then self:load_image(file_id, converted, self.stickers)
                else self:load_sticker(file_id, local_.path) end
            end
        end
    elseif not entry.download_requested then
        entry.download_requested = true
        entry.status = "downloading"
        local extra = self:send({
            ["@type"] = "downloadFile",
            file_id = file_id,
            priority = 1,
            offset = 0,
            limit = 0,
            synchronous = false,
        }, "sticker:" .. tostring(file_id))
        if not extra then
            entry.download_requested = false
            entry.status = "remote"
        end
    end
end

function telegram:add_proxy(proxy)
    local kind = proxy.type
    local proxy_type
    if kind == "socks5" then
        proxy_type = {
            ["@type"] = "proxyTypeSocks5",
            username = proxy.username or "",
            password = proxy.password or "",
        }
    elseif kind == "http" then
        proxy_type = {
            ["@type"] = "proxyTypeHttp",
            username = proxy.username or "",
            password = proxy.password or "",
            http_only = false,
        }
    elseif kind == "mtproto" then
        proxy_type = {
            ["@type"] = "proxyTypeMtproto",
            secret = proxy.secret or "",
        }
    elseif kind == "web" then
        proxy_type = {
            ["@type"] = "proxyTypeWeb",
            path = proxy.path or "",
            secret = proxy.secret or "",
        }
    else
        self.auth_error = "Неизвестный тип прокси: " .. tostring(kind)
        return
    end

    if self.proxy_flat then
        self:send({
            ["@type"] = "addProxy",
            server = proxy.server,
            port = proxy.port,
            type = proxy_type,
            enable = true,
        }, "proxy")
    else
        self:send({
            ["@type"] = "addProxy",
            proxy = {
                ["@type"] = "proxy",
                server = proxy.server,
                port = proxy.port,
                type = proxy_type,
            },
            enable = true,
        }, "proxy")
    end
end

function telegram:send_tdlib_parameters()
    local options = self.options or {}
    local parameters = {
        ["@type"] = "tdlibParameters",
        use_test_dc = false,
        database_directory = options.db,
        files_directory = options.files,
        use_message_database = true,
        use_file_database = true,
        use_chat_info_database = true,
        use_secret_chats = false,
        api_id = options.api_id,
        api_hash = options.api_hash,
        system_language_code = "en",
        device_model = "love_tg_native",
        system_version = "Linux",
        application_version = "0.1",
        enable_storage_optimizer = true,
        ignore_file_names = false,
    }
    if self.tdlib_parameters_nested then
        self:send({["@type"] = "setTdlibParameters", parameters = parameters}, "tdlib_params")
    else
        local request = {}
        for key, value in pairs(parameters) do
            if key ~= "@type" then request[key] = value end
        end
        request["@type"] = "setTdlibParameters"
        self:send(request, "tdlib_params")
    end
end

function telegram:handle_authorization(state)
    local kind = state["@type"]
    local options = self.options or {}
    local previous_state = self.auth_state
    self.auth_state = kind

    if kind == "authorizationStateWaitTdlibParameters" then
        -- Proxy is force-confirmed via fallback after 2s; don't block here
        self:send_tdlib_parameters()
    elseif kind == "authorizationStateWaitEncryptionKey" then
        log_to_file(self, "TDLib: authorizationStateWaitEncryptionKey")
        if not self.encryption_key_sent then
            self.encryption_key_sent = true
            self:send({
                ["@type"] = "checkDatabaseEncryptionKey",
                encryption_key = "",
            }, "encryption_key")
        end
    elseif kind == "authorizationStateWaitPhoneNumber" then
        log_to_file(self, string.format("TDLib: authorizationStateWaitPhoneNumber (previous=%s, logout_pending=%s)", tostring(previous_state), tostring(self.logout_pending)))
        -- Always reset account state when entering phone-number wait state;
        -- this ensures encryption_key_sent, qr flags, and media caches are clean
        -- after logout or any previous session.
        self:reset_account_state()
        if self.on_logged_out then self.on_logged_out() end
        self.logout_pending = false
        self.ready = false
        self.qr_link = ""
        self.qr_conflict = false
        self.action_status = ""
        self.action_error = ""
        self.auth_error = ""
        -- Proxy should already be added and confirmed from start()
        -- Request QR code explicitly; TDLib does not send requestQrCodeAuthentication
        -- automatically on this state. request_qr() has its own 30s debounce.
        self:request_qr()
        -- Clear QR conflict after timeout to allow retry
        if self.qr_conflict and love.timer.getTime() - self.qr_requested_at >= 120 then
            self.qr_conflict = false
            self.qr_request_pending = false
        end
    elseif kind == "authorizationStateWaitOtherDeviceConfirmation" then
        self.qr_request_pending = false
        self.qr_conflict = false
        self.qr_link = state.link or ""
        self.auth_error = ""
    elseif kind == "authorizationStateWaitPassword" then
        self.qr_conflict = false
        self.password_hint = state.password_hint or ""
        self.auth_error = ""
    elseif kind == "authorizationStateReady" then
        log_to_file(self, "TDLib: authorizationStateReady")
        self.qr_conflict = false
        self.ready = true
        self.qr_link = ""
        self.auth_error = ""
        self.action_status = ""
        self.action_error = ""
        self:send({["@type"] = "getMe"}, "me")
        self:send({
            ["@type"] = "loadChats",
            chat_list = {["@type"] = "chatListMain"},
            limit = 15,
        }, "loadChats")
        if self.on_ready then
            self.on_ready()
        end
    elseif kind == "authorizationStateClosed" then
        log_to_file(self, "TDLib: authorizationStateClosed")
        self.closed = true
        self.ready = false
        -- Drop TDLib database on logout to prevent photo loading on next start
        self:send({["@type"] = "destroy"}, "destroy")
        self:reset_account_state()
    else
        self.ready = false
    end
end

return telegram
