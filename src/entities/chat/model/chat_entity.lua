-- src/entities/chat/model/chat_entity.lua — бизнес-сущность чата
local chat_entity = {}

function chat_entity.new(raw)
    local self = {}
    self.id = raw.id
    self.title = raw.title
    self.type = raw.type
    self.last_message = raw.last_message
    self.unread_count = raw.unread_count or 0
    self.date = raw.last_message and raw.last_message.date or 0
    return setmetatable(self, {__index = chat_entity})
end

function chat_entity:get_title()
    return self.title or ("Chat " .. tostring(self.id))
end

function chat_entity:get_preview(tg)
    if not self.last_message then return "" end
    if tg then
        return tg:message_text(self.last_message)
    end
    return ""
end

function chat_entity:get_sort_key()
    return self.date or 0
end

return chat_entity
