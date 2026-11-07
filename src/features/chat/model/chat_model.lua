-- src/features/chat/model/chat_model.lua — состояние списка чатов
local chat_model = {}

function chat_model.new(tg)
    local self = {}
    self.tg = tg
    self.selected = 1
    self.list_offset = 0
    self.scroll = 0
    self.max_scroll = 0
    self.input = ""
    self.archive_mode = false
    return setmetatable(self, {__index = chat_model})
end

function chat_model:selected_chat()
    local list = self.visible_chats or (self.archive_mode and self.tg.archive_chats or self.tg.chats)
    return list[self.selected]
end

function chat_model:current_chat()
    local chat_id = self.tg.current_chat_id
    if not chat_id then return nil end
    return self.tg.chats_by_id[chat_id] or self.tg.archive_chats_by_id[chat_id]
end

function chat_model:clamp_selection()
    local list = self.visible_chats or (self.archive_mode and self.tg.archive_chats or self.tg.chats)
    if #list == 0 then
        self.selected = 1
    elseif self.selected > #list then
        self.selected = #list
    end
end

function chat_model:update_list_offset(visible)
    local list = self.visible_chats or (self.archive_mode and self.tg.archive_chats or self.tg.chats)
    if self.selected < self.list_offset + 1 then
        self.list_offset = self.selected - 1
    elseif self.selected > self.list_offset + visible then
        self.list_offset = self.selected - visible
    end
    self.list_offset = math.max(0, math.min(self.list_offset, math.max(0, #list - visible)))
end

return chat_model
