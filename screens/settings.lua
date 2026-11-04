local ui = require("ui")

local settings = {}
settings.__index = settings

function settings.new(fonts)
    local self = setmetatable({}, settings)
    self.fonts = fonts
    self.selected = 1
    self.items = {
        {name = "Language", value = "English"},
        {name = "Animations", value = "On"},
        {name = "Notifications", value = "On"},
        {name = "About", value = ""},
        {name = "Exit", value = ""},
    }
    return self
end

function settings:enter() end
function settings:leave() end
function settings:update(dt) end

function settings:draw()
    local f = self.fonts
    
    ui.rect(0, 0, 640, 48, COLORS.header)
    ui.drawText("< Settings", 16, 12, f.normal, COLORS.text)
    
    for i, item in ipairs(self.items) do
        local y = 70 + (i-1) * 48
        local isSel = i == self.selected
        if isSel then
            ui.rect(8, y, 624, 42, COLORS.panel)
        end
        ui.drawText(item.name, 16, y+12, f.normal, COLORS.text)
        if item.value ~= "" then
            ui.drawText(item.value, 580, y+12, f.small, COLORS.muted)
        end
    end
    
    ui.drawText("TGMUOS LÖVE v1.0 | No VPN", 16, 420, f.tiny, COLORS.muted)
    ui.drawText("[A] Select  [B] Back  [START] Exit", 16, 450, f.tiny, COLORS.muted)
end

function settings:keypressed(key)
    if key == "up" then
        self.selected = math.max(1, self.selected - 1)
    elseif key == "down" then
        self.selected = math.min(#self.items, self.selected + 1)
    elseif key == "backspace" then
        switchScreen("chats")
    elseif key == "space" then
        if self.selected == 5 then
            love.event.quit()
        elseif self.selected == 1 then
            if self.items[1].value == "English" then
                self.items[1].value = "Russian"
            else
                self.items[1].value = "English"
            end
        elseif self.selected == 2 then
            if self.items[2].value == "On" then
                self.items[2].value = "Off"
            else
                self.items[2].value = "On"
            end
        elseif self.selected == 3 then
            if self.items[3].value == "On" then
                self.items[3].value = "Off"
            else
                self.items[3].value = "On"
            end
        end
    elseif key == "s" then
        love.event.quit()
    end
end

return settings
