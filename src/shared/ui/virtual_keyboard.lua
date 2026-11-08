-- src/shared/ui/virtual_keyboard.lua — экранная QWERTY/ЙЦУКЕН-клавиатура для геймпада
local ui = require("src.shared.ui.ui_kit")

local keyboard = {}

local LAYOUT_EN = {
    {"q", "w", "e", "r", "t", "y", "u", "i", "o", "p"},
    {"a", "s", "d", "f", "g", "h", "j", "k", "l"},
    {"z", "x", "c", "v", "b", "n", "m", ",", ".", "?"},
}

local LAYOUT_RU = {
    {"й", "ц", "у", "к", "е", "ё", "н", "г", "ш", "щ", "з", "х"},
    {"ф", "ы", "в", "а", "п", "р", "о", "л", "д", "ж", "э"},
    {"я", "ч", "с", "м", "и", "т", "ь", "б", "ю", ".", ","},
}

local EMOJI_PAGES = {
    {
        {"😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "😊", "😇"},
        {"🙂", "🙃", "😉", "😌", "😍", "🥰", "😘", "😗", "😙", "😚"},
        {"😋", "😛", "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🤩"},
        {"🥳", "😏", "😒", "😞", "😔", "😟", "😕", "🙁", "☹️", "😣"},
    },
    {
        {"😖", "😫", "😩", "🥺", "😢", "😭", "😤", "😠", "😡", "🤬"},
        {"🤯", "😳", "🥵", "🥶", "😱", "😨", "😰", "😥", "😓", "🤗"},
        {"🤔", "🤭", "🤫", "🤥", "😶", "😐", "😑", "😬", "🙄", "😯"},
        {"😦", "😧", "😮", "😲", "🥱", "😴", "🤤", "😪", "😵", "🤐"},
    },
    {
        {"👍", "👎", "👌", "🤌", "🤏", "✌️", "🤞", "🤟", "🤘", "🤙"},
        {"👈", "👉", "👆", "👇", "☝️", "✋", "🤚", "🖐", "🖖", "👋"},
        {"🤝", "🙏", "✍️", "💪", "🦾", "🖕", "👏", "🙌", "👐", "🤲"},
        {"🫶", "🫰", "🫱", "🫲", "🫳", "🫴", "💅", "🤳", "🧠", "👀"},
    },
    {
        {"❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔"},
        {"❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟", "♥️"},
        {"🔥", "✨", "⭐", "🌟", "💫", "⚡", "💥", "💯", "✅", "❌"},
        {"⭕", "❗", "❓", "‼️", "⁉️", "💤", "🎉", "🎊", "🎁", "🏆"},
    },
    {
        {"🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯"},
        {"🦁", "🐮", "🐷", "🐸", "🐵", "🐔", "🐧", "🐦", "🐤", "🦆"},
        {"🦅", "🦉", "🦇", "🐺", "🐗", "🐴", "🦄", "🐝", "🐛", "🦋"},
        {"🐌", "🐞", "🐢", "🐍", "🦎", "🐙", "🦑", "🦀", "🐬", "🐳"},
    },
    {
        {"🍏", "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🍒"},
        {"🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🥑", "🥦", "🥕", "🌽"},
        {"🍞", "🧀", "🍗", "🍔", "🍟", "🍕", "🌭", "🍿", "🍰", "🍫"},
        {"🍬", "🍺", "☕", "🍵", "🎮", "🎲", "🎯", "🎸", "🎧", "📱"},
    },
}

local RU_UPPER = {
    ["й"] = "Й", ["ц"] = "Ц", ["у"] = "У", ["к"] = "К", ["е"] = "Е",
    ["н"] = "Н", ["г"] = "Г", ["ш"] = "Ш", ["щ"] = "Щ", ["з"] = "З",
    ["х"] = "Х", ["ф"] = "Ф", ["ы"] = "Ы", ["в"] = "В", ["а"] = "А",
    ["п"] = "П", ["р"] = "Р", ["о"] = "О", ["л"] = "Л", ["д"] = "Д",
    ["ж"] = "Ж", ["э"] = "Э", ["я"] = "Я", ["ч"] = "Ч", ["с"] = "С",
    ["м"] = "М", ["и"] = "И", ["т"] = "Т", ["ь"] = "Ь", ["б"] = "Б",
    ["ю"] = "Ю", ["ё"] = "Ё",
}

local CONTROLS = {
    {label = "Shift", action = "shift", width = 62},
    {label = "RU/EN", action = "lang", width = 62},
    {label = "Caps", action = "caps", width = 58},
    {label = "Пробел", action = "space", width = 120},
    {label = "😀", action = "emoji", width = 52},
    {label = "Стикеры", action = "stickers", width = 62},
    {label = "Файлы", action = "files", width = 58},
    {label = "⌫", action = "backspace", width = 52},
    {label = "⏎", action = "enter", width = 52},
    {label = "Скрыть", action = "hide", width = 66},
}

local PAD = 8
local KEY_W = 44
local KEY_H = 38
local KEY_GAP = 4
local PREVIEW_H = 30
local ROW_H = KEY_H + KEY_GAP

-- Calculate keyboard width dynamically based on widest row content
local function calc_row_width(row)
    local w = 0
    for i, key in ipairs(row) do
        w = w + (key.width or KEY_W)
        if i > 1 then w = w + KEY_GAP end
    end
    return w
end

local KB_W = 0
for _, row in ipairs(LAYOUT_EN) do
    KB_W = math.max(KB_W, calc_row_width(row))
end
for _, row in ipairs(LAYOUT_RU) do
    KB_W = math.max(KB_W, calc_row_width(row))
end
local ctrl_w = 0
for i, c in ipairs(CONTROLS) do
    ctrl_w = ctrl_w + c.width
    if i > 1 then ctrl_w = ctrl_w + KEY_GAP end
end
KB_W = math.max(KB_W, ctrl_w)
-- Don't shrink KB_W below ctrl_w; keyboard may overflow screen but keys stay within it
    if KB_W < ui.width() - PAD * 2 then
        KB_W = ui.width() - PAD * 2
    end

local function upper_key(key)
    return RU_UPPER[key] or string.upper(key)
end

function keyboard.new(fonts)
    local self = {}
    self.fonts = fonts
    self.visible = false
    self.lang = "en"
    self.mode = "text"
    self.emoji_page = 1
    self.shift = false
    self.caps = false
    self.row = 1
    self.col = 1
    setmetatable(self, {__index = keyboard})
    self:_sync_layout()
    return self
end

function keyboard:_sync_layout()
    if self.mode == "emoji" then
        self.emoji_page = math.max(1, math.min(#EMOJI_PAGES, self.emoji_page or 1))
        self.layout = EMOJI_PAGES[self.emoji_page]
    elseif self.lang == "ru" then
        self.layout = LAYOUT_RU
    else
        self.layout = LAYOUT_EN
    end
end

function keyboard:switch_emoji_page(delta)
    if self.mode ~= "emoji" then return end
    local count = #EMOJI_PAGES
    self.emoji_page = ((self.emoji_page - 1 + delta) % count) + 1
    self:_sync_layout()
    self:_clamp_cursor()
end

function keyboard:_row_count()
    return #self.layout + 1
end

function keyboard:_col_count(row)
    if row <= #self.layout then return #self.layout[row] end
    return #CONTROLS
end

function keyboard:_clamp_cursor()
    self.row = math.max(1, math.min(self:_row_count(), self.row or 1))
    self.col = math.max(1, math.min(self:_col_count(self.row), self.col or 1))
end

function keyboard:toggle()
    self.visible = not self.visible
    return self.visible
end

function keyboard:switch_lang()
    self.lang = (self.lang == "en") and "ru" or "en"
    self:_sync_layout()
    self:_clamp_cursor()
end

function keyboard:cycle_mode()
    if self.mode == "text" and self.lang == "ru" then
        self.lang = "en"
        self:_sync_layout()
        self:_clamp_cursor()
        return "nav"
    elseif self.mode == "text" and self.lang == "en" then
        self.mode = "emoji"
        self:_sync_layout()
        self:_clamp_cursor()
        return "nav"
    elseif self.mode == "emoji" then
        self.mode = "stickers"
        self:_sync_layout()
        self:_clamp_cursor()
        return "nav"
    elseif self.mode == "stickers" then
        self.mode = "text"
        self.lang = "ru"
        self:_sync_layout()
        self:_clamp_cursor()
        return "nav"
    end
    self.lang = "ru"
    self.mode = "text"
    self:_sync_layout()
    self:_clamp_cursor()
    return "nav"
end

function keyboard:navigate(dx, dy)
    if dy ~= 0 then
        self.row = self.row + dy
        if self.row < 1 then self.row = self:_row_count() end
        if self.row > self:_row_count() then self.row = 1 end
        self.col = math.min(self.col, self:_col_count(self.row))
    end
    if dx ~= 0 then
        local count = self:_col_count(self.row)
        self.col = self.col + dx
        if self.col < 1 then self.col = count end
        if self.col > count then self.col = 1 end
    end
    return {kind = "nav"}
end

function keyboard:activate()
    if self.row <= #self.layout then
        local key = self.layout[self.row][self.col]
        if not key then return nil end
        local text = key
        if self.mode == "text" and self.shift ~= self.caps then text = upper_key(key) end
        if self.mode == "text" and self.shift then self.shift = false end
        return {kind = "text", text = text}
    end

    local control = CONTROLS[self.col]
    if not control then return nil end
    if control.action == "shift" then
        self.shift = not self.shift
        return {kind = "nav"}
    elseif control.action == "caps" then
        self.caps = not self.caps
        return {kind = "nav"}
    elseif control.action == "lang" then
        self:switch_lang()
        return {kind = "nav"}
    elseif control.action == "emoji" then
        self.mode = self.mode == "emoji" and "text" or "emoji"
        self:_sync_layout()
        self:_clamp_cursor()
        return {kind = "nav"}
    elseif control.action == "space" then
        return {kind = "text", text = " "}
    elseif control.action == "backspace" then
        return {kind = "backspace"}
    elseif control.action == "enter" then
        return {kind = "enter"}
    elseif control.action == "hide" then
        self.visible = false
        return {kind = "hide"}
    elseif control.action == "stickers" then
        return {kind = "stickers"}
    elseif control.action == "files" then
        return {kind = "files"}
    end
    return nil
end

-- Возвращает true, если клавиша обработана, и результат действия.
function keyboard:keypressed(key)
    if not self.visible then return false end

    if key == "escape" then
        self.visible = false
        return true, {kind = "hide"}
    elseif self.mode == "emoji" and (key == "pageup" or key == "l1") then
        self:switch_emoji_page(-1)
        return true, {kind = "nav"}
    elseif self.mode == "emoji" and (key == "pagedown" or key == "r1") then
        self:switch_emoji_page(1)
        return true, {kind = "nav"}
    elseif key == "up" then
        return true, self:navigate(0, -1)
    elseif key == "down" then
        return true, self:navigate(0, 1)
    elseif key == "left" then
        return true, self:navigate(-1, 0)
    elseif key == "right" then
        return true, self:navigate(1, 0)
    elseif key == "x" then
        self.shift = not self.shift
        return true, {kind = "nav"}
    elseif key == "y" then
        local kind = self:cycle_mode()
        return true, {kind = kind}
    elseif key == "return" or key == "kpenter" or key == "a" then
        return true, self:activate()
    elseif key == "backspace" then
        return true, {kind = "backspace"}
    end
    return false
end

function keyboard:draw(preview)
    if not self.visible then return end

    local f = self.fonts.normal or self.fonts
    local small = self.fonts.small or f
    local tiny = self.fonts.tiny or small
    local colors = ui.colors

    local kb_h = PREVIEW_H + PAD + #self.layout * ROW_H + ROW_H + PAD
    local x = math.floor((ui.width() - KB_W) / 2)
    local y = ui.height() - kb_h - 6

    ui.rect(x, y, KB_W, kb_h, colors.panel, 8)
    ui.outline(x, y, KB_W, kb_h, colors.accent, 8)

    local lang_text = (self.lang == "ru") and "RU" or "EN"
    if self.mode == "emoji" then
        lang_text = string.format("EMOJI %d/%d", self.emoji_page or 1, #EMOJI_PAGES)
    end
    local state = {}
    if self.mode == "text" and self.shift then state[#state + 1] = "SHIFT" end
    if self.mode == "text" and self.caps then state[#state + 1] = "CAPS" end
    ui.text(lang_text .. (#state > 0 and ("  " .. table.concat(state, " ")) or ""),
        x + PAD, y + 5, tiny, colors.accent)

    local shown = preview or ""
    if shown == "" then
        shown = self.mode == "emoji"
            and "A — вставить   B — ⌫   L1/R1 — страница   MENU — скрыть"
            or "A — ввод   B — ⌫   X — Shift   Y — RU/EN/Emoji/Стикеры   MENU — скрыть"
    end
    ui.text(ui.fit(shown, small, KB_W - 120), x + PAD + 74, y + 5, small,
        preview and preview ~= "" and colors.text or colors.muted)

    local key_y = y + PREVIEW_H + PAD
    for row_idx, row in ipairs(self.layout) do
        local row_w = 0
        for i, key in ipairs(row) do
            row_w = row_w + (key.width or KEY_W)
            if i > 1 then row_w = row_w + KEY_GAP end
        end
        local key_x = x + PAD + math.floor((KB_W - PAD * 2 - row_w) / 2)
        for col_idx, key in ipairs(row) do
            local kwidth = key.width or KEY_W
            local selected = self.row == row_idx and self.col == col_idx
            local bg = selected and colors.accent_dark or colors.bg
            local outline = selected and colors.accent or colors.muted
            ui.rect(key_x, key_y, kwidth, KEY_H, bg, 4)
            ui.outline(key_x, key_y, kwidth, KEY_H, outline, 4)
            local label = key
            if self.shift ~= self.caps then label = upper_key(key) end
            ui.text(label, key_x + math.floor((kwidth - f:getWidth(label)) / 2),
                key_y + math.floor((KEY_H - f:getHeight()) / 2), f, colors.text)
            key_x = key_x + kwidth + KEY_GAP
        end
        key_y = key_y + ROW_H
    end

    local total_w = 0
    for i, control in ipairs(CONTROLS) do
        total_w = total_w + control.width
        if i > 1 then total_w = total_w + KEY_GAP end
    end
    local key_x = x + PAD + math.floor((KB_W - PAD * 2 - total_w) / 2)
    for col_idx, control in ipairs(CONTROLS) do
        local selected = self.row == #self.layout + 1 and self.col == col_idx
        local active = (control.action == "shift" and self.shift)
            or (control.action == "caps" and self.caps)
        local bg = selected and colors.accent_dark or (active and colors.accent or colors.bg)
        local outline = selected and colors.accent or colors.muted
        ui.rect(key_x, key_y, control.width, KEY_H, bg, 4)
        ui.outline(key_x, key_y, control.width, KEY_H, outline, 4)
        ui.text(control.label, key_x + math.floor((control.width - tiny:getWidth(control.label)) / 2),
            key_y + math.floor((KEY_H - tiny:getHeight()) / 2), tiny,
            active and colors.bg or colors.text)
        key_x = key_x + control.width + KEY_GAP
    end
end

function keyboard:textinput(text)
    -- Ввод идёт через keypressed/activate; физическая клавиатура обрабатывается экраном.
end

return keyboard
