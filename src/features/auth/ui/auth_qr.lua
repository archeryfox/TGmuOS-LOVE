-- src/features/auth/ui/auth_qr.lua
-- Extracted from auth_screen.lua - QR code authentication

local ui = require("src.shared.ui.ui_kit")
local qr = require("src.shared.lib.qr")
local auth_model = require("src.features.auth.model.auth_model")

local auth_qr = {}

function auth_qr.new(fonts, tg)
    local self = {}
    self.fonts = fonts
    self.tg = tg
    self.model = auth_model.new(tg)
    self.qr_link = nil
    self.qr_image = nil
    self.qr_size = 0
    self.qr_error = ""
    self.password = ""
    self.conn_mode = "direct"
    self.connection_attempt = 0
    self.last_connection_check = 0
    self.vpn_status = "disconnected"
    self.vpn_latency = nil
    self.vpn_error = nil
    self.vpn_servers = {}
    self.vpn_selected = 1
    self.vpn_first_row = 0
    self.vpn_action_idx = 1
    return setmetatable(self, {__index = auth_qr})
end

function auth_qr:enter()
    self.password = ""
    self:load_vpn_config()
    self:try_direct_connection()
end

function auth_qr:try_direct_connection()
    self.tg.proxy_enabled = false
    self.conn_mode = "direct"
    self.connection_attempt = 0
    self.last_connection_check = love.timer.getTime()
    if self.tg.restart_without_proxy then
        self.tg:restart_without_proxy()
    end
end

function auth_qr:try_vpn_connection()
    self.tg.proxy_enabled = false
    self.conn_mode = "vpn"
    self:vpn_action("start")
end

function auth_qr:load_vpn_config()
    local servers_file = "/root/.config/muvpn/servers.tsv"
    local handle = io.open(servers_file, "r")
    if handle then
        for line in handle:lines() do
            local fields = {}
            for field in line:gmatch("([^\t]+)") do table.insert(fields, field) end
            if #fields >= 3 then
                table.insert(self.vpn_servers, {id = fields[1], name = fields[2], country = fields[3]})
            end
        end
        handle:close()
    end
    
    local sub_file = "/root/.config/tgmuos/subscription.conf"
    handle = io.open(sub_file, "r")
    if handle then
        for line in handle:lines() do
            local id = line:match("^selected=([%w]+)")
            if id then
                for i, s in ipairs(self.vpn_servers) do
                    if s.id == id then self.vpn_selected = i break end
                end
            end
        end
        handle:close()
    end
    self:update_vpn_status()
end

function auth_qr:update_vpn_status()
    local handle = io.popen("/mnt/mmc/MUOS/application/muvpn_love/tools/muvpn.py health 2>/dev/null")
    if handle then
        local result = handle:read("*a")
        handle:close()
        local ok, data = pcall(function() return require("dkjson").decode(result) end)
        if ok and data then
            self.vpn_status = data.connected and "connected" or "disconnected"
            self.vpn_latency = data.latency_ms
            self.vpn_error = data.probe_error
        end
    end
end

function auth_qr:vpn_action(action)
    local cmd = "/mnt/mmc/MUOS/application/muvpn_love/tools/muvpn.py " .. action
    if action == "select" and self.vpn_servers[self.vpn_selected] then
        cmd = cmd .. " " .. self.vpn_servers[self.vpn_selected].id
    elseif action == "refresh" then
        cmd = "/mnt/mmc/MUOS/application/muvpn_love/tools/muvpn.py refresh"
    end
    local handle = io.popen(cmd .. " 2>&1")
    if handle then
        local result = handle:read("*a")
        handle:close()
        self.vpn_error = result
    end
    self:update_vpn_status()
end

function auth_qr:update(dt)
    if self.tg.qr_link ~= self.qr_link then
        self.qr_link = self.tg.qr_link
        if self.qr_link and self.qr_link ~= "" then
            local matrix, size = qr.encode(self.qr_link)
            if matrix then
                self.qr_image = qr.make_image(matrix, size)
                self.qr_size = size
                self.qr_error = ""
            else
                self.qr_image = nil
                self.qr_size = 0
                self.qr_error = "Ссылка авторизации не помещается в поддерживаемый QR-код"
            end
        else
            self.qr_image = nil
            self.qr_size = 0
            self.qr_error = ""
        end
    end
end

function auth_qr:draw(w, h, f, colors)
    if self.model:is_password_mode() then
        self:draw_password(w, h, f, colors)
        return
    end

    local status_y = 96
    if self.model:has_error() then
        ui.printf(self.model:get_error(), 80, 90, w - 160, "center", f.small, colors.red)
        local _, error_lines = f.small:getWrap(self.model:get_error(), w - 160)
        status_y = 90 + math.max(1, #error_lines) * f.small:getHeight() + 8
    end

    local status = self.model:get_status_text()
    if self.conn_mode == "direct" and self.connection_attempt > 0 then
        status = status .. " (попытка " .. self.connection_attempt .. ")"
    elseif self.conn_mode == "vpn" then
        status = status .. " [VPN: " .. self.vpn_status .. "]"
    end
    ui.printf(status, 80, status_y, w - 160, "center", f.normal, colors.text)

    -- Quick VPN toggle
    local vpn_y = status_y + 30
    if self.conn_mode == "direct" then
        ui.rect(80, vpn_y, w - 160, 36, colors.panel, 6)
        ui.outline(80, vpn_y, w - 160, 36, colors.accent, 6)
        ui.text("VPN: ВЫКЛ  →  A для включения VPN", 90, vpn_y + 8, f.normal, colors.accent)
        vpn_y = vpn_y + 45
    else
        local vpn_color = (self.vpn_status == "connected") and colors.green or colors.red
        ui.rect(80, vpn_y, w - 160, 36, colors.panel, 6)
        ui.outline(80, vpn_y, w - 160, 36, vpn_color, 6)
        ui.text("VPN: " .. (self.vpn_status == "connected" and "ВКЛ" or "ОШИБКА") .. "  →  A: переключить | B: меню VPN", 90, vpn_y + 8, f.normal, vpn_color)
        if self.vpn_latency then
            ui.text("Пинг: " .. self.vpn_latency .. " ms", w - 200, vpn_y + 8, f.small, colors.muted)
        end
        vpn_y = vpn_y + 45
    end

    if self.qr_image then
        local available = math.min(w * 0.55, h - 300)
        local scale = math.max(3, math.floor(available / (self.qr_size + 8)))
        local total = (self.qr_size + 8) * scale
        local x = math.floor((w - total) / 2)
        local y = 150
        qr.draw(self.qr_image, x, y, scale, 4)

        ui.printf("Откройте Telegram на телефоне", 80, y + total + 20, w - 160, "center", f.normal, colors.text)
        ui.printf("Настройки → Устройства → Подключить устройство", 80, y + total + 48, w - 160, "center", f.small, colors.muted)
        ui.printf("Наведите камеру на QR-код", 80, y + total + 74, w - 160, "center", f.small, colors.muted)
        ui.printf("QR-код обновляется автоматически", 80, h - 70, w - 160, "center", f.tiny, colors.muted)
    else
        if self.qr_error ~= "" then
            ui.printf(self.qr_error, 80, 220, w - 160, "center", f.normal, colors.red)
        else
            ui.printf("QR-код ещё не получен", 80, 220, w - 160, "center", f.normal, colors.muted)
            if self.conn_mode == "direct" then
                ui.printf("Прямое соединение... (авто-VPN через 30 сек)", 80, 250, w - 160, "center", f.small, colors.accent)
            else
                ui.printf("VPN активен. Ожидание QR...", 80, 250, w - 160, "center", f.small, colors.muted)
            end
        end
    end

    ui.text("Esc — выход | → — VPN", 24, h - 32, f.tiny, colors.muted)
end

function auth_qr:draw_password(w, h, f, colors)
    local box_w = math.min(560, w - 120)
    local x = math.floor((w - box_w) / 2)
    local y = 220

    ui.printf("Двухфакторная аутентификация", 80, 150, w - 160, "center", f.subtitle, colors.text)
    if self.model:get_password_hint() ~= "" then
        ui.printf(self.model:get_password_hint(), 80, 185, w - 160, "center", f.small, colors.muted)
    end
    ui.rect(x, y, box_w, 48, colors.panel, 8)
    ui.outline(x, y, box_w, 48, colors.accent, 8)
    local shown = string.rep("•", math.max(0, #self.password))
    if shown == "" then shown = "Пароль" end
    ui.text(shown, x + 16, y + 13, f.normal, self.password == "" and colors.muted or colors.text)
    ui.printf("Enter — подтвердить", 80, y + 70, w - 160, "center", f.small, colors.muted)
    if self.model:has_error() then
        ui.printf(self.model:get_error(), 80, y + 105, w - 160, "center", f.small, colors.red)
    end
end

function auth_qr:draw_vpn(w, h, f, colors)
    -- VPN tab drawing logic
end

function auth_qr:textinput(text)
    if self.model:is_password_mode() then
        self.password = self.password .. text
    end
end

function auth_qr:keypressed(key)
    if self.model:is_password_mode() then
        if key == "backspace" then
            self.password = ui.remove_last_utf8(self.password)
        elseif key == "return" or key == "kpenter" then
            self.tg:submit_password(self.password)
            self.password = ""
        end
        return
    end

    if key == "left" or key == "right" then
        local tabs = {"auth", "vpn"}
        local idx = 1
        for i, t in ipairs(tabs) do if t == self.tab then idx = i end end
        if key == "left" then idx = idx - 1 else idx = idx + 1 end
        if idx < 1 then idx = #tabs end
        if idx > #tabs then idx = 1 end
        self.tab = tabs[idx]
        return
    end

    if key == "a" or key == "return" then
        if self.conn_mode == "direct" then
            self:try_vpn_connection()
        else
            if self.vpn_status == "connected" then
                self:vpn_action("stop")
            else
                self:vpn_action("start")
            end
        end
        return
    end

    if key == "escape" then
        if self.tab ~= "auth" then
            self.tab = "auth"
        else
            love.event.quit()
        end
    end
end

return auth_qr