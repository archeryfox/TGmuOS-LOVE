-- src/features/messages/api/history_api.lua — загрузка истории сообщений
local history_api = {}

function history_api.load_history(tg, chat_id)
    tg:send({
        ["@type"] = "getChatHistory",
        chat_id = chat_id,
        from_message_id = 0,
        offset = 0,
        limit = 50,
        only_local = false,
    }, "history:" .. tostring(chat_id))
end

function history_api.send_message(tg, chat_id, text)
    if not chat_id or not text or text == "" then return end
    tg:send({
        ["@type"] = "sendMessage",
        chat_id = chat_id,
        input_message_content = {
            ["@type"] = "inputMessageText",
            text = {["@type"] = "formattedText", text = text, entities = {}},
        },
    })
end

return history_api
