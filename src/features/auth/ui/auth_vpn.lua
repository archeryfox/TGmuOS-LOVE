-- src/features/auth/ui/auth_vpn.lua
-- Extracted from auth_screen.lua - VPN settings tab

local ui = require("src.shared.ui.ui_kit")

local auth_vpn = {}

function auth_vpn.new(fonts, tg)
    local self = {}
    self.fonts = fonts
    self.tg = tg
    self.vpn_status = "disconnected"
    self.vpn_latency = nil
    self.vpn_error = nil
    self.vpn_servers = {}
    self.vpn_selected = 1
    self.vpn_first_row = 0
    self.vpn_action_idx = 1
    return setmetatable(self, {__index = auth_vpn})
end

function auth_vpn:enter()
    self:load_vpn_config()
    self:update_vpn_status()
end

function auth_vpn:load_vpn_config()
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
    local handle = io.open(sub_file, "r")
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
end

function auth_vpn:update_vpn_status()
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

function auth_vpn:vpn_action(action)
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

function auth_vpn:draw(w, h, f, colors)
    local y = 90
    ui.printf("VPN (muVPN / sing-box / VLESS Reality)", 80, y, w - 160, "center", f.subtitle, colors.text)
    y = y + 40

    local status_color = (self.vpn_status == "connected") and colors.green or colors.red
    ui.text("Статус: " .. (self.vpn_status == "connected" and "Подключено" or "Отключено"), 100, y, f.normal, status_color)
    if self.vpn_latency then
        ui.text("Пинг: " .. self.vpn_latency .. " ms", 350, y, f.small, colors.muted)
    end
    if self.vpn_error then
        ui.text("Ошибка: " .. self.vpn_error, 100, y + 25, f.small, colors.red)
    end
    y = y + 55

    local actions = {"Подключить", "Отключить", "Обновить подписку", "Проверить здоровье", "Использовать для Telegram"}
    for i, a in ipairs(actions) do
        local sel = (i == self.vpn_action_idx)
        ui.rect(80, y, w - 160, 36, sel and colors.accent or colors.panel, 6)
        ui.outline(80, y, w - 160, 36, sel and colors.text or colors.muted, 6)
        ui.text(a, 90, y + 8, f.normal, sel and colors.bg or colors.text)
        y = y + 42
    end

    y = y + 10
    ui.printf("Серверы подписки:", 80, y, w - 160, "left", f.small, colors.muted)
    y = y + 25

    local visible = 5
    for idx = self.vpn_first_row + 1, math.min(self.vpn_first_row + visible, #self.vpn_servers) do
        local s = self.vpn_servers[idx]
        if not s then break end
        local sel = (idx == self.vpn_selected)
        ui.rect(80, y, w - 160, 32, sel and colors.accent or colors.panel, 4)
        ui.outline(80, y, w - 160, 32, sel and colors.text or colors.muted, 4)
        ui.text(s.name .. " (" .. s.country .. ")", 90, y + 6, f.normal, sel and colors.bg or colors.text)
        y = y + 36
    end

    y = h - 60
    ui.printf("↑/↓ — действие/сервер | A — выполнить | ← — назад", 80, y, w - 160, "center", f.tiny, colors.muted)
end

function auth_vpn:keypressed(key)
    if key == "up" then
        if self.vpn_action_idx > 1 then
            self.vpn_action_idx = self.vpn_action_idx - 1
        else
            if self.vpn_selected > 1 then self.vpn_selected = self.vpn_selected - 1 end
            if self.vpn_selected <= self.vpn_first_row then self.vpn_first_row = self.vpn_first_row - 1 end
        end
    elseif key == "down" then
        if self.vpn_action_idx < 5 then
            self.vpn_action_idx = self.vpn_action_idx + 1
        else
            if self.vpn_selected < #self.vpn_servers then self.vpn_selected = self.vpn_selected + 1 end
            if self.vpn_selected > self.vpn_first_row + 4 then self.vpn_first_row = self.vpn_first_row + 1 end
        end
    elseif key == "a" or key == "return" then
        local actions = {"start", "stop", "refresh", "health", "select"}
        if self.vpn_action_idx <= #actions then
            self:vpn_action(actions[self.vpn_action_idx])
        end
        if self.vpn_action_idx == 5 then
            self.tg.proxy_enabled = false
            self.conn_mode = "vpn"
            self:vpn_action("start")
        end
    end
end

return auth_vpn