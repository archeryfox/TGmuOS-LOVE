local ui = require("ui")

local chat = {}
chat.__index = chat

function chat.new(fonts)
    local self = setmetatable({}, chat)
    self.fonts = fonts
    self.messages = {}
    self.input = ""
    self.scroll = 0
    self.cursor = 1
    self.showKeyboard = false
    self.chatTitle = "Chat"
    self.chatId = nil
    return self
end

function chat:enter()
    self.messages = {}
    self.input = ""
    self.chatId = _G.tg and _G.tg.current_chat_id or nil
    self.chatTitle = "Chat"
    if _G.tg and _G.tg.chats then
        for _, c in ipairs(_G.tg.chats) do
            if c.id == self.chatId then
                self.chatTitle = c.title or c.first_name or c.last_name or "Chat"
                break
            end
        end
    end
    if _G.tg then
        _G.tg:poll()
    end
end

function chat:leave() end

function chat:update(dt)
    if _G.tg then
        _G.tg:poll()
        if _G.tg.messages then
            self.messages = _G.tg.messages
        end
    end
end

function chat:draw()
    local f = self.fonts
    
    ui.rect(0, 0, 640, 48, COLORS.header)
    ui.drawText("< " .. self.chatTitle, 16, 12, f.normal, COLORS.text)
    
    local y = 60
    local visible = 0
    for i, msg in ipairs(self.messages) do
        if i <= self.scroll then goto continue end
        if y > 420 then break end
        visible = visible + 1
        if i == self.cursor then
            ui.rect(10, y-2, 620, 44, {0.3, 0.5, 0.9, 0.3})
        end
        local isOutgoing = (msg.sender_user_id and _G.tg and msg.sender_user_id == _G.tg.me_id) or (msg.from == "me")
        
        if not isOutgoing then
            ui.rect(16, y, 400, 40, COLORS.panel)
            ui.drawText(msg.text or "", 24, y+12, f.small, COLORS.text)
            local date = msg.date or 0
            ui.drawText(os.date("%H:%M", date), 380, y+26, f.tiny, COLORS.muted)
            y = y + 50
        else
            ui.rect(224, y, 400, 40, COLORS.accent)
            ui.drawText(msg.text or "", 232, y+12, f.small, COLORS.text)
            local date = msg.date or 0
            ui.drawText(os.date("%H:%M", date), 588, y+26, f.tiny, COLORS.text)
            y = y + 50
        end
        ::continue::
    end
    
    ui.rect(0, 420, 640, 60, COLORS.header)
    ui.rect(16, 430, 560, 38, COLORS.panel)
    ui.drawText(self.input == "" and "Message..." or self.input, 28, 440, f.small, self.input == "" and COLORS.muted or COLORS.text)
    ui.rect(586, 430, 38, 38, COLORS.accent)
    ui.drawText(">", 598, 438, f.normal, COLORS.text)
    
    if self.showKeyboard then
        ui.rect(0, 280, 640, 200, COLORS.header)
        ui.drawText("[Keyboard]", 16, 290, f.tiny, COLORS.muted)
    end
    
    ui.drawText("[A] Send  [X] Keyboard  [Up/Down] Scroll  [B] Back", 16, 450, f.tiny, COLORS.muted)
end

function chat:keypressed(key)
    if key == "up" then
        self.cursor = math.max(1, self.cursor - 1)
        if self.cursor < self.scroll + 1 then self.scroll = self.cursor - 1 end
    elseif key == "down" then
        self.cursor = math.min(#self.messages, self.cursor + 1)
        if self.cursor > self.scroll + 6 then self.scroll = self.cursor - 6 end
    elseif key == "backspace" then
        if self.input == "" then
            switchScreen("chats")
        else
            self.input = string.sub(self.input, 1, -2)
        end
    elseif key == "x" then
        self.showKeyboard = not self.showKeyboard
    elseif key == "space" then
        if self.input ~= "" then
            if _G.tg and self.chatId then
                _G.tg:send({["@type"] = "sendMessage", chat_id = self.chatId, input_message_content = {["@type"] = "inputMessageText", text = {["@type"] = "formattedText", text = self.input, entities = {}}}})
            end
            self.input = ""
        end
    elseif key == "s" then
        if self.input ~= "" then
            if _G.tg and self.chatId then
                _G.tg:send({["@type"] = "sendMessage", chat_id = self.chatId, input_message_content = {["@type"] = "inputMessageText", text = {["@type"] = "formattedText", text = self.input, entities = {}}}})
            end
            self.input = ""
        end
    else
        if #key == 1 and string.match(key, "[a-zA-Z0-9%p%s]") then
            self.input = self.input .. key
        end
    end
end

return chat
