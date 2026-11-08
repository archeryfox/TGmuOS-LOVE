-- src/features/auth/ui/auth_screen.lua — экран авторизации (QR + 2FA)
local ui = require("src.shared.ui.ui_kit")
local qr = require("src.shared.lib.qr")
local auth_model = require("src.features.auth.model.auth_model")
local utf8 = require("utf8")
local tg_process = require("src.shared.system.tg_process")

local auth_screen = {}

local function key_chars(list)
    local out = {}
    for _, ch in ipairs(list) do
        out[#out + 1] = {ch = ch}
    end
    return out
end

function auth_screen.new(fonts, tg, callbacks)
    local self = {}
    self.fonts = fonts
    self.tg = tg
    self.callbacks = callbacks or {}
    self.model = auth_model.new(tg)
    self.qr_link = nil
    self.qr_image = nil
    self.qr_size = 0
    self.qr_error = ""
    self.password = ""
    -- Navigation
    self.selected_item = 1
    self.items = {"Авторизация", "Настройки VPN", "Очистить все данные", "Закрыть все процессы ТГ", "Выйти из приложения"}
    self.kb_row = 1
    self.kb_col = 1
    self.account_selected = 1
    self.account_bounds = {}
    self.kb_layer = "abc"
    self.kb_shift = false
    setmetatable(self, {__index = auth_screen})
    self:build_keyboard()
    return self
end

function auth_screen:enter()
    self.password = ""
    self.selected_item = 1
    self.account_selected = 1
    self.was_password_mode = false
    self:reset_keyboard()
end

function auth_screen:update(dt)
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

    local password_mode = self.model:is_password_mode()
    if password_mode and not self.was_password_mode then
        self:reset_keyboard()
    end
    self.was_password_mode = password_mode
end

function auth_screen:draw()
    local f = self.fonts
    local w = ui.width()
    local h = ui.height()
    local colors = ui.colors

    ui.rect(0, 0, w, h, colors.bg)
    ui.rect(0, 0, w, 48, colors.header)
    ui.text("Telegram", 20, 10, f.subtitle, colors.text)
    ui.text("LÖVE + TDLib", w - 150, 15, f.small, colors.muted)

    if self.model:is_password_mode() then
        self:draw_password(w, h)
        return
    end

    local status_y = 60
    if self.model:has_error() then
        ui.printf(self.model:get_error(), 40, 58, w - 80, "center", f.small, colors.red)
        local _, error_lines = f.small:getWrap(self.model:get_error(), w - 80)
        status_y = 58 + math.max(1, #error_lines) * f.small:getHeight() + 6
    end

    ui.printf(self.model:get_status_text(), 40, status_y, w - 80, "center", f.normal, colors.text)

    -- Saved accounts (return to logged-in account)
    local accounts = (self.callbacks and self.callbacks.accounts and self.callbacks.accounts()) or ({})
    local active_key = nil
    local acc_list = accounts[1] or accounts
    -- accounts callback returns (list, active_key)
    local accs, active = {}, nil
    if self.callbacks and self.callbacks.accounts then
        local l, a = self.callbacks.accounts()
        accs = l or {}
        active = a
    end
    local saved = {}
    for _, a in ipairs(accs) do
        if a.authorized then saved[#saved+1] = a end
    end
    local btn_w = 300
    local btn_h = 30
    local gap = 8
    local acc_y = status_y + 10
    if #saved > 0 then
        ui.text("Сохранённые аккаунты:", 40, acc_y, f.small, colors.accent)
        acc_y = acc_y + 22
        self.account_bounds = {}
        for i, acc in ipairs(saved) do
            local x = math.floor((w - btn_w) / 2)
            local y = acc_y + (i - 1) * (btn_h + gap)
            local sel = (i == self.account_selected)
            local bg = sel and colors.accent or colors.panel
            local txt_color = sel and colors.bg or colors.text
            ui.rect(x, y, btn_w, btn_h, bg, 8)
            ui.outline(x, y, btn_w, btn_h, sel and colors.text or colors.muted, 8)
            local label = ui.fit((acc.title or "Аккаунт") .. (acc.key == active and " (активен)" or ""), f.normal, btn_w - 20)
            local tx = x + 10
            local ty = y + math.floor((btn_h - f.normal:getHeight()) / 2)
            ui.text(label, tx, ty, f.normal, txt_color)
            self.account_bounds[i] = {x = x, y = y, w = btn_w, h = btn_h, key = acc.key}
        end
        acc_y = acc_y + #saved * (btn_h + gap) + 8
    end

    -- Menu items
    local menu_h = #self.items * btn_h + (#self.items - 1) * gap
    local menu_y = h - menu_h - 18
    for i, item in ipairs(self.items) do
        local sel = (i == self.selected_item)
        local x = math.floor((w - btn_w) / 2)
        local y = menu_y + (i - 1) * (btn_h + gap)

        local bg = sel and colors.accent or colors.panel
        local txt_color = sel and colors.bg or colors.text
        ui.rect(x, y, btn_w, btn_h, bg, 8)
        ui.outline(x, y, btn_w, btn_h, sel and colors.text or colors.muted, 8)
        local tx = x + math.floor((btn_w - f.normal:getWidth(item)) / 2)
        local ty = y + math.floor((btn_h - f.normal:getHeight()) / 2)
        ui.text(item, tx, ty, f.normal, txt_color)
    end

    if self.qr_image then
        local available = math.min(w * 0.5, h - 300)
        local scale = math.max(2, math.floor(available / (self.qr_size + 8)))
        local total = (self.qr_size + 8) * scale
        local x = math.floor((w - total) / 2)
        local y = 100
        qr.draw(self.qr_image, x, y, scale, 3)

        local ty = y + total + 10
        ui.printf("Откройте Telegram на телефоне", 40, ty, w - 80, "center", f.small, colors.text)
        ui.printf("Настройки → Устройства → Подключить устройство", 40, ty + 18, w - 80, "center", f.tiny, colors.muted)
        ui.printf("Наведите камеру на QR-код", 40, ty + 34, w - 80, "center", f.tiny, colors.muted)
    else
        if self.qr_error ~= "" then
            ui.printf(self.qr_error, 40, 190, w - 80, "center", f.normal, colors.red)
        else
            ui.printf("QR-код ещё не получен", 40, 190, w - 80, "center", f.normal, colors.muted)
            ui.printf("Проверьте подключение к сети и параметры api_id/api_hash", 40, 218, w - 80, "center", f.small, colors.muted)
        end
    end

    ui.text("↑↓ — выбор  A — выбрать  MENU — выход", 20, h - 14, f.tiny, colors.muted)
end

function auth_screen:reset_keyboard()
    self.kb_row = 1
    self.kb_col = 1
    self.kb_layer = "abc"
    self.kb_shift = false
    self:build_keyboard()
end

function auth_screen:build_keyboard()
    local L = {}
    if self.kb_layer == "sym" then
        L[1] = key_chars({"!", "@", "#", "$", "%", "^", "&", "*", "(", ")"})
        L[2] = key_chars({"-", "_", "=", "+", "[", "]", "{", "}", "\\", "|"})
        L[3] = key_chars({";", ":", "'", "\"", ",", ".", "<", ">", "/", "?"})
        L[4] = {{label = "ABC", action = "layer", w = 70}}
        for _, ch in ipairs({"~", "`", "\\", "|"}) do
            L[4][#L[4] + 1] = {ch = ch}
        end
        L[4][#L[4] + 1] = {label = "DEL", action = "backspace", w = 70}
        L[5] = {
            {label = "Пробел", action = "space", w = 200},
            {ch = ","},
            {label = "Ввод", action = "enter", w = 140},
        }
        L[6] = {{label = "Закрыть все процессы ТГ", action = "close_all", w = 400}}
    else
        L[1] = key_chars({"1", "2", "3", "4", "5", "6", "7", "8", "9", "0"})
        L[2] = key_chars({"q", "w", "e", "r", "t", "y", "u", "i", "o", "p"})
        L[3] = key_chars({"a", "s", "d", "f", "g", "h", "j", "k", "l"})
        L[4] = {{label = "SHIFT", action = "shift", w = 70}}
        for _, ch in ipairs({"z", "x", "c", "v", "b", "n", "m"}) do
            L[4][#L[4] + 1] = {ch = ch}
        end
        L[4][#L[4] + 1] = {label = "DEL", action = "backspace", w = 70}
        L[5] = {{label = "?123", action = "layer", w = 70}}
        for _, ch in ipairs({"@", ".", "_", "-", "/", ":", ";", "!", "?"}) do
            L[5][#L[5] + 1] = {ch = ch}
        end
        L[6] = {
            {label = "Пробел", action = "space", w = 200},
            {ch = ","},
            {label = "Ввод", action = "enter", w = 140},
        }
        L[7] = {{label = "Закрыть все процессы ТГ", action = "close_all", w = 400}}
    end
    self.kb_layout = L
    self.kb_row = math.max(1, math.min(self.kb_row or 1, #L))
    local row = L[self.kb_row]
    self.kb_col = math.max(1, math.min(self.kb_col or 1, #row))
end

function auth_screen:move_kb(dr, dc)
    local L = self.kb_layout
    if not L then return end
    if dr ~= 0 then
        self.kb_row = math.max(1, math.min(#L, self.kb_row + dr))
        local row = L[self.kb_row]
        self.kb_col = math.min(self.kb_col, #row)
    elseif dc ~= 0 then
        local row = L[self.kb_row]
        self.kb_col = math.max(1, math.min(#row, self.kb_col + dc))
    end
end

function auth_screen:activate_kb()
    local row = self.kb_layout and self.kb_layout[self.kb_row]
    local k = row and row[self.kb_col]
    if not k then return end
    if k.action == "shift" then
        self.kb_shift = not self.kb_shift
    elseif k.action == "layer" then
        self.kb_layer = (self.kb_layer == "abc") and "sym" or "abc"
        self:build_keyboard()
    elseif k.action == "backspace" then
        self.password = ui.remove_last_utf8(self.password)
    elseif k.action == "space" then
        self.password = self.password .. " "
    elseif k.action == "enter" then
        if self.password ~= "" then
            self.tg:submit_password(self.password)
            self.password = ""
        end
    elseif k.action == "close_all" then
        self:close_all_tg()
    elseif k.ch then
        local ch = k.ch
        if self.kb_layer == "abc" and self.kb_shift and ch:match("%a") then
            ch = ch:upper()
        end
        self.password = self.password .. ch
    end
end

function auth_screen:draw_password(w, h)
    local f = self.fonts
    local colors = ui.colors

    ui.printf("Двухфакторная аутентификация", 40, 58, w - 80, "center", f.subtitle, colors.text)
    if self.model:get_password_hint() ~= "" then
        ui.printf(self.model:get_password_hint(), 40, 84, w - 80, "center", f.small, colors.muted)
    end

    local box_w = math.min(560, w - 80)
    local box_h = 40
    local bx = math.floor((w - box_w) / 2)
    local by = 108
    ui.rect(bx, by, box_w, box_h, colors.panel, 8)
    ui.outline(bx, by, box_w, box_h, colors.accent, 8)
    local shown = "Пароль"
    if #self.password > 0 then
        local count = utf8.len(self.password) or #self.password
        shown = string.rep("•", count)
    end
    local ty = by + math.floor((box_h - f.normal:getHeight()) / 2)
    ui.text(shown, bx + 16, ty, f.normal, #self.password == 0 and colors.muted or colors.text)

    if self.model:has_error() then
        ui.printf(self.model:get_error(), 40, by + box_h + 2, w - 80, "center", f.tiny, colors.red)
    end

    if not self.kb_layout then self:build_keyboard() end
    local L = self.kb_layout
    local key_h = 36
    local gap = 3
    local kb_y = 166
    for r, row in ipairs(L) do
        local total = 0
        for i, k in ipairs(row) do
            total = total + (k.w or 58)
            if i > 1 then total = total + 3 end
        end
        local x = math.floor((w - total) / 2)
        local y = kb_y + (r - 1) * (key_h + gap)
        for c, k in ipairs(row) do
            local kw = k.w or 58
            local label = k.label
            if not label then
                label = k.ch
                if self.kb_layer == "abc" and self.kb_shift and label:match("%a") then
                    label = label:upper()
                end
            end
            local sel = (r == self.kb_row and c == self.kb_col)
            local active = (k.action == "shift" and self.kb_shift)
            local bg, txt, border
            if k.action == "close_all" then
                bg = sel and colors.red or colors.panel
                txt = sel and colors.white or colors.red
                border = colors.red
            else
                bg = sel and colors.accent or (active and colors.header or colors.panel)
                txt = sel and colors.bg or colors.text
                border = sel and colors.text or colors.muted
            end
            ui.rect(x, y, kw, key_h, bg, 6)
            ui.outline(x, y, kw, key_h, border, 6)
            local lw = f.normal:getWidth(label)
            local lx = x + math.floor((kw - lw) / 2)
            local ly = y + math.floor((key_h - f.normal:getHeight()) / 2)
            ui.text(label, lx, ly, f.normal, txt)
            x = x + kw + 3
        end
    end

    ui.text("Стрелки — выбор  A — нажать  B — стереть  Esc — выход", 20, h - 14, f.tiny, colors.muted)
end

function auth_screen:textinput(text)
    if self.model:is_password_mode() then
        self.password = self.password .. text
    end
end

function auth_screen:close_all_tg()
    tg_process.kill_all()
    love.event.quit()
end

function auth_screen:clear_all_data()
    local paths = {
        "/root/.local/share/love/Telegram",
        "/root/.config/Telegram",
        "/mnt/mmc/MUOS/application/Telegram/data",
    }
    for _, path in ipairs(paths) do
        local handle = io.popen("rm -rf " .. path .. " 2>/dev/null")
        if handle then handle:close() end
    end
    -- Restart the app to reinitialize
    love.event.quit("restart")
end

function auth_screen:keypressed(key)
    if self.model:is_password_mode() then
        if key == "up" then
            self:move_kb(-1, 0)
        elseif key == "down" then
            self:move_kb(1, 0)
        elseif key == "left" then
            self:move_kb(0, -1)
        elseif key == "right" then
            self:move_kb(0, 1)
        elseif key == "backspace" then
            self.password = ui.remove_last_utf8(self.password)
        elseif key == "return" or key == "kpenter" then
            self:activate_kb()
        elseif key == "escape" then
            love.event.quit()
        end
        return
    end

    local accs, active = {}, nil
    if self.callbacks and self.callbacks.accounts then
        local l, a = self.callbacks.accounts()
        accs = l or {}
        active = a
    end
    local saved = {}
    for _, a in ipairs(accs) do if a.authorized then saved[#saved+1] = a end end

    if key == "up" then
        if #saved > 0 and self.account_selected > 1 then
            self.account_selected = self.account_selected - 1
        else
            self.selected_item = math.max(1, self.selected_item - 1)
        end
    elseif key == "down" then
        if #saved > 0 and self.account_selected < #saved then
            self.account_selected = self.account_selected + 1
        else
            self.selected_item = math.min(#self.items, self.selected_item + 1)
        end
    elseif key == "return" or key == "kpenter" or key == "a" then
        if #saved > 0 and self.account_bounds[self.account_selected] then
            local key_name = saved[self.account_selected].key
            if key_name ~= active and self.callbacks.switch_account then
                self.callbacks.switch_account(key_name)
            end
        else
            local item = self.items[self.selected_item]
            if item == "Выйти из приложения" then
                love.event.quit()
            elseif item == "Закрыть все процессы ТГ" then
                self:close_all_tg()
            elseif item == "Очистить все данные" then
                self:clear_all_data()
            elseif item == "Настройки VPN" then
            end
        end
    elseif key == "escape" then
        love.event.quit()
    end
end

function auth_screen:mousepressed(x, y, button)
    if button == 1 then
        local w = ui.width()
        local exit_btn_w = 120
        local exit_btn_h = 36
        local exit_btn_x = w - exit_btn_w - 20
        local exit_btn_y = 10
        if x >= exit_btn_x and x <= exit_btn_x + exit_btn_w and y >= exit_btn_y and y <= exit_btn_y + exit_btn_h then
            love.event.quit()
        end
    end
end
function auth_screen:wheelmoved() end

return auth_screen
