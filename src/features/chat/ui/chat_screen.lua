-- src/features/chat/ui/chat_screen.lua — главный экран мессенджера (список чатов + беседа)
local ui = require("src.shared.ui.ui_kit")
local chat_model = require("src.features.chat.model.chat_model")
local chat_item = require("src.entities.chat.ui.chat_item")
local virtual_keyboard = require("src.shared.ui.virtual_keyboard")
local performance = require("src.shared.system.performance")

local HEADER_HEIGHT = 56
local CHAT_HEADER_HEIGHT = 64
local INPUT_HEIGHT = 72
local ITEM_HEIGHT = 76
local REACTION_EMOJIS = {
    "👍", "👎", "❤️", "🔥", "🥰",
    "👏", "😁", "🤔", "🤯", "😱",
    "🤬", "😢", "🎉", "🤩", "💩",
    "🙏", "💯", "👀", "🤝", "✌️",
}
local REACTION_COLUMNS = 5

local function alpha_color(color, alpha)
    return {color[1], color[2], color[3], alpha}
end

local messenger_screen = {}
require("src.features.chat.ui.chat_screen_media")(messenger_screen)
require("src.features.chat.ui.chat_screen_input")(messenger_screen, {
    HEADER_HEIGHT = HEADER_HEIGHT,
    CHAT_HEADER_HEIGHT = CHAT_HEADER_HEIGHT,
    INPUT_HEIGHT = INPUT_HEIGHT,
    ITEM_HEIGHT = ITEM_HEIGHT,
    REACTION_EMOJIS = REACTION_EMOJIS,
    REACTION_COLUMNS = REACTION_COLUMNS,
})

local helpers = require("src.features.chat.ui.chat_screen_helpers")
local wrapped_lines = helpers.wrapped_lines
local draw_circle_image = helpers.draw_circle_image
local draw_text_lines = helpers.draw_text_lines

local function render_markdown(text, x, y, width, font, color)
  if not text or text == "" then return end
  -- Parse into segments: {text, style} where style in {plain,bold,italic,code}
  local segments = {}
  local i = 1
  local n = #text
  while i <= n do
    -- code span
    if text:sub(i, i) == "`" then
      local j = text:find("`", i + 1, true)
      if j then
        segments[#segments+1] = {text:sub(i+1, j-1), "code"}
        i = j + 1
      else
        segments[#segments+1] = {text:sub(i, i), "plain"}
        i = i + 1
      end
    -- bold
    elseif text:sub(i, i+1) == "**" then
      local j = text:find("**", i + 2, true)
      if j then
        segments[#segments+1] = {text:sub(i+2, j-1), "bold"}
        i = j + 2
      else
        segments[#segments+1] = {text:sub(i, i), "plain"}
        i = i + 1
      end
    -- italic
    elseif text:sub(i, i) == "*" then
      local j = text:find("*", i + 1, true)
      if j then
        segments[#segments+1] = {text:sub(i+1, j-1), "italic"}
        i = j + 1
      else
        segments[#segments+1] = {text:sub(i, i), "plain"}
        i = i + 1
      end
    else
      -- collect plain until next marker
      local nextpos = n + 1
      for _, m in ipairs({"`", "**", "*"}) do
        local p = text:find(m, i, true)
        if p and p < nextpos then nextpos = p end
      end
      segments[#segments+1] = {text:sub(i, nextpos - 1), "plain"}
      i = nextpos
    end
  end
  -- Render with wrapping
  local line_h = font:getHeight()
  local cur_x = x
  local cur_y = y
  for _, seg in ipairs(segments) do
    local style = seg[2]
    local segtext = seg[1]
    -- split by words for wrapping
    -- handle newlines within segment
    local parts = {}
    for part in (segtext .. "\n"):gmatch("([^\n]*)\n") do parts[#parts+1] = part end
    for _, part in ipairs(parts) do
      for word in part:gmatch("%S+") do
      local w = font:getWidth(word .. " ")
      if cur_x + w > x + width and cur_x > x then
        cur_x = x
        cur_y = cur_y + line_h
      end
      if style == "bold" then
        love.graphics.setColor(1, 1, 1, 1)
      elseif style == "italic" then
        love.graphics.setColor(0.85, 0.85, 0.95, 1)
      elseif style == "code" then
        love.graphics.setColor(0.9, 0.9, 0.6, 1)
      else
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
      end
      local seg_color = (style == "bold" and {1,1,1,1}) or (style == "italic" and {0.85,0.85,0.95,1}) or (style == "code" and {0.9,0.9,0.6,1}) or color
      ui.text(word, cur_x, cur_y, font, seg_color)
      if style == "bold" then
        -- fake bold: draw again with 1px offset
        ui.text(word, cur_x + 1, cur_y, font, seg_color)
      end
      cur_x = cur_x + font:getWidth(word .. " ")
      end
      -- newline within segment
      if part ~= parts[#parts] then
        cur_x = x
        cur_y = cur_y + line_h
      end
    end
    -- handle spaces between segments: add a space
    if cur_x > x then
      cur_x = cur_x + font:getWidth(" ")
    end
  end
  love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
end
local conversation_items = helpers.conversation_items

function messenger_screen.new(fonts, tg)
    local self = {}
    self.fonts = fonts
    self.tg = tg
    self.model = chat_model.new(tg)
    self.keyboard = virtual_keyboard.new(fonts)
    self.model.input = ""
    self.archive_mode = false
    self.list_kind = "main"
    self.list_filter_id = nil
    self.selected_messages = {}
    self.context_menu = nil
    self.reaction_menu = nil
    self.forward_mode = false
    self.forward_from_chat_id = nil
    self.wants_settings = false
    self.wants_profile_chat_id = nil
    self.wants_profile_self = nil
    self.edit_mode = false
    self.edit_message = nil
    self.edit_input = ""
    self.wants_profile_user_id = nil
    self.wants_open_chat = nil
    self.fullscreen_media = nil
    self.sticker_pack_menu = nil
    self.last_media_click = nil
    self.search_active = false
    self.search_query = ""
    self.search_changed_at = 0
    self.search_submitted_query = nil
    self.hashtag_hits = {}
    self.rmb_last_msg_id = nil
    self.rmb_last_time = 0
    self.rmb_click_count = 0
    self.message_cursor_id = nil
    self.display_cursor_id = nil
    self.cursor_highlight_timer = 0
    self.nav_messages = {}
    self.nav_pos = {}
    self.conv_area_x = nil
    self.conv_area_y = nil
    self.conv_area_w = nil
    self.conv_area_h = nil
    self.fullscreen_zoom = 1
    self.fullscreen_pan_x = 0
    self.fullscreen_pan_y = 0
    self.fullscreen_drag_start = nil
    self.notification_timer = nil
    self.smooth_scroll = 0
    self.scroll_dir = nil
    self.scroll_hold_start = nil
    self.menu_anim = 1
    return setmetatable(self, {__index = messenger_screen})
end

function messenger_screen:enter()
    self.model.input = ""
    self.model.scroll = 0
    self.smooth_scroll = 0
    self.model.list_offset = 0
    if self.tg.current_chat_id then
        self:select_chat(self.tg.current_chat_id)
    else
        self:load_chats_for_mode()
    end
end

function messenger_screen:select_chat(chat_id)
    if self.tg.current_chat_id == chat_id then return end
    self.tg:open_chat(chat_id)
    self.model.scroll = 0
    self.smooth_scroll = 0
    self.message_cursor_id = nil
    self.display_cursor_id = nil
    self.cursor_highlight_timer = 0
    self.nav_messages = {}
    self.nav_pos = {}
    if self.search_active and self.search_query ~= "" then
        self.tg:search_chat_messages(chat_id, self.search_query)
    end
end

function messenger_screen:list_entries()
    local entries = {{kind = "main", title = "Чаты"}}
    for _, filter in ipairs(self.tg.chat_filters or {}) do
        entries[#entries + 1] = {
            kind = "filter",
            id = filter.id,
            title = filter.title or ("Папка " .. tostring(filter.id)),
        }
    end
    entries[#entries + 1] = {kind = "archive", title = "Архив"}
    return entries
end

function messenger_screen:is_current_entry(entry)
    return entry.kind == self.list_kind
        and (entry.kind ~= "filter" or entry.id == self.list_filter_id)
end

function messenger_screen:current_list_entry()
    for _, entry in ipairs(self:list_entries()) do
        if self:is_current_entry(entry) then return entry end
    end
    return {kind = "main", title = "Чаты"}
end

function messenger_screen:load_chats_for_mode()
    if self.list_kind == "archive" then
        self.tg:load_archive_chats()
    elseif self.list_kind == "filter" then
        self.tg:load_filter_chats(self.list_filter_id)
    else
        self.tg:send({
            ["@type"] = "loadChats",
            chat_list = {["@type"] = "chatListMain"},
            limit = 20,
        }, "loadChats")
    end
end

function messenger_screen:switch_list(delta)
    local entries = self:list_entries()
    if #entries <= 1 then return end
    local index = 1
    for i, entry in ipairs(entries) do
        if self:is_current_entry(entry) then
            index = i
            break
        end
    end
    index = ((index - 1 + delta) % #entries) + 1
    local target = entries[index]
    if self:is_current_entry(target) then return end
    if self.tg.current_chat_id then self.tg:close_chat() end
    self.list_kind = target.kind
    self.list_filter_id = target.id
    self.archive_mode = target.kind == "archive"
    self.model.archive_mode = self.archive_mode
    self.model.selected = 1
    self.model.list_offset = 0
    self.model.scroll = 0
    self:load_chats_for_mode()
end

function messenger_screen:toggle_archive()
    self:switch_list(1)
end

function messenger_screen:archive_current_chat(archive)
    if not self.tg.current_chat_id then return end
    self.tg:archive_chat(self.tg.current_chat_id, archive)
end

function messenger_screen:get_visible_chat_list()
    if self.search_active and self.search_query ~= "" then
        local results, seen = {}, {}
        for _, chats in ipairs({self.tg.search_chat_results or {}, self.tg.public_search_results or {}}) do
            for _, chat in ipairs(chats) do
                if chat.id and not seen[chat.id] then
                    seen[chat.id] = true
                    results[#results + 1] = chat
                end
            end
        end
        return results
    end
    if self.list_kind == "archive" then return self.tg.archive_chats end
    if self.list_kind == "filter" then
        return (self.tg.filter_chats or {})[self.list_filter_id] or {}
    end
    -- Фильтруем каналы из основного списка чатов (посты из каналов не должны засорять список)
    local chats = self.tg.chats or {}
    local filtered = {}
    for _, chat in ipairs(chats) do
        local t = chat.type
        if t then
            local is_channel = (t["@type"] == "chatTypeChannel")
                or (t["@type"] == "chatTypeSupergroup" and t.is_channel == true)
            if not is_channel then
                filtered[#filtered + 1] = chat
            end
        else
            filtered[#filtered + 1] = chat
        end
    end
    return filtered
end

function messenger_screen:set_search_query(query, immediate)
    self.search_query = query or ""
    self.search_changed_at = love.timer.getTime()
    if immediate then
        self.search_changed_at = self.search_changed_at - 1
    end
    self.search_submitted_query = nil
    self.model.list_offset = 0
    self.model.selected = 1
    self.tg:search_chats("")
    self.tg:search_public_chats("")
    if self.search_query == "" then
        if self.tg.current_chat_id then
            self.tg:search_chat_messages(self.tg.current_chat_id, "")
        end
        self.search_submitted_query = ""
    else
        self.tg.search_chat_results = {}
        self.tg.public_search_results = {}
    end
end

function messenger_screen:submit_search()
    local query = self.search_query
    if query == self.search_submitted_query then return end
    self.search_submitted_query = query
    self.tg:search_chats(query)
    self.tg:search_public_chats(query)
    if self.tg.current_chat_id then
        self.tg:search_chat_messages(self.tg.current_chat_id, query)
    end
end

function messenger_screen:update(dt)
    -- Auto-clear notifications after 15 seconds
    if (self.tg.action_status ~= "" or self.tg.action_error ~= "") and not self.notification_timer then
        self.notification_timer = 15
    elseif self.notification_timer then
        self.notification_timer = self.notification_timer - dt
        if self.notification_timer <= 0 then
            self.tg.action_status = ""
            self.tg.action_error = ""
            self.notification_timer = nil
        end
    end

    if self.list_kind == "filter" then
        local found = false
        for _, filter in ipairs(self.tg.chat_filters or {}) do
            if filter.id == self.list_filter_id then
                found = true
                break
            end
        end
        if not found then
            self.list_kind = "main"
            self.list_filter_id = nil
            self.archive_mode = false
            self.model.archive_mode = false
        end
    end
    if self.search_active and self.search_query ~= ""
        and self.search_query ~= self.search_submitted_query
        and love.timer.getTime() - self.search_changed_at >= 0.25 then
        self:submit_search()
    end
    self.model.visible_chats = self:get_visible_chat_list()
    self.model:clamp_selection()

    local target_scroll = self.model.scroll or 0
    if self.smooth_scroll == nil or math.abs(target_scroll - self.smooth_scroll) > 2000 then
        self.smooth_scroll = target_scroll
    end
    local factor = 0.25
    self.smooth_scroll = self.smooth_scroll + (target_scroll - self.smooth_scroll) * factor
    if math.abs(target_scroll - self.smooth_scroll) < 0.5 then
        self.smooth_scroll = target_scroll
        if self.message_cursor_target_id then
            self.display_cursor_id = self.message_cursor_target_id
            self.message_cursor_target_id = nil
        end
    end
    -- Text preview: load file when downloaded
    if self.text_preview and self.text_preview.loading then
        local msg = self.text_preview.message
        local doc = msg and msg.content and msg.content.document
        local file = doc and doc.document
        local fl = file and file["local"]
        if fl and fl.is_downloading_completed and fl.path and fl.path ~= "" then
            local lines = {}
            local f = io.open(fl.path, "r")
            if f then
                for line in f:lines() do lines[#lines+1] = line end
                f:close()
            end
            self.text_preview.loading = false
            self.text_preview.lines = lines
        end
    end
    if self.tg.installed_sticker_sets_just_loaded and self.context_menu then
        self.tg.installed_sticker_sets_just_loaded = false
        local has_sticker_item = false
        for _, it in ipairs(self.context_menu.items or {}) do
            if it.action == "open_sticker_pack_by_name" or it.label == "Загрузка стикерпаков…" or it.label == "Нет установленных стикерпаков" then
                has_sticker_item = true
                break
            end
        end
        if has_sticker_item then
            self:open_sticker_pack_list()
        end
    end
    self.menu_anim = math.min(1, (self.menu_anim or 1) + dt * 12)

    -- Hold-to-scroll: while nav keys are held, accumulate scroll deltas
    local held_keys = {}
    if self.tg and love and love.keyboard and love.keyboard.isDown then
        if love.keyboard.isDown("left") then held_keys[#held_keys + 1] = "left" end
        if love.keyboard.isDown("right") then held_keys[#held_keys + 1] = "right" end
        if love.keyboard.isDown("pageup") then held_keys[#held_keys + 1] = "pageup" end
        if love.keyboard.isDown("pagedown") then held_keys[#held_keys + 1] = "pagedown" end
    end
    if held_keys[1] == "pageup" and self.tg.current_chat_id then
        local step = (self.conv_area_h or 300) * 0.9
        self.smooth_scroll = math.min(self.model.max_scroll or 0, (self.smooth_scroll or 0) + step * dt)
    elseif held_keys[1] == "pagedown" and self.tg.current_chat_id then
        local step = (self.conv_area_h or 300) * 0.9
        self.smooth_scroll = math.max(0, (self.smooth_scroll or 0) - step * dt)
    end
end

function messenger_screen:draw()
    local f = self.fonts
    local colors = ui.colors
    local w = ui.width()
    local h = ui.height()
    -- Wider chat list when no chat selected
    local left_width = self.tg.current_chat_id and math.floor(w * 0.30) or math.floor(w * 0.50)
    local right_width = w - left_width

    ui.rect(0, 0, w, h, colors.bg)
    ui.rect(0, 0, w, HEADER_HEIGHT, colors.header)
    if self.search_active then
        ui.text("Поиск", 24, 15, f.subtitle, colors.text)
    else
        local entry = self:current_list_entry()
        ui.text(ui.fit(entry.title, f.subtitle, left_width - 130), 24, 15, f.subtitle, colors.text)
    end
    if self.search_active then
        ui.rect(left_width + 8, 10, math.max(100, right_width - 190), 36, colors.panel_alt, 6)
        ui.text(ui.fit(self.search_query .. (self.search_query == "" and "Поиск чатов, каналов или @username…" or " |"), f.small, math.max(80, right_width - 210)),
            left_width + 18, 19, f.small, colors.text)
    end

    if self.forward_mode then
        ui.text("Пересылка — выберите чат назначения", w - 260, 18, f.tiny, colors.yellow)
    end

    local settings_btn_w = 36
    ui.rect(w - 20 - settings_btn_w, 15, settings_btn_w, 26, colors.panel_alt, 6)
    ui.text("⚙", w - 20 - settings_btn_w + 10, 17, f.small, colors.accent)

    local me = self.tg.me
    if self.search_active then
        ui.text("Esc — закрыть поиск", w - 190, 18, f.tiny, colors.muted)
    elseif me then
        local name = self.tg:user_name(me.id)
        ui.text(name, w - 30 - settings_btn_w - f.normal:getWidth(name), 18, f.normal, colors.text)
    else
        ui.text("Подключено", w - 30 - settings_btn_w - 90, 18, f.normal, colors.muted)
    end

    self:draw_loading_indicator(f, colors, w, left_width, right_width)

    self:draw_chat_list(left_width, h)

    local chat = self.model:current_chat()
    if chat then
        self:draw_conversation(chat, left_width, right_width, h)
    else
        ui.rect(left_width, HEADER_HEIGHT, right_width, h - HEADER_HEIGHT, colors.bg)
        ui.printf("Выберите чат слева", left_width, h / 2 - 20, right_width, "center", f.subtitle, colors.muted)
        ui.printf("↑/↓ — выбор, Enter — открыть, SELECT — управление", left_width, h / 2 + 18, right_width, "center", f.small, colors.muted)
    end

    if self.forward_mode then
        ui.text("MENU — отмена", 24, h - 28, f.tiny, colors.muted)
    else
        ui.text("MENU — выход  A — ввод/отпр.", 24, h - 28, f.tiny, colors.muted)
    end
    local action_message = self.tg.action_error ~= "" and self.tg.action_error or self.tg.action_status
    if action_message and action_message ~= "" then
        local color = self.tg.action_error ~= "" and colors.red or colors.green
        local alpha = 1
        if self.notification_timer and self.notification_timer < 1.5 then
            alpha = math.max(0, self.notification_timer / 1.5)
        end
        ui.printf(action_message, 24, h - 44, w - 48, "left", f.tiny,
            {color[1], color[2], color[3], alpha})
    end

    self:draw_notifications(f, colors, w)
    self:draw_context_menu(f, colors, w, h)
    self:draw_reaction_menu(f, colors, w, h)

    self:draw_edit_overlay(f, colors, w, h)
    if self.keyboard and self.keyboard.visible and not self.fullscreen_media
        and not self.tg.sticker_set_viewer then
        self.keyboard:draw(self:keyboard_preview())
    end
    self:draw_fullscreen_media(w, h)
    self:draw_sticker_pack(w, h)
    self:draw_text_preview(w, h)
    self:draw_file_browser(w, h)
end

function messenger_screen:draw_file_browser(w, h)
    local fb = self.file_browser
    if not fb then return end
    local f = self.fonts
    local colors = ui.colors
    love.graphics.setColor(0, 0, 0, 0.92)
    love.graphics.rectangle("fill", 0, 0, w, h)
    local panel_w = math.min(w - 32, 760)
    local panel_h = math.min(h - 32, 620)
    local panel_x = (w - panel_w) / 2
    local panel_y = (h - panel_h) / 2
    ui.rect(panel_x, panel_y, panel_w, panel_h, colors.panel, 8)
    ui.outline(panel_x, panel_y, panel_w, panel_h, colors.accent, 8)
    ui.text(ui.fit("Файлы: " .. (fb.path or ""), f.subtitle, panel_w - 24), panel_x + 12, panel_y + 8, f.subtitle, colors.text)
    local files = fb.files or {}
    if #files == 0 then
        ui.text("Папка пуста", panel_x + 12, panel_y + 40, f.small, colors.muted)
        ui.text("Esc/B — закрыть", panel_x + 12, panel_y + panel_h - 18, f.tiny, colors.muted)
        return
    end
    local line_h = 24
    local visible = math.floor((panel_h - 60) / line_h)
    local focus = fb.focus or 1
    local scroll = fb.scroll or 0
    local max_scroll = math.max(0, #files - visible)
    if focus < scroll + 1 then scroll = focus - 1 end
    if focus > scroll + visible then scroll = focus - visible end
    scroll = math.max(0, math.min(max_scroll, scroll))
    fb.scroll = scroll
    love.graphics.setScissor(panel_x + 8, panel_y + 36, panel_w - 16, panel_h - 52)
    local y = panel_y + 36
    for i = scroll + 1, math.min(#files, scroll + visible) do
        local entry = files[i]
        local is_focus = (i == focus)
        if is_focus then
            ui.rect(panel_x + 8, y - 2, panel_w - 16, line_h, colors.accent, 4)
        end
        local icon = entry.is_dir and "📁" or "📄"
        local col = is_focus and colors.bg or colors.text
        ui.text(ui.fit(icon .. " " .. entry.name, f.tiny, panel_w - 24), panel_x + 12, y + 4, f.tiny, col)
        y = y + line_h
    end
    love.graphics.setScissor()
    ui.text("↑↓ навигация · A Enter/отправить · B/Esc закрыть · PgUp/PgDn", panel_x + 12, panel_y + panel_h - 18, f.tiny, colors.muted)
end

function messenger_screen:draw_text_preview(w, h)
    local tp = self.text_preview
    if not tp then return end
    local f = self.fonts
    local colors = ui.colors
    love.graphics.setColor(0, 0, 0, 0.92)
    love.graphics.rectangle("fill", 0, 0, w, h)
    local panel_w = math.min(w - 32, 760)
    local panel_h = math.min(h - 32, 620)
    local panel_x = (w - panel_w) / 2
    local panel_y = (h - panel_h) / 2
    ui.rect(panel_x, panel_y, panel_w, panel_h, colors.panel, 8)
    ui.outline(panel_x, panel_y, panel_w, panel_h, colors.accent, 8)
    local title = "Текстовый файл"
    if tp.message and tp.message.content and tp.message.content.document then
        title = tp.message.content.document.file_name or title
    end
    ui.text(ui.fit(title, f.subtitle, panel_w - 24), panel_x + 12, panel_y + 8, f.subtitle, colors.text)
    if tp.loading then
        ui.text("Загрузка…", panel_x + 12, panel_y + 40, f.small, colors.muted)
        return
    end
    local lines = tp.lines or {}
    local line_h = f.tiny:getHeight() + 2
    local visible = math.floor((panel_h - 60) / line_h)
    local scroll = tp.scroll or 0
    local max_scroll = math.max(0, #lines - visible)
    if scroll > max_scroll then scroll = max_scroll; tp.scroll = scroll end
    love.graphics.setScissor(panel_x + 8, panel_y + 36, panel_w - 16, panel_h - 52)
    local y = panel_y + 36 - scroll * line_h
    for i = scroll + 1, math.min(#lines, scroll + visible + 2) do
        ui.text(ui.fit(lines[i] or "", f.tiny, panel_w - 24), panel_x + 12, y, f.tiny, colors.text)
        y = y + line_h
    end
    love.graphics.setScissor()
    ui.text(string.format("%d/%d строк · ↑↓ листать · PgUp/PgDn · Esc/B закрыть", scroll + 1, math.max(1, #lines)),
        panel_x + 12, panel_y + panel_h - 18, f.tiny, colors.muted)
end

function messenger_screen:draw_sticker_pack(w, h)
    local pack = self.tg.sticker_set_viewer
    if not pack then return end

    local colors, fonts = ui.colors, self.fonts
    local panel_w = math.min(w - 48, 760)
    local panel_h = math.min(h - 48, 620)
    local panel_x, panel_y = (w - panel_w) / 2, (h - panel_h) / 2
    local grid_x, grid_y = panel_x + 16, panel_y + 58
    local grid_w, grid_h = panel_w - 32, panel_h - 92
    local columns = math.max(1, math.floor(grid_w / 112))
    local cell_w = grid_w / columns
    local cell_h = math.min(116, cell_w)
    local rows_per_page = math.max(1, math.floor(grid_h / cell_h))
    local row_count = math.ceil(#(pack.stickers or {}) / columns)
    pack.scroll = math.max(0, math.min(math.max(0, row_count - rows_per_page), pack.scroll or 0))

    love.graphics.setColor(0, 0, 0, 0.76)
    love.graphics.rectangle("fill", 0, 0, w, h)
    ui.rect(panel_x, panel_y, panel_w, panel_h, colors.panel, 10)
    ui.outline(panel_x, panel_y, panel_w, panel_h, colors.accent_dark, 10)
    ui.text(ui.fit(pack.title or "Набор стикеров", fonts.subtitle, panel_w - 100),
        panel_x + 18, panel_y + 14, fonts.subtitle, colors.text)
    ui.text("×", panel_x + panel_w - 38, panel_y + 14, fonts.subtitle, colors.muted)

    if pack.loading then
        ui.printf("Загрузка набора…", panel_x + 20, panel_y + panel_h / 2, panel_w - 40,
            "center", fonts.normal, colors.muted)
    elseif pack.error then
        ui.printf("Не удалось загрузить набор: " .. tostring(pack.error), panel_x + 20,
            panel_y + panel_h / 2, panel_w - 40, "center", fonts.small, colors.red)
    elseif #pack.stickers == 0 then
        ui.printf("В этом наборе нет стикеров", panel_x + 20, panel_y + panel_h / 2,
            panel_w - 40, "center", fonts.small, colors.muted)
    else
        love.graphics.setScissor(grid_x, grid_y, grid_w, grid_h)
        local first_index = pack.scroll * columns + 1
        local last_index = math.min(#pack.stickers, first_index + rows_per_page * columns - 1)
        local selected_idx = pack.focus or pack.selected_index or 1
        for index = first_index, last_index do
            local slot = index - first_index
            local column = slot % columns
            local row = math.floor(slot / columns)
            local x = grid_x + column * cell_w
            local y = grid_y + row * cell_h
            local is_selected = index == selected_idx
            ui.rect(x + 3, y + 3, cell_w - 6, cell_h - 6, colors.panel_alt, 7)
            if is_selected then
                love.graphics.setColor(0.2, 0.6, 1, 0.9)
                love.graphics.rectangle("fill", x + 3, y + 3, cell_w - 6, cell_h - 6, 7)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.rectangle("line", x + 3, y + 3, cell_w - 6, cell_h - 6, 7, 3)
            end
            local sticker = pack.stickers[index]
            local file = sticker and sticker.sticker
            local entry = file and self.tg.stickers[file.id]
            local image = entry and (entry.image or (entry.frames and entry.frames[1]))
            if image then
                local max_size = math.min(cell_w - 20, cell_h - 32)
                local scale = math.min(max_size / image:getWidth(), max_size / image:getHeight())
                local image_w, image_h = image:getWidth() * scale, image:getHeight() * scale
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(image, x + (cell_w - image_w) / 2, y + 4 + (max_size - image_h) / 2,
                    0, scale, scale)
            else
                ui.printf(entry and entry.status == "error" and "Ошибка" or "Загрузка…",
                    x + 5, y + cell_h / 2 - fonts.tiny:getHeight() / 2, cell_w - 10,
                    "center", fonts.tiny, colors.muted)
            end
            local emoji = sticker and sticker.emoji
            if emoji and emoji ~= "" then
                ui.text(ui.fit(emoji, fonts.tiny, cell_w - 12), x + 6, y + cell_h - fonts.tiny:getHeight() - 3,
                    fonts.tiny, colors.muted)
            end
        end
        love.graphics.setScissor()
    end
    ui.text(tostring(#(pack.stickers or {})) .. " стикеров · стрелки фокус · A отправить · X предпросмотр · Esc закрыть",
        panel_x + 18, panel_y + panel_h - 25, fonts.tiny, colors.muted)

    -- Fullscreen sticker preview
    if self.sticker_fullscreen_image then
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.rectangle("fill", 0, 0, w, h)
        local img = self.sticker_fullscreen_image
        local fit = math.min((w - 48) / img:getWidth(), (h - 48) / img:getHeight())
        local dw, dh = img:getWidth() * fit, img:getHeight() * fit
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, (w - dw) / 2, (h - dh) / 2, 0, fit, fit)
        ui.text("X — отправить · Esc / B — закрыть", 12, h - 22, fonts.tiny, colors.muted)
    end
end

function messenger_screen:draw_notifications(f, colors, w)
    local notices = self.tg.notifications or {}
    if #notices == 0 then return end
    local now = love.timer.getTime()
    local box_w = 280
    local box_h = 58
    local x = w - box_w - 12
    local y = HEADER_HEIGHT + 8
    for _, notice in ipairs(notices) do
        local age = now - (notice.created or now)
        local alpha = 1
        if age > 13.5 then alpha = math.max(0, (15 - age) / 1.5) end
        if alpha > 0 then
            ui.rect(x, y, box_w, box_h,
                {colors.panel[1], colors.panel[2], colors.panel[3], 0.96 * alpha}, 6)
            ui.outline(x, y, box_w, box_h,
                {colors.accent_dark[1], colors.accent_dark[2], colors.accent_dark[3], alpha}, 6)
            local title = ui.fit(notice.title or "Telegram", f.small, box_w - 20)
            local text = ui.fit(notice.text or "", f.tiny, box_w - 20)
            ui.text(title, x + 10, y + 8, f.small,
                {colors.text[1], colors.text[2], colors.text[3], alpha})
            ui.text(text, x + 10, y + 30, f.tiny,
                {colors.muted[1], colors.muted[2], colors.muted[3], alpha})
            y = y + box_h + 6
        end
    end
end

function messenger_screen:draw_context_menu(f, colors, w, h)
    if not self.context_menu then return end
    local mx, my = self.context_menu.x, self.context_menu.y
    local menu_w = 240
    local row_h = 24
    local items = self.context_menu.items or {}
    local max_visible = 12
    local visible_count = math.min(#items, max_visible)
    local menu_h = visible_count * row_h + 12
    local anim = self.menu_anim or 1
    local offset = (1 - anim) * 8
    local mx2 = math.min(mx, w - menu_w - 8)
    local my2 = math.min(my + offset, h - menu_h - 8)

    self.context_menu.scroll = self.context_menu.scroll or 0
    local scroll = self.context_menu.scroll
    if scroll < 0 then scroll = 0 end
    if scroll > math.max(0, #items - visible_count) then scroll = math.max(0, #items - visible_count) end
    self.context_menu.scroll = scroll

    ui.rect(mx2, my2, menu_w, menu_h, alpha_color(colors.panel, 0.97 * anim), 6)
    ui.outline(mx2, my2, menu_w, menu_h, alpha_color(colors.accent_dark, anim), 6)

    for vi = 1, visible_count do
        local index = scroll + vi
        local item = items[index]
        if not item then break end
        local row_y = my2 + 6 + (vi - 1) * row_h
        if self.context_menu.index == index then
            ui.rect(mx2 + 4, row_y - 2, menu_w - 8, row_h,
                alpha_color(colors.accent_dark, anim), 4)
        end
        ui.text(item.label, mx2 + 12, row_y, f.small, alpha_color(colors.text, anim))
    end
    if #items > visible_count then
        local bar_h = math.max(10, visible_count / #items * (menu_h - 12))
        local bar_y = my2 + 6 + (scroll / math.max(1, #items - visible_count)) * (menu_h - 12 - bar_h)
        ui.rect(mx2 + menu_w - 6, my2 + 6, 4, menu_h - 12, colors.panel_alt, 2)
        ui.rect(mx2 + menu_w - 6, bar_y, 4, bar_h, colors.accent, 2)
    end
end

function messenger_screen:draw_reaction_menu(f, colors, w, h)
    local menu = self.reaction_menu
    if not menu then return end
    local anim = self.menu_anim or 1
    local items = menu.items or {}
    local cols = REACTION_COLUMNS
    local rows = math.max(1, math.ceil(#items / cols))
    local cell = 56
    local gap = 8
    local menu_w = cols * cell + (cols - 1) * gap + 32
    local menu_h = rows * cell + (rows - 1) * gap + 76
    local mx = math.floor((w - menu_w) / 2)
    local my = math.floor((h - menu_h) / 2)

    love.graphics.setColor(0, 0, 0, 0.55 * anim)
    love.graphics.rectangle("fill", 0, 0, w, h)
    ui.rect(mx, my, menu_w, menu_h, alpha_color(colors.panel, 0.98 * anim), 10)
    ui.outline(mx, my, menu_w, menu_h, alpha_color(colors.accent_dark, anim), 10)
    ui.text("Реакция", mx + 16, my + 12, f.small, alpha_color(colors.muted, anim))

    for index, item in ipairs(items) do
        local col = (index - 1) % cols
        local row = math.floor((index - 1) / cols)
        local x = mx + 16 + col * (cell + gap)
        local y = my + 44 + row * (cell + gap)
        if index == menu.index then
            ui.rect(x, y, cell, cell, alpha_color(colors.accent_dark, anim), 8)
        elseif item.chosen then
            ui.rect(x, y, cell, cell, alpha_color(colors.header, anim), 8)
            ui.outline(x, y, cell, cell, alpha_color(colors.accent, anim), 8)
        end
        ui.text(item.emoji, x + (cell - f.normal:getWidth(item.emoji)) / 2,
            y + (cell - f.normal:getHeight()) / 2, f.normal, alpha_color(colors.text, anim))
    end

    ui.text("A — отправить   B — отмена", mx + 16, my + menu_h - 24, f.tiny,
        alpha_color(colors.muted, anim))
end

function messenger_screen:draw_fullscreen_media(w, h)
    local fullscreen = self.fullscreen_media
    if not fullscreen then return end
    local image
    local media_index = fullscreen.media_index or 1
    if fullscreen.kind == "video" then
        image = self.tg:video_image(fullscreen.message)
    elseif fullscreen.kind == "video_note" then
        image = self.tg:video_note_image(fullscreen.message)
    elseif fullscreen.kind == "sticker" then
        image = self.tg:sticker_image(fullscreen.message)
    elseif fullscreen.kind == "animation" then
        image = self.tg:animation_image(fullscreen.message)
    else
        image = self.tg:photo_image(fullscreen.message, media_index)
    end
    love.graphics.setColor(0, 0, 0, 0.88)
    love.graphics.rectangle("fill", 0, 0, w, h)
    -- Animate fullscreen zoom
    if self.fullscreen_zoom_target and self.fullscreen_zoom < self.fullscreen_zoom_target then
        local elapsed = love.timer.getTime() - (self.fullscreen_zoom_start or love.timer.getTime())
        local t = math.min(1, elapsed / 0.25)
        self.fullscreen_zoom = 0.5 + 0.5 * t
        if t >= 1 then
            self.fullscreen_zoom = self.fullscreen_zoom_target
            self.fullscreen_zoom_target = nil
        end
    end

    if image then
        if fullscreen.video_note then
            local panel_h = 0
            local diameter = math.min(w - 48, h - 128)
            diameter = math.max(48, diameter)
            draw_circle_image(image, (w - diameter) / 2, math.max(16, (h - 88 - diameter) / 2), diameter)
        else
            local panel_h = 66
            local available_h = h - panel_h - 24
            local fit = math.min((w - 48) / image:getWidth(), available_h / image:getHeight())
            local scale = fit * (self.fullscreen_zoom or 1)
            local draw_w = image:getWidth() * scale
            local draw_h = image:getHeight() * scale
            local pan_x = self.fullscreen_pan_x or 0
            local pan_y = self.fullscreen_pan_y or 0
            local draw_x = (w - draw_w) / 2 + pan_x
            local draw_y = (h - draw_h) / 2 + pan_y - panel_h / 2
            -- Clamp draw area to allow panning within image bounds
            if draw_w > w then
                draw_x = math.max(w - draw_w, math.min(draw_x, 0))
            else
                draw_x = (w - draw_w) / 2
            end
            if draw_h > h then
                draw_y = math.max(h - draw_h, math.min(draw_y, 0))
            else
                draw_y = (h - draw_h) / 2 - panel_h / 2
            end
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(image, draw_x, draw_y, 0, scale, scale)
        end
    else
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Загрузка медиа…", 24, h / 2, w - 48, "center")
    end

    if fullscreen.kind == "video" then
        local position, duration, playing = self.tg:media_playback_state(fullscreen.message)
        local panel_w = math.min(w - 40, 440)
        local panel_x = (w - panel_w) / 2
        local panel_y = h - 66
        ui.rect(panel_x, panel_y, panel_w, 52, {0.08, 0.09, 0.12, 0.96}, 8)

        local button_x, button_y = panel_x + 12, panel_y + 12
        love.graphics.setColor(1, 1, 1, 1)
        if playing then
            love.graphics.rectangle("fill", button_x + 7, button_y + 4, 4, 14)
            love.graphics.rectangle("fill", button_x + 15, button_y + 4, 4, 14)
        else
            love.graphics.polygon("fill", button_x + 7, button_y + 3, button_x + 7, button_y + 19, button_x + 21, button_y + 11)
        end

        local track_x = panel_x + 44
        local track_w = panel_w - 100
        local track_y = panel_y + 20
        local progress = duration > 0 and math.min(1, math.max(0, position / duration)) or 0
        ui.rect(track_x, track_y, track_w, 5, {0.35, 0.37, 0.4}, 2)
        if progress > 0 then ui.rect(track_x, track_y, track_w * progress, 5, ui.colors.accent, 2) end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("fill", track_x + track_w * progress, track_y + 2.5, 5)

        local time_label = string.format("%d:%02d / %d:%02d",
            math.floor(position / 60), math.floor(position % 60),
            math.floor(duration / 60), math.floor(duration % 60))
        ui.printf(time_label, track_x, panel_y + 42, panel_w - 56, "left", self.fonts.tiny, ui.colors.text)
        self.player_controls = {
            button = {x = button_x, y = button_y, w = 28, h = 28},
            track = {x = track_x, y = track_y - 8, w = track_w, h = 30},
        }
    else
        self.player_controls = nil
    end
    if fullscreen.kind ~= "video" and fullscreen.kind ~= "video_note" then
        local hint = string.format("↑/↓ — масштаб %d%%   ←/→ — медиа   R2+↑↓←→ — панорамирование   A — загрузить в HiRes   B — назад", math.floor((self.fullscreen_zoom or 1) * 100))
        ui.text(hint, 24, h - 26, self.fonts.tiny, ui.colors.muted)
    else
        ui.text("←/→ — медиа   L1/R1 — ±5с   B — назад",
            24, h - 26, self.fonts.tiny, ui.colors.muted)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function messenger_screen:draw_edit_overlay(f, colors, w, h)
    if not self.edit_mode then return end
    local overlay_w = math.floor(w * 0.7)
    local lines = wrapped_lines(f.normal, self.edit_input, overlay_w - 64)
    local text_h = math.max(1, #lines) * f.normal:getHeight()
    local overlay_h = math.min(h - 32, math.max(150, text_h + 112))
    local overlay_x = math.floor((w - overlay_w) / 2)
    local overlay_y = math.floor((h - overlay_h) / 2)

    ui.rect(overlay_x, overlay_y, overlay_w, overlay_h, colors.panel, 8)
    ui.outline(overlay_x, overlay_y, overlay_w, overlay_h, colors.accent_dark, 8)

    ui.text("Редактирование сообщения", overlay_x + 20, overlay_y + 18, f.small, colors.muted)
    local text_box_y = overlay_y + 44
    local text_box_h = overlay_h - 88
    ui.rect(overlay_x + 20, text_box_y, overlay_w - 40, text_box_h, colors.panel_alt, 6)
    if self.edit_input == "" then
        ui.text("Текст...", overlay_x + 32, text_box_y + 10, f.normal, colors.muted)
    else
        draw_text_lines(lines, overlay_x + 32, text_box_y + 10, f.normal, colors.text)
    end
    ui.text("Shift+Enter — новая строка   Enter — сохранить   Esc — отмена",
        overlay_x + 20, overlay_y + overlay_h - 28, f.tiny, colors.muted)
end

function messenger_screen:context_menu_items(message)
    local items = {}
    -- "Посмотреть" — для GIF/анимаций открывает фуллскрин
    local content_type = message and message.content and message.content["@type"]
    if content_type == "messageAnimation" or content_type == "messageSticker" then
        items[#items + 1] = {label = "Посмотреть", action = "view_fullscreen"}
    end
    if content_type == "messageSticker" then
        items[#items + 1] = {label = "Стикерпак", action = "open_sticker_pack"}
        items[#items + 1] = {label = "Загрузить стикер", action = "download_sticker"}
    end
    if content_type == "messageDocument" then
        local doc = message.content.document
        local mime = doc and (doc.mime_type or "")
        local fname = doc and (doc.file_name or "")
        if mime:match("^text/") or fname:match("%.txt$") or fname:match("%.log$") or fname:match("%.md$") or fname:match("%.json$") or fname:match("%.lua$") then
            items[#items + 1] = {label = "Просмотреть текст", action = "preview_text"}
        end
    end

    -- "Скачать в hi-res" — для фото загружает最高 разрешение
    if content_type == "messagePhoto" then
        local hi = self.tg and self.tg:choose_photo_hires(message)
        if hi and hi.photo and hi.photo.id then
            local entry = self.photos and self.photos[hi.photo.id]
            local is_downloaded = false
            if entry ~= nil and entry.source_path ~= nil and entry.source_path ~= "" then
                is_downloaded = true
            end
            if is_downloaded then
                items[#items + 1] = {label = "Уже загружено", action = nil}
            else
                items[#items + 1] = {label = "Скачать в hi-res", action = "download_photo_hires"}
            end
        end
    end

    -- "Воспроизвести" — только для анимированных стикеров/анимаций
    local can_play_media = false
    if content_type == "messageAnimation" then
        can_play_media = true
    elseif content_type == "messageSticker" then
        can_play_media = self.tg.sticker_playback_supported and self.tg:sticker_playback_supported(message)
    elseif content_type == "messageVoiceNote" or content_type == "messageAudio" then
        can_play_media = true
    end
    if can_play_media then
        local _, _, entry = self.tg:media_file_for_message(message)
        if entry then
            local sticker = self.tg.choose_sticker_size and self.tg:choose_sticker_size(message)
            local is_tgs = sticker and sticker.format and sticker.format["@type"] == "stickerFormatTgs"
            local play_label = is_tgs and "Конвертировать и воспроизвести" or "Воспроизвести"
            if entry.playing then
                items[#items + 1] = {label = "Остановить", action = "stop_media"}
            elseif entry.frames and #entry.frames > 1 then
                items[#items + 1] = {label = play_label, action = "play_media"}
            elseif entry.source_path then
                items[#items + 1] = {label = play_label, action = "play_media"}
            else
                items[#items + 1] = {label = is_tgs and "Загрузить, конвертировать и воспроизвести"
                    or "Загрузить и воспроизвести", action = "play_media"}
            end
        else
            local sticker = self.tg.choose_sticker_size and self.tg:choose_sticker_size(message)
            local is_tgs = sticker and sticker.format and sticker.format["@type"] == "stickerFormatTgs"
            local play_label = is_tgs and "Загрузить, конвертировать и воспроизвести" or "Загрузить и воспроизвести"
            items[#items + 1] = {label = play_label, action = "play_media"}
        end
    end
    -- Detect sticker pack link in message text
    local msg_text = ""
    if message and message.content then
        if message.content.text and message.content.text.text then
            msg_text = message.content.text.text
        elseif message.content.caption and message.content.caption.text then
            msg_text = message.content.caption.text
        end
    end
    local sticker_link = msg_text:match("https?://t%.me/addstickers/[^%s]+") or msg_text:match("https?://telegram%.me/addstickers/[^%s]+")
    if sticker_link then
        items[#items + 1] = {label = "Открыть стикерпак", action = "open_sticker_pack_from_link", link = sticker_link}
    end

    items[#items + 1] = {label = "Копировать", action = "copy"}
    items[#items + 1] = {label = "Реакция", action = "react"}
    items[#items + 1] = {label = "Переслать", action = "forward"}
    items[#items + 1] = {label = message.is_pinned and "Открепить" or "Закрепить", action = message.is_pinned and "unpin" or "pin"}
    items[#items + 1] = {label = "Удалить для меня", action = "delete"}
    items[#items + 1] = {label = "Удалить для всех", action = "delete_all"}
    -- "Write to author" for non-outgoing messages
    if not self:outgoing(message) then
        local sender = message.sender_id
        if sender and sender["@type"] == "messageSenderUser" then
            items[#items + 1] = {label = "Написать ему", action = "write_to_author", sender_id = sender.user_id}
        end
    end
    if self:outgoing(message) and message.content and message.content["@type"] == "messageText" then
        items[#items + 1] = {label = "Редактировать", action = "edit"}
    end
    return items
end

function messenger_screen:chat_context_menu_items(chat)
    local settings = chat and chat.notification_settings or {}
    local muted = (tonumber(settings.mute_for) or 0) > 0
    local is_archived = chat and chat.chat_list and chat.chat_list["@type"] == "chatListArchive"
    local items = {
        {label = muted and "Размутить" or "Замутить навсегда", action = muted and "unmute_chat" or "mute_chat"},
        {label = is_archived and "Вернуть из архива" or "Отправить в архив", action = is_archived and "unarchive_chat" or "archive_chat"},
        {label = "Мой профиль", action = "open_my_profile"},
        {label = "Отправить файл", action = "open_file_browser"},
    }
    local chat_type = chat and chat.type and chat.type["@type"]
    if chat_type ~= "chatTypePrivate" and chat_type ~= "chatTypeSecret" then
        items[#items + 1] = {label = "Покинуть чат", action = "leave_chat"}
    end
    return items
end

function messenger_screen:is_loading()
    -- Chats list still loading (no chat selected yet)
    if not self.tg.current_chat_id and not self.tg.chats_loaded then
        return true
    end
    -- Current chat history loading
    local chat = self.model:current_chat()
    if chat then
        local hs = self.tg.history_state and self.tg.history_state[chat.id]
        if hs and hs.loading then return true end
    end
    -- Filter folder loading
    if self.list_kind == "filter" and self.list_filter_id
        and self.tg.filter_load_pending[self.list_filter_id] then
        return true
    end
    -- Archive loading
    if self.list_kind == "archive" and not self.tg.archive_loaded then
        return true
    end
    -- Search loading
    if self.search_active and self.search_query ~= "" then
        if self.tg.dialog_search_query and self.tg.dialog_search_query[chat and chat.id or 0]
            and self.tg.dialog_search_query[chat and chat.id or 0] ~= self.search_query then
            return true
        end
    end
    return false
end

function messenger_screen:draw_loading_indicator(f, colors, w, left_width, right_width)
    if not self:is_loading() then return end
    local now = love.timer.getTime()

    -- Spinner in top center (tray area)
    local cx = w / 2
    local cy = HEADER_HEIGHT / 2
    local radius = 8
    local angle = (now * 3) % (math.pi * 2)
    love.graphics.setColor(colors.accent[1], colors.accent[2], colors.accent[3], 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.arc("line", cx, cy, radius, angle, angle + math.pi * 1.5)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function messenger_screen:draw_chat_list(left_width, h)
    local f = self.fonts
    local colors = ui.colors
    local list_h = h - HEADER_HEIGHT
    local visible = math.max(1, math.floor(list_h / ITEM_HEIGHT))

    self.model:update_list_offset(visible)

    ui.rect(0, HEADER_HEIGHT, left_width, list_h, colors.panel)
    ui.rect(left_width - 1, HEADER_HEIGHT, 1, list_h, colors.bg)

    local chat_list = self:get_visible_chat_list()
    if #chat_list == 0 then
        if self.search_active and self.search_query ~= "" then
            local search_error = self.tg.chat_search_error or self.tg.public_search_error
            local label = search_error
                and ("Ошибка поиска: " .. search_error)
                or "Чаты не найдены"
            if self.tg.chat_search_query ~= self.search_query
                or self.tg.public_search_query ~= self.search_query
                or self.tg.public_search_pending or self.tg.public_search_user_pending then
                label = "Поиск чатов, каналов и пользователей..."
            end
            ui.printf(label, 16, HEADER_HEIGHT + 40, left_width - 32, "left", f.small,
                search_error and colors.red or colors.muted)
            return
        elseif self.list_kind == "filter" then
            if self.tg.filter_load_pending[self.list_filter_id] then
                ui.printf("Загрузка папки...", 16, HEADER_HEIGHT + 40, left_width - 32, "left", f.small, colors.muted)
            else
                ui.printf("В папке нет чатов", 16, HEADER_HEIGHT + 40, left_width - 32, "left", f.small, colors.muted)
            end
            return
        elseif self.list_kind == "archive" then
            if self.tg.archive_load_error then
                ui.printf("Не удалось загрузить архив: " .. self.tg.archive_load_error, 16, HEADER_HEIGHT + 40, left_width - 32, "left", f.small, colors.red)
            elseif self.tg.archive_loaded then
                ui.printf("Архив пуст", 16, HEADER_HEIGHT + 40, left_width - 32, "left", f.small, colors.muted)
            else
                ui.printf("Загрузка архива...", 16, HEADER_HEIGHT + 40, left_width - 32, "left", f.small, colors.muted)
            end
            return
        elseif self.tg.chats_loaded then
            ui.printf("Нет чатов", 16, HEADER_HEIGHT + 40, left_width - 32, "left", f.small, colors.muted)
        else
            ui.printf("Загрузка чатов...", 16, HEADER_HEIGHT + 40, left_width - 32, "left", f.small, colors.muted)
        end
        return
    end

    for index = self.model.list_offset + 1, math.min(#chat_list, self.model.list_offset + visible) do
        local chat = chat_list[index]
        local y = HEADER_HEIGHT + (index - self.model.list_offset - 1) * ITEM_HEIGHT
        local is_selected = index == self.model.selected
        local is_current = self.tg.current_chat_id == chat.id

        chat_item.draw(self, chat, 0, y, left_width, ITEM_HEIGHT, f, colors, is_selected, is_current)
    end
end

function messenger_screen:draw_conversation(chat, left_width, right_width, h)
    local f = self.fonts
    local colors = ui.colors
    local panel_x = left_width
    local panel_w = right_width

    ui.rect(panel_x, HEADER_HEIGHT, panel_w, CHAT_HEADER_HEIGHT, colors.header)
    local profile_user_id = self.tg:private_chat_user_id(chat)
    if profile_user_id then
        self.tg:ensure_user(profile_user_id)
        ui.text(self.tg:user_status_text(profile_user_id), panel_x + 20, HEADER_HEIGHT + 40, f.tiny, colors.muted)
    else
        ui.text("Открыть профиль", panel_x + 20, HEADER_HEIGHT + 40, f.tiny, colors.muted)
    end
    ui.text(ui.fit(chat.title or "Chat", f.subtitle, panel_w - 48), panel_x + 20, HEADER_HEIGHT + 12, f.subtitle, colors.text)

    local area_x = panel_x
    local area_y = HEADER_HEIGHT + CHAT_HEADER_HEIGHT
    local area_w = panel_w
    local area_h = h - area_y - INPUT_HEIGHT

    self.conv_area_x, self.conv_area_y = area_x, area_y
    self.conv_area_w, self.conv_area_h = area_w, area_h
    self.nav_messages = {}
    self.nav_pos = {}

    ui.rect(area_x, area_y, area_w, area_h, colors.bg)

    local messages = self.tg:get_messages(chat.id)
    local search_loading = false
    if self.search_active and self.search_query ~= "" then
        local search_results = self.tg.dialog_search_results and self.tg.dialog_search_results[chat.id]
        search_loading = search_results == false or self.tg.dialog_search_query[chat.id] ~= self.search_query
        messages = type(search_results) == "table" and search_results or {}
    end
    local items = conversation_items(messages)
    if #messages == 0 then
        local empty_label = self.search_active and self.search_query ~= "" and "Сообщения не найдены" or "Нет сообщений"
        if self.search_active and self.tg.dialog_search_error then
            empty_label = "Ошибка поиска: " .. self.tg.dialog_search_error
        elseif search_loading then
            empty_label = "Поиск сообщений..."
        end
        ui.printf(empty_label, area_x, area_y + area_h / 2 - 20, area_w, "center", f.small, colors.muted)
    end

    local font = f.normal
    local small = f.small
    local padding = 10
    -- Wider bubbles: 85% of conversation area
    local max_bubble = math.floor(area_w * 0.85)
    -- Limit wrap width to prevent emoji overflow
    local wrap_width = math.min(max_bubble - padding * 2, 280)
    local line_height = font:getHeight()
    local small_height = small:getHeight()
    local heights = {}
    local total = 0

    for i, item in ipairs(items) do
        if item.date_label then
            heights[i] = 28
            total = total + heights[i] + 6
        elseif item.action_label then
            heights[i] = 24
            total = total + heights[i] + 6
        elseif item.messages then
            local count = #item.messages
            local cols = math.min(3, count)
            local gap = 3
            local cell = math.max(48, math.floor((max_bubble - padding * 2 - gap * (cols - 1)) / cols))
            local rows = math.ceil(count / cols)
            local author_height = self:outgoing(item.messages[1]) and 0 or small_height + 2
            heights[i] = padding * 2 + author_height + rows * cell + gap * (rows - 1) + small_height + 4
            local reactions = helpers.merge_message_reactions(item.messages)
            local reaction_rows = helpers.reaction_rows(reactions, f.tiny, max_bubble - padding * 2)
            heights[i] = heights[i] + #reaction_rows * 22
            total = total + heights[i] + 6
        else
        local message = item.message
        local author_height = 0
        if not self:outgoing(message) then
            author_height = small_height + 2
        end
        local image, image_width, image_height = self:photo_geometry(message, max_bubble, padding)
        local is_sticker = false
        local is_animation = false
        local is_video = false
        local sticker_emoji = ""
        local animation_label = ""
        local video_label = ""
        local content_type = message.content and message.content["@type"]
        local sticker_like_doc = false
        if content_type == "messageDocument" then
            local doc = message.content.document
            if doc then
                local mime = doc.mime_type or ""
                local fname = doc.file_name or ""
                sticker_like_doc = mime:match("^video/") ~= nil or fname:match("%.webm$") ~= nil or fname:match("%.tgs$") ~= nil
            end
        end
        if not image then
            local simg, sw, sh, semoji = self:sticker_geometry(message, max_bubble, padding)
            if simg then
                image, image_width, image_height, sticker_emoji = simg, sw, sh, semoji
                is_sticker = true
            end
        end
        if not is_sticker and sticker_like_doc then
            is_sticker = true
            local simg, sw, sh, semoji = self:sticker_geometry(message, max_bubble, padding)
            if simg then
                image, image_width, image_height, sticker_emoji = simg, sw, sh, semoji
            else
                local aimg, aw, ah, alabel = self:animation_geometry(message, max_bubble, padding)
                if aimg then
                    image, image_width, image_height, animation_label = aimg, aw, ah, alabel
                end
            end
        end
        if not image then
            local aimg, aw, ah, alabel = self:animation_geometry(message, max_bubble, padding)
            if aimg then
                image, image_width, image_height, animation_label = aimg, aw, ah, alabel
                is_animation = true
            end
        end
        if not image and message.content and (message.content["@type"] == "messageVideo" or message.content["@type"] == "messageVideoNote") then
            is_video = true
            local vimg, vw, vh, vlabel = self:video_geometry(message, max_bubble, padding)
            if vimg then
                image, image_width, image_height, video_label = vimg, vw, vh, vlabel
            else
                video_label = "[видео]"
            end
        end
        local height
        if image then
            local caption = (is_sticker or is_animation or is_video) and "" or self:photo_caption(message)
            local _, caption_lines = font:getWrap(caption, image_width)
            local caption_height = caption ~= "" and (#caption_lines * line_height + 4) or 0
            if is_video and message.content and message.content["@type"] == "messageVideoNote" then
                height = padding * 2 + author_height + image_height + 2
            else
                height = padding * 2 + author_height + image_height + caption_height + small_height + 2
            end
        elseif is_sticker and sticker_emoji ~= "" then
            local emoji_font = f.subtitle
            local _, emoji_lines = emoji_font:getWrap(sticker_emoji, wrap_width)
            local emoji_line_count = math.max(1, #emoji_lines)
            height = padding * 2 + author_height + emoji_line_count * emoji_font:getHeight() + small_height + 2
        elseif is_animation and animation_label ~= "" then
            local small_font = f.small
            local _, label_lines = small_font:getWrap(animation_label, wrap_width)
            local label_line_count = math.max(1, #label_lines)
            height = padding * 2 + author_height + label_line_count * small_font:getHeight() + small_height + 2
        elseif is_video and video_label ~= "" then
            local small_font = f.small
            local _, label_lines = small_font:getWrap(video_label, wrap_width)
            local label_line_count = math.max(1, #label_lines)
            height = padding * 2 + author_height + label_line_count * small_font:getHeight() + small_height + 2
        elseif message.content and message.content["@type"] == "messageAudio" then
            height = padding * 2 + author_height + 54 + small_height + 2
        elseif message.content and message.content["@type"] == "messageVoiceNote" then
            height = padding * 2 + author_height + 38 + small_height + 2
        elseif message.content and message.content["@type"] == "messageDocument" then
            local text = self.tg:document_label(message)
            local lines = wrapped_lines(font, text, math.max(32, wrap_width - 28))
            height = padding * 2 + author_height + math.max(1, #lines) * line_height + small_height + 2
        else
            local text = self.tg:message_text(message)
    local entities = (message and message.content and message.content.text and message.content.text.entities) or {}
            local lines = wrapped_lines(font, text, wrap_width)
            local line_count = math.max(1, #lines)
            height = padding * 2 + author_height + line_count * line_height + small_height + 2
        end
        local reactions = helpers.reaction_rows(helpers.reaction_summary(message), f.tiny, max_bubble - padding * 2)
        height = height + #reactions * 22
        local download_state = self.tg:media_download_state(message)
        if download_state and download_state.status == "downloading" then
            height = height + 30
        end
        heights[i] = height
        total = total + height + 6
        end
    end

    self.model.max_scroll = math.max(0, total - area_h)
    if self.model.scroll > self.model.max_scroll then self.model.scroll = self.model.max_scroll end
    if self.model.scroll < 0 then self.model.scroll = 0 end
    local history_state = self.tg.history_state and self.tg.history_state[chat.id]
    if history_state and history_state.stick_to_top then
        self.model.scroll = self.model.max_scroll
        self.smooth_scroll = self.model.max_scroll
        if history_state.new_page_top_id then
            self.message_cursor_id = history_state.new_page_top_id
        end
        history_state.stick_to_top = nil
    end

    love.graphics.setScissor(area_x, area_y, area_w, area_h)
    local y = area_y + area_h + (self.smooth_scroll or self.model.scroll)
    self.message_hits = {}
    self.media_hits = {}
    self.profile_hits = {}
    self.hashtag_hits = {}
    for i = #items, 1, -1 do
        local item = items[i]
        if item.date_label then
            local date_height = 28
            y = y - date_height - 6
            if y + date_height >= area_y and y <= area_y + area_h then
                local label_w = f.tiny:getWidth(item.date_label) + 22
                local label_x = area_x + (area_w - label_w) / 2
                ui.rect(label_x, y + 3, label_w, 22, colors.header, 10)
                ui.printf(item.date_label, label_x, y + 6, label_w, "center", f.tiny, colors.muted)
            end
            if y < area_y - 100 then break end
        elseif item.action_label then
            local action_height = 24
            y = y - action_height - 6
            if y + action_height >= area_y and y <= area_y + area_h then
                local label_w = math.min(area_w - 20, f.tiny:getWidth(item.action_label) + 22)
                local label_x = area_x + (area_w - label_w) / 2
                ui.rect(label_x, y + 2, label_w, 20, colors.header, 10)
                ui.printf(item.action_label, label_x, y + 5, label_w, "center", f.tiny, colors.muted)
            end
            if y < area_y - 100 then break end
        else
        local height = heights[i] or 60
        y = y - height - 6
        local nav_msg = item.messages and item.messages[1] or item.message
        if nav_msg then
            self.nav_messages[#self.nav_messages + 1] = nav_msg
            self.nav_pos[nav_msg.id] = {y = y, h = height}
        end
        if y + height >= area_y and y <= area_y + area_h then
            if item.messages then
                self:draw_album(item.messages, area_x, y, area_w, height, max_bubble, padding, small_height, colors)
            else
                local hit = { message = item.message, x = area_x, y = y, w = area_w, h = height }
                table.insert(self.message_hits, hit)
                self:draw_message(item.message, area_x, y, area_w, height, max_bubble, padding, wrap_width, small_height, line_height, colors, hit)
            end
            if nav_msg and self.display_cursor_id == nav_msg.id then
                local c = colors.accent
                ui.outline(area_x + 1, y + 1, area_w - 2, height - 2, {c[1], c[2], c[3], 0.9}, 6)
            end
        end
        if y < area_y - 100 then break end
        end
    end
    love.graphics.setScissor()
    local ordered = {}
    for index = #self.nav_messages, 1, -1 do
        ordered[#ordered + 1] = self.nav_messages[index]
    end
    self.nav_messages = ordered
    if self.message_cursor_id and not self.nav_pos[self.message_cursor_id] then
        self.message_cursor_id = nil
        self.display_cursor_id = nil
    end
    if not self.message_cursor_id and #ordered > 0 then
        self.message_cursor_id = ordered[#ordered].id
        self.display_cursor_id = ordered[#ordered].id
    end
    -- Sync display cursor when scroll is settled
    if math.abs((self.model.scroll or 0) - (self.smooth_scroll or 0)) < 1 then
        self.display_cursor_id = self.message_cursor_id
    end

    self.load_more_button = nil
    if history_state and not (self.search_active and self.search_query ~= "")
        and (history_state.loading or history_state.has_more or history_state.error)
        and self.model.scroll >= self.model.max_scroll - 12 then
        local button_w, button_h = 146, 28
        local button_x, button_y = area_x + (area_w - button_w) / 2, area_y + 6
        local label = history_state.loading and "Загрузка..."
            or history_state.error and "Повторить загрузку"
            or "Загрузить ещё"
        ui.rect(button_x, button_y, button_w, button_h, colors.header, 8)
        ui.printf(label, button_x + 4, button_y + 6, button_w - 8, "center", f.tiny,
            history_state.error and colors.red or colors.text)
        self.load_more_button = {x = button_x, y = button_y, w = button_w, h = button_h}
    end

    self:draw_input(panel_x, panel_w, h)
end

function messenger_screen:draw_message(message, area_x, y, area_w, height, max_bubble, padding, wrap_width, small_height, line_height, colors, hit)
    local function sticker_like_document(message)
        local content = message and message.content
        if not content or content["@type"] ~= "messageDocument" then return false end
        local doc = content.document
        if not doc then return false end
        local mime = doc.mime_type or ""
        local fname = doc.file_name or ""
        return mime:match("^video/") ~= nil or fname:match("%.webm$") ~= nil or fname:match("%.tgs$") ~= nil
    end
    local f = self.fonts
    local content = message and message.content
    local content_type = content and content["@type"]
    local is_sticker_like_doc = sticker_like_document(message)
    if content_type == "messageSticker" or is_sticker_like_doc then
        self.tg:ensure_sticker(message)
        self.tg:ensure_animated_sticker(message)
    end
    if content_type == "messageAnimation" then
        self.tg:ensure_animation(message)
        self.tg:ensure_animated_animation(message)
    end
    if content_type == "messageVideo" then
        self.tg:ensure_video(message)
    end
    if content_type == "messageVideoNote" then
        self.tg:ensure_video_note(message)
    end
    local outgoing = self:outgoing(message)
    local text = self.tg:message_text(message)
    local entities = (message and message.content and message.content.text and message.content.text.entities) or {}
    local sender_name = not outgoing and self.tg:sender_name(message) or nil
    local download_state = self.tg:media_download_state(message)
    local is_downloading = download_state and download_state.status == "downloading"
    local image, image_width, image_height = self:photo_geometry(message, max_bubble, padding)
    local is_sticker = false
    local is_animation = false
    local is_video = false
    local animation_label = ""
    local sticker_emoji = ""
    local video_label = ""
    local is_selected = self.selected_messages[message.id] ~= nil
    local reactions = helpers.reaction_rows(
        helpers.reaction_summary(message), f.tiny, max_bubble - padding * 2
    )
    local reactions_height = #reactions * 22
    local is_document = (content_type == "messageDocument" or content_type == "messageAudio") and not is_sticker_like_doc
    local display_text = is_document and self.tg:document_label(message) or text
    if not image then
        local simg, sw, sh, semoji = self:sticker_geometry(message, max_bubble, padding)
        if simg then
            image, image_width, image_height, sticker_emoji = simg, sw, sh, semoji
            is_sticker = true
        end
    end
    if not is_sticker and is_sticker_like_doc then
        is_sticker = true
        local simg, sw, sh, semoji = self:sticker_geometry(message, max_bubble, padding)
        if simg then
            image, image_width, image_height, sticker_emoji = simg, sw, sh, semoji
        else
            local aimg, aw, ah, alabel = self:animation_geometry(message, max_bubble, padding)
            if aimg then
                image, image_width, image_height, animation_label = aimg, aw, ah, alabel
            end
        end
    end
    if content_type == "messageAnimation" then
        is_animation = true
        local aimg, aw, ah, alabel = self:animation_geometry(message, max_bubble, padding)
        if aimg then
            image, image_width, image_height, animation_label = aimg, aw, ah, alabel
        else
            animation_label = "[GIF]"
        end
    end
    if not image and content_type and (content_type == "messageVideo" or content_type == "messageVideoNote") then
        is_video = true
        local vimg, vw, vh, vlabel = self:video_geometry(message, max_bubble, padding)
        if vimg then
            image, image_width, image_height, video_label = vimg, vw, vh, vlabel
        else
            video_label = "[видео]"
        end
    end
    local caption = (is_sticker or is_animation or is_video) and "" or (image and self:photo_caption(message) or "")
    local bubble_w
    local draw_bubble_bg = not is_sticker and not (content_type == "messageVideoNote")

    if image then
        local _, caption_lines = f.normal:getWrap(caption, image_width)
        local caption_width = 0
        for _, line in ipairs(caption_lines or {}) do
            caption_width = math.max(caption_width, f.normal:getWidth(line))
        end
        bubble_w = image_width + padding * 2
    else
        local _, lines = f.normal:getWrap(display_text, is_document and math.max(32, wrap_width - 28) or wrap_width)
        local max_line = 0
        for _, line in ipairs(lines or {}) do
            local line_w = f.normal:getWidth(line)
            -- Safety: if line visually exceeds wrap_width (e.g. emoji width), force re-wrap
            if line_w > wrap_width then
                local _, relines = f.normal:getWrap(display_text, wrap_width * 0.75)
                lines = relines
                max_line = 0
                for _, l in ipairs(relines or {}) do
                    max_line = math.max(max_line, f.normal:getWidth(l))
                end
            else
                max_line = math.max(max_line, line_w)
            end
        end
        bubble_w = math.min(max_bubble, math.max(96, max_line + padding * 2 + (is_document and 28 or 0)))
    end
    if sender_name then
        bubble_w = math.max(bubble_w, math.min(max_bubble, f.small:getWidth(sender_name) + padding * 2))
    end
    bubble_w = math.min(max_bubble, math.max(
        bubble_w, helpers.reaction_rows_width(reactions) + padding * 2
    ))
    if is_downloading then
        bubble_w = math.min(max_bubble, math.max(bubble_w, 210))
    end

    if message.content and (message.content["@type"] == "messageVoiceNote"
        or message.content["@type"] == "messageAudio") then
        bubble_w = math.min(max_bubble, math.max(bubble_w, 220))
    end

    local x = outgoing and (area_x + area_w - bubble_w - 18) or (area_x + 28)
    if draw_bubble_bg then
        if is_selected then
            ui.rect(x, y, bubble_w, height, colors.accent, 10)
        elseif outgoing then
            ui.rect(x, y, bubble_w, height, colors.accent_dark, 10)
        else
            ui.rect(x, y, bubble_w, height, colors.panel_alt, 10)
        end
    elseif is_selected then
        ui.rect(x, y, bubble_w, height, colors.accent, 10)
    end

    local text_y = y + padding
    if not outgoing then
        local sender_id = message.sender_id and message.sender_id["@type"] == "messageSenderUser" and message.sender_id.user_id
        ui.text(ui.fit(sender_name, f.small, bubble_w - padding * 2), x + padding, text_y, f.small, colors.accent)
        self:draw_sender_avatar(sender_id, sender_name, x - 27, text_y, 22)
        if sender_id then
            hit.profile_user_id = sender_id
            self.profile_hits[#self.profile_hits + 1] = {
                user_id = sender_id, x = x - 27, y = text_y, w = bubble_w + 27, h = small_height,
            }
        end
        text_y = text_y + small_height + 2
    end

    if image then
        local media_x, media_y = x + padding, text_y
        local content_kind = message.content and message.content["@type"]
        if content_kind == "messageVideoNote" then
            draw_circle_image(image, media_x, media_y, image_width)
            -- Duration label in corner
            local dur = message.content and message.content.video_note and message.content.video_note.duration
            if dur then
                local mins = math.floor(dur / 60)
                local secs = dur % 60
                local label = string.format("%d:%02d", mins, secs)
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.print(label, media_x + image_width - 30, media_y + image_width - 16)
                love.graphics.setColor(1, 1, 1, 1)
            end
        else
            local scale = image_width / image:getWidth()
            love.graphics.draw(image, media_x, media_y, 0, scale, scale)
        end
        if content_kind == "messagePhoto" or content_kind == "messageVideo" or content_kind == "messageVideoNote" then
            hit.media = true
            hit.media_kind = (content_kind == "messagePhoto") and "photo" or "video"
            hit.media_circle = content_kind == "messageVideoNote"
            hit.media_x, hit.media_y = media_x, media_y
            hit.media_w, hit.media_h = image_width, image_height
            self.media_hits[#self.media_hits + 1] = hit
        elseif is_sticker or is_animation then
            local can_play = not is_sticker or self.tg:sticker_playback_supported(message)
            hit.media = true
            hit.media_kind = is_sticker and "sticker" or "animation"
            hit.media_x, hit.media_y = media_x, media_y
            hit.media_w, hit.media_h = image_width, image_height
            -- Store sticker set link for opening sticker pack (stickers + TGS/WebM animations)
            local sticker_obj = nil
            if message and message.content then
                if message.content.sticker then
                    sticker_obj = message.content.sticker
                elseif message.content.animation then
                    sticker_obj = message.content.animation
                end
            end
            if (is_sticker or is_animation) and sticker_obj then
                local set_id = sticker_obj.set_id
                if not set_id and sticker_obj.sticker then
                    set_id = sticker_obj.sticker.set_id
                end
                if set_id then
                    hit.link = "https://t.me/addstickers/" .. tostring(set_id)
                    hit.sticker_set_id = set_id
                    -- Also store in message for context menu access
                    message._sticker_set_link = hit.link
                    message._sticker_set_id = set_id
                end
            end
            self.media_hits[#self.media_hits + 1] = hit
            if can_play then
                local _, _, playback_entry = self.tg:media_file_for_message(message)
                local button_x, button_y = media_x + image_width - 22, media_y + image_height - 22
                hit.play_x, hit.play_y = button_x, button_y
                hit.play_w, hit.play_h = 24, 24
                love.graphics.setColor(colors.header[1], colors.header[2], colors.header[3], 0.88)
                love.graphics.circle("fill", button_x + 12, button_y + 12, 12)
                love.graphics.setColor(colors.white)
                if playback_entry and playback_entry.playing then
                    love.graphics.rectangle("fill", button_x + 8, button_y + 7, 3, 10)
                    love.graphics.rectangle("fill", button_x + 14, button_y + 7, 3, 10)
                else
                    love.graphics.polygon("fill", button_x + 9, button_y + 6, button_x + 9, button_y + 18, button_x + 18, button_y + 12)
                end
            end
        end
        text_y = text_y + image_height + 4
        if caption ~= "" then
            ui.printf(caption, x + padding, text_y, image_width, "left", f.normal, colors.text)
        end
        if is_sticker and sticker_emoji ~= "" then
            ui.text(sticker_emoji, x + padding, text_y + 4, f.small, colors.accent)
        end
    elseif is_sticker and sticker_emoji ~= "" then
        ui.text(sticker_emoji, x + padding, text_y, f.small, colors.accent)
    elseif message.content and message.content["@type"] == "messageAudio" then
        local _, _, audio_entry = self.tg:media_file_for_message(message)
        self:draw_music_track(message, audio_entry, x + padding, text_y, bubble_w - padding * 2, colors)
        hit.voice = true
        hit.voice_x, hit.voice_y = x + padding, text_y
        hit.voice_w, hit.voice_h = bubble_w - padding * 2, 54
    elseif message.content and message.content["@type"] == "messageVoiceNote" then
        local _, _, voice_entry = self.tg:media_file_for_message(message)
        self:draw_voice_note(message, voice_entry, x + padding, text_y, bubble_w - padding * 2, colors)
        hit.voice = true
        hit.voice_x, hit.voice_y = x + padding, text_y
        hit.voice_w, hit.voice_h = bubble_w - padding * 2, 38
    elseif is_animation and animation_label ~= "" then
        ui.printf(animation_label, x + padding, text_y, wrap_width, "left", f.small, colors.muted)
    elseif is_video and video_label ~= "" then
        ui.printf(video_label, x + padding, text_y, wrap_width, "left", f.small, colors.muted)
    elseif is_document then
        local icon_x = x + padding + 2
        local icon_y = text_y + 2
        love.graphics.setColor(colors.accent)
        love.graphics.rectangle("line", icon_x, icon_y, 16, 20, 2)
        love.graphics.line(icon_x + 10, icon_y, icon_x + 10, icon_y + 6, icon_x + 16, icon_y + 6)
        love.graphics.line(icon_x + 3, icon_y + 11, icon_x + 13, icon_y + 11)
        love.graphics.line(icon_x + 3, icon_y + 15, icon_x + 11, icon_y + 15)
        draw_text_lines(wrapped_lines(f.normal, display_text, math.max(32, wrap_width - 28)),
            x + padding + 26, text_y, f.normal, colors.text)
    else
        render_markdown(text, x + padding, text_y, wrap_width, f.normal, colors.text)
        local tags = helpers.hashtag_tokens(text)
        for _, tag in ipairs(tags) do
            for line_index, line in ipairs(lines) do
                local tag_start = line:find(tag, 1, true)
                if tag_start then
                    local tag_x = x + padding + f.normal:getWidth(line:sub(1, tag_start - 1))
                    local tag_y = text_y + (line_index - 1) * line_height
                    local tag_width = f.normal:getWidth(tag)
                    love.graphics.setColor(colors.accent)
                    love.graphics.line(tag_x, tag_y + line_height - 1, tag_x + tag_width, tag_y + line_height - 1)
                    self.hashtag_hits[#self.hashtag_hits + 1] = {
                        tag = tag, x = tag_x, y = tag_y, w = tag_width, h = line_height,
                    }
                    break
                end
            end
        end
    end

    if is_downloading then
        local progress_y = y + height - padding - small_height - 25 - reactions_height
        local downloaded = self:format_bytes(download_state.downloaded)
        local label
        if download_state.size > 0 then
            local remaining = math.max(0, download_state.size - download_state.downloaded)
            label = "Осталось " .. self:format_bytes(remaining)
            if download_state.progress then
                label = label .. string.format(" · %.0f%%", (1 - download_state.progress) * 100)
            end
        else
            label = downloaded .. " загружено"
        end
        ui.text(label, x + padding, progress_y, f.tiny, colors.muted)
        local bar_x = x + padding
        local bar_y = progress_y + f.tiny:getHeight() + 2
        local bar_w = bubble_w - padding * 2
        ui.rect(bar_x, bar_y, bar_w, 4, colors.header, 2)
        if download_state.progress and download_state.progress > 0 then
            ui.rect(bar_x, bar_y, bar_w * download_state.progress, 4, colors.accent, 2)
        end
    end

    if #reactions > 0 then
        local reactions_y = y + height - padding - small_height - reactions_height
        helpers.draw_reaction_rows(reactions, x + padding, reactions_y, f.tiny, colors)
    end

    local time_text = os.date("%H:%M", message.date or 0)
    ui.text(time_text, x + bubble_w - padding - f.tiny:getWidth(time_text), y + height - padding - f.tiny:getHeight(), f.tiny, colors.muted)
end

function messenger_screen:draw_input(panel_x, panel_w, h)
    local f = self.fonts
    local colors = ui.colors

    if self.sticker_link_mode then
        ui.rect(panel_x, h - INPUT_HEIGHT, panel_w, INPUT_HEIGHT, colors.header)
        ui.text("Введите ссылку на стикерпак:", panel_x + 16, h - INPUT_HEIGHT + 16, f.small, colors.text)
        ui.text("> " .. self.sticker_link_input, panel_x + 16, h - INPUT_HEIGHT + 42, f.normal, colors.text)
        ui.text("Enter — открыть  Esc — отмена", panel_x + 16, h - INPUT_HEIGHT + 66, f.tiny, colors.muted)
        return
    end

    local input_x = panel_x + 16
    local input_y = h - INPUT_HEIGHT + 16
    local send_w = 96
    local input_w = panel_w - 32 - send_w - 12

    ui.rect(panel_x, h - INPUT_HEIGHT, panel_w, INPUT_HEIGHT, colors.header)
    ui.rect(input_x, input_y, input_w, 42, colors.panel_alt, 8)
    ui.outline(input_x, input_y, input_w, 42, colors.accent_dark, 8)

    local shown = self.model.input
    if shown == "" then shown = "Сообщение..." end
    ui.text(ui.fit(shown, f.normal, input_w - 24), input_x + 12, input_y + 11, f.normal, self.model.input == "" and colors.muted or colors.text)

    ui.rect(input_x + input_w + 12, input_y, send_w, 42, colors.accent, 8)
    ui.printf("Отправить", input_x + input_w + 12, input_y + 11, send_w, "center", f.small, colors.text)
end




local function render_formatted_text(text, entities, x, y, width, font, color)
  if not text or text == "" then return end
  local cps = {}
  for p, c in utf8.codes(text) do cps[#cps+1] = {pos = p, cp = c} end
  local function style_at(idx)
    for _, e in ipairs(entities or {}) do
      local etype = e.type and e.type["@type"]
      local off = (e.offset or 0) + 1
      local len = e.length or 0
      if idx >= off and idx < off + len then
        if etype == "textEntityTypeBold" then return "bold" end
        if etype == "textEntityTypeItalic" then return "italic" end
        if etype == "textEntityTypeCode" then return "code" end
        if etype == "textEntityTypePre" or etype == "textEntityTypePreCode" then return "code" end
        if etype == "textEntityTypeUnderline" then return "underline" end
        if etype == "textEntityTypeStrikethrough" then return "strike" end
        if etype == "textEntityTypeTextUrl" or etype == "textEntityTypeUrl" then return "link" end
      end
    end
    return "plain"
  end
  local runs = {}
  local cur = nil
  for idx, info in ipairs(cps) do
    if info.cp == 10 then
      if cur then runs[#runs+1] = cur; cur = nil end
      runs[#runs+1] = {text = "\n", style = "newline"}
    else
      local st = style_at(idx)
      local ch = utf8.char(info.cp)
      if not cur or cur.style ~= st then
        if cur then runs[#runs+1] = cur end
        cur = {text = ch, style = st}
      else
        cur.text = cur.text .. ch
      end
    end
  end
  if cur then runs[#runs+1] = cur end
  local line_h = font:getHeight()
  local cur_x = x
  local cur_y = y
  for _, run in ipairs(runs) do
    if run.style == "newline" then
      cur_x = x
      cur_y = cur_y + line_h
    else
      local seg_color = (run.style == "bold" and {1,1,1,1}) or (run.style == "italic" and {0.85,0.85,0.95,1}) or (run.style == "code" and {0.9,0.9,0.6,1}) or (run.style == "link" and {0.4,0.7,1,1}) or color
      for word in run.text:gmatch("%S+") do
        local w = font:getWidth(word .. " ")
        if cur_x + w > x + width and cur_x > x then
          cur_x = x
          cur_y = cur_y + line_h
        end
        ui.text(word, cur_x, cur_y, font, seg_color)
        if run.style == "bold" then ui.text(word, cur_x + 1, cur_y, font, seg_color) end
        cur_x = cur_x + font:getWidth(word .. " ")
      end
      if run.text:match("%s$") then
        cur_x = cur_x + font:getWidth(" ")
      end
    end
  end
  love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
end

return messenger_screen
