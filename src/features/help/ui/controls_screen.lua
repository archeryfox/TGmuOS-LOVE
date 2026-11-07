local ui = require("src.shared.ui.ui_kit")

local controls_screen = {}

local SECTIONS = {
    { title = "Список чатов", rows = {
        {"↑ / ↓", "выбор чата"}, {"A", "открыть чат"}, {"X", "поиск"}, {"Y", "меню чата"},
        {"L1 / R1", "прокрутка на 5 чатов"}, {"L2 / R2", "чаты → папки → архив"},
        {"M / P", "открыть свой профиль"}, {"START", "настройки"}, {"SELECT", "эта справка"},
    }},
    { title = "Беседа", rows = {
        {"↑ / ↓", "курсор по сообщениям"}, {"← / →", "прокрутка чата"},
        {"A", "открыть сообщение или отправить"}, {"X", "меню сообщения"},
        {"Y", "выбрать сообщение"}, {"SELECT", "экранная клавиатура"},
        {"A / B", "ввод / стирание"}, {"X / Y", "Shift / RU-EN-Emoji-Стикеры"},
        {"START / MENU", "Enter / скрыть клавиатуру"}, {"L1 / R1", "страница истории"},
        {"B", "закрыть чат"}, {"PgUp / PgDn", "страница вверх/вниз"},
    }},
    { title = "Медиа", rows = {
        {"A", "воспроизвести или пауза"}, {"← / →", "предыдущее или следующее"},
        {"↑ / ↓", "масштаб фото"}, {"L1 / R1", "перемотка видео ±5 с"},
        {"B", "закрыть просмотр"},
    }},
    { title = "Стикеры", rows = {
        {"F1", "список стикерпаков (Мои стикеры)"}, {"Enter", "предпросмотр стикера на весь экран"},
        {"A / X", "отправить стикер"}, {"↑↓←→", "навигация по стикерам"},
        {"B / Esc", "закрыть предпросмотр / пак"},
    }},
    { title = "Профиль", rows = {
        {"M / P", "свой профиль"}, {"Y на чате", "профиль пользователя/чата"},
        {"Esc", "назад"},
    }},
    { title = "Файлы", rows = {
        {"X на сообщении", "меню сообщения"}, {"Просмотреть текст", "текстовый файл (txt/log/md/json/lua)"},
        {"↑ / ↓", "прокрутка текста"}, {"Esc / B", "закрыть просмотр"},
    }},
    { title = "Голосовые / Аудио", rows = {
        {"A", "воспроизвести / пауза"}, {"B", "остановить"},
    }},
    { title = "Общее", rows = {
        {"START", "настройки"}, {"SELECT", "эта справка"}, {"BACK + A", "профиль"},
        {"MENU + A", "аварийный выход"}, {"HOME", "свернуть ТГ"}, {"B", "назад"},
        {"VOL+ / VOL-", "громкость (muOS)"},
    }},
}

function controls_screen.new(fonts, tg)
    local self = {fonts = fonts, tg = tg, scroll = 0}
    return setmetatable(self, {__index = controls_screen})
end

function controls_screen:enter()
    self.scroll = 0
end

function controls_screen:update(dt)
end

function controls_screen:draw()
    local f, colors = self.fonts, ui.colors
    local w, h = ui.width(), ui.height()

    ui.rect(0, 0, w, h, colors.bg)
    ui.rect(0, 0, w, 56, colors.header)
    ui.text("Управление", 24, 15, f.subtitle, colors.text)
    ui.text("SELECT / Tab — закрыть   ↑↓ — прокрутка", w - 260, 18, f.tiny, colors.muted)

    local margin = 24
    local gap = 24
    local col_w = math.floor((w - margin * 2 - gap) / 2)
    local col_x = {margin, margin + col_w + gap}
    local col_y = {72 - self.scroll, 72 - self.scroll}

    local max_y = 72
    for _, section in ipairs(SECTIONS) do
        max_y = max_y + 24 + #section.rows * 22 + 14
    end
    max_y = max_y - 72 + 30

    local max_scroll = math.max(0, max_y - (h - 80))
    self.scroll = math.max(0, math.min(max_scroll, self.scroll))

    for index, section in ipairs(SECTIONS) do
        local column = index <= 4 and 1 or 2
        local x = col_x[column]
        local y = col_y[column]
        ui.text(section.title, x, y, f.small, colors.accent)
        y = y + 24
        for _, row in ipairs(section.rows) do
            local chip_w = math.max(36, f.tiny:getWidth(row[1]) + 12)
            ui.rect(x, y, chip_w, 18, colors.panel_alt, 4)
            ui.text(row[1], x + 6, y + 3, f.tiny, colors.text)
            ui.text(ui.fit(row[2], f.tiny, col_w - chip_w - 12), x + chip_w + 8, y + 3, f.tiny, colors.muted)
            y = y + 22
        end
        col_y[column] = y + 14
    end

    if max_scroll > 0 then
        local bar_h = math.max(30, (h - 80) / max_y * (h - 80))
        local bar_y = 80 + (self.scroll / max_scroll) * (h - 80 - bar_h)
        ui.rect(w - 10, 80, 6, h - 80, colors.panel_alt, 3)
        ui.rect(w - 10, bar_y, 6, bar_h, colors.accent, 3)
    end

    ui.text("B / MENU / Tab — назад   ↑↓ — прокрутка", 24, h - 30, f.tiny, colors.muted)
end

function controls_screen:keypressed(key)
    if key == "escape" or key == "tab" or key == "return" or key == "kpenter" or key == "b" then
        return "back"
    elseif key == "up" then
        local w, h = ui.width(), ui.height()
        local max_y = 72
        for _, section in ipairs(SECTIONS) do
            max_y = max_y + 24 + #section.rows * 22 + 14
        end
        max_y = max_y - 72 + 30
        local max_scroll = math.max(0, max_y - (h - 80))
        self.scroll = math.min(max_scroll, self.scroll + 30)
    elseif key == "down" then
        self.scroll = math.max(0, self.scroll - 30)
    end
end

function controls_screen:mousepressed(x, y, button) end

return controls_screen
