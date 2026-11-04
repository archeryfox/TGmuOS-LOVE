-- src/features/chat/api/chats_api.lua — методы для работы со списком чатов
local chats_api = {}

function chats_api.load_chats(tg)
    tg:send({
        ["@type"] = "loadChats",
        chat_list = {["@type"] = "chatListMain"},
        limit = 100,
    }, "loadChats")
end

function chats_api.open_chat(tg, chat_id)
    tg.current_chat_id = chat_id
    local chat = tg.chats_by_id[chat_id]
    local last = chat and chat.last_message
    tg.messages[chat_id] = last and {last} or {}
    if last then
        tg:ensure_photo(last)
        tg:ensure_sticker(last)
        tg:ensure_animation(last)
    end
    tg:send({["@type"] = "openChat", chat_id = chat_id})
    tg:send({
        ["@type"] = "getChatHistory",
        chat_id = chat_id,
        from_message_id = last and last.id or 0,
        offset = 0,
        limit = 50,
        only_local = false,
    }, "history:" .. tostring(chat_id))
end

function chats_api.close_chat(tg)
    local chat_id = tg.current_chat_id
    tg.current_chat_id = nil
    if chat_id then
        tg:send({["@type"] = "closeChat", chat_id = chat_id})
    end
end

return chats_api
