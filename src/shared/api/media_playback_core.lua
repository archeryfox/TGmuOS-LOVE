-- src/shared/api/media_playback_core.lua
-- Decoder/thread infrastructure for media playback.
-- Split from media_playback.lua: worker lifecycle, decode queues
-- and the decoder poll loop. Playback controls remain in media_playback.lua.

return function(telegram)
    function telegram:ensure_media_decoder()
        if self.anim_worker then return true end
        self.anim_in:clear()
        self.anim_out:clear()
        self.anim_worker = love.thread.newThread("threads/anim_decode.lua")
        self.anim_worker:start()
        return true
    end

    function telegram:media_entry(kind, file_id)
        if kind == "animation" then return self.animations[file_id] end
        if kind == "video" then return self.videos[file_id] end
        if kind == "sticker" then return self.stickers[file_id] end
        if kind == "voice" then return self.voice_notes[file_id] end
        if kind == "audio" then return self.audios[file_id] end
        return nil
    end

    function telegram:media_file_for_message(message)
        if not message or not message.id then
            return nil, nil, nil
        end
        local content = message.content or {}
        local kind, file_id
        if content["@type"] == "messageVideo" then
            kind = "video"
            file_id = self.video_by_message[message.id]
            if not file_id and content.video then
                file_id = content.video.id
                self.video_by_message[message.id] = file_id
            end
        elseif content["@type"] == "messageVideoNote" then
            kind = "video_note"
            file_id = self.video_note_by_message[message.id]
            if not file_id and content.video_note and content.video_note.video_note then
                file_id = content.video_note.video_note.id
                self.video_note_by_message[message.id] = file_id
            end
        elseif content["@type"] == "messageAnimation" then
            kind = "animation"
            file_id = self.animation_by_message[message.id]
            if not file_id and content.animation then
                file_id = content.animation.id
                self.animation_by_message[message.id] = file_id
            end
        elseif content["@type"] == "messagePhoto" then
            kind = "photo"
            file_id = self.photo_by_message[message.id]
            if not file_id then
                local size = self:choose_photo_size(message)
                file_id = size and size.photo and size.photo.id
                self.photo_by_message[message.id] = file_id
            end
        elseif content["@type"] == "messageSticker" then
            kind = "sticker"
            file_id = self.sticker_by_message[message.id]
            if not file_id and content.sticker and content.sticker.sticker then
                file_id = content.sticker.sticker.id
                self.sticker_by_message[message.id] = file_id
            end
        elseif content["@type"] == "messageVoiceNote" then
            kind = "voice"
            file_id = self.voice_by_message[message.id]
            if not file_id and content.voice_note and content.voice_note.voice then
                file_id = content.voice_note.voice.id
                self.voice_by_message[message.id] = file_id
            end
        elseif content["@type"] == "messageAudio" then
            kind = "audio"
            file_id = self.audio_by_message[message.id]
            if not file_id and content.audio and content.audio.audio then
                file_id = content.audio.audio.id
                self.audio_by_message[message.id] = file_id
            end
        end
        if not kind or not file_id then
            return nil, nil, nil
        end
        local entry
        if kind == "photo" then entry = self.photos[file_id]
        elseif kind == "video" then entry = self.videos[file_id]
        elseif kind == "video_note" then entry = self.video_notes[file_id]
        elseif kind == "animation" then entry = self.animations[file_id]
        elseif kind == "sticker" then entry = self.stickers[file_id]
        elseif kind == "voice" then entry = self.voice_notes[file_id]
        elseif kind == "audio" then entry = self.audios[file_id]
        end
        return kind, file_id, entry
    end

    function telegram:queue_media_decode(kind, file_id, path, first_frame)
        local entry = self:media_entry(kind, file_id)
        if not entry or not path then return end
        if first_frame and (entry.preview_ready or entry.preview_requested or entry.frames) then return end
        if not first_frame and (entry.decode_requested or entry.frames) then return end
        self:ensure_media_decoder()
        local safe_id = tostring(file_id):gsub("[^%w_-]", "_")
        local mode = first_frame and "preview" or "playback"
        if first_frame then
            entry.preview_requested = true
        else
            entry.decode_requested = true
        end
        entry.status = "decoding"
        self.anim_in:push({
            type = "decode",
            kind = kind,
            file_id = file_id,
            path = path,
            sticker_format = kind == "sticker" and self.sticker_format_by_file[file_id] or nil,
            first_frame = first_frame == true,
            out_dir = love.filesystem.getSaveDirectory() .. "/anim_" .. kind .. "_" .. safe_id .. "_" .. mode,
        })
    end

    function telegram:ensure_animated_sticker(message)
        if not self:sticker_playback_supported(message) then return false end
        local _, file_id, entry = self:media_file_for_message(message)
        if not file_id or not entry then return false end
        if entry.sticker_autoplay_started then return true end

        entry.sticker_autoplay_started = true
        entry.autoplay = true
        if entry.frames and #entry.frames > 0 then
            entry.playing = true
            entry.play_origin = love.timer.getTime() - (tonumber(entry.play_position) or 0)
        elseif entry.source_path then
            self:queue_media_decode("sticker", file_id, entry.source_path)
        end
        return true
    end

    function telegram:queue_audio_decode(kind, file_id, path, duration)
        local entry = self:media_entry(kind, file_id)
        if not entry or not path or entry.audio_decode_requested or entry.audio_source then return end
        self:ensure_media_decoder()
        local safe_id = tostring(file_id):gsub("[^%w_-]", "_")
        entry.audio_decode_requested = true
        entry.status = "decoding"
        self.anim_in:push({
            type = "decode_audio",
            kind = kind,
            file_id = file_id,
            path = path,
            duration = duration,
            out_dir = love.filesystem.getSaveDirectory() .. "/audio_" .. kind .. "_" .. safe_id,
        })
    end

    local function load_decoded_frame(path, name)
        local file = io.open(path, "rb")
        if not file then return nil end
        local data = file:read("*a")
        file:close()
        if not data or data == "" then return nil end
        local ok_data, file_data = pcall(love.filesystem.newFileData, data, name)
        if not ok_data or not file_data then return nil end
        local ok_image_data, image_data = pcall(love.image.newImageData, file_data)
        if not ok_image_data or not image_data then return nil end
        local ok_image, image = pcall(love.graphics.newImage, image_data)
        if not ok_image then return nil end
        return image
    end

    local function load_audio_source(entry, path, file_id, looping)
        if not love.audio or not love.audio.newSource then
            entry.audio_error = "LÖVE audio module is disabled"
            return false
        end
        local file = io.open(path, "rb")
        if not file then
            entry.audio_error = "decoded audio file is missing"
            return false
        end
        local bytes = file:read("*a")
        file:close()
        local ok_data, data = pcall(love.filesystem.newFileData, bytes, "audio_" .. tostring(file_id) .. ".wav")
        if not ok_data or not data then
            entry.audio_error = tostring(data or "could not load audio data")
            return false
        end
        local ok_source, source = pcall(love.audio.newSource, data, "static")
        if not ok_source or not source then
            entry.audio_error = tostring(source or "could not create audio source")
            return false
        end
        if looping then
            pcall(source.setLooping, source, true)
        end
        entry.audio_source = source
        entry.audio_error = nil
        if entry.autoplay then
            if (tonumber(entry.play_position) or 0) > 0 then
                pcall(source.seek, source, entry.play_position)
            end
            local ok_play, play_error = pcall(source.play, source)
            if not ok_play then
                entry.audio_error = tostring(play_error)
                entry.playing = false
                return false
            end
        end
        return true
    end

    function telegram:poll_media_decoder()
        if not self.anim_out then return end
        while true do
            local result = self.anim_out:pop()
            if not result then break end
            if type(result) == "table" and result.file_id then
                local entry = self:media_entry(result.kind, result.file_id)
                if entry then
                    if not result.paths and (result.audio_path or result.audio_error) then
                        entry.audio_decode_requested = nil
                        if result.audio_path then
                            load_audio_source(entry, result.audio_path, result.file_id, false)
                            if (result.kind == "voice" or result.kind == "audio")
                                and entry.audio_source and entry.autoplay then
                                entry.playing = true
                            end
                        else
                            entry.audio_error = result.audio_error
                            if result.kind == "voice" or result.kind == "audio" then
                                entry.status = "error"
                            end
                        end
                        if (result.kind == "voice" or result.kind == "audio") and result.audio_path then
                            entry.status = entry.audio_source and "ready" or "error"
                        end
                    end
                    if not result.paths and result.error then
                        if result.first_frame then
                            entry.preview_requested = nil
                        else
                            entry.decode_requested = nil
                        end
                        entry.status = entry.image and "ready" or "error"
                        entry.decode_error = result.error
                        if entry.autoplay then
                            self.action_error = entry.decode_error
                            self.action_status = ""
                        end
                    end
                    if result.paths then
                        if result.first_frame then
                            entry.preview_requested = nil
                        else
                            entry.decode_requested = nil
                        end
                        if result.ok and type(result.paths) == "table" then
                            local frames = {}
                            for index, path in ipairs(result.paths) do
                                local image = load_decoded_frame(path, "media_" .. tostring(result.file_id) .. "_" .. tostring(index))
                                if image then frames[#frames + 1] = image end
                            end
                            if #frames > 0 then
                                entry.width = result.width or frames[1]:getWidth()
                                entry.height = result.height or frames[1]:getHeight()
                                entry.image = frames[1]
                                if result.audio_path then
                                    load_audio_source(entry, result.audio_path, result.file_id, false)
                                elseif result.kind == "video" and not result.first_frame then
                                    entry.audio_error = "no audio track found"
                                end
                                if result.first_frame then
                                    entry.preview_ready = true
                                    entry.status = "ready"
                                else
                                    entry.frames = frames
                                    entry.frame_dt = result.frame_dt or (1 / 10)
                                    entry.status = "ready"
                                    entry.playing = entry.autoplay == true
                                    entry.play_origin = love.timer.getTime() - (tonumber(entry.play_position) or 0)
                                end
                            else
                                entry.status = entry.image and "ready" or "error"
                                entry.decode_error = "no decodable frames"
                            end
                        else
                            entry.status = entry.image and "ready" or "error"
                            entry.decode_error = result.error or "media decoding failed"
                            if entry.autoplay then
                                self.action_error = entry.decode_error
                                self.action_status = ""
                            end
                        end
                    end
                elseif type(result) == "table" then
                    local voice_entry = result.kind == "voice" and self.voice_notes[result.file_id]
                    if voice_entry then
                        voice_entry.audio_decode_requested = nil
                        voice_entry.status = "error"
                        voice_entry.audio_error = result.audio_error or result.error or "audio decoding failed"
                    end
                end
            end
        end
    end
end
