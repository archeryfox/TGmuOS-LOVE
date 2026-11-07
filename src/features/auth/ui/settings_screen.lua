local ui = require("src.shared.ui.ui_kit")
local performance = require("src.shared.system.performance")
local media_settings = require("src.shared.system.media_settings")

local settings_screen = {}
local ACCOUNT_ROW_HEIGHT = 28
local VISIBLE_ACCOUNTS = 3
local ITEM_HEIGHT = 34
local VISIBLE_ITEMS = 8

function settings_screen.new(fonts, tg, callbacks)
    local self = {
        fonts = fonts,
        tg = tg,
        callbacks = callbacks or {},
        scale = ui.get_scale(),
        hovered_item = "exit_app",
        selected_item = 1,
        scroll_offset = 0,
        account_scroll = 0,
        logout_confirm = false,
        vpn_restarting = false,
        vpn_spinner = 0,
        tg_push_enabled = false,
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
    items[#items + 1] = {id = "autoplay_videos"}
    items[#items + 1] = {id = "autoplay_stickers"}
    items[#items + 1] = {id = "autoplay_animated"}
    items[#items + 1] = {id = "autoplay_images"}
    items[#items + 1] = {id = "autoplay_circles"}
    items[#items + 1] = {id = "autoload"}
items[#items + 1] = {id = "vsync"}
items[#items + 1] = {id = "vibration_test"}
items[#items + 1] = {id = "minimize"}
items[#items + 1] = {id = "abxy"}
    items[#items + 1] = {id = "vpn"}
    items[#items + 1] = {id = "tg_push"}
    for _, account in ipairs(accounts) do
        items[#items + 1] = {id = "account:" .. account.key, account = account}
    end
    items[#items + 1] = {id = "add_account"}
    items[#items + 1] = {id = "logout"}
    return items
end

function settings_screen:enter()
    self.scale = ui.get_scale()
    self.hovered_item = "scale"
    self.selected_item = 1
    self.logout_confirm = false
    media_settings.load()
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

    local item_h = ITEM_HEIGHT
    local start_y = 70
    local content_h = h - start_y - 40
    local max_items_visible = math.floor(content_h / (item_h + 12))
    local max_visible = math.max(1, math.min(#items, max_items_visible))

    self:clamp_scroll(#items, max_visible)

    ui.rect(0, 0, w, h, colors.bg)
    ui.rect(0, 0, w, 56, colors.header)
    ui.text("Настройки", 24, 15, f.subtitle, colors.text)
    ui.text("Esc — назад", w - 140, 18, f.tiny, colors.muted)

    local first_visible = self.scroll_offset + 1
    local last_visible = math.min(#items, self.scroll_offset + max_visible)

    for idx = first_visible, last_visible do
        local item = items[idx]
        local display_idx = idx - self.scroll_offset
        local y = start_y + (display_idx - 1) * (item_h + 12)
        local selected = self.selected_item == idx
        local is_scale = item.id == "scale"
        local is_performance = item.id == "performance"
local is_vsync = item.id == "vsync"
local is_vibration_test = item.id == "vibration_test"
local is_minimize = item.id == "minimize"
local is_abxy = item.id == "abxy"
        local is_vpn = item.id == "vpn"
        local is_tg_push = item.id == "tg_push"
        local is_account = item.id and item.id:match("^account:")
        local is_exit = item.id == "exit_app"
        local is_add = item.id == "add_account"
        local is_logout = item.id == "logout"

        local bg = selected and colors.accent or colors.panel_alt
        if is_exit then bg = selected and colors.red or colors.panel_alt end
        if is_logout then bg = selected and colors.red or colors.panel_alt end
        if self.vpn_restarting and is_vpn then bg = colors.panel_alt end

        ui.rect(40, y, w - 80, item_h, bg, 8)

        if is_exit then
            ui.text("Выйти из приложения", 60, y + 9, f.normal, selected and colors.bg or colors.text)
            self.exit_button = {x = 40, y = y, w = w - 80, h = item_h}
        elseif is_scale then
            ui.text("Масштаб экрана", 60, y + 7, f.normal, colors.text)
            ui.text(string.format("%.1f x", self.scale), w - 100, y + 7, f.small, colors.text)
            ui.text("←/→ — изменить, Enter — применить", 60, y + item_h + 1, f.tiny, colors.muted)
            self.scale_button = {x = 40, y = y, w = w - 80, h = item_h}
        elseif is_performance then
            local perf_mode = performance.get_mode()
            ui.text("Производительность", 60, y + 7, f.normal, colors.text)
            ui.text(perf_mode == "minimum" and "Minimum" or perf_mode == "balance" and "Balance" or perf_mode == "performance" and "Performance" or "Maximum",
                w - 190, y + 7, f.small, colors.text)
            ui.text("←/→ — переключить", 60, y + item_h + 1, f.tiny, colors.muted)
            self.performance_button = {x = 40, y = y, w = w - 80, h = item_h}
        elseif item.id == "autoplay_videos" then
            ui.text("Автоплей видео", 60, y + 7, f.normal, colors.text)
            ui.text(media_settings.get("autoplay_videos") and "Вкл" or "Выкл", w - 110, y + 7, f.small, media_settings.get("autoplay_videos") and colors.green or colors.muted)
            ui.text("←/→ — переключить", 60, y + item_h + 1, f.tiny, colors.muted)
            self.autoplay_videos_button = {x = 40, y = y, w = w - 80, h = item_h}
        elseif item.id == "autoplay_stickers" then
            ui.text("Автоплей стикеров", 60, y + 7, f.normal, colors.text)
            ui.text(media_settings.get("autoplay_stickers") and "Вкл" or "Выкл", w - 110, y + 7, f.small, media_settings.get("autoplay_stickers") and colors.green or colors.muted)
            ui.text("←/→ — переключить", 60, y + item_h + 1, f.tiny, colors.muted)
            self.autoplay_stickers_button = {x = 40, y = y, w = w - 80, h = item_h}
        elseif item.id == "autoplay_animated" then
            ui.text("Автоплей аним. стикеров", 60, y + 7, f.normal, colors.text)
            ui.text(media_settings.get("autoplay_animated_stickers") and "Вкл" or "Выкл", w - 110, y + 7, f.small, media_settings.get("autoplay_animated_stickers") and colors.green or colors.muted)
            ui.text("←/→ — переключить", 60, y + item_h + 1, f.tiny, colors.muted)
            self.autoplay_animated_button = {x = 40, y = y, w = w - 80, h = item_h}
        elseif item.id == "autoplay_images" then
            ui.text("Автоплей изображений", 60, y + 7, f.normal, colors.text)
            ui.text(media_settings.get("autoplay_images") and "Вкл" or "Выкл", w - 110, y + 7, f.small, media_settings.get("autoplay_images") and colors.green or colors.muted)
            ui.text("←/→ — переключить", 60, y + item_h + 1, f.tiny, colors.muted)
            self.autoplay_images_button = {x = 40, y = y, w = w - 80, h = item_h}
        elseif item.id == "autoplay_circles" then
            ui.text("Автоплей кружков", 60, y + 7, f.normal, colors.text)
            ui.text(media_settings.get("autoplay_circles") and "Вкл" or "Выкл", w - 110, y + 7, f.small, media_settings.get("autoplay_circles") and colors.green or colors.muted)
            ui.text("←/→ — переключить", 60, y + item_h + 1, f.tiny, colors.muted)
            self.autoplay_circles_button = {x = 40, y = y, w = w - 80, h = item_h}
        elseif item.id == "autoload" then
            ui.text("Автозагрузка медиа", 60, y + 7, f.normal, colors.text)
            ui.text(media_settings.get("autoload") and "Вкл" or "Выкл", w - 110, y + 7, f.small, media_settings.get("autoload") and colors.green or colors.muted)
            ui.text("←/→ — переключить", 60, y + item_h + 1, f.tiny, colors.muted)
            self.autoload_button = {x = 40, y = y, w = w - 80, h = item_h}
        elseif is_vsync then
            local half_gap = 12
            local half_w = math.floor((w - 80 - half_gap) / 2)
            ui.text("VSync", 56, y + 7, f.normal, colors.text)
            ui.text(performance.get_vsync() and "Вкл" or "Выкл", 40 + half_w - 54, y + 7, f.small, colors.text)
            self.vsync_button = {x = 40, y = y, w = half_w, h = item_h}
        elseif is_vibration_test then
            ui.text("Тест вибрации", 60, y + 7, f.normal, colors.text)
            ui.text("Enter — вибрировать", w - 200, y + 7, f.small, colors.muted)
            self.vibration_test_button = {x = 40, y = y, w = w - 80, h = item_h}
        elseif is_minimize then
            ui.text("Выйти в меню muOS", 60, y + 7, f.normal, colors.text)
            ui.text("Enter — свернуть", w - 180, y + 7, f.small, colors.muted)
            self.minimize_button = {x = 40, y = y, w = w - 80, h = item_h}
        elseif is_abxy then
            local half_gap = 12
            local half_w = math.floor((w - 80 - half_gap) / 2)
            local abxy_x = 40 + half_w + half_gap
            ui.text("Кнопки ABXY", abxy_x + 16, y + 7, f.normal, colors.text)
            ui.text(self:abxy_layout() == "retro" and "Retro" or "Modern",
                abxy_x + half_w - 76, y + 7, f.small, colors.text)
            self.abxy_button = {x = abxy_x, y = y, w = half_w, h = item_h}
            ui.text("←/→ — переключить", 56, y + item_h + 1, f.tiny, colors.muted)
        elseif is_vpn then
            if self.vpn_restarting then
                -- White spinner on the right side
                local cx = w - 70
                local cy = y + item_h / 2
                local radius = 10
                local angle = self.vpn_spinner
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.setLineWidth(3)
                love.graphics.arc("line", cx, cy, radius, angle, angle + math.pi * 1.5)
                love.graphics.setLineWidth(1)
                ui.text("VPN перезапуск...", 60, y + 7, f.small, colors.text)
            else
                local vpn_status = self.callbacks.get_vpn_status and self.callbacks.get_vpn_status() or "—"
                ui.text("VPN / Прокси", 60, y + 7, f.normal, colors.text)
                ui.text(vpn_status .. "   A — перезапустить", w - 180, y + 7, f.small, colors.muted)
            end
            self.vpn_button = {x = 40, y = y, w = w - 80, h = item_h}
        elseif is_tg_push then
            ui.text("TG-push сервис", 60, y + 7, f.normal, colors.text)
            ui.text(self.tg_push_enabled and "Включен" or "Выключен", w - 130, y + 7, f.small, self.tg_push_enabled and colors.green or colors.muted)
            ui.text("←/→ — переключить", 60, y + item_h + 1, f.tiny, colors.muted)
            self.tg_push_button = {x = 40, y = y, w = w - 80, h = item_h}
        elseif is_account then
            local account = item.account
            ui.text(ui.fit(account.title or "Аккаунт", f.small, w - 190), 54, y + 2, f.small, colors.text)
            local status = account.key == active_key and "активен"
                or account.authorized and "сохранён" or "не авторизован"
            ui.text(status, w - 150, y + 4, f.tiny, account.key == active_key and colors.green or colors.muted)
            self.account_bounds[item.id] = {x = 40, y = y, w = w - 80, h = item_h - 2}
        elseif is_add then
            ui.text("+ Добавить аккаунт", 54, y + 5, f.small, colors.text)
            self.add_button = {x = 40, y = y, w = w - 80, h = 30}
        elseif is_logout then
            local logout_label = self.logout_confirm and "Подтвердить выход из аккаунта" or "Выйти из аккаунта"
            ui.text(logout_label, 54, y + 7, f.small, colors.text)
            self.logout_button = {x = 40, y = y, w = w - 80, h = 34}
        end
    end

    local status = self.tg.action_error ~= "" and self.tg.action_error or self.tg.action_status
    if status and status ~= "" then
        local status_y = start_y + (last_visible - first_visible + 1) * (item_h + 12) + 10
        ui.text(ui.fit(status, f.tiny, w - 80), 44, status_y, f.tiny,
            self.tg.action_error ~= "" and colors.red or colors.muted)
    end

    local hint_y = h - 30
    ui.text("↑/↓ — выбор, ←/→ — значение, Enter — применить, MENU — назад", 24, hint_y, f.tiny, colors.muted)

    if #items > max_visible then
        local scroll_h = content_h
        local thumb_h = math.max(20, scroll_h * max_visible / #items)
        local thumb_y = start_y + (self.scroll_offset / math.max(1, #items - max_visible)) * (scroll_h - thumb_h)
        ui.rect(w - 16, start_y, 8, scroll_h, colors.panel, 4)
        ui.rect(w - 16, thumb_y, 8, thumb_h, colors.accent, 4)
    end

    if self.vpn_restarting then
        self.vpn_spinner = (self.vpn_spinner + 0.1) % (math.pi * 2)
    end
    self.items_cache = items
end

function settings_screen:clamp_scroll(total_items, max_visible)
    local max_scroll = math.max(0, total_items - max_visible)
    self.scroll_offset = math.max(0, math.min(max_scroll, self.scroll_offset))
    if self.selected_item <= self.scroll_offset then
        self.scroll_offset = self.selected_item - 1
    elseif self.selected_item > self.scroll_offset + max_visible then
        self.scroll_offset = self.selected_item - max_visible
    end
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
    elseif item.id == "vibration_test" then
        local ok = false
        if love.system and love.system.vibrate then
            local s, e = pcall(love.system.vibrate, 0.5)
            if s then ok = true end
        end
        if not ok then
            for _, j in ipairs(love.joystick.getJoysticks()) do
                local s = pcall(function() j:setVibration(1, 1, 0.5) end)
                if s then ok = true; break end
            end
        end
        if ok then
            self.tg.action_status = "Вибрация отправлена"
        else
            self.tg.action_error = "Вибрация недоступна (нет API)"
        end
    elseif item.id == "minimize" then
        if love.event and love.event.quit then
            love.event.quit()
            self.tg.action_status = "Приложение свёрнуто"
        end
    elseif item.id == "abxy" then
        self:toggle_abxy()
    elseif item.id == "vpn" then
        if not self.vpn_restarting and self.callbacks.restart_vpn then
            self.vpn_restarting = true
            self.vpn_spinner = 0
            self.callbacks.restart_vpn(function()
                self.vpn_restarting = false
            end)
        end
    elseif item.id == "tg_push" then
        self.tg_push_enabled = not self.tg_push_enabled
        if self.callbacks.set_tg_push then
            self.callbacks.set_tg_push(self.tg_push_enabled)
        end
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
    local is_vpn_selected = selected and selected.id == "vpn"
    local is_tg_push_selected = selected and selected.id == "tg_push"

    if key == "up" or key == "down" then
        local direction = key == "down" and 1 or -1
        self.selected_item = math.max(1, math.min(#items, self.selected_item + direction))
        self:clamp_scroll(#items, math.floor((ui.height() - 110) / 46))
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
        elseif selected and selected.id == "autoplay_videos" then
            media_settings.toggle("autoplay_videos")
        elseif selected and selected.id == "autoplay_stickers" then
            media_settings.toggle("autoplay_stickers")
        elseif selected and selected.id == "autoplay_animated" then
            media_settings.toggle("autoplay_animated_stickers")
        elseif selected and selected.id == "autoplay_images" then
            media_settings.toggle("autoplay_images")
        elseif selected and selected.id == "autoplay_circles" then
            media_settings.toggle("autoplay_circles")
        elseif selected and selected.id == "autoload" then
            media_settings.toggle("autoload")
        elseif is_vsync_selected then
            performance.toggle_vsync()
        elseif is_abxy_selected then
            self:toggle_abxy()
        elseif is_vpn_selected and not self.vpn_restarting and self.callbacks.restart_vpn then
            self.vpn_restarting = true
            self.vpn_spinner = 0
            self.callbacks.restart_vpn(function()
                self.vpn_restarting = false
            end)
        elseif is_tg_push_selected then
            self.tg_push_enabled = not self.tg_push_enabled
            if self.callbacks.set_tg_push then
                self.callbacks.set_tg_push(self.tg_push_enabled)
            end
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
        elseif selected and selected.id == "autoplay_videos" then
            media_settings.toggle("autoplay_videos")
        elseif selected and selected.id == "autoplay_stickers" then
            media_settings.toggle("autoplay_stickers")
        elseif selected and selected.id == "autoplay_animated" then
            media_settings.toggle("autoplay_animated_stickers")
        elseif selected and selected.id == "autoplay_images" then
            media_settings.toggle("autoplay_images")
        elseif selected and selected.id == "autoplay_circles" then
            media_settings.toggle("autoplay_circles")
        elseif selected and selected.id == "autoload" then
            media_settings.toggle("autoload")
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
    local items = self:items()
    local max_visible = math.floor((ui.height() - 110) / 46)
    self.scroll_offset = math.max(0, math.min(math.max(0, #items - max_visible), self.scroll_offset - y))
    self:clamp_scroll(#items, max_visible)
end

function settings_screen:mousepressed(x, y, button)
    if button ~= 1 then return end
    local items = self:items()
    local max_visible = math.floor((ui.height() - 110) / 46)
    local start_y = 70
    local item_h = ITEM_HEIGHT

    for idx = self.scroll_offset + 1, math.min(#items, self.scroll_offset + max_visible) do
        local item = items[idx]
        local display_idx = idx - self.scroll_offset
        local y_pos = start_y + (display_idx - 1) * (item_h + 12)
        local bounds = {x = 40, y = y_pos, w = ui.width() - 80, h = item_h}

        if x >= bounds.x and x <= bounds.x + bounds.w and y >= bounds.y and y <= bounds.y + bounds.h then
            self.selected_item = idx
            self.hovered_item = item.id
            if item.id == "exit_app" then
                self:activate_item({id = "exit_app"})
            elseif item.id == "logout" then
                self:activate_item({id = "logout"})
            elseif item.id == "add_account" then
                self:activate_item({id = "add_account"})
            elseif item.id:match("^account:") then
                self:activate_item({id = item.id})
            elseif item.id == "scale" then
                if x < ui.width() / 2 then
                    self.scale = math.max(0.7, self.scale - 0.1)
                else
                    self.scale = math.min(2.0, self.scale + 0.1)
                end
                ui.set_scale(self.scale)
            elseif item.id == "performance" then
                performance.toggle()
            elseif item.id == "vsync" then
                performance.toggle_vsync()
            elseif item.id == "vibration_test" then
                local ok = false
                if love.system and love.system.vibrate then
                    local s = pcall(love.system.vibrate, 0.5)
                    if s then ok = true end
                end
                if not ok then
                    for _, j in ipairs(love.joystick.getJoysticks()) do
                        local s = pcall(function() j:setVibration(1, 1, 0.5) end)
                        if s then ok = true; break end
                    end
                end
                if ok then
                    self.tg.action_status = "Вибрация отправлена"
                else
                    self.tg.action_error = "Вибрация недоступна (нет API)"
                end
            elseif item.id == "minimize" then
                if love.event and love.event.quit then
                    love.event.quit()
                    self.tg.action_status = "Приложение свёрнуто"
                end
            elseif item.id == "abxy" then
                self:toggle_abxy()
            elseif item.id == "vpn" and not self.vpn_restarting and self.callbacks.restart_vpn then
                self.vpn_restarting = true
                self.vpn_spinner = 0
                self.callbacks.restart_vpn(function()
                    self.vpn_restarting = false
                end)
            elseif item.id == "tg_push" then
                self.tg_push_enabled = not self.tg_push_enabled
                if self.callbacks.set_tg_push then
                    self.callbacks.set_tg_push(self.tg_push_enabled)
                end
            end
            return
        end
    end

    if self.logout_confirm then self.logout_confirm = false end
end

function settings_screen:textinput() end

return settings_screen
