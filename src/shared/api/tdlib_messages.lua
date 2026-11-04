-- src/shared/api/tdlib_messages.lua
-- Extracted from tdlib_client.lua - message operations

local tdlib_messages = {}

function tdlib_messages.setup(tdlib)
    tdlib.messages_by_id = {}
    tdlib.messages_by_chat = {}
end

function tdlib_messages.send_message(tdlib, chat_id, text, reply_to_message_id)
    tdlib:send({
        ["@type"] = "sendMessage",
        chat_id = chat_id,
        reply_to_message_id = reply_to_message_id or 0,
        input_message_content = {
            ["@type"] = "inputMessageText",
            text = {text = text},
            disable_web_page_preview = true,
            clear_draft = true,
        },
    }, "sendMessage:" .. tostring(chat_id))
end

function tdlib_messages.edit_message_text(tdlib, chat_id, message_id, text)
    tdlib:send({
        ["@type"] = "editMessageText",
        chat_id = chat_id,
        message_id = message_id,
        input_message_content = {
            ["@type"] = "inputMessageText",
            text = {text = text},
            disable_web_page_preview = true,
        },
    }, "editMessage:" .. tostring(message_id))
end

function tdlib_messages.delete_messages(tdlib, chat_id, message_ids, revoke)
    tdlib:send({
        ["@type"] = "deleteMessages",
        chat_id = chat_id,
        message_ids = message_ids,
        revoke = revoke,
    }, "deleteMessages:" .. table.concat(message_ids, ","))
end

function tdlib_messages.forward_messages(tdlib, chat_id, from_chat_id, message_ids)
    tdlib:send({
        ["@type"] = "forwardMessages",
        chat_id = chat_id,
        from_chat_id = from_chat_id,
        message_ids = message_ids,
    }, "forwardMessages:" .. table.concat(message_ids, ","))
end

function tdlib_messages.set_message_pinned(tdlib, chat_id, message_id, pinned)
    tdlib:send({
        ["@type"] = "pinChatMessage",
        chat_id = chat_id,
        message_id = message_id,
        pinned = pinned,
    }, "pinMessage:" .. tostring(message_id))
end

function tdlib_messages.get_messages(tdlib, chat_id, limit)
    tdlib:send({
        ["@type"] = "getChatHistory",
        chat_id = chat_id,
        from_message_id = 0,
        limit = limit or 50,
        only_local = false,
    }, "getChatHistory:" .. tostring(chat_id))
end

function tdlib_messages.search_dialog_messages(tdlib, chat_id, query)
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

function tdlib_messages.edit_message_text(tdlib, chat_id, message_id, text)
    tdlib:send({
        ["@type"] = "editMessageText",
        chat_id = chat_id,
        message_id = message_id,
        input_message_content = {
            ["@type"] = "inputMessageText",
            text = {text = text},
            disable_web_page_preview = true,
        },
    }, "editMessage:" .. tostring(message_id))
end

function tdlib_messages.delete_messages(tdlib, chat_id, message_ids, revoke)
    tdlib:send({
        ["@type"] = "deleteMessages",
        chat_id = chat_id,
        message_ids = message_ids,
        revoke = revoke,
    }, "deleteMessages:" .. table.concat(message_ids, ","))
end

function tdlib_messages.forward_messages(tdlib, chat_id, from_chat_id, message_ids)
    tdlib:send({
        ["@type"] = "forwardMessages",
        chat_id = chat_id,
        from_chat_id = from_chat_id,
        message_ids = message_ids,
    }, "forwardMessages:" .. table.concat(message_ids, ","))
end

function tdlib_messages.set_message_pinned(tdlib, chat_id, message_id, pinned)
    tdlib:send({
        ["@type"] = "pinChatMessage",
        chat_id = chat_id,
        message_id = message_id,
        pinned = pinned,
    }, "pinMessage:" .. tostring(message_id))
end

function tdlib_messages.delete_messages(tdlib, chat_id, message_ids, revoke)
    tdlib:send({
        ["@type"] = "deleteMessages",
        chat_id = chat_id,
        message_ids = message_ids,
        revoke = revoke,
    }, "deleteMessages:" .. table.concat(message_ids, ","))
end

function tdlib_messages.forward_messages(tdlib, chat_id, from_chat_id, message_ids)
    tdlib:send({
        ["@type"] = "forwardMessages",
        chat_id = chat_id,
        from_chat_id = from_chat_id,
        message_ids = message_ids,
    }, "forwardMessages:" .. table.concat(message_ids, ","))
end

function tdlib_messages.set_message_pinned(tdlib, chat_id, message_id, pinned)
    tdlib:send({
        ["@type"] = "pinChatMessage",
        chat_id = chat_id,
        message_id = message_id,
        pinned = pinned,
    }, "pinMessage:" .. tostring(message_id))
end

return tdlib_messages