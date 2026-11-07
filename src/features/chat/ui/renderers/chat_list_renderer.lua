-- src/features/chat/ui/renderers/chat_list_renderer.lua
-- Extracted from chat_screen.lua - draws the chat list

local ui = require("src.shared.ui.ui_kit")
local chat_item = require("src.entities.chat.ui.chat_item")

local chat_list_renderer = {}

function chat_list_renderer.draw(ms, left_width, h)
    local f = ms.fonts
    local colors = ui.colors
    local chat_list = ms:get_visible_chat_list()
    local list_h = h - HEADER_HEIGHT
    local visible = math.max(1, math.floor(list_h / ITEM_HEIGHT))

    ms.model:update_list_offset(visible)

    ui.rect(0, HEADER_HEIGHT, left_width, list_h, colors.panel)
    ui.rect(left_width - 1, HEADER_HEIGHT, 1, list_h, colors.bg)

    if #chat_list == 0 then
        if ms.search_active and ms.search_query ~= "" then
            local search_error = ms.tg.chat_search_error or ms.tg.public_search_error
            local label = search_error or "Чаты не найдены"
            ui.printf(label, 16, HEADER_HEIGHT + 40, left_width - 32, "left", f.small, colors.muted)
        else
            ui.printf("Нет чатов", 16, HEADER_HEIGHT + 40, left_width - 32, "left", f.small, colors.muted)
        end
        return
    end

    for index = ms.model.list_offset + 1, math.min(#chat_list, ms.model.list_offset + visible) do
        local chat = chat_list[index]
        if chat and chat.id then ms.tg:ensure_chat_photo(chat.id) end
        local y = HEADER_HEIGHT + (index - ms.model.list_offset - 1) * ITEM_HEIGHT
        local is_selected = index == ms.model.selected
        local is_current = ms.tg.current_chat_id == chat.id

        chat_item.draw(ms, chat, 0, y, left_width, ITEM_HEIGHT, ms.fonts, ui.colors, is_selected, is_current)
    end
end

return chat_list_renderer