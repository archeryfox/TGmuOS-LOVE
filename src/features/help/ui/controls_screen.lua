local ui = require("src.shared.ui.ui_kit")

local controls_screen = {}

local SECTIONS = {
    { title = "Список чатов", rows = {
        {"↑ / ↓", "выбор чата"}, {"A", "открыть чат"}, {"X", "поиск"}, {"Y", "меню чата"},
        {"L1 / R1", "прокрутка на 5 чатов"}, {"L2 / R2", "чаты → папки → архив"},
    }},
    { title = "Беседа", rows = {
        {"↑ / ↓", "курсор по сообщениям"}, {"A", "открыть сообщение или отправить"},
        {"X", "меню сообщения"}, {"Y", "выбрать сообщение"}, {"SELECT", "экранная клавиатура"},
        {"A / B", "ввод / стирание"}, {"X / Y", "Shift / RU-EN"},
        {"START / MENU", "Enter / скрыть клавиатуру"}, {"L1 / R1", "страница истории"}, {"B", "закрыть чат"},
    }},
    { title = "Медиа", rows = {
        {"A", "воспроизвести или пауза"}, {"← / →", "предыдущее или следующее"},
        {"↑ / ↓", "масштаб фото"}, {"L1 / R1", "перемотка видео ±5 с"},
        {"B", "закрыть просмотр"}, {"—", "webm-стикер: демо внизу экрана"},
    }},
    { title = "Общее", rows = {
        {"START", "настройки"}, {"SELECT", "эта справка"}, {"BACK + A", "профиль"},
        {"MENU + A", "аварийный выход"}, {"HOME", "свернуть ТГ"}, {"B", "назад"},
    }},
}

function controls_screen.new(fonts, tg)
    local self = {fonts = fonts, tg = tg, scroll = 0, sticker_menu = false, sticker_sel = 1,
                  webm_icon = nil,
                  anim_file_id = 999999,
                  anim_playing = false, anim_time = 0,
                  pipeline_stage = "ожидание", pipeline_step = 0}
    return setmetatable(self, {__index = controls_screen})
end

local function load_image_abs(path, name)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    if not data or data == "" then return nil end
    local ok_fd, fd = pcall(love.filesystem.newFileData, data, name)
    if not ok_fd or not fd then return nil end
    local ok_id, id = pcall(love.image.newImageData, fd)
    if not ok_id or not id then return nil end
    local ok_img, img = pcall(love.graphics.newImage, id)
    if not ok_img or not img then return nil end
    return img, id:getWidth(), id:getHeight()
end

function controls_screen:enter()
    self.scroll = 0
    self.sticker_menu = false
    self.sticker_sel = 1
    self.webm_icon = nil
    self.anim_playing = false
    self.anim_time = 0
    self.pipeline_stage = "запуск (runtime)…"
    self.pipeline_step = 1  -- 1=preview, 2=queue decode, 3=done

    local icon = load_image_abs("/mnt/mmc/MUOS/application/Telegram/data/files/webm_icon.png", "webm_icon.png")
    self.webm_icon = icon
    local save = love.filesystem.getSaveDirectory()
    os.execute("rm -rf '" .. save .. "/anim_animation_999999_playback'")
end

function controls_screen:update(dt)
    if self.tg.poll_media_decoder then
        self.tg:poll_media_decoder()
    end

    -- Runtime pipeline: webm -> png frames directly (bypass GIF) by engine
    local webm_path = "/mnt/mmc/MUOS/application/Telegram/data/files/webm/3sticker.webm"
    if self.pipeline_step == 1 then
        self.pipeline_stage = "превью (runtime)"
        local preview_path = love.filesystem.getSaveDirectory() .. "/3sticker_preview.png"
        local function shq(v) return "'" .. tostring(v):gsub("'", "'\\''") .. "'" end
        os.execute("env -u LD_LIBRARY_PATH ffmpeg -y -v error -threads 1 -i " .. shq(webm_path) .. " -frames:v 1 -f image2 " .. shq(preview_path) .. " 2>/dev/null")
        local img, w, h = load_image_abs(preview_path, "3sticker_preview.png")
        if not self.tg.animations[self.anim_file_id] then
            self.tg.animations[self.anim_file_id] = {status = "remote", autoplay = true}
        end
        local a = self.tg.animations[self.anim_file_id]
        a.source_path = webm_path
        a.frames = nil; a.decode_requested = nil; a.decode_error = nil; a.playing = false
        if img then a.image = img; a.width = w; a.height = h end
        self.pipeline_step = 2
        self.pipeline_stage = "webm→кадры (runtime)"
        return
    elseif self.pipeline_step == 2 then
        local a = self.tg.animations[self.anim_file_id]
        if a and not a.decode_requested then
            self.tg:queue_media_decode("animation", self.anim_file_id, webm_path)
            self.pipeline_stage = "декодирование (runtime)…"
        end
        self.pipeline_step = 3
        return
    end

    local a = self.tg.animations[self.anim_file_id]
    if a then
        if a.frames and #a.frames > 0 then
            self.pipeline_stage = "готово (" .. #a.frames .. " кадров)"
            if not self.anim_playing then
                self.anim_playing = true
                self.anim_time = 0
            end
        elseif a.decode_requested then
            self.pipeline_stage = "декодирование (runtime)…"
        elseif a.decode_error then
            self.pipeline_stage = "ошибка: " .. tostring(a.decode_error):sub(1, 40)
        end
    end
    if self.anim_playing then
        self.anim_time = self.anim_time + dt
    end
end

function controls_screen:draw()
    local f, colors = self.fonts, ui.colors
    local w, h = ui.width(), ui.height()

    ui.rect(0, 0, w, h, colors.bg)
    ui.rect(0, 0, w, 56, colors.header)
    ui.text("Управление", 24, 15, f.subtitle, colors.text)
    ui.text("SELECT / Tab — закрыть   ↑↓ — прокрутка", w - 240, 18, f.tiny, colors.muted)

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
        local column = index <= 2 and 1 or 2
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

    if self.sticker_menu then
        local mw, mh = 320, 140
        local mx, my = math.floor((w - mw)/2), math.floor((h - mh)/2)
        ui.rect(mx, my, mw, mh, colors.panel, 8)
        ui.text("Выбор стикер-пака", mx + 16, my + 12, f.subtitle, colors.text)
        local opts = {"Набор 1 (Zhivchiks)", "Набор 2 (HotCherry)"}
        for i, o in ipairs(opts) do
            local yy = my + 50 + (i-1)*36
            if i == self.sticker_sel then ui.rect(mx+12, yy-4, mw-24, 28, colors.accent, 4) end
            ui.text(o, mx + 20, yy, f.small, colors.text)
        end
        ui.text("A - открыть   B - закрыть", mx + 16, my + mh - 24, f.tiny, colors.muted)
    end

    -- Runtime WebM sticker (3sticker.webm): preview -> frames -> playback
    local a = self.tg.animations[self.anim_file_id]
    local image, iw, ih = nil, 0, 0
    if a then
        if a.frames and #a.frames > 0 then
            local step = math.max(0.03, a.frame_dt or (1/10))
            local pos = self.anim_playing and (self.anim_time % (step * #a.frames)) or 0
            local idx = math.floor(pos / step) % #a.frames + 1
            image = a.frames[idx] or a.frames[1]
            iw, ih = a.width or image:getWidth(), a.height or image:getHeight()
        elseif a.image then
            image = a.image
            iw, ih = a.width or image:getWidth(), a.height or image:getHeight()
        end
    end
    if image then
        local scale = math.min(1, 140 / iw, 140 / ih)
        local dw, dh = math.floor(iw * scale), math.floor(ih * scale)
        local dx, dy = math.floor((w - dw)/2), h - dh - 95
        ui.rect(dx - 4, dy - 4, dw + 8, dh + 8, colors.panel_alt, 4)
        love.graphics.draw(image, dx, dy, 0, scale, scale)
        ui.text(self.pipeline_stage or "", dx, dy + dh + 4, f.tiny, colors.accent)
        ui.text("3sticker.webm  L1: пуск/пауза", dx, dy + dh + 18, f.tiny, colors.muted)
    else
        ui.text("3sticker.webm: " .. (self.pipeline_stage or ""), 24, h - 95, f.tiny, colors.accent)
    end

    local note_y = h - 48
    if self.webm_icon then
        love.graphics.draw(self.webm_icon, 24, note_y - 24)
    end
    ui.text("WebM-стикеры: webm→gif→png кадры→анимация (runtime)", 24 + (self.webm_icon and 40 or 0), note_y, f.tiny, colors.muted)
    ui.text("B / MENU — назад   ↑↓ — прокрутка   START — стикеры", 24, h - 30, f.tiny, colors.muted)

    -- Clickable mouse demo button
    local btn_x, btn_y, btn_w, btn_h = 24, h - 90, 160, 30
    ui.rect(btn_x, btn_y, btn_w, btn_h, colors.accent, 4)
    ui.text("Клик мышью", btn_x + 12, btn_y + 8, f.tiny, colors.text)
    self.mouse_button = {x = btn_x, y = btn_y, w = btn_w, h = btn_h}

    -- Draw mouse cursor icon
    local mx, my = love.mouse.getPosition()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.polygon("fill", mx, my, mx + 12, my + 4, mx + 4, my + 12)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.polygon("line", mx, my, mx + 12, my + 4, mx + 4, my + 12)
end

function controls_screen:keypressed(key)
    if self.sticker_menu then
        if key == "up" then self.sticker_sel = math.max(1, self.sticker_sel - 1); return
        elseif key == "down" then self.sticker_sel = math.min(2, self.sticker_sel + 1); return
        elseif key == "a" or key == "return" or key == "kpenter" then
            if self.sticker_sel == 1 then self.tg:open_sticker_set_by_name("Zhivchiks")
            else self.tg:open_sticker_set_by_name("HotCherry") end
            self.sticker_menu = false
            return "back"
        elseif key == "escape" or key == "b" or key == "tab" then
            self.sticker_menu = false; return
        end
        return
    end
    if key == "f1" or key == "start" then
        self.sticker_menu = true; self.sticker_sel = 1; return
    elseif key == "l1" or key == "leftshoulder" then
        local a = self.tg.animations[self.anim_file_id]
        if a and a.frames and #a.frames > 0 then
            self.anim_playing = not self.anim_playing
            if self.anim_playing then self.anim_time = 0 end
        elseif self.pipeline_step == 0 or self.pipeline_step >= 4 then
            -- Restart runtime pipeline
            local save = love.filesystem.getSaveDirectory()
            os.execute("rm -rf '" .. save .. "/anim_animation_999999_playback'")
            if self.tg.animations[self.anim_file_id] then
                self.tg.animations[self.anim_file_id].frames = nil
                self.tg.animations[self.anim_file_id].decode_requested = nil
                self.tg.animations[self.anim_file_id].decode_error = nil
            end
            self.pipeline_step = 1
            self.pipeline_stage = "запуск (runtime)…"
        end
        return
    elseif key == "escape" or key == "tab" or key == "return" or key == "kpenter" then
        return "back"
    elseif key == "up" then
        self.scroll = math.max(0, self.scroll - 30)
    elseif key == "down" then
        local w, h = ui.width(), ui.height()
        local max_y = 72
        for _, section in ipairs(SECTIONS) do
            max_y = max_y + 24 + #section.rows * 22 + 14
        end
        max_y = max_y - 72 + 30
        local max_scroll = math.max(0, max_y - (h - 80))
        self.scroll = math.min(max_scroll, self.scroll + 30)
    end
end

function controls_screen:mousepressed(x, y, button)
    if button ~= 1 then return end
    local b = self.mouse_button
    if b and x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
        self.tg.action_status = "Мышь работает!"
    end
end

return controls_screen
