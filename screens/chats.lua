local ui = require("ui")

local chats = {}
chats.__index = chats

function chats.new(fonts)
    local self = setmetatable({}, chats)
    self.fonts = fonts
    self.selected = 1
    self.chats = {}
    self.scrollOffset = 0
    self.folder = "main"  -- main | archive
    return self
end

function chats:enter()
    self.chats = {}
    self.selected = 1
    self.scrollOffset = 0
    if _G.tg then
        self.chats = _G.tg.chats or {}
        if #self.chats == 0 then
            _G.tg:send({["@type"] = "getChats", chat_list = {["@type"] = "chatListMain"}, limit = 50})
        end
    end
end

function chats:leave() end

function chats:update(dt)
    if _G.tg then
        _G.tg:poll()
        self.chats = _G.tg.chats or {}
    end
end

function chats:draw()
    local f = self.fonts
    
    ui.rect(0, 0, 640, 48, COLORS.header)
    ui.drawText("Chats", 16, 12, f.subtitle, COLORS.text)
    ui.drawText("All", 580, 14, f.small, COLORS.accent)
    
    local visible = math.floor((480 - 60 - 40) / 64)
    local startIdx = 1
    local endIdx = #self.chats
    
    if #self.chats > visible then
        -- simple scroll clamp
        local maxSel = math.min(#self.chats, self.selected)
        if maxSel > visible then
            self.scrollOffset = math.max(0, math.min(maxSel - visible, self.scrollOffset))
        end
    else
        self.scrollOffset = 0
    end
    
    local y = 60
    local count = 0
    for i = 1 + self.scrollOffset, endIdx do
        if count >= visible then break end
        local chat = self.chats[i]
        local isSel = (i - self.scrollOffset) == self.selected
        local drawY = y + (i - 1 - self.scrollOffset) * 64 + 4
        
        local name = chat.title or chat.first_name or chat.last_name or "Unknown"
        if chat.first_name and chat.last_name then
            name = chat.first_name .. " " .. chat.last_name
        end
        
        local username = chat.username and ("@" .. chat.username) or ""
        local preview = ""
        if chat.last_message then
            local lm = chat.last_message
            if lm.content then
                if lm.content["@type"] == "messageText" then
                    preview = lm.content.text and lm.content.text.text or ""
                else
                    preview = "[media]"
                end
            end
        end
        local date = chat.last_message and chat.last_message.date or 0
        local timeStr = ""
        if date and date > 0 then
            timeStr = os.date("%H:%M", date)
        end
        
        if isSel then
            ui.rect(8, drawY, 624, 58, COLORS.panel)
        end
        
        ui.rect(16, drawY+8, 42, 42, COLORS.accent)
        local initial = string.sub(name, 1, 1):upper()
        ui.drawText(initial, 28, drawY+18, f.normal, COLORS.text)
        
        ui.drawText(name, 70, drawY+10, f.normal, COLORS.text)
        if username ~= "" then
            ui.drawText(username, 70, drawY+32, f.tiny, COLORS.muted)
        end
        ui.drawText(timeStr, 580, drawY+10, f.tiny, COLORS.muted)
        ui.drawText(preview, 70, drawY+32, f.small, COLORS.muted)
        
        if chat.unread_count and chat.unread_count > 0 then
            ui.rect(580, drawY+30, 28, 18, COLORS.accent)
            ui.drawText(tostring(chat.unread_count), 590, drawY+32, f.tiny, COLORS.text)
        end
        
        count = count + 1
    end
    
    if #self.chats == 0 then
        ui.drawText("No chats", 16, 100, f.normal, COLORS.muted)
        ui.drawText("Loading...", 16, 120, f.small, COLORS.muted)
    end
    
    ui.drawText("[A] Open  [SELECT] Settings  [START] Exit", 16, 450, f.tiny, COLORS.muted)
end

function chats:keypressed(key)
    if key == "up" then
        self.selected = math.max(1, self.selected - 1)
    elseif key == "down" then
        self.selected = math.min(#self.chats, self.selected + 1)
    elseif key == "space" then
        local idx = self.selected + self.scrollOffset
        local chat = self.chats[idx]
        if chat then
            _G.tg.current_chat_id = chat.id
            _G.tg:send({["@type"] = "getChatHistory", chat_id = chat.id, limit = 50, from_message_id = 0, offset = 0, only_local = false})
            switchScreen("chat")
        end
    elseif key == "s" then
        love.event.quit()
    elseif key == "t" or key == "backspace" then
        switchScreen("settings")
    end
end

return chats
