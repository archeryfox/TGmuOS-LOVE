-- src/shared/api/tdlib_chats.lua
-- Extracted from tdlib_client.lua - chat operations

local tdlib_chats = {}

function tdlib_chats.setup(tdlib)
    tdlib.chats_by_id = {}
    tdlib.archive_chats_by_id = {}
    tdlib.chat_filters = {}
    tdlib.history_state = {}
    tdlib.dialog_search_results = {}
    tdlib.dialog_search_query = {}
    tdlib.chat_search_error = ""
    tdlib.public_search_error = ""
end

function tdlib_chats.load_chats_for_mode(tdlib)
    local list = {["@type"] = "chatListMain"}
    if tdlib.list_kind == "archive" then
        list = {["@type"] = "chatListArchive"}
    elseif tdlib.list_kind == "filter" then
        list = {["@type"] = "chatListFilter", chat_filter_id = tdlib.list_filter_id}
    end
    tdlib:send({
        ["@type"] = "loadChats",
        chat_list = list,
        limit = 15,
    }, "loadChats")
end

function tdlib_chats.handle_chat_list(tdlib, object)
    if object.chat_ids then
        for _, chat_id in ipairs(object.chat_ids) do
            local chat = tdlib.chats_by_id[chat_id] or tdlib.archive_chats_by_id[chat_id]
            if chat then
                -- Chat already cached
            end
        end
    end
end

function tdlib_chats.handle_chat(tdlib, object)
    local chat = object
    tdlib.chats_by_id[chat.id] = chat
    if chat.chat_list and chat.chat_list["@type"] == "chatListArchive" then
        tdlib.archive_chats_by_id[chat.id] = chat
    end
end

function tdlib_chats.handle_update_chat(tdlib, object)
    if object.chat then
        local chat = object.chat
        tdlib.chats_by_id[chat.id] = chat
        if chat.chat_list and chat.chat_list["@type"] == "chatListArchive" then
            tdlib.archive_chats_by_id[chat.id] = chat
        end
    end
end

function tdlib_chats.handle_delete_chat(tdlib, object)
    if object.chat_id then
        tdlib.chats_by_id[object.chat_id] = nil
        tdlib.archive_chats_by_id[object.chat_id] = nil
    end
end

function tdlib_chats.open_chat(tdlib, chat_id)
    tdlib:send({
        ["@type"] = "openChat",
        chat_id = chat_id,
    }, "openChat:" .. tostring(chat_id))
end

function tdlib_chats.close_chat(tdlib, chat_id)
    tdlib:send({
        ["@type"] = "closeChat",
        chat_id = chat_id,
    }, "closeChat:" .. tostring(chat_id))
end

function tdlib_chats.archive_chat(tdlib, chat_id, archive)
    tdlib:send({
        ["@type"] = "archiveChat",
        chat_id = chat_id,
        archive = archive,
    }, "archiveChat:" .. tostring(chat_id))
end

function tdlib_chats.mute_chat(tdlib, chat_id, mute)
    tdlib:send({
        ["@type"] = "setChatNotificationSettings",
        chat_id = chat_id,
        notification_settings = {
            mute_for = mute and 31536000 or 0,
            sound = "",
            show_preview = true,
            disable_mention_notifications = false,
            disable_pinned_message_notifications = false,
        },
    }, "muteChat:" .. tostring(chat_id))
end

function tdlib_chats.switch_list(tdlib, delta)
    local entries = tdlib:list_entries()
    if #entries <= 1 then return end
    local index = 1
    for i, entry in ipairs(entries) do
        if tdlib:is_current_entry(entry) then
            index = i
            break
        end
    end
    index = ((index - 1 + delta) % #entries) + 1
    local target = entries[index]
    if tdlib:is_current_entry(target) then return end
    if tdlib.current_chat_id then tdlib:close_chat() end
    tdlib.list_kind = target.kind
    tdlib.list_filter_id = target.id
    tdlib.archive_mode = target.kind == "archive"
    tdlib:load_chats_for_mode()
end

function tdlib_chats.add_chat_filter(tdlib, filter)
    tdlib:send({
        ["@type"] = "addChatFilter",
        filter = filter,
    }, "addChatFilter")
end

function tdlib_chats.remove_chat_filter(tdlib, filter_id)
    tdlib:send({
        ["@type"] = "removeChatFilter",
        chat_filter_id = filter_id,
    }, "removeChatFilter")
end

function tdlib_chats.search_public_chats(tdlib, query)
    tdlib:send({
        ["@type"] = "searchPublicChats",
        query = query,
    }, "searchPublicChats:" .. query)
end

function tdlib_chats.search_dialog_messages(tdlib, chat_id, query)
    tdlib:send({
        ["@type"] = "searchChatMessages",
        chat_id = chat_id,
        query = query,
        sender_id = nil,
        from_message_id = 0,
        limit = 20,
        filter = {["@type"] = "searchMessagesFilterEmpty"},
    }, "searchDialog:" .. tostring(chat_id))
end

function tdlib_chats.handle_update_chat_filters(tdlib, object)
    if object.chat_filters then
        tdlib.chat_filters = object.chat_filters
    end
end

return tdlib_chats