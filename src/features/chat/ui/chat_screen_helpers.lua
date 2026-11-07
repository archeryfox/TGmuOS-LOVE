local ui = require("src.shared.ui.ui_kit")

local function wrapped_lines(font, text, width)
    local lines = {}
    local start = 1
    while true do
        local newline = text:find("\n", start, true)
        local paragraph = text:sub(start, newline and newline - 1 or #text)
        if paragraph == "" then
            lines[#lines + 1] = ""
        else
            local ok, _, paragraph_lines = pcall(font.getWrap, font, paragraph, width)
            if ok and type(paragraph_lines) == "table" and #paragraph_lines > 0 then
                for _, line in ipairs(paragraph_lines) do lines[#lines + 1] = line end
            else
                lines[#lines + 1] = paragraph
            end
        end
        if not newline then break end
        start = newline + 1
    end
    return lines
end

local function draw_circle_image(image, x, y, diameter)
    local scale = math.max(diameter / image:getWidth(), diameter / image:getHeight())
    local draw_w = image:getWidth() * scale
    local draw_h = image:getHeight() * scale
    love.graphics.stencil(function()
        love.graphics.circle("fill", x + diameter / 2, y + diameter / 2, diameter / 2)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, x + (diameter - draw_w) / 2, y + (diameter - draw_h) / 2, 0, scale, scale)
    love.graphics.setStencilTest()
end

local function draw_text_lines(lines, x, y, font, color)
    for index, line in ipairs(lines) do
        ui.text(line, x, y + (index - 1) * font:getHeight(), font, color)
    end
end

local function draw_settings_icon(x, y, color)
    love.graphics.setColor(color)
    love.graphics.setLineWidth(2)
    for index = 0, 7 do
        local angle = index * math.pi / 4
        love.graphics.line(
            x + math.cos(angle) * 6, y + math.sin(angle) * 6,
            x + math.cos(angle) * 10, y + math.sin(angle) * 10
        )
    end
    love.graphics.circle("line", x, y, 6)
    love.graphics.circle("line", x, y, 2)
    love.graphics.setLineWidth(1)
end

local function media_album_id(message)
    local id = message and message.media_album_id
    if not id or tostring(id) == "0" then return nil end
    return tostring(id)
end

local MONTHS_GENITIVE = {
    "января", "февраля", "марта", "апреля", "мая", "июня",
    "июля", "августа", "сентября", "октября", "ноября", "декабря",
}

local date_label

local function conversation_items(messages)
    local items = {}
    local last_day
    for _, message in ipairs(messages) do
        local timestamp = tonumber(message.date) or 0
        local day = os.date("%Y-%m-%d", timestamp)
        if day ~= last_day then
            items[#items + 1] = {
                date_label = date_label(timestamp),
            }
            last_day = day
        end
        local content = message.content
        local ctype = content and content["@type"]
        -- Service/action messages: render centered like date labels
        local action_text = nil
        if ctype == "messageChatAddMembers" then
            local members = content.member_user_ids or {}
            action_text = "Участник(и) добавлены в чат"
        elseif ctype == "messageChatDeleteMember" then
            action_text = "Участник покинул чат"
        elseif ctype == "messageChatChangeTitle" then
            action_text = "Название чата изменено: " .. tostring(content.title or "")
        elseif ctype == "messageChatChangePhoto" then
            action_text = "Фото чата изменено"
        elseif ctype == "messagePinMessage" then
            action_text = "Сообщение закреплено"
        elseif ctype == "messageBasicGroupChatCreate" or ctype == "messageSupergroupChatCreate" then
            action_text = "Группа создана"
        elseif ctype == "messageCall" then
            local duration = tonumber(content.duration) or 0
            local reason = content.discard_reason and content.discard_reason["@type"]
            if reason == "callDiscardReasonMissed" then
                action_text = "Пропущенный звонок"
            elseif reason == "callDiscardReasonDeclined" then
                action_text = "Звонок отклонён"
            elseif reason == "callDiscardReasonDisconnected" then
                action_text = "Звонок прерван"
            elseif reason == "callDiscardReasonHungUp" then
                if duration > 0 then
                    action_text = string.format("Звонок завершён (%d:%02d)", math.floor(duration / 60), duration % 60)
                else
                    action_text = "Звонок завершён"
                end
            else
                action_text = "Звонок"
            end
        elseif ctype == "messageChatSetTtl" then
            action_text = "Таймер самоуничтожения изменён"
        end
        if action_text then
            items[#items + 1] = {action_label = action_text}
        else
            local album_id = ctype == "messagePhoto" and media_album_id(message)
            local previous = items[#items]
            if album_id and previous and previous.album_id == album_id and #previous.messages < 10 then
                previous.messages[#previous.messages + 1] = message
            elseif album_id then
                items[#items + 1] = {album_id = album_id, messages = {message}}
            else
                items[#items + 1] = {message = message}
            end
        end
    end
    for index = #items, 1, -1 do
        local item = items[index]
        if item.messages and #item.messages == 1 then
            item.message = item.messages[1]
            item.messages = nil
        end
    end
    return items
end

date_label = function(timestamp)
    if not timestamp or timestamp <= 0 then return "" end
    local date = os.date("*t", timestamp)
    local day_month = tostring(date.day) .. " " .. MONTHS_GENITIVE[date.month]
    if date.year ~= os.date("*t").year then
        return tostring(date.year) .. " " .. day_month
    end
    return day_month
end

local function hashtag_tokens(text)
    local tokens = {}
    local index = 1
    while index <= #text do
        if text:sub(index, index) == "#" then
            local finish = index + 1
            while finish <= #text do
                local byte = text:byte(finish)
                local is_ascii_word = (byte >= 48 and byte <= 57)
                    or (byte >= 65 and byte <= 90)
                    or (byte >= 97 and byte <= 122)
                    or byte == 95
                if not is_ascii_word and byte < 128 then break end
                finish = finish + 1
            end
            if finish > index + 1 then
                tokens[#tokens + 1] = text:sub(index, finish - 1)
            end
            index = finish
        else
            index = index + 1
        end
    end
    return tokens
end

local function reaction_summary(message)
    local interaction_info = message and message.interaction_info
    local reactions = interaction_info and interaction_info.reactions
    local summary = {}
    for _, reaction in ipairs(reactions and reactions.reactions or {}) do
        local reaction_type = reaction.type or {}
        local type_name = reaction_type["@type"]
        local emoji = type_name == "reactionTypeEmoji" and reaction_type.emoji
            or type_name == "reactionTypePaid" and "⭐"
            or "✨"
        local count = tonumber(reaction.total_count) or 0
        if count > 0 then
            summary[#summary + 1] = {
                emoji = emoji,
                key = type_name == "reactionTypeEmoji" and emoji
                    or (tostring(type_name) .. ":" .. tostring(reaction_type.custom_emoji_id or "")),
                count = count,
                chosen = reaction.is_chosen == true,
            }
        end
    end
    return summary
end

local function merge_message_reactions(messages)
    local summary, by_emoji = {}, {}
    for _, message in ipairs(messages or {}) do
        for _, reaction in ipairs(reaction_summary(message)) do
            local merged = by_emoji[reaction.key]
            if merged then
                merged.count = merged.count + reaction.count
                merged.chosen = merged.chosen or reaction.chosen
            else
                merged = {
                    emoji = reaction.emoji,
                    count = reaction.count,
                    chosen = reaction.chosen,
                }
                by_emoji[reaction.key] = merged
                summary[#summary + 1] = merged
            end
        end
    end
    return summary
end

local function reaction_rows(summary, font, max_width)
    local rows = {}
    local row, row_width = {}, 0
    for _, reaction in ipairs(summary or {}) do
        local count = tostring(reaction.count)
        local width = font:getHeight() + font:getWidth(count) + 18
        if #row > 0 and row_width + width > max_width then
            rows[#rows + 1] = row
            row, row_width = {}, 0
        end
        row[#row + 1] = {reaction = reaction, count = count, width = width}
        row_width = row_width + width + (#row > 1 and 4 or 0)
    end
    if #row > 0 then rows[#rows + 1] = row end
    return rows
end

local function draw_reaction_rows(rows, x, y, font, colors)
    local chip_height = 20
    for row_index, row in ipairs(rows or {}) do
        local chip_x = x
        local chip_y = y + (row_index - 1) * 22
        for _, chip in ipairs(row) do
            local reaction = chip.reaction
            ui.rect(chip_x, chip_y, chip.width, chip_height,
                reaction.chosen and colors.accent_dark or colors.header, 10)
            if reaction.chosen then
                ui.outline(chip_x, chip_y, chip.width, chip_height, colors.accent, 10)
            end

            ui.text(reaction.emoji, chip_x + 5, chip_y + 3, font, colors.text)
            ui.text(chip.count, chip_x + 5 + font:getHeight(), chip_y + 3, font,
                reaction.chosen and colors.text or colors.muted)
            chip_x = chip_x + chip.width + 4
        end
    end
end

local function reaction_rows_width(rows)
    local max_width = 0
    for _, row in ipairs(rows or {}) do
        local width = math.max(0, (#row - 1) * 4)
        for _, chip in ipairs(row) do
            width = width + chip.width
        end
        max_width = math.max(max_width, width)
    end
    return max_width
end

local waveform_alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local waveform_values = {}
for index = 1, #waveform_alphabet do
    waveform_values[waveform_alphabet:sub(index, index)] = index - 1
end
local waveform_cache = {}

local function decode_waveform(encoded)
    if type(encoded) ~= "string" or encoded == "" then return {} end
    if waveform_cache[encoded] then return waveform_cache[encoded] end
    local bytes, accumulator, bit_count = {}, 0, 0
    for index = 1, #encoded do
        local value = waveform_values[encoded:sub(index, index)]
        if value then
            accumulator = accumulator * 64 + value
            bit_count = bit_count + 6
            if bit_count >= 8 then
                bit_count = bit_count - 8
                bytes[#bytes + 1] = math.floor(accumulator / (2 ^ bit_count)) % 256
                accumulator = accumulator % (2 ^ bit_count)
            end
        end
    end
    local samples = {}
    accumulator, bit_count = 0, 0
    for _, byte in ipairs(bytes) do
        accumulator = accumulator + byte * (2 ^ bit_count)
        bit_count = bit_count + 8
        while bit_count >= 5 do
            samples[#samples + 1] = accumulator % 32
            accumulator = math.floor(accumulator / 32)
            bit_count = bit_count - 5
        end
    end
    waveform_cache[encoded] = samples
    return samples
end

return {
    wrapped_lines = wrapped_lines,
    draw_circle_image = draw_circle_image,
    draw_text_lines = draw_text_lines,
    media_album_id = media_album_id,
    conversation_items = conversation_items,
    date_label = date_label,
    hashtag_tokens = hashtag_tokens,
    reaction_summary = reaction_summary,
    merge_message_reactions = merge_message_reactions,
    reaction_rows = reaction_rows,
    reaction_rows_width = reaction_rows_width,
    draw_reaction_rows = draw_reaction_rows,
    decode_waveform = decode_waveform,
}
