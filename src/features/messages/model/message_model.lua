-- src/features/messages/model/message_model.lua — состояние сообщений в чате
local message_model = {}

function message_model.new(tg)
    local self = {}
    self.tg = tg
    return setmetatable(self, {__index = message_model})
end

function message_model:get_messages(chat_id)
    return self.tg.messages[chat_id] or {}
end

function message_model:ensure_media(message)
    self.tg:ensure_photo(message)
    self.tg:ensure_sticker(message)
    self.tg:ensure_animation(message)
end

return message_model
