local ui = require("src.shared.ui.ui_kit")
local performance = require("src.shared.system.performance")

local settings_screen = {}
local ACCOUNT_ROW_HEIGHT = 28
local VISIBLE_ACCOUNTS = 3

function settings_screen.new(fonts, tg, callbacks)
    local self = {
        fonts = fonts,
        tg = tg,
        callbacks = callbacks or {},
        scale = ui.get_scale(),
        hovered_item = "scale",
        selected_item = 1,
        account_scroll = 0,
        logout_confirm = false,
    }
    return setmetatable(self, {__index = settings_screen})
end

function settings_screen:accounts()
    if self.callbacks.accounts then return self.callbacks.accounts() end
    return {}, nil
end

function settings_screen:abxy_layout()
    if self.callbacks.abxy_layout then return self.callbacks.abxy_layout() end
    return "modern"
end

function settings_screen:toggle_abxy()
    if self.callbacks.toggle_abxy then self.callbacks.toggle_abxy() end
end

function settings_screen:items()
    local accounts = self:accounts()
    local items = {{id = "exit_app"}}
    items[#items + 1] = {id = "scale"}
    items[#items + 1] = {id = "performance"}
    items[#items + 1] = {id = "vsync"}
    items[#items + 1] = {id = "abxy"}
    for _, account in ipairs(accounts) do
        items[#items + 1] = {id = "account:" .. account.key, account = account}
    end
    items[#items + 1] = {id = "add_account"}
    items[#items + 1] = {id = "logout"}
    return items
end

function settings_screen:enter()
    self.scale = ui.get_scale()
    self.hovered_item = "exit_app"
    self.selected_item = 1
    self.logout_confirm = false
end

function settings_screen:draw()
    local f, colors = self.fonts, ui.colors
    local w, h = ui.width(), ui.height()
    local accounts, active_key = self:accounts()
    local items = self:items()

    ui.rect(0, 0, w, h, colors.bg)
    ui.rect(0, 0, w, 56, colors.header)
    ui.text("Настройки", 24, 15, f.subtitle, colors.text)
    ui.text("Esc — назад", w - 140, 18, f.tiny, colors.muted)

    -- Exit App button (first)
    local exit_y = 70
    local exit_bg = self.hovered_item == "exit_app" and colors.red or colors.panel_alt
    ui.rect(40, exit_y, w - 80, 38, exit_bg, 8)
    ui.text("Выйти из приложения", 60, exit_y + 9, f.normal, self.hovered_item == "exit_app" and colors.bg or colors.text)
    self.exit_button = {x = 40, y = exit_y, w = w - 80, h = 38}

    local scale_y, item_h = exit_y + 46, 34
    local scale_bg = self.hovered_item == "scale" and colors.accent or colors.panel_alt
    ui.rect(40, scale_y, w - 80, item_h, scale_bg, 8)
    ui.text("Масштаб экрана", 60, scale_y + 7, f.normal, colors.text)
    ui.text(string.format("%.1f x", self.scale), w - 100, scale_y + 7, f.small, colors.text)
    ui.text("Применяется сразу", 60, scale_y + item_h + 1, f.tiny, colors.muted)
    self.scale_button = {x = 40, y = scale_y, w = w - 80, h = item_h}

    local perf_y = scale_y + item_h + 16
    local perf_bg = self.hovered_item == "performance" and colors.accent or colors.panel_alt
    local perf_mode = performance.get_mode()
    ui.rect(40, perf_y, w - 80, item_h, perf_bg, 8)
    ui.text("Производительность", 60, perf_y + 7, f.normal, colors.text)
    ui.text(perf_mode == "eco" and "Eco · 30 FPS" or "Performance · 60 FPS",
        w - 190, perf_y + 7, f.small, colors.text)
    ui.text("←/→ — переключить", 60, perf_y + item_h + 1, f.tiny, colors.muted)
    self.performance_button = {x = 40, y = perf_y, w = w - 80, h = item_h}

    local vsync_y = perf_y + item_h + 16
    local half_gap = 12
    local half_w = math.floor((w - 80 - half_gap) / 2)
    local vsync_bg = self.hovered_item == "vsync" and colors.accent or colors.panel_alt
    ui.rect(40, vsync_y, half_w, item_h, vsync_bg, 8)
    ui.text("VSync", 56, vsync_y + 7, f.normal, colors.text)
    ui.text(performance.get_vsync() and "Вкл" or "Выкл", 40 + half_w - 54, vsync_y + 7, f.small, colors.text)
    self.vsync_button = {x = 40, y = vsync_y, w = half_w, h = item_h}

    local abxy_x = 40 + half_w + half_gap
    local abxy_bg = self.hovered_item == "abxy" and colors.accent or colors.panel_alt
    ui.rect(abxy_x, vsync_y, half_w, item_h, abxy_bg, 8)
    ui.text("Кнопки ABXY", abxy_x + 16, vsync_y + 7, f.normal, colors.text)
    ui.text(self:abxy_layout() == "retro" and "Retro" or "Modern",
        abxy_x + half_w - 76, vsync_y + 7, f.small, colors.text)
    self.abxy_button = {x = abxy_x, y = vsync_y, w = half_w, h = item_h}
    ui.text("←/→ — переключить", 56, vsync_y + item_h + 1, f.tiny, colors.muted)

    local label_y = vsync_y + item_h + 18
    ui.text(#accounts > VISIBLE_ACCOUNTS and "Аккаунты · колесо мыши для списка" or "Сохранённые аккаунты",
        44, label_y, f.small, colors.text)
    self.account_bounds = {}
    local account_y = label_y + 24
    self.account_list_bounds = {x = 40, y = account_y, w = w - 80, h = VISIBLE_ACCOUNTS * ACCOUNT_ROW_HEIGHT}
    for visible_index = 1, VISIBLE_ACCOUNTS do
        local account_index = self.account_scroll + visible_index
        local account = accounts[account_index]
        if account then
            local y = account_y + (visible_index - 1) * ACCOUNT_ROW_HEIGHT
            local id = "account:" .. account.key
            local selected = self.hovered_item == id
            local background = selected and colors.accent or colors.panel_alt
            ui.rect(40, y, w - 80, ACCOUNT_ROW_HEIGHT - 2, background, 6)
            ui.text(ui.fit(account.title or "Аккаунт", f.small, w - 190), 54, y + 2, f.small, colors.text)
            local status = account.key == active_key and "активен"
                or account.authorized and "сохранён" or "не авторизован"
            ui.text(status, w - 150, y + 4, f.tiny, account.key == active_key and colors.green or colors.muted)
            self.account_bounds[id] = {x = 40, y = y, w = w - 80, h = ACCOUNT_ROW_HEIGHT - 2}
        end
    end

    local add_y = account_y + VISIBLE_ACCOUNTS * ACCOUNT_ROW_HEIGHT + 3
    local add_bg = self.hovered_item == "add_account" and colors.accent or colors.panel_alt
    ui.rect(40, add_y, w - 80, 30, add_bg, 7)
    ui.text("+ Добавить аккаунт", 54, add_y + 5, f.small, colors.text)
    self.add_button = {x = 40, y = add_y, w = w - 80, h = 30}

    local logout_y = add_y + 36
    local logout_label = self.logout_confirm and "Подтвердить выход из аккаунта" or "Выйти из аккаунта"
    local logout_bg = self.hovered_item == "logout" and colors.red or colors.panel_alt
    ui.rect(40, logout_y, w - 80, 34, logout_bg, 8)
    ui.text(logout_label, 54, logout_y + 7, f.small, colors.text)
    self.logout_button = {x = 40, y = logout_y, w = w - 80, h = 34}

    local status = self.tg.action_error ~= "" and self.tg.action_error or self.tg.action_status
    if status and status ~= "" then
        ui.text(ui.fit(status, f.tiny, w - 80), 44, logout_y + 38, f.tiny,
            self.tg.action_error ~= "" and colors.red or colors.muted)
    end
    ui.text("↑/↓ — выбор, ←/→ — значение, Enter — применить, MENU — назад", 24, 56, f.tiny, colors.muted)
    self.items_cache = items
end

function settings_screen:activate_item(item)
    if not item then return end
    if item.id == "exit_app" then
        love.event.quit()
    elseif item.id:match("^account:") then
        local key = item.id:sub(9)
        local _, active_key = self:accounts()
        if key ~= active_key and self.callbacks.switch_account then
            self.callbacks.switch_account(key)
        end
    elseif item.id == "add_account" then
        if self.callbacks.add_account then self.callbacks.add_account() end
    elseif item.id == "logout" then
        if self.logout_confirm then
            if self.tg:log_out() then self.logout_confirm = false end
        else
            self.logout_confirm = true
        end
    elseif item.id == "scale" then
        ui.set_scale(self.scale)
    elseif item.id == "performance" then
        performance.toggle()
    elseif item.id == "vsync" then
        performance.toggle_vsync()
    elseif item.id == "abxy" then
        self:toggle_abxy()
    end
end

function settings_screen:keypressed(key)
    if key == "escape" then return "back" end
    local items = self:items()
    local selected = items[self.selected_item]
    local is_scale_selected = selected and selected.id == "scale"
    local is_performance_selected = selected and selected.id == "performance"
    local is_vsync_selected = selected and selected.id == "vsync"
    local is_abxy_selected = selected and selected.id == "abxy"

    if key == "up" or key == "down" then
        local direction = key == "down" and 1 or -1
        self.selected_item = math.max(1, math.min(#items, self.selected_item + direction))
        selected = items[self.selected_item]
        self.hovered_item = selected and selected.id or "scale"
        local account_index = self.hovered_item:match("^account:")
        if account_index then
            local key_name = self.hovered_item:sub(9)
            local accounts = self:accounts()
            for index, account in ipairs(accounts) do
                if account.key == key_name then
                    self.account_scroll = math.max(0, math.min(#accounts - VISIBLE_ACCOUNTS, index - VISIBLE_ACCOUNTS + 1))
                    break
                end
            end
        end
    elseif key == "left" or key == "right" then
        if is_scale_selected then
            local direction = key == "right" and 0.1 or -0.1
            self.scale = math.max(0.7, math.min(2.0, self.scale + direction))
        elseif is_performance_selected then
            performance.toggle()
        elseif is_vsync_selected then
            performance.toggle_vsync()
        elseif is_abxy_selected then
            self:toggle_abxy()
        end
    elseif key == "kpplus" or key == "+" or key == "=" then
        if is_scale_selected then
            self.scale = math.min(2.0, self.scale + 0.1)
        end
    elseif key == "kpminus" or key == "-" then
        if is_scale_selected then
            self.scale = math.max(0.7, self.scale - 0.1)
        end
    elseif key == "return" or key == "kpenter" then
        if is_scale_selected then
            ui.set_scale(self.scale)
        elseif is_performance_selected then
            performance.toggle()
        elseif is_vsync_selected then
            performance.toggle_vsync()
        elseif is_abxy_selected then
            self:toggle_abxy()
        else
            self:activate_item(items[self.selected_item])
        end
    end
end

function settings_screen:wheelmoved(_, y)
    if not self.account_list_bounds then return end
    local x, mouse_y = love.mouse.getPosition()
    local bounds = self.account_list_bounds
    if x >= bounds.x and x <= bounds.x + bounds.w and mouse_y >= bounds.y
        and mouse_y <= bounds.y + bounds.h then
        local accounts = self:accounts()
        self.account_scroll = math.max(0, math.min(math.max(0, #accounts - VISIBLE_ACCOUNTS), self.account_scroll - y))
    end
end

function settings_screen:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.exit_button and x >= self.exit_button.x and x <= self.exit_button.x + self.exit_button.w
        and y >= self.exit_button.y and y <= self.exit_button.y + self.exit_button.h then
        self.hovered_item = "exit_app"
        self:activate_item({id = "exit_app"})
        return
    end
    if self.logout_button and x >= self.logout_button.x and x <= self.logout_button.x + self.logout_button.w
        and y >= self.logout_button.y and y <= self.logout_button.y + self.logout_button.h then
        self.hovered_item = "logout"
        self:activate_item({id = "logout"})
        return
    end
    if self.add_button and x >= self.add_button.x and x <= self.add_button.x + self.add_button.w
        and y >= self.add_button.y and y <= self.add_button.y + self.add_button.h then
        self.hovered_item = "add_account"
        self:activate_item({id = "add_account"})
        return
    end
    for id, bounds in pairs(self.account_bounds or {}) do
        if x >= bounds.x and x <= bounds.x + bounds.w and y >= bounds.y and y <= bounds.y + bounds.h then
            self.hovered_item = id
            self:activate_item({id = id})
            return
        end
    end
    if self.scale_button and x >= self.scale_button.x and x <= self.scale_button.x + self.scale_button.w
        and y >= self.scale_button.y and y <= self.scale_button.y + self.scale_button.h then
        if x < ui.width() / 2 then
            self.scale = math.max(0.7, self.scale - 0.1)
        else
            self.scale = math.min(2.0, self.scale + 0.1)
        end
        ui.set_scale(self.scale)
        return
    end
    if self.performance_button and x >= self.performance_button.x
        and x <= self.performance_button.x + self.performance_button.w
        and y >= self.performance_button.y and y <= self.performance_button.y + self.performance_button.h then
        performance.toggle()
        return
    end
    if self.vsync_button and x >= self.vsync_button.x
        and x <= self.vsync_button.x + self.vsync_button.w
        and y >= self.vsync_button.y and y <= self.vsync_button.y + self.vsync_button.h then
        performance.toggle_vsync()
        return
    end
    if self.abxy_button and x >= self.abxy_button.x
        and x <= self.abxy_button.x + self.abxy_button.w
        and y >= self.abxy_button.y and y <= self.abxy_button.y + self.abxy_button.h then
        self:toggle_abxy()
        return
    end
    if self.logout_confirm then self.logout_confirm = false end
end

function settings_screen:textinput() end

return settings_screen
