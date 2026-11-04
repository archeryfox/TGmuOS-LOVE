local ui = require("ui")
local telegram = require("telegram")
local qr = require("qr_lua")

local auth = {}
auth.__index = auth

function auth.new(fonts)
    local self = setmetatable({}, auth)
    self.fonts = fonts
    self.selected = 1
    self.input = ""
    self.state = "phone"
    self.timer = 0
    self.caps = false
    self.russian = false
    self.showKeyboard = true
    self.qrMode = false
    self.qrLink = ""
    self.qrMatrix = nil
    self.qrSize = 0
    self.tg = telegram.new()
    _G.auth_screen = self
    
    self.keys = {
        {"1","2","3","4","5","6","7","8","9","0"},
        {"q","w","e","r","t","y","u","i","o","p"},
        {"a","s","d","f","g","h","j","k","l",""},
        {"z","x","c","v","b","n","m","","",""},
        {"SPACE","DEL","CASE","EN","OK","QR"},
    }
    
    return self
end

function auth:setQrLink(link)
    self.qrLink = link or ""
    if self.qrLink ~= "" then
        self.qrMatrix, self.qrSize = qr.generate(self.qrLink)
    end
end

function auth:enter()
    self.state = "phone"
    self.input = ""
    self.showKeyboard = true
    self.selected = 1
    self.qrMode = false
    self.qrLink = ""
    self.qrMatrix = nil
    self.russian = false
    self.keys = {
        {"1","2","3","4","5","6","7","8","9","0"},
        {"q","w","e","r","t","y","u","i","o","p"},
        {"a","s","d","f","g","h","j","k","l",""},
        {"z","x","c","v","b","n","m","","",""},
        {"SPACE","DEL","CASE","EN","OK","QR"},
    }
    pcall(function() self.tg:init() end)
end

function auth:leave() end

function auth:update(dt)
    self.timer = self.timer + dt
    if self.tg then
        pcall(function() self.tg:poll() end)
        if self.tg.qr_link and self.tg.qr_link ~= "" and self.tg.qr_link ~= self.qrLink then
            self:setQrLink(self.tg.qr_link)
        end
    end
end

function auth:draw()
    local f = self.fonts
    
    ui.rect(0, 0, 640, 48, COLORS.header)
    ui.drawText("Telegram", 16, 12, f.subtitle, COLORS.text)
    
    if self.qrMode then
        ui.drawText("Scan QR code with Telegram", 16, 70, f.normal, COLORS.text)
        ui.drawText("Settings > Devices > Link Desktop Device", 16, 96, f.small, COLORS.muted)
        if self.qrMatrix and self.qrSize then
            qr.draw(self.qrMatrix, self.qrSize, 320 - (self.qrSize*1.5), 120, 3)
        else
            ui.rect(220, 140, 200, 200, COLORS.panel)
            ui.outline(220, 140, 200, 200, COLORS.accent)
            ui.drawText("Generating QR...", 245, 230, f.small, COLORS.yellow)
        end
        if self.qrLink and self.qrLink ~= "" then
            local short = self.qrLink
            if #short > 45 then short = string.sub(short, 1, 42) .. "..." end
            ui.drawText(short, 16, 370, f.tiny, COLORS.muted)
        else
            ui.drawText("QR link not available", 16, 370, f.tiny, COLORS.red)
        end
        ui.drawText("[B] Back", 16, 450, f.tiny, COLORS.muted)
        return
    end
    
    ui.drawText("Sign in", 16, 70, f.normal, COLORS.text)
    ui.drawText("Phone number (e.g. +1234567890)", 16, 96, f.small, COLORS.muted)
    
    ui.rect(16, 130, 608, 42, COLORS.panel)
    ui.outline(16, 130, 608, 42, COLORS.accent)
    local display = self.input == "" and "+1234567890" or self.input
    ui.drawText(display, 28, 142, f.normal, self.input == "" and COLORS.muted or COLORS.text)
    
    if self.showKeyboard then
        self:drawKeyboard()
    end
    
    ui.drawText("[START] Next  [X] Keyboard  [T] QR  [SELECT] Settings", 16, 450, f.tiny, COLORS.muted)
end

function auth:drawKeyboard()
    local f = self.fonts
    local startY = 260
    local keyW, keyH = 56, 28
    local gap = 4
    
    for rowIdx, row in ipairs(self.keys) do
        local y = startY + (rowIdx-1) * (keyH + gap)
        local xOffset = 16
        if rowIdx == 2 then xOffset = 16 + (keyW + gap) * 0.5 end
        if rowIdx == 3 then xOffset = 16 + (keyW + gap) * 1.0 end
        if rowIdx == 4 then xOffset = 16 + (keyW + gap) * 1.5 end
        if rowIdx == 5 then xOffset = 16 end
        
        for colIdx, key in ipairs(row) do
            if key ~= "" then
                local x = xOffset + (colIdx-1) * (keyW + gap)
                local isSel = (rowIdx == math.floor((self.selected-1)/10)+1) and (colIdx == (self.selected-1)%10+1)
                local bgColor = isSel and COLORS.accent or COLORS.panel
                ui.rect(x, y, keyW, keyH, bgColor)
                if isSel then
                    ui.outline(x, y, keyW, keyH, COLORS.text)
                end
                local label = key
                if key == "SPACE" then label = "SPACE" end
                if key == "DEL" then label = "DEL" end
                if key == "CASE" then label = "Aa" end
                if key == "EN" then label = "EN" end
                if key == "QR" then label = "QR" end
                if key == "OK" then label = "OK" end
                ui.drawText(label, x + 4, y + 6, f.tiny, COLORS.text)
            end
        end
    end
end

function auth:keypressed(key)
    if self.qrMode then
        if key == "backspace" or key == "b" or key == "x" then
            self.qrMode = false
        end
        return
    end
    
    if key == "x" then
        self.showKeyboard = not self.showKeyboard
        return
    end
    if key == "y" then
        self.caps = not self.caps
        return
    end
    if key == "t" then
        self.qrMode = true
        self.qrLink = ""
        self.qrMatrix = nil
        if self.tg and self.tg.requestQrCodeAuthentication then
            pcall(function() self.tg:requestQrCodeAuthentication() end)
        end
        return
    end
    if key == "up" then
        self.selected = math.max(1, self.selected - 10)
    elseif key == "down" then
        self.selected = math.min(50, self.selected + 10)
    elseif key == "left" then
        self.selected = math.max(1, self.selected - 1)
    elseif key == "right" then
        self.selected = math.min(50, self.selected + 1)
    elseif key == "space" then
        local row = math.floor((self.selected-1)/10)+1
        local col = (self.selected-1)%10+1
        local k = self.keys[row] and self.keys[row][col]
        if k then
            if k == "DEL" then
                self.input = string.sub(self.input, 1, -2)
            elseif k == "SPACE" then
                self.input = self.input .. " "
            elseif k == "OK" then
                if self.input ~= "" then
                    if self.tg and self.tg.setPhoneNumber then
                        pcall(function() self.tg:setPhoneNumber(self.input) end)
                    end
                    switchScreen("chats")
                end
            elseif k == "QR" then
                self.qrMode = true
                self.qrLink = ""
                self.qrMatrix = nil
                if self.tg and self.tg.requestQrCodeAuthentication then
                    pcall(function() self.tg:requestQrCodeAuthentication() end)
                end
            elseif k == "EN" then
            else
                local ch = k
                if self.caps and string.match(ch, "%a") then
                    ch = string.upper(ch)
                end
                self.input = self.input .. ch
            end
        end
    elseif key == "s" then
        if self.input ~= "" then
            if self.tg and self.tg.setPhoneNumber then
                pcall(function() self.tg:setPhoneNumber(self.input) end)
            end
            switchScreen("chats")
        end
    elseif key == "backspace" then
        if self.input ~= "" then
            self.input = string.sub(self.input, 1, -2)
        end
    end
end

return auth
