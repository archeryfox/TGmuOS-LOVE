-- src/entities/message/model/message_entity.lua — бизнес-сущность сообщения
local message_entity = {}

function message_entity.new(raw)
    local self = {}
    self.id = raw.id
    self.chat_id = raw.chat_id
    self.date = raw.date
    self.sender_id = raw.sender_id
    self.content = raw.content
    self.outgoing = false
    return setmetatable(self, {__index = message_entity})
end

function message_entity:is_outgoing(me_id)
    if not self.sender_id then return false end
    if self.sender_id["@type"] == "messageSenderUser" then
        return self.sender_id.user_id == me_id
    end
    return false
end

function message_entity:get_text()
    local content = self.content
    if not content then return "" end
    local kind = content["@type"]
    if kind == "messageText" then
        local t = content.text
        return t and t.text or ""
    elseif kind == "messagePhoto" then
        local cap = content.caption and content.caption.text or ""
        return cap ~= "" and cap or "[фото]"
    elseif kind == "messageSticker" then
        local emoji = content.sticker and content.sticker.emoji or ""
        return emoji ~= "" and (emoji .. " стикер") or "[стикер]"
    elseif kind == "messageAnimation" then
        return "[GIF]"
    elseif kind == "messageVideo" or kind == "messageVideoNote" then
        return kind == "messageVideoNote" and "[видеосообщение]" or "[видео]"
    elseif kind == "messageVoiceNote" then
        local note = content.voice_note
        local duration = note and tonumber(note.duration)
        if duration and duration > 0 then
            return string.format("[голосовое · %d:%02d]", math.floor(duration / 60), math.floor(duration % 60))
        end
        return "[голосовое]"
    elseif kind == "messageDocument" then
        return "[файл]"
    end
    return "[сообщение]"
end

function message_entity:has_media()
    local kind = self.content and self.content["@type"]
    return kind == "messagePhoto" or kind == "messageSticker" or kind == "messageAnimation"
        or kind == "messageVideo" or kind == "messageVideoNote" or kind == "messageVoiceNote"
end

return message_entity
