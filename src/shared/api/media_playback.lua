-- src/shared/api/media_playback.lua
-- Playback controls: request/pause/resume/seek/stop and playback state.
-- Decoder/thread infrastructure lives in media_playback_core.lua.

return function(telegram)
    local MAX_DECODED_VIDEO_DURATION = 60

    function telegram:request_media_playback(message)
        local kind, file_id, entry = self:media_file_for_message(message)
        if not kind or not file_id or not entry then
            return false, "Этот формат анимации не поддерживается"
        end
        entry.autoplay = true
        entry.paused = false
        entry.play_position = 0
        if kind == "audio" then entry.audio_error = nil end
        if kind == "voice" or kind == "audio" then
            if entry.audio_source then
                local ok, err = pcall(function()
                    entry.audio_source:stop()
                    entry.audio_source:seek(0)
                    entry.audio_source:play()
                end)
                if not ok then
                    entry.audio_error = tostring(err)
                    return false, entry.audio_error
                end
                entry.playing = true
            elseif entry.source_path then
                self:queue_audio_decode(kind, file_id, entry.source_path, entry.duration)
            elseif kind == "audio" and entry.status ~= "downloading" then
                entry.status = "downloading"
                self:send({
                    ["@type"] = "downloadFile",
                    file_id = file_id,
                    priority = 1,
                    offset = 0,
                    limit = 0,
                    synchronous = false,
                }, "audio:" .. tostring(file_id))
            end
            return true
        end
        if entry.frames and #entry.frames > 0 then
            entry.playing = true
            entry.play_origin = love.timer.getTime()
            if entry.audio_source then
                local ok, err = pcall(function()
                    entry.audio_source:stop()
                    entry.audio_source:seek(0)
                    entry.audio_source:play()
                end)
                if not ok then
                    entry.audio_error = tostring(err)
                end
            end
            return true
        end
        if entry.source_path then
            self:queue_media_decode(kind, file_id, entry.source_path, false)
        end
        return true
    end

    function telegram:media_playback_state(message)
        local kind, _, entry = self:media_file_for_message(message)
        if not kind or not entry then return 0, 0, false end
        local content = message.content or {}
        local duration = tonumber(entry.duration)
        if not duration then
            if content["@type"] == "messageVideo" then
                duration = tonumber(content.video and content.video.duration)
            elseif content["@type"] == "messageVideoNote" then
                duration = tonumber(content.video_note and content.video_note.duration)
            elseif content["@type"] == "messageVoiceNote" then
                duration = tonumber(content.voice_note and content.voice_note.duration)
            elseif content["@type"] == "messageAudio" then
                duration = tonumber(content.audio and content.audio.duration)
            end
        end
        if (kind == "video" or kind == "audio" or kind == "voice") and entry.audio_source then
            local ok, source_duration = pcall(entry.audio_source.getDuration, entry.audio_source, "seconds")
            if ok and tonumber(source_duration) and source_duration > 0 then duration = tonumber(source_duration) end
        elseif (kind == "video" or kind == "sticker" or kind == "animation") and entry.frames and #entry.frames > 0 then
            duration = #entry.frames * (entry.frame_dt or (1 / 10))
        end
        duration = math.max(0, duration or 0)
        if kind == "video" then duration = math.min(duration, MAX_DECODED_VIDEO_DURATION) end

        local position = tonumber(entry.play_position) or 0
        if entry.audio_source then
            local ok, source_position = pcall(entry.audio_source.tell, entry.audio_source, "seconds")
            if ok and tonumber(source_position) then position = tonumber(source_position) end
        elseif entry.playing then
            position = math.max(0, love.timer.getTime() - (entry.play_origin or love.timer.getTime()))
        end
        if (kind == "sticker" or kind == "animation") and entry.playing and duration > 0 then
            position = position % duration
        end
        position = math.min(duration > 0 and duration or position, math.max(0, position))
        entry.play_position = position
        return position, duration, entry.playing == true
    end

    function telegram:pause_media_playback(message)
        local kind, _, entry = self:media_file_for_message(message)
        if not kind or not entry then return false end
        local position = self:media_playback_state(message)
        entry.play_position = position
        entry.playing = false
        entry.paused = true
        entry.autoplay = false
        if entry.audio_source then
            pcall(entry.audio_source.pause, entry.audio_source)
        end
        return true
    end

    function telegram:resume_media_playback(message)
        local kind, _, entry = self:media_file_for_message(message)
        if not kind or not entry then return false end
        if not entry.frames and not entry.audio_source then
            return self:request_media_playback(message)
        end
        local position = self:media_playback_state(message)
        entry.play_position = position
        entry.playing = true
        entry.paused = false
        entry.play_origin = love.timer.getTime() - position
        if entry.audio_source then
            local ok, err = pcall(function()
                entry.audio_source:seek(position)
                entry.audio_source:play()
            end)
            if not ok then
                entry.playing = false
                entry.audio_error = tostring(err)
                return false
            end
        end
        return true
    end

    function telegram:seek_media_playback(message, position)
        local kind, _, entry = self:media_file_for_message(message)
        if not kind or not entry then return false end
        local _, duration = self:media_playback_state(message)
        position = math.max(0, tonumber(position) or 0)
        if duration > 0 then position = math.min(duration, position) end
        entry.play_position = position
        entry.play_origin = love.timer.getTime() - position
        if entry.audio_source then
            local ok, err = pcall(entry.audio_source.seek, entry.audio_source, position)
            if not ok then
                entry.audio_error = tostring(err)
                return false
            end
        end
        return true
    end

    function telegram:stop_media_playback(message)
        local kind, _, entry = self:media_file_for_message(message)
        if entry then
            entry.autoplay = false
            entry.playing = false
            entry.paused = false
            entry.play_position = 0
            if entry.audio_source then
                pcall(entry.audio_source.stop, entry.audio_source)
            end
        end
        return kind ~= nil
    end

    function telegram:media_download_state(message)
        local kind, file_id, entry = self:media_file_for_message(message)
        if not entry then return nil end
        return {
            kind = kind,
            file_id = file_id,
            status = entry.status,
            downloaded = entry.downloaded_bytes or 0,
            size = entry.total_bytes or 0,
            progress = entry.download_progress,
        }
    end
end
