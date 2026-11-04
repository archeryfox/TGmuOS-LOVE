-- src/features/auth/ui/auth_2fa.lua
-- Extracted from auth_screen.lua - 2FA password handling

local ui = require("src.shared.ui.ui_kit")

local auth_2fa = {}

function auth_2fa.new(fonts, tg)
    local self = {}
    self.fonts = fonts
    self.tg = tg
    self.password = ""
    return setmetatable(self, {__index = auth_2fa})
end

function auth_2fa:enter()
    self.password = ""
end

function auth_2fa:is_password_mode()
    return self.tg.auth_state == "authorizationStateWaitPassword"
end

function auth_2fa:has_error()
    return self.model and self.model:has_error()
end

function auth_2fa:get_error()
    return self.model and self.model:get_error() or ""
end

function auth_2fa:get_password_hint()
    return self.tg.auth_password_hint or ""
end

function auth_2fa:get_status_text()
    return "Введите пароль двухфакторной аутентификации"
end

function auth_2fa:update(dt)
    -- No-op
end

function auth_2fa:draw(w, h, f, colors)
    local box_w = math.min(560, w - 120)
    local x = math.floor((w - box_w) / 2)
    local y = 220

    ui.printf("Двухфакторная аутентификация", 80, 150, w - 160, "center", f.subtitle, colors.text)
    if self:get_password_hint() ~= "" then
        ui.printf(self:get_password_hint(), 80, 185, w - 160, "center", f.small, colors.muted)
    end
    ui.rect(x, y, box_w, 48, colors.panel, 8)
    ui.outline(x, y, box_w, 48, colors.accent, 8)
    local shown = string.rep("•", math.max(0, #self.password))
    if shown == "" then shown = "Пароль" end
    ui.text(shown, x + 16, y + 13, f.normal, self.password == "" and colors.muted or colors.text)
    ui.printf("Enter — подтвердить", 80, y + 70, w - 160, "center", f.small, colors.muted)
    if self:has_error() then
        ui.printf(self:get_error(), 80, y + 105, w - 160, "center", f.small, colors.red)
    end
end

function auth_2fa:textinput(text)
    self.password = self.password .. text
end

function auth_2fa:keypressed(key)
    if key == "backspace" then
        self.password = self:remove_last_utf8(self.password)
    elseif key == "return" or key == "kpenter" then
        self.tg:submit_password(self.password)
        self.password = ""
    end
end

function auth_2fa:remove_last_utf8(str)
    local byte = string.byte(str, -1)
    if not byte then return "" end
    if byte < 128 then
        return str:sub(1, -2)
    elseif byte < 192 then
        -- continuation byte, find start of char
        local i = #str
        while i > 0 and string.byte(str, i) >= 128 and string.byte(str, i) < 192 do
            i = i - 1
        end
        return str:sub(1, i - 1)
    else
        return str:sub(1, -2)
    end
end

return auth_2fa