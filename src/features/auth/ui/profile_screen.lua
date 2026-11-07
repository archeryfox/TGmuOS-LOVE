-- src/features/auth/ui/profile_screen.lua — экран профиля (аватарка + имя)
local ui = require("src.shared.ui.ui_kit")

local profile_screen = {}
local categories = {
    {key = "photos", label = "Фото"},
    {key = "videos", label = "Видео"},
    {key = "files", label = "Файлы"},
    {key = "links", label = "Ссылки"},
    {key = "music", label = "Музыка"},
    {key = "voice", label = "Голос"},
}

local function draw_avatar(image, x, y, size)
    if not image then return end
    local scale = math.max(size / image:getWidth(), size / image:getHeight())
    local draw_w = image:getWidth() * scale
    local draw_h = image:getHeight() * scale
    love.graphics.stencil(function()
        love.graphics.circle("fill", x + size / 2, y + size / 2, size / 2)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, x + (size - draw_w) / 2, y + (size - draw_h) / 2, 0, scale, scale)
    love.graphics.setStencilTest()
end

function profile_screen.new(fonts, tg)
    local self = {}
    self.fonts = fonts
    self.tg = tg
    self.user_id = nil
    self.chat_id = nil
    self.is_me = false
    self.category = "photos"
    self.media_scroll = 0
    return setmetatable(self, {__index = profile_screen})
end

function profile_screen:enter()
    self.avatar = nil
    self.avatar_w = 0
    self.avatar_h = 0
    self.name = ""
    self.username = ""
    self.bio = ""
    self.phone = ""
    self.status = ""
    self.media_scroll = 0

    if self.is_me then
        local me = self.tg.me
        if me then
            self.user_id = me.id
            self.name = self.tg:user_name(me.id)
            self.username = me.username or ""
            self.phone = me.phone_number or ""
            local avatar = self.tg:user_photo_image(me.id)
            if avatar then
                self.avatar = avatar
                self.avatar_w = avatar:getWidth()
                self.avatar_h = avatar:getHeight()
            end
        end
    elseif self.user_id then
        self.tg:ensure_user(self.user_id)
        local user = self.tg.users[self.user_id]
        if user then
            self.name = self.tg:user_name(self.user_id)
            self.username = user.username or ""
            self.phone = user.phone_number or ""
            local avatar = self.tg:user_photo_image(self.user_id)
            if avatar then
                self.avatar = avatar
                self.avatar_w = avatar:getWidth()
                self.avatar_h = avatar:getHeight()
            end
        end
        self.status = self.tg:user_status_text(self.user_id)
    elseif self.chat_id then
        local chat = self.tg.chats_by_id[self.chat_id] or self.tg.archive_chats_by_id[self.chat_id]
        if chat then
            self.name = chat.title or ("Chat " .. tostring(self.chat_id))
            self.username = chat.username or ""
            local avatar = self.tg:chat_photo_image(self.chat_id)
            if avatar then
                self.avatar = avatar
                self.avatar_w = avatar:getWidth()
                self.avatar_h = avatar:getHeight()
            end
            self.user_id = self.tg:private_chat_user_id(chat)
            if self.user_id then
                self.tg:ensure_user(self.user_id)
                self.status = self.tg:user_status_text(self.user_id)
                local user = self.tg.users[self.user_id]
                if user then
                    self.username = user.username or self.username
                    self.phone = user.phone_number or ""
                end
            end
        end
    end
    if self.chat_id then
        for _, category in ipairs(categories) do
            self.tg:load_profile_media(self.chat_id, category.key)
        end
    end
end

function profile_screen:update()
    if not self.user_id then return end
    local user = self.tg.users[self.user_id]
    if user then
        self.name = self.tg:user_name(self.user_id)
        self.username = user.username or self.username
        self.phone = user.phone_number or self.phone
        self.status = self.tg:user_status_text(self.user_id)
    end
    local avatar = self.tg:user_photo_image(self.user_id)
    if avatar then
        self.avatar = avatar
        self.avatar_w = avatar:getWidth()
        self.avatar_h = avatar:getHeight()
    end
end

function profile_screen:draw_media(f, colors, w, h)
    local top = 220
    for index, category in ipairs(categories) do
        local x = 16 + (index - 1) * 100
        local selected = self.category == category.key
        ui.rect(x, top - 4, 94, 26, selected and colors.accent_dark or colors.panel_alt, 5)
        ui.printf(category.label, x, top + 1, 94, "center", f.tiny, colors.text)
    end
    local media_by_chat = self.tg.profile_media[self.category] or {}
    local data = self.chat_id and media_by_chat[self.chat_id]
    local list_y = top + 32
    local list_h = h - list_y - 42
    ui.rect(12, list_y, w - 24, list_h, colors.panel, 6)
    if not data or data.loading then
        ui.printf("Загрузка медиа…", 24, list_y + 20, w - 48, "left", f.small, colors.muted)
        return
    end
    if data.error then
        ui.printf(ui.fit(data.error, f.small, w - 48), 24, list_y + 20, w - 48, "left", f.small, colors.red)
        return
    end
    local messages = data.messages or {}
    if #messages == 0 then
        ui.printf("В этой категории пока пусто", 24, list_y + 20, w - 48, "left", f.small, colors.muted)
        return
    end
    local row_h = 44
    local visible = math.max(1, math.floor((list_h - 8) / row_h))
    love.graphics.setScissor(12, list_y, w - 24, list_h)
    for index = self.media_scroll + 1, math.min(#messages, self.media_scroll + visible) do
        local message = messages[index]
        local row_y = list_y + 6 + (index - self.media_scroll - 1) * row_h
        local text = self.tg:message_text(message)
        local content = message.content or {}
        if self.category == "files" then
            text = self.tg:document_label(message)
        elseif self.category == "music" then
            text = self.tg:document_label(message)
        elseif self.category == "videos" then
            local video = content.video and content.video.video
            text = (video and video.file_name) or "[видео]"
        end
        if self.category == "photos" then
            local image = self.tg:photo_image(message)
            if image then
                local size = 36
                local scale = math.min(size / image:getWidth(), size / image:getHeight())
                love.graphics.draw(image, 20, row_y + 3, 0, scale, scale)
            end
        end
        local date = os.date("%d.%m.%Y", message.date or 0)
        ui.text(ui.fit(text, f.small, w - 150), 68, row_y + 4, f.small, colors.text)
        ui.text(date, w - 84, row_y + 5, f.tiny, colors.muted)
        ui.rect(68, row_y + row_h - 1, w - 100, 1, colors.panel_alt)
    end
    love.graphics.setScissor()
    ui.text("Колёсико — список медиа", 20, h - 30, f.tiny, colors.muted)
end

function profile_screen:draw()
    local f = self.fonts
    local w = ui.width()
    local h = ui.height()
    local colors = ui.colors

    ui.rect(0, 0, w, h, colors.bg)
    ui.rect(0, 0, w, 56, colors.header)
    ui.text("Профиль", 24, 15, f.subtitle, colors.text)
    ui.text("Esc — назад", w - 140, 18, f.tiny, colors.muted)

    local avatar_size = 76
    local avatar_x = 24
    local avatar_y = 70

    if self.avatar then
        draw_avatar(self.avatar, avatar_x, avatar_y, avatar_size)
    else
        love.graphics.setColor(colors.accent)
        love.graphics.circle("fill", avatar_x + avatar_size / 2, avatar_y + avatar_size / 2, avatar_size / 2)
        local initial = ui.first_char(self.name)
        ui.printf(initial, avatar_x, avatar_y + avatar_size / 2 - f.normal:getHeight() / 2, avatar_size, "center", f.normal, colors.text)
    end

    local text_x = avatar_x + avatar_size + 18
    local yy = avatar_y + 2
    ui.text(ui.fit(self.name, f.subtitle, w - text_x - 20), text_x, yy, f.subtitle, colors.text)
    yy = yy + f.subtitle:getHeight() + 6
    if self.status ~= "" then
        ui.text(ui.fit(self.status, f.small, w - text_x - 20), text_x, yy, f.small,
            self.status == "в сети" and colors.green or colors.muted)
        yy = yy + f.small:getHeight() + 6
    end
    if self.username and self.username ~= "" then
        ui.text("@" .. self.username, text_x, yy, f.small, colors.muted)
        yy = yy + f.small:getHeight() + 4
    end
    if self.phone and self.phone ~= "" then
        ui.text(self.phone, text_x, yy, f.tiny, colors.muted)
    end

    if self.chat_id then self:draw_media(f, colors, w, h) end

    ui.text("Esc — назад", 24, h - 32, f.tiny, colors.muted)
end

function profile_screen:keypressed(key)
    if key == "escape" then
        return "back"
    end
end

function profile_screen:wheelmoved(_, y)
    local data = self.chat_id and self.tg.profile_media[self.category]
        and self.tg.profile_media[self.category][self.chat_id]
    local count = data and #(data.messages or {}) or 0
    local visible = math.max(1, math.floor((ui.height() - 294) / 44))
    self.media_scroll = math.max(0, math.min(math.max(0, count - visible), self.media_scroll - y * 2))
end
function profile_screen:mousepressed(x, y, button)
    if button ~= 1 then return end
    local tab_y = 216
    if y >= tab_y and y <= tab_y + 32 then
        local index = math.floor((x - 16) / 100) + 1
        local category = categories[index]
        if category then
            self.category = category.key
            self.media_scroll = 0
            if self.chat_id then self.tg:load_profile_media(self.chat_id, self.category) end
        end
    end
end
function profile_screen:textinput() end

return profile_screen
