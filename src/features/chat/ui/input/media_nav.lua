-- src/features/chat/ui/input/media_nav.lua
-- Extracted from chat_screen_input.lua - media navigation in fullscreen

local media_nav = {}

function media_nav.media_nav_list(ms)
    local list = {}
    for _, message in ipairs(ms.nav_messages or {}) do
        local kind = message.content and message.content["@type"]
        if kind == "messagePhoto" then
            -- Expand photo albums into individual media items
            if message.content and message.content.photos then
                for i, _ in ipairs(message.content.photos) do
                    list[#list + 1] = {message = message, media_index = i, media_kind = "photo"}
                end
            else
                list[#list + 1] = {message = message, media_index = 1, media_kind = "photo"}
            end
        elseif kind == "messageVideo" then
            list[#list + 1] = {message = message, media_index = 1, media_kind = "video"}
        elseif kind == "messageVideoNote" then
            list[#list + 1] = {message = message, media_index = 1, media_kind = "video_note"}
        elseif kind == "messageAnimation" then
            list[#list + 1] = {message = message, media_index = 1, media_kind = "animation"}
        end
    end
    return list
end

function media_nav.switch_fullscreen_media(ms, delta)
    local fm = ms.fullscreen_media
    if not fm then return end
    local list = ms:media_nav_list()
    if #list == 0 then return end
    local index = 1
    for i, item in ipairs(list) do
        if item.message.id == fm.message.id and (item.media_index or 1) == (fm.media_index or 1) then
            index = i
            break
        end
    end
    local new_index = math.max(1, math.min(#list, index + delta))
    if new_index == index then return end
    local item = list[new_index]
    if fm.kind == "video" then
        ms.tg:stop_media_playback(fm.message)
    end
    local kind = item.media_kind
    if kind == "video" or kind == "video_note" then
        ms.fullscreen_media = {message = item.message, kind = kind == "video" and "video" or "video", video_note = kind == "video_note", media_index = item.media_index}
        ms.tg:request_media_playback(item.message)
    else
        ms.fullscreen_media = {message = item.message, kind = "photo", media_index = item.media_index}
    end
    ms.fullscreen_zoom = 1
    ms.player_controls = nil
end

function media_nav.update(ms, dt)
    -- No-op for now
end

return media_nav