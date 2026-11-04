-- src/shared/api/media_stickers.lua
-- Sticker handling extracted from media_methods.lua

return function(telegram)
    function telegram:choose_sticker_size(message)
        local content = message and message.content
        if not content or content["@type"] ~= "messageSticker" then
            return nil
        end
        local sticker = content.sticker and content.sticker.sticker
        if not sticker or not sticker.id then
            return nil
        end
        return sticker
    end

    function telegram:sticker_thumbnail_file(sticker)
        local thumbnail = sticker and sticker.thumbnail
        if not thumbnail then return nil end
        return thumbnail.file or (thumbnail.photo and thumbnail.photo.file) or thumbnail.photo
    end

    function telegram:ensure_sticker(message, sticker_format)
        local sticker = self:choose_sticker_size(message)
        if not sticker then return end

        local file = sticker.sticker or sticker
        if not file or not file.id then return end
        local file_id = file.id
        self.sticker_by_message[message.id] = file_id

        local format = sticker.format and sticker.format["@type"] or sticker_format
        self.sticker_format_by_file[file_id] = format

        local entry = self.stickers[file_id]
        if not entry then
            entry = {status = "remote", format = format}
            self.stickers[file_id] = entry
        else
            entry.format = format or entry.format
        end

        local file_local = file["local"] or {}
        if file_local.is_downloading_completed and file_local.path and file_local.path ~= "" then
            entry.source_path = file_local.path
            if not entry.image then self:load_sticker(file_id, file_local.path) end
        elseif not entry.download_requested then
            entry.download_requested = true
            entry.status = "downloading"
            self:send({
                ["@type"] = "downloadFile",
                file_id = file_id,
                priority = 1,
                offset = 0,
                limit = 0,
                synchronous = false,
            }, "sticker:" .. tostring(file_id))
        end
    end

    function telegram:load_sticker(file_id, path)
        -- Load sticker image from file path
    end

    function telegram:sticker_playback_supported(message)
        local sticker = self:choose_sticker_size(message)
        local format = sticker and sticker.format and sticker.format["@type"]
        return format == "stickerFormatWebm" or format == "stickerFormatTgs"
    end

    function telegram:sticker_image(message)
        local content = message and message.content
        if not content or content["@type"] ~= "messageSticker" then return nil end

        local sticker = content.sticker and content.sticker.sticker
        if not sticker or not sticker.id then return nil end

        local file_id = sticker.id
        local entry = self.stickers[file_id]
        if entry and entry.image then
            return entry.image, entry.width, entry.height
        end
        return nil
    end
end