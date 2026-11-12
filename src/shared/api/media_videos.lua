-- src/shared/api/media_videos.lua
-- Video handling extracted from media_methods.lua

local media_settings = require("src.shared.system.media_settings")

return function(telegram)
    local function diag(message)
        local handle = io.open("log.txt", "a")
        if handle then
            handle:write(string.format("[%s] %s\n", os.date("%Y-%m-%d %H:%M:%S"), message))
            handle:close()
        end
    end

    -- Thumbnail-first preview: download the small thumbnail file of a media object
    -- and load it into the owner's entry.image, so something is visible before
    -- (and even without) the full file decode.
    local function request_preview(self, kind, storage_name, owner_file_id, obj)
        if self.media_preview_by_file == nil then
            self.media_preview_by_file = {}
        end
        local thumbnail = obj and obj.thumbnail
        local thumb_file = thumbnail and (thumbnail.file or (thumbnail.photo and thumbnail.photo.file) or thumbnail.photo)
        if not thumb_file or not thumb_file.id then
            diag("PREVIEW: no thumb kind=" .. kind .. " owner=" .. tostring(owner_file_id))
            return false
        end
        local thumb_id = tonumber(thumb_file.id)
        if self.media_preview_by_file[thumb_id] then return true end
        local l = thumb_file["local"] or {}
        if l.is_downloading_completed and l.path and l.path ~= "" then
            self:load_image(owner_file_id, l.path, self[storage_name])
            diag("PREVIEW: loaded inline kind=" .. kind .. " owner=" .. tostring(owner_file_id))
            return true
        end
        self.media_preview_by_file[thumb_id] = {kind = kind, owner = owner_file_id, storage = storage_name}
        diag("PREVIEW: request kind=" .. kind .. " owner=" .. tostring(owner_file_id) ..
            " thumb=" .. tostring(thumb_id))
        self:send({
            ["@type"] = "downloadFile",
            file_id = thumb_id,
            priority = 16,
            offset = 0,
            limit = 0,
            synchronous = false,
        }, "thumb:" .. kind .. ":" .. tostring(thumb_id))
        return true
    end

    function telegram:choose_video_size(message)
        local content = message and message.content
        if not content or content["@type"] ~= "messageVideo" then
            return nil
        end
        -- TDLib nests the file object: content.video.video
        local video = content.video and content.video.video
        if not video or not video.id then return nil end
        return video
    end

    function telegram:choose_animation_size(message)
        local content = message and message.content
        if not content or content["@type"] ~= "messageAnimation" then
            return nil
        end
        -- TDLib nests the file object: content.animation.animation
        local animation = content.animation and content.animation.animation
        if not animation or not animation.id then return nil end
        return animation
    end

    function telegram:ensure_video(message)
        if not message or not message.id then
            return
        end
        local file_id = self.video_by_message[message.id]
        if file_id then
            local entry = self.videos[file_id]
            if entry then
                return entry
            end
            -- Already requested download, waiting for it to complete
            return nil
        end
        local video = self:choose_video_size(message)
        if not video then
            diag("ensure_video: no video.size msg=" .. tostring(message.id) ..
                " type=" .. tostring(message.content and message.content["@type"]) ..
                " video_id=" .. tostring(message.content and message.content.video and message.content.video.id))
            return
        end
        file_id = video.id
        local entry = self.videos[file_id]
        request_preview(self, "video", "videos", file_id, message.content and message.content.video)
        local content = message.content or {}
        local duration = content.video and content.video.duration
        if not entry then
            local extra = self:send({
                ["@type"] = "downloadFile",
                file_id = file_id,
                priority = 1,
                offset = 0,
                limit = 0,
                synchronous = false,
            }, "video:" .. tostring(file_id))
            if not extra then
                return nil
            end
            entry = {status = "downloading", duration = tonumber(duration), autoplay = media_settings.get("autoplay_videos")}
            self.videos[file_id] = entry
            self.video_by_message[message.id] = file_id
        elseif not entry.duration and tonumber(duration) then
            entry.duration = tonumber(duration)
        end
        return entry
    end

    function telegram:ensure_animation(message)
        if not message or not message.id then return end
        local file_id = self.animation_by_message[message.id]
        if file_id then
            diag("ensure_animation: already mapped msg=" .. tostring(message.id) .. " id=" .. tostring(file_id))
            return self.animations[file_id]
        end

        local animation = self:choose_animation_size(message)
        if not animation then
            local ok_json, content_dump = pcall(function()
                local dkjson = require("dkjson")
                return dkjson.encode(message.content)
            end)
            diag("ensure_animation: no animation.size msg=" .. tostring(message.id) ..
                " type=" .. tostring(message.content and message.content["@type"]) ..
                " content=" .. tostring(content_dump or "encode-fail"))
            -- probe TDLib directly: what does getMessage return for this message?
            local mtype = message.content and message.content["@type"]
            if message.chat_id and (mtype == "messageUnsupported" or mtype == "messageAnimation"
                or mtype == "messageVideo") then
                local probe = self.message_probe_sent or {}
                self.message_probe_sent = probe
                if not probe[message.id] then
                    probe[message.id] = true
                    self:send({
                        ["@type"] = "getMessage",
                        chat_id = message.chat_id,
                        message_id = message.id,
                    }, "msgprobe:" .. tostring(message.id))
                end
            end
            return
        end
        
        file_id = animation.id
        local entry = self.animations[file_id]
        request_preview(self, "animation", "animations", file_id, message.content and message.content.animation)
        if not entry then
            local extra = self:send({
                ["@type"] = "downloadFile",
                file_id = file_id,
                priority = 1,
                offset = 0,
                limit = 0,
                synchronous = false,
            }, "animation:" .. tostring(file_id))
            if not extra then
                return nil
            end
            entry = {status = "downloading"}
            self.animations[file_id] = entry
            self.animation_by_message[message.id] = file_id
        end
        -- GIF autoplay intentionally OFF: user starts playback via A / fullscreen / manual toggle
        entry.autoplay = false
        return entry
    end

    function telegram:ensure_video_note(message)
        if not message or not message.id then return end
        local file_id = self.video_note_by_message[message.id]
        if file_id then return self.video_notes[file_id] end
        
        local content = message.content
        local note = content and content.video_note
        local video_note = note and note.video
        if not video_note or not video_note.id then return end
        
        file_id = video_note.id
        local entry = self.video_notes[file_id]
        request_preview(self, "video_note", "video_notes", file_id, note)
        if not entry then
            local extra = self:send({
                ["@type"] = "downloadFile",
                file_id = file_id,
                priority = 1,
                offset = 0,
                limit = 0,
                synchronous = false,
            }, "video_note:" .. tostring(file_id))
            if not extra then
                return nil
            end
            entry = {status = "downloading", duration = tonumber(note.duration), autoplay = false}
            self.video_notes[file_id] = entry
            self.video_note_by_message[message.id] = file_id
        end
        if entry then entry.autoplay = false end
        return entry
    end

    function telegram:video_image(message)
        local content = message and message.content or {}
        local file_id, entry
        if content["@type"] == "messageVideoNote" then
            file_id = self.video_note_by_message and self.video_note_by_message[message.id]
            entry = file_id and self.video_notes[file_id]
        else
            file_id = self.video_by_message[message.id]
            entry = file_id and self.videos[file_id]
        end
        if entry then
            local image = entry.image
            if entry.frames and #entry.frames > 0 then
                image = entry.frames[1]
                local step = math.max(0.03, entry.frame_dt or (1 / 10))
                local position = entry.playing
                    and math.max(0, love.timer.getTime() - (entry.play_origin or love.timer.getTime()))
                    or (tonumber(entry.play_position) or 0)
                local index = math.floor(position / step) % #entry.frames + 1
                image = entry.frames[index] or image
            end
            if image then
                return image, entry.width or image:getWidth(), entry.height or image:getHeight()
            end
            if entry.image then
                return entry.image, entry.width, entry.height
            end
        end
        return nil
    end

    function telegram:video_note_image(message)
        local file_id = self.video_note_by_message[message.id]
        local entry = file_id and self.video_notes[file_id]
        if entry then
            local image = entry.image
            if entry.frames and #entry.frames > 0 then
                image = entry.frames[1]
                local step = math.max(0.03, entry.frame_dt or (1 / 10))
                local position = entry.playing
                    and math.max(0, love.timer.getTime() - (entry.play_origin or love.timer.getTime()))
                    or (tonumber(entry.play_position) or 0)
                local index = math.floor(position / step) % #entry.frames + 1
                image = entry.frames[index] or image
            end
            if image then
                return image, entry.width or image:getWidth(), entry.height or image:getHeight()
            end
            if entry.image then
                return entry.image, entry.width, entry.height
            end
        end
        return nil
    end

    function telegram:animation_image(message)
        local file_id = self.animation_by_message[message.id]
        local entry = file_id and self.animations[file_id]
        if entry then
            local image = entry.image
            if entry.frames and #entry.frames > 0 then
                image = entry.frames[1]
                local step = math.max(0.03, entry.frame_dt or (1 / 10))
                local position = entry.playing
                    and math.max(0, love.timer.getTime() - (entry.play_origin or love.timer.getTime()))
                    or (tonumber(entry.play_position) or 0)
                local index = math.floor(position / step) % #entry.frames + 1
                image = entry.frames[index] or image
            end
            if image then
                return image, entry.width or image:getWidth(), entry.height or image:getHeight()
            end
            if entry.image then
                return entry.image, entry.width, entry.height
            end
        end
        return nil
    end

    function telegram:load_video(file_id, path)
        local entry = self.videos[file_id]
        if not entry then return end
        entry.source_path = path
        self:queue_media_decode("video", file_id, path, not entry.autoplay)
    end

    function telegram:load_video_note(file_id, path)
        local entry = self.video_notes[file_id]
        if not entry then return end
        entry.source_path = path
        self:queue_media_decode("video_note", file_id, path, not entry.autoplay)
    end

    function telegram:load_animation(file_id, path)
        local entry = self.animations[file_id]
        if not entry then return end
        entry.source_path = path
        if entry.image then return end
        self:load_image(file_id, path, self.animations)
        local entry2 = self.animations[file_id]
        if entry2 and not entry2.image then
            local converted = self:convert_to_png(path)
            if converted then
                self:load_image(file_id, converted, self.animations)
            end
        end
    end
end