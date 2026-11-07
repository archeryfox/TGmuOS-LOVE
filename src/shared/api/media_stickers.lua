-- src/shared/api/media_stickers.lua
-- Sticker handling extracted from media_methods.lua

return function(telegram)
    function telegram:choose_sticker_size(message)
        local content = message and message.content
        if not content then return nil end
        
        -- Handle messageSticker
        if content["@type"] == "messageSticker" then
            local sticker = content.sticker and content.sticker.sticker
            if not sticker or not sticker.id then return nil end
            return sticker
        end
        
        -- Handle messageDocument that might be a sticker (webm/tgs)
        if content["@type"] == "messageDocument" then
            local doc = content.document
            if doc then
                local mime = doc.mime_type or ""
                local fname = doc.file_name or ""
                if mime:match("^video/") or fname:match("%.webm$") or fname:match("%.tgs$") then
                    return doc
                end
            end
        end
        
        return nil
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

        local sticker_obj = message.content and message.content.sticker
        local format = (sticker_obj and sticker_obj.format and sticker_obj.format["@type"]) or sticker_format

        local file_local = file["local"] or {}
        -- Fallback: detect from file if format missing
        if not format and file_local.path then
            local ext = file_local.path:match("%.([^.]+)$")
            if ext == "webm" then format = "stickerFormatWebm"
            elseif ext == "tgs" then format = "stickerFormatTgs"
            end
        end

        self.sticker_format_by_file[file_id] = format

        local is_animated = (format == "stickerFormatWebm" or format == "stickerFormatTgs")

        local entry = self.stickers[file_id]
        if not entry then
            entry = {status = "remote", format = format, autoplay = is_animated}
            self.stickers[file_id] = entry
        else
            entry.format = format or entry.format
            if is_animated then entry.autoplay = true end
        end
        if file_local.is_downloading_completed and file_local.path and file_local.path ~= "" then
            entry.source_path = file_local.path
            if is_animated then
                -- Direct runtime pipeline for webm: skip GIF, decode webm -> frames
                if format == "stickerFormatWebm" then
                    self.animation_by_message[message.id] = file_id
                    if not self.animations[file_id] then
                        self.animations[file_id] = {status = "remote", autoplay = true}
                    end
                    local anim_entry = self.animations[file_id]
                    anim_entry.source_path = file_local.path
                    -- Preview: extract first frame as PNG (fast)
                    if not anim_entry.image then
                        local preview = self:convert_to_png(file_local.path)
                        if preview then
                            self:load_image(file_id, preview, self.animations)
                        end
                    end
                    if not anim_entry.frames and not anim_entry.decode_requested then
                        self:queue_media_decode("animation", file_id, file_local.path)
                    end
                else
                    -- TGS still needs conversion path; try GIF then fallback
                    local gif_path = self:convert_to_gif(file_local.path)
                    if gif_path then
                        self.animation_by_message[message.id] = file_id
                        if not self.animations[file_id] then
                            self.animations[file_id] = {status = "remote", autoplay = true}
                        end
                        local anim_entry = self.animations[file_id]
                        anim_entry.source_path = gif_path
                        if not anim_entry.image then
                            self:load_image(file_id, gif_path, self.animations)
                        end
                        if not anim_entry.frames and not anim_entry.decode_requested then
                            self:queue_media_decode("animation", file_id, gif_path)
                        end
                    else
                        local converted = self:convert_to_png(file_local.path)
                        if converted then
                            self:load_image(file_id, converted, self.stickers)
                        else
                            self:load_sticker(file_id, file_local.path)
                        end
                    end
                end
            else
                if not entry.image then
                    local converted = self:convert_to_png(file_local.path)
                    if converted then
                        self:load_image(file_id, converted, self.stickers)
                    else
                        self:load_sticker(file_id, file_local.path)
                    end
                end
            end
        elseif not entry.download_requested then
            entry.download_requested = true
            entry.status = "downloading"
            local extra = self:send({
                ["@type"] = "downloadFile",
                file_id = file_id,
                priority = 1,
                offset = 0,
                limit = 0,
                synchronous = false,
            }, "sticker:" .. tostring(file_id))
            if not extra then
                entry.download_requested = false
                entry.status = "remote"
            end
        end
    end

    function telegram:load_sticker(file_id, path)
        local entry = self.stickers[file_id]
        if not entry then return end
        local converted = self:convert_to_png(path)
        if converted then
            self:load_image(file_id, converted, self.stickers)
        else
            self:load_image(file_id, path, self.stickers)
        end
        -- Resend pending sticker if this file is now ready
        if self.pending_sticker_send and self.pending_sticker_send.sticker then
            local sticker = self.pending_sticker_send.sticker
            local f = sticker.sticker or sticker
            if f and f.id == file_id then
                local cid = self.pending_sticker_send.chat_id
                self.pending_sticker_send = nil
                self:send_sticker(cid, sticker)
            end
        end
    end

    function telegram:sticker_playback_supported(message)
        local content = message and message.content
        local sticker_obj = content and content.sticker
        local format = sticker_obj and sticker_obj.format and sticker_obj.format["@type"]
        return format == "stickerFormatWebm" or format == "stickerFormatTgs"
    end

    function telegram:sticker_image(message)
        local content = message and message.content
        if not content or content["@type"] ~= "messageSticker" then return nil end

        local sticker = content.sticker and content.sticker.sticker
        if not sticker or not sticker.id then return nil end

        local file_id = sticker.id
        local format = self.sticker_format_by_file[file_id]
        
        -- Fallback: detect from sticker object
        if not format then
            local fmt_obj = content.sticker and content.sticker.format
            format = fmt_obj and fmt_obj["@type"]
        end
        
        local is_animated = (format == "stickerFormatWebm" or format == "stickerFormatTgs")

        if is_animated then
            local image, w, h = self:animation_image(message)
            if image then return image, w, h end
        end

        local entry = self.stickers[file_id]
        if entry and entry.image then
            return entry.image, entry.width, entry.height
        end
        return nil
    end
end