-- src/features/chat/ui/input/search_handler.lua
-- Extracted from chat_screen_input.lua - search functionality

local ui = require("src.shared.ui.ui_kit")

local search_handler = {}

function search_handler.setup(ms)
    ms.search_active = false
    ms.search_query = ""
    ms.search_changed_at = 0
    ms.search_submitted_query = nil
    ms.hashtag_hits = {}
end

function search_handler.set_search_query(ms, query, submit)
    ms.search_query = query
    ms.search_changed_at = love.timer.getTime()
    if submit then
        ms.search_submitted_query = query
        ms.tg:search_dialog_messages(ms.tg.current_chat_id, query)
    end
end

function search_handler.submit_search(ms)
    ms.search_submitted_query = ms.search_query
    if ms.tg.current_chat_id then
        ms.tg:search_dialog_messages(ms.tg.current_chat_id, ms.search_query)
    end
end

function search_handler.update(ms, dt)
    if ms.search_active and ms.search_query ~= "" and ms.search_query ~= ms.search_submitted_query
        and love.timer.getTime() - ms.search_changed_at >= 0.25 then
        ms:submit_search()
    end
end

function search_handler.keypressed(ms, key)
    if not ms.search_active then return false end
    if key == "escape" then
        ms.search_active = false
        ms:set_search_query("", false)
    elseif key == "backspace" then
        ms:set_search_query(ui.remove_last_utf8(ms.search_query), false)
    elseif key == "return" or key == "kpenter" then
        ms:submit_search()
    end
    return true
end

function search_handler.textinput(ms, text)
    if ms.search_active then
        ms:set_search_query(ms.search_query .. text, false)
    end
end

function search_handler.draw(ms, f, colors, left_width, h)
    if not ms.search_active then return end
    -- Search UI is drawn in chat_screen draw()
end

return {
    setup = function(ms) end,
    keypressed = search_handler.keypressed,
    textinput = search_handler.textinput,
    update = search_handler.update,
}